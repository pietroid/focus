import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { A2uiParserService } from '../a2ui/a2ui-parser.service';
import { A2uiPromptService } from '../a2ui/a2ui-prompt.service';
import { A2uiValidationService } from '../a2ui/a2ui-validation.service';
import {
  containsConfirm,
  emptyReplyUi,
  unavailableUi,
  writeFailedUi,
} from '../a2ui/a2ui.builders';
import { syncFailedUi } from '../a2ui/a2ui.guards';
import { A2uiComponent, TimingAction } from '../a2ui/a2ui.types';
import {
  CalendarSyncService,
  SyncFailure,
} from '../calendar/calendar-sync.service';
import { isCalendarSlug } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import {
  AgentUnavailableError,
  AgentService,
  GenerateResult,
  ToolDescriptor,
} from './agent.service';
import { Message, MessageMetadata, ToolRun } from './entities/message.entity';
import { Thread, ThreadItem, ThreadSummary } from './entities/thread.entity';
import { messageId, slugify, titleFrom } from './thread-markdown';
import { toItem, ThreadsStore } from './threads.store';
import { TimelineService } from './timeline.service';
import {
  ScheduleRequest,
  TimingOutcome,
  TimingService,
} from './timing.service';

/** How the calendar catch-up went: nothing to say, or something to draw. */
export interface SyncOutcome {
  ok: boolean;
  /** The popup, when the calendar did not keep up. */
  guard?: A2uiComponent;
}

/**
 * A thread, end to end.
 *
 * One turn is always the same five steps: write what the user said, build the
 * prompt, ask the agent, read what came back, write the answer. The agent runs
 * whatever tools it needs inside step three, so there is one place where a turn
 * can go wrong and one trace that describes it.
 *
 * Step three has one extra input: whether this turn may change anything. Reads
 * always run. A write runs only when the user has just authorised it, and this
 * is the only place that decides so.
 */
@Injectable()
export class ThreadsService {
  constructor(
    private readonly store: ThreadsStore,
    private readonly agent: AgentService,
    private readonly prompt: A2uiPromptService,
    private readonly parser: A2uiParserService,
    private readonly validator: A2uiValidationService,
    private readonly timeline: TimelineService,
    private readonly timing: TimingService,
    private readonly syncs: CalendarSyncService,
  ) {}

  /** Every card the timeline draws: the threads, and the calendar beside them. */
  async findAll(userId: string): Promise<ThreadSummary[]> {
    return this.timeline.cards(userId);
  }

