import { Injectable, NotFoundException } from '@nestjs/common';
import { A2uiParserService } from '../a2ui/a2ui-parser.service';
import { A2uiPromptService } from '../a2ui/a2ui-prompt.service';
import { A2uiValidationService } from '../a2ui/a2ui-validation.service';
import { emptyReplyUi, unavailableUi } from '../a2ui/a2ui.builders';
import { A2uiComponent } from '../a2ui/a2ui.types';
import { Trace } from '../common/trace';
import {
  AgentUnavailableError,
  AgentService,
  GenerateResult,
  ToolDescriptor,
} from './agent.service';
import { Message, MessageMetadata } from './entities/message.entity';
import { Thread, ThreadSummary } from './entities/thread.entity';
import { messageId, slugify, titleFrom } from './thread-markdown';
import { ThreadsStore } from './threads.store';

/**
 * A thread, end to end.
 *
 * One turn is always the same five steps: write what the user said, build the
 * prompt, ask the agent, read what came back, write the answer. The agent runs
 * whatever tools it needs inside step three, so there is one place where a turn
 * can go wrong and one trace that describes it.
 */
@Injectable()
export class ThreadsService {
  constructor(
    private readonly store: ThreadsStore,
    private readonly agent: AgentService,
    private readonly prompt: A2uiPromptService,
    private readonly parser: A2uiParserService,
    private readonly validator: A2uiValidationService,
  ) {}

  async findAll(userId: string): Promise<ThreadSummary[]> {
    return this.store.readAllSummaries(userId);
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

    await this.store.append(userId, slug, titleFrom(text), [
      userMessage(text),
    ]);
    await this._answer(userId, slug, trace);

    return this.findOne(userId, slug);
  }

  /** Appends a message to an existing thread and answers it. */
  async addMessage(
    userId: string,
    slug: string,
    text: string,
    trace: Trace,
  ): Promise<Thread> {
    const thread = await this.findOne(userId, slug);
    trace.log('thread.message', { slug, length: text.length });

    await this.store.append(userId, slug, thread.title, [userMessage(text)]);
    await this._answer(userId, slug, trace);

    return this.findOne(userId, slug);
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
      case 'solve':
        await this.store.updateState(userId, slug, { solved: true });
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
      note?: string;
      toolRuns?: MessageMetadata['toolRuns'];
    } = {},
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
        note: options.note,
      });

      trace.log('prompt.built', {
        messageCount: messages.length,
        systemChars: messages[0]?.content.length ?? 0,
        tools: tools.map((tool) => tool.name),
      });

      result = await this.agent.generate({ userId, slug, messages }, trace);
    } catch (error) {
      await this._handleUnavailable(userId, slug, thread.title, trace, error);
      return;
    }

    const toolRuns = [
      ...(options.toolRuns ?? []),
      ...result.toolTrace.map((entry) => ({
        name: entry.name,
        ok: entry.ok,
        durationMs: entry.durationMs,
        error: entry.error,
      })),
    ];

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

    await this._appendUi(userId, slug, thread.title, validated.component, {
      contentType: 'a2ui',
      model: result.model,
      latencyMs: result.latencyMs,
      traceId: trace.id,
      toolRuns: toolRuns.length > 0 ? toolRuns : undefined,
      a2uiIssues: validated.issues.length > 0 ? validated.issues : undefined,
      parseStrategy: parsed.strategy,
    });

    await this._saveTrace(userId, slug, trace);
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
  return 1 + (component.children ?? []).reduce(
    (total, child) => total + countComponents(child),
    0,
  );
}