  /** Everything the user has closed, most recently touched first. */
  async findSolved(userId: string): Promise<ThreadItem[]> {
    return (await this.store.readAll(userId))
      .filter((thread) => thread.solved)
      .map(toItem)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  async findOne(userId: string, slug: string): Promise<Thread> {
    const thread = await this.store.read(userId, slug);
    if (thread === null) throw new NotFoundException(`No thread "${slug}"`);
    return thread;
  }

  /** One turn's trace, for debugging a reply after the fact. */
  async findTrace(
    userId: string,
    slug: string,
    traceId: string,
  ): Promise<unknown> {
    const trace = await this.store.readTrace(userId, slug, traceId);
    if (trace === null) throw new NotFoundException(`No trace "${traceId}"`);
    return trace;
  }

  /**
   * Starts a thread from its first message and answers it.
   *
   * The slug comes from the message, so a thread's folder says what it is
   * without anything having to open it.
   */
  async create(userId: string, text: string, trace: Trace): Promise<Thread> {
    const slug = await this._freeSlug(userId, slugify(text));
    trace.attachSlug(slug);
    trace.log('thread.create', { slug });

    await this.store.append(userId, slug, titleFrom(text), [userMessage(text)]);
    // Nothing has been proposed yet, so the first turn of a thread can only
    // read and propose.
    await this._answer(userId, slug, trace, { allowWrites: false });

    return this.findOne(userId, slug);
  }

  /**
   * Writes something down and puts it straight on the timeline.
   *
   * The Tempo half of the app, and deliberately not a conversation: the user
   * said what it is and how long it takes, which is everything needed to give
   * it an hour. No agent runs, nothing is proposed, and the card is on screen
   * by the time the sheet closes.
   */
  async createScheduled(
    userId: string,
    text: string,
    request: ScheduleRequest,
    trace: Trace,
  ): Promise<ThreadSummary[]> {
    const slug = await this._freeSlug(userId, slugify(text));
    trace.attachSlug(slug);
    trace.log('thread.createScheduled', {
      slug,
      durationMinutes: request.durationMinutes,
      fixed: request.fixed,
    });

    await this.store.append(userId, slug, titleFrom(text), [userMessage(text)]);

    try {
      return await this.timing.schedule(userId, slug, request, trace);
    } catch (error) {
      // The thread exists on disk by now but never got an hour, so it would
      // sit in Coisas as a ghost of something the user thinks failed. A
      // refused add leaves nothing behind.
      trace.error('thread.createScheduledFailed', { slug });
      await this.store.remove(userId, slug);
      throw error;
    }
  }

  /**
   * Appends a message to an existing thread and answers it.
   *
   * [armWrites] is true when the message came from a confirm action, which is
   * the user saying yes to a change described in the previous message.
   */
  async addMessage(
    userId: string,
    slug: string,
    text: string,
    trace: Trace,
    armWrites = false,
  ): Promise<Thread> {
    const thread = await this.findOne(userId, slug);
    trace.log('thread.message', { slug, length: text.length, armWrites });

    // Read before appending: the proposal is the message that was last on
    // screen when the user answered.
    const allowWrites =
      armWrites || this._awaitingConfirmation(thread.messages);

    await this.store.append(userId, slug, thread.title, [userMessage(text)]);
    await this._answer(userId, slug, trace, { allowWrites });

    return this.findOne(userId, slug);
  }

  /**
   * Whether the last thing the assistant said was a proposal.
   *
   * A tapped button is not the only way to say yes. Someone who reads "posso
   * agendar quinta às 10?" and types "pode" has confirmed it just as clearly,
   * and being told to use the button instead would be the pedantry this whole
   * flow exists to avoid. So the proposal arms the turn that answers it,
   * however that answer arrives.
   *
   * It arms exactly one turn. The next message lands after a reply that is no
   * longer a proposal, and the gate closes again.
   */
  private _awaitingConfirmation(messages: Message[]): boolean {
    for (let index = messages.length - 1; index >= 0; index--) {
      const message = messages[index];
      if (message.role !== 'agent') continue;
      return message.metadata?.proposedWrite === true;
    }
    return false;
  }

  /**
   * Moves one thread to [index] in the day's queue.
   *
   * One index rather than a whole placement. The old screen had three
   * hand-ordered lists and a drop changed the index of everything below it in
   * two of them at once, so the only safe thing to send was the result. There
   * is one list now and it is ordered by the clock, so a drop is a single
   * number and the server works out every hour from it.
   */
  async moveThread(
    userId: string,
    slug: string,
    index: number,
    trace: Trace,
  ): Promise<TimingOutcome> {
    if (isCalendarSlug(slug)) {
      throw new BadRequestException('A calendar event cannot be moved here');
    }

    trace.log('thread.move', { slug, index });

    return this.timing.move(userId, { type: 'timing', slug, index }, trace);
  }

  async applyTiming(
    userId: string,
    action: TimingAction,
    trace: Trace,
  ): Promise<TimingOutcome> {
    return this.timing.move(userId, action, trace);
  }

  /** Marks a thread solved, or puts an already solved one back. */
  async setSolved(
    userId: string,
    slug: string,
    solved: boolean,
    trace: Trace,
  ): Promise<ThreadSummary[]> {
    await this.findOne(userId, slug);
    trace.log('thread.solved', { slug, solved });

    // A solved thread gives its hour back, so the calendar and the screen go
    // on saying the same thing, and the day closes up over the space it left.
    // Reopening one puts it in Coisas with no hour, which is honest: the time
    // it had is long gone.
    if (solved) {
      await this.timing.solve(userId, slug, trace);
    } else {
      await this.store.updateState(userId, slug, { solved: false });
    }

    return this.findAll(userId);
  }

  /**
   * Waits for the queued calendar work and reports what the user should see.
   *
   * Nothing to say is the usual answer and the good one. When there is
   * something, it is a tree rather than an error: the day is not wrong, only
   * its copy on Google, and the user needs a button rather than an apology.
   */
  async awaitSync(userId: string, trace: Trace): Promise<SyncOutcome> {
    const failure = await this.syncs.settle(userId);
    if (failure !== undefined) {
      trace.warn('sync.behind', { slug: failure.slug, error: failure.error });
    }

    return this._syncOutcome(userId, failure);
  }

  /** Runs the failed calendar work again. */
  async retrySync(userId: string, trace: Trace): Promise<SyncOutcome> {
    return this._syncOutcome(userId, await this.syncs.retry(userId, trace));
  }

  private async _syncOutcome(
    userId: string,
    failure: SyncFailure | undefined,
  ): Promise<SyncOutcome> {
    if (failure === undefined) return { ok: true };

    const thread = await this.store.read(userId, failure.slug);

    return {
      ok: false,
      guard: syncFailedUi(thread?.title ?? failure.slug),
    };
  }

  /** Applies a thread-level change the app asked for. */
  async applyThreadOp(
    userId: string,
    slug: string,
    op: 'solve' | 'reopen' | 'rename' | 'delete',
    title: string | undefined,
    trace: Trace,
  ): Promise<Thread | null> {
    await this.findOne(userId, slug);
    trace.log('thread.op', { slug, op, title });

    switch (op) {
      // The same act as dragging the card aside, so the same path: the hour
      // goes back and the rest of the day moves up into it.
      case 'solve':
        await this.timing.solve(userId, slug, trace);
        break;
      case 'reopen':
        await this.store.updateState(userId, slug, { solved: false });
        break;
      case 'rename':
        if (title === undefined || title.trim() === '') {
          throw new NotFoundException('rename needs a title');
        }
        await this.store.updateState(userId, slug, { title: title.trim() });
        break;
      case 'delete':
        await this.store.remove(userId, slug);
        return null;
    }

    return this.findOne(userId, slug);
  }

  /**
   * Asks the agent for the next reply and writes it into the thread.
   *
   * Everything the user will read passes through parse, then validate, then
   * store. A reply that fails any of those still lands as a message, because a
   * thread that silently stops answering is harder to debug than one that says
   * what went wrong.
   */
  private async _answer(
    userId: string,
    slug: string,
    trace: Trace,
    options: {
      /** Whether a tool may change the user's data on this turn. */
      allowWrites: boolean;
      note?: string;
      toolRuns?: MessageMetadata['toolRuns'];
    },
  ): Promise<void> {
    const thread = await this.findOne(userId, slug);

    let tools: ToolDescriptor[] = [];
    let result: GenerateResult;

    try {
      tools = await this.agent.tools(trace);
      const messages = this.prompt.build({
        history: thread.messages,
        userMessage: '',
        tools,
        allowWrites: options.allowWrites,
        note: options.note,
      });

      trace.log('prompt.built', {
        messageCount: messages.length,
        systemChars: messages[0]?.content.length ?? 0,
        tools: tools.map((tool) => tool.name),
        allowWrites: options.allowWrites,
      });

      result = await this.agent.generate(
        { userId, slug, messages, allowWrites: options.allowWrites },
        trace,
      );
    } catch (error) {
      await this._handleUnavailable(userId, slug, thread.title, trace, error);
      return;
    }

    const toolRuns: ToolRun[] = [
      ...(options.toolRuns ?? []),
      ...result.toolTrace.map((entry) => ({
        name: entry.name,
        effect: entry.effect,
        ok: entry.ok,
        blocked: entry.blocked,
        durationMs: entry.durationMs,
        error: entry.error,
      })),
    ];

    // The one case where the model does not get the last word. A write that
    // was attempted and broke is where a reply is most likely to say "pronto,
    // agendei" over a tool result that says nothing of the sort, and no amount
    // of prompting makes that safe. The trace is the fact; the prose is not.
    const failure = this._failedWrite(result);
    if (failure !== undefined) {
      trace.error('turn.writeFailed', {
        tool: failure.name,
        error: failure.error,
        claimedLength: result.raw.length,
      });

      await this._appendUi(
        userId,
        slug,
        thread.title,
        writeFailedUi(failure.summary, failure.error ?? ''),
        {
          contentType: 'a2ui',
          model: result.model,
          latencyMs: result.latencyMs,
          traceId: trace.id,
          toolRuns,
          // The retry button is a confirm, so the next turn is still allowed to
          // run the write. Making the user re-approve something they already
          // approved, because the calendar timed out, would be punishing them
          // for an outage.
          proposedWrite: true,
        },
      );

      await this._saveTrace(userId, slug, trace);
      return;
    }

    const parsed = this.parser.parse(result.raw);
    trace.log('a2ui.parse', {
      strategy: parsed.strategy,
      detail: parsed.detail,
      rawLength: result.raw.length,
    });

    // A failed parse used to be wrapped anyway, as `children: [undefined]`.
    // The validator then rejected the child, dropped the empty Column, and the
    // user read a generic apology whose real cause was that the model had
    // returned nothing at all. It is its own outcome, and it says so.
    if (parsed.component === undefined) {
      trace.error('a2ui.parseFailed', {
        detail: parsed.detail,
        rawLength: result.raw.length,
        toolsRun: toolRuns.map((run) => run.name),
      });

      await this._appendUi(userId, slug, thread.title, emptyReplyUi(), {
        contentType: 'a2ui',
        model: result.model,
        latencyMs: result.latencyMs,
        traceId: trace.id,
        toolRuns: toolRuns.length > 0 ? toolRuns : undefined,
        parseStrategy: parsed.strategy,
      });

      await this._saveTrace(userId, slug, trace);
      return;
    }

    const validated = this.validator.validate(
      { component: 'Column', children: [parsed.component] },
      { toolNames: tools.map((tool) => tool.name) },
    );

    if (!validated.clean) {
      // Logged in full, because a reply that quietly lost a button looks fine
      // on screen and is invisible without this line.
      trace.warn('a2ui.repaired', {
        issues: validated.issues,
        strategy: parsed.strategy,
      });
    }

    trace.log('a2ui.validated', {
      clean: validated.clean,
      issues: validated.issues.length,
      components: countComponents(validated.component),
    });

    // A proposal arms the next turn, so it is recorded on the message rather
    // than inferred later from prose that no longer carries the action.
    const proposedWrite = containsConfirm(validated.component);
    if (proposedWrite) trace.log('turn.proposedWrite', {});

    await this._appendUi(userId, slug, thread.title, validated.component, {
      contentType: 'a2ui',
      model: result.model,
      latencyMs: result.latencyMs,
      traceId: trace.id,
      toolRuns: toolRuns.length > 0 ? toolRuns : undefined,
      a2uiIssues: validated.issues.length > 0 ? validated.issues : undefined,
      parseStrategy: parsed.strategy,
      proposedWrite: proposedWrite ? true : undefined,
    });

    await this._saveTrace(userId, slug, trace);
  }

  /**
   * The write that was attempted and broke, if the turn has one.
   *
   * A blocked write does not count: nothing was tried, and the reply proposing
   * it is exactly what should be shown. A write that failed and was then
   * retried successfully does not count either, which is why the whole trace is
   * weighed rather than the last entry.
   */
  private _failedWrite(
    result: GenerateResult,
  ): GenerateResult['toolTrace'][number] | undefined {
    const writes = result.toolTrace.filter((entry) => entry.effect === 'write');
    if (writes.some((entry) => entry.ok)) return undefined;
    return writes.find((entry) => entry.blocked !== true);
  }

  private async _handleUnavailable(
    userId: string,
    slug: string,
    title: string,
    trace: Trace,
    error: unknown,
  ): Promise<void> {
    const message = error instanceof Error ? error.message : String(error);
    trace.error('turn.unavailable', {
      error: message,
      kind: error instanceof AgentUnavailableError ? 'agent' : 'server',
    });

    await this._appendUi(userId, slug, title, unavailableUi(), {
      contentType: 'a2ui',
      traceId: trace.id,
      model: 'unavailable',
    });

    await this._saveTrace(userId, slug, trace);
  }

  private async _appendUi(
    userId: string,
    slug: string,
    title: string,
    component: A2uiComponent,
    metadata: MessageMetadata,
  ): Promise<void> {
    const createdAt = new Date();

    await this.store.append(userId, slug, title, [
      {
        id: messageId('agent', createdAt),
        role: 'agent',
        text: '',
        createdAt,
        metadata: { ...metadata, a2ui: component },
      },
    ]);
  }

  private async _saveTrace(
    userId: string,
    slug: string,
    trace: Trace,
  ): Promise<void> {
    try {
      await this.store.saveTrace(userId, slug, trace.id, {
        traceId: trace.id,
        slug,
        totalMs: trace.elapsedMs,
        events: trace.events,
      });
    } catch (error) {
      // A trace that cannot be written must never cost the user their reply.
      trace.warn('trace.saveFailed', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * The first slug not already taken, suffixed `-2`, `-3`, and so on.
   *
   * Two threads can genuinely start with the same sentence, and neither should
   * silently land in the other's folder.
   */
  private async _freeSlug(userId: string, base: string): Promise<string> {
    if (!(await this.store.exists(userId, base))) return base;

    for (let suffix = 2; suffix < 1000; suffix++) {
      const candidate = `${base}-${suffix}`;
      if (!(await this.store.exists(userId, candidate))) return candidate;
    }

    return `${base}-${Date.now()}`;
  }
}

function userMessage(text: string): Message {
  const createdAt = new Date();
  return {
    id: messageId('user', createdAt),
    role: 'user',
    text,
    createdAt,
  };
}

function countComponents(component: A2uiComponent): number {
  return (
    1 +
    (component.children ?? []).reduce(
      (total, child) => total + countComponents(child),
      0,
    )
  );
}
