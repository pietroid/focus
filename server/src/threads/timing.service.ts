import { Injectable, NotFoundException } from '@nestjs/common';
import { startNowGuard } from '../a2ui/a2ui.guards';
import { A2uiComponent, TimingAction } from '../a2ui/a2ui.types';
import { isCalendarSlug } from '../calendar/calendar.types';
import { CalendarWriterService } from '../calendar/calendar-writer.service';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { CalendarSyncService } from '../calendar/calendar-sync.service';
import { Trace } from '../common/trace';
import { moved, PlannedBlock, relayout } from '../time/scheduling';
import {
  addMinutes,
  earliestStart,
  Interval,
  nextFreeSlot,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import { Thread, ThreadSummary, ThreadTiming } from './entities/thread.entity';
import { TimeBlock, TimelineService } from './timeline.service';
import { ThreadsStore } from './threads.store';

/** What a move produced: the timeline, and a question if one is still open. */
export interface TimingOutcome {
  cards: ThreadSummary[];
  /** The guard to draw. Absent means the move went through. */
  guard?: A2uiComponent;
}

/** What the user said when they wrote something down. */
export interface ScheduleRequest {
  durationMinutes: number;
  /** Whether the hour is the point of it. */
  fixed: boolean;
  /** ISO 8601. Only a fixed block gets to name one. */
  startTime?: string;
}

/**
 * When things happen.
 *
 * Two operations, and one rule underneath both. The rule is that the day is a
 * queue of flexible blocks flowing around a handful of fixed ones, packed as
 * close to now as they will go. Adding drops something into the first gap
 * that fits without disturbing anybody; dragging rewrites the queue order and
 * lets the whole thing repack.
 *
 * No model is involved, and nothing is asked that arithmetic can answer. The
 * single surviving question is what to do with the thing that was already
 * running when something else was dragged on top of it.
 *
 * **The store goes first and Google follows.** Every hour here is also an
 * hour on Google, but the drag does not wait for it: the day is laid out,
 * written, and answered, and a reconciliation is queued behind the response.
 * See [CalendarSyncService] for why that is safe, and for what the user sees
 * on the rare occasion it does not work.
 */
@Injectable()
export class TimingService {
  constructor(
    private readonly _store: ThreadsStore,
    private readonly _timeline: TimelineService,
    private readonly _writer: CalendarWriterService,
    private readonly _calendar: CalendarReaderService,
    private readonly _syncs: CalendarSyncService,
  ) {}

  /**
   * Gives [slug] an hour and puts it in the calendar.
   *
   * A flexible block takes the first gap that fits, which is what "as close
   * to now as possible without moving anything" means in one line. A fixed
   * one takes the hour it was given, whatever else is there: the user named
   * it, so it is not the server's to negotiate.
   */
  async schedule(
    userId: string,
    slug: string,
    request: ScheduleRequest,
    trace: Trace,
    now = new Date(),
  ): Promise<ThreadSummary[]> {
    const thread = await this._require(userId, slug);
    const blocks = await this._timeline.blocks(userId, { excludeSlug: slug });

    const slot = this._slotFor(request, blocks, now);
    trace.log('timing.schedule', {
      slug,
      fixed: request.fixed,
      start: slot.start.toISOString(),
    });

    await this._book(userId, thread, slot, request.fixed, trace);

    return this._timeline.cards(userId, now);
  }

  /**
   * Moves [slug] to [index] in the day's queue and repacks around it.
   *
   * The index is a place in the whole timeline rather than in a section,
   * because the sections are only the clock reading itself back: there is one
   * list, and a drop is a place in it.
   */
  async move(
    userId: string,
    action: TimingAction,
    trace: Trace,
    now = new Date(),
  ): Promise<TimingOutcome> {
    await this._require(userId, action.slug);

    const cards = await this._timeline.cards(userId, now);
    const running = cards.find(
      (card) =>
        card.kind === 'thread' &&
        card.slug !== action.slug &&
        Date.parse(card.startTime) <= now.getTime() &&
        Date.parse(card.endTime) > now.getTime(),
    );

    // The only destructive drag there is: something else is happening, and
    // the user has just said this is what they are doing instead.
    if (action.index === 0 && running !== undefined && !action.decision) {
      return {
        cards,
        guard: startNowGuard(action.slug, action.index, {
          title: running.title,
          interval: {
            start: new Date(running.startTime),
            end: new Date(running.endTime),
          },
        }),
      };
    }

    const closed =
      action.decision === 'solve_current' && running !== undefined
        ? running.slug
        : undefined;

    if (closed !== undefined) await this._solve(userId, closed, trace);

    // The thread that was just closed is out of the day, so it is out of the
    // queue too. Laying it out again would leave a hole in the afternoon the
    // shape of something nobody is going to do.
    //
    // A calendar that refuses throws out of here. Whatever was already
    // rebooked stays rebooked and stays in step with Google; the rest is
    // untouched, so the day is half-rearranged but never out of sync.
    await this._repack(userId, this._queue(cards, action, closed), trace, now);

    return { cards: await this._timeline.cards(userId, now) };
  }

  /**
   * Marks [slug] done and closes the hole it leaves in the day.
   *
   * Finishing something early gives its hour back, and an afternoon with a
   * gap in it where a finished thing used to be is a day that has stopped
   * describing itself. So the rest of the queue is laid out again from now:
   * everything flexible moves up into the space, around whatever is fixed,
   * by the same function a drag uses. Solving is a rearrangement like any
   * other; it just happens to be the one where a block leaves the queue.
   *
   * A calendar that refuses does not undo the solve. The thread is done
   * whatever Google thinks, and having the card spring back onto the
   * timeline because a rebooking timed out would be the app arguing with
   * the user about something they already know. The day is left part-packed,
   * every part of it still in step with the calendar, and the next drag
   * lays it out again.
   */
  async solve(
    userId: string,
    slug: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const cards = await this._timeline.cards(userId, now);

    await this._solve(userId, slug, trace);

    try {
      await this._repack(userId, this._blocksOf(cards, slug), trace, now);
    } catch (error) {
      trace.warn('timing.repackFailed', {
        slug,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Takes [slug] out of the calendar, keeping the hour it had.
   *
   * Solving frees the hour on Google, because leaving a booking behind for
   * something the user has finished would be the calendar disagreeing with
   * the screen. The hour itself stays on the thread: it is when the thing was
   * done, which is the one useful thing the concluded list can say about it.
   */
  async release(userId: string, slug: string, trace: Trace): Promise<void> {
    const state = await this._store.readState(userId, slug);
    const timing = state.timing;
    if (timing?.calendarEventId === undefined) return;

    trace.log('timing.release', { slug, eventId: timing.calendarEventId });

    // Out of the picture the screen is drawn from straight away, so the hour
    // is free for the repack that is about to happen. Google is told behind
    // the response, like every other change.
    //
    // The id stays on the thread until the job has actually deleted the
    // event. Clearing it here would leave nothing pointing at the booking if
    // the delete failed, or if a create for this same thread were still in
    // the queue behind it: the event would exist on Google with no thread
    // claiming it, and the timeline would draw it as somebody else's meeting.
    await this._calendar.remove(timing.calendarEventId);

    this._sync(userId, slug, timing.calendarEventId, trace);
  }

  /** The hour a new block gets. */
  private _slotFor(
    request: ScheduleRequest,
    blocks: TimeBlock[],
    now: Date,
  ): Interval {
    if (request.fixed && request.startTime !== undefined) {
      const start = roundUpToFiveMinutes(new Date(request.startTime));
      return { start, end: addMinutes(start, request.durationMinutes) };
    }

    return nextFreeSlot(
      earliestStart(now),
      request.durationMinutes,
      blocks.map((block) => block.interval),
    );
  }

  /**
   * The day as a queue: every card in screen order, [closed] left out.
   *
   * The order on screen is the order of the queue, which is the whole of
   * what the sections are. Nothing here decides an hour; that is the
   * layout's job, and this only says what is in the day and in what order.
   */
  private _blocksOf(cards: ThreadSummary[], closed?: string): PlannedBlock[] {
    return cards
      .filter((card) => card.slug !== closed)
      .map((card): PlannedBlock => ({
        id: card.slug,
        minutes: card.durationMinutes,
        // An event is somebody else's hour, and so is a card whose hour is
        // the point of it. Neither is repacked.
        fixed: card.fixed || isCalendarSlug(card.slug),
        interval: {
          start: new Date(card.startTime),
          end: new Date(card.endTime),
        },
      }));
  }

  /**
   * The day's queue after the drop: every card in screen order, with the
   * dragged one lifted out and put back at [action.index].
   *
   * Calendar events stay in the queue so a drop counted past one lands where
   * the finger was, but they are anchors and so nothing ever assigns them a
   * new hour.
   */
  private _queue(
    cards: ThreadSummary[],
    action: TimingAction,
    closed?: string,
  ): PlannedBlock[] {
    const blocks = this._blocksOf(cards, closed);

    const from = blocks.findIndex((block) => block.id === action.slug);
    if (from === -1) return blocks;

    const [dragged] = blocks.splice(from, 1);
    // Dropping a card at the top is the user saying "now", which overrules
    // the hour it was pinned to. Nothing else about the drop can.
    const landing = action.index === 0 ? { ...dragged, fixed: false } : dragged;
    blocks.splice(Math.min(action.index, blocks.length), 0, landing);

    return blocks;
  }

  /** Lays the queue out from [now] and writes everything that moved. */
  private async _repack(
    userId: string,
    queue: PlannedBlock[],
    trace: Trace,
    now: Date,
  ): Promise<void> {
    const anchors = queue
      .filter((block) => block.fixed)
      .map((block) => block.interval);

    const placed = relayout(queue, anchors, earliestStart(now));

    for (const block of queue) {
      const slot = placed.get(block.id);
      if (slot === undefined || !moved(block, slot)) continue;

      trace.log('timing.repack', {
        slug: block.id,
        from: block.interval.start.toISOString(),
        to: slot.start.toISOString(),
      });

      await this._move(userId, block.id, slot, trace);
    }
  }

  /**
   * Moves one thread's hour.
   *
   * The hour is stored and the drag is done. Google is told afterwards, by a
   * job that reads the thread again rather than carrying these times with
   * it, so a card dragged three times in five seconds costs three instant
   * drops and one calendar that ends up at the third one.
   */
  private async _move(
    userId: string,
    slug: string,
    to: Interval,
    trace: Trace,
  ): Promise<void> {
    const state = await this._store.readState(userId, slug);
    if (state.timing === undefined) return;

    const when = {
      startTime: to.start.toISOString(),
      endTime: to.end.toISOString(),
    };

    await this._store.updateState(userId, slug, {
      timing: { ...state.timing, ...when },
    });

    const eventId = state.timing.calendarEventId;
    if (eventId !== undefined) {
      // The local copy moves now so the next layout, which may well run
      // before Google has answered, prices the day against the hour the user
      // can see rather than the one it used to have.
      await this._calendar.upsert({
        id: eventId,
        title: (await this._store.read(userId, slug))?.title ?? '',
        ...when,
      });
    }

    this._sync(userId, slug, eventId, trace);
  }

  /**
   * Gives [thread] the hour at [slot], and has Google told about it.
   *
   * The event id is not known yet and is not waited for. It arrives when the
   * reconciliation runs and is written onto the thread then; until it does,
   * the thread has an hour and no booking, which is exactly the state a
   * reconciliation exists to resolve.
   */
  private async _book(
    userId: string,
    thread: Thread,
    slot: Interval,
    fixed: boolean,
    trace: Trace,
  ): Promise<void> {
    const when = {
      startTime: slot.start.toISOString(),
      endTime: slot.end.toISOString(),
    };

    const timing: ThreadTiming = {
      durationMinutes: Math.round(
        (slot.end.getTime() - slot.start.getTime()) / 60_000,
      ),
      ...when,
      fixed,
      calendarEventId: thread.timing?.calendarEventId,
    };

    await this._store.updateState(userId, thread.slug, { timing });

    if (timing.calendarEventId !== undefined) {
      await this._calendar.upsert({
        id: timing.calendarEventId,
        title: thread.title,
        ...when,
      });
    }

    this._sync(userId, thread.slug, timing.calendarEventId, trace);
  }

  /** Closes a thread and gives its hour back. */
  private async _solve(
    userId: string,
    slug: string,
    trace: Trace,
  ): Promise<void> {
    trace.log('timing.solveCurrent', { slug });

    // Marked done before the calendar job is queued, never after. The job
    // reads the thread to decide what Google should hold, so queueing it
    // first is asking a question before writing down the answer: it would
    // read a thread that still wanted its booking and dutifully keep it.
    await this._store.updateState(userId, slug, { solved: true });
    await this.release(userId, slug, trace);
  }

  /**
   * Queues the one job that makes Google agree with the store.
   *
   * [known] is the event the thread had when the caller looked, and it is
   * only a hint: the job reads the thread again, because by the time it runs
   * the user may have dragged the card twice more, and pushing what was true
   * two drags ago would be the calendar catching up to the wrong moment.
   */
  private _sync(
    userId: string,
    slug: string,
    known: string | undefined,
    trace: Trace,
  ): void {
    this._syncs.enqueue(
      userId,
      slug,
      () => this._reconcile(userId, slug, known, trace),
      trace,
    );
  }

  /**
   * Makes the calendar say what the thread says, whatever either of them
   * said before.
   *
   * One rule decides everything: a thread should have an event exactly when
   * it has an hour and is not done. Everything else falls out of comparing
   * that to what Google currently holds, which is what makes this safe to
   * run twice, or late, or after three more changes have landed on top of
   * the one that queued it.
   */
  private async _reconcile(
    userId: string,
    slug: string,
    known: string | undefined,
    trace: Trace,
  ): Promise<void> {
    const thread = await this._store.read(userId, slug);
    const timing = thread?.timing;
    const eventId = timing?.calendarEventId ?? known;
    const wanted = thread !== null && !thread.solved && timing !== undefined;

    if (!wanted) {
      if (eventId === undefined) return;

      await this._writer.remove(eventId, trace);
      await this._calendar.remove(eventId);

      // Only now, with the booking actually gone, does the thread stop
      // claiming it. A thread reopened later starts from no event rather
      // than from one that was deleted while it was in the concluded list.
      if (timing !== undefined) {
        await this._store.updateState(userId, slug, {
          timing: { ...timing, calendarEventId: undefined },
        });
      }

      return;
    }

    const when = { startTime: timing.startTime, endTime: timing.endTime };

    if (eventId === undefined) {
      const event = await this._writer.create(
        { title: thread.title, ...when },
        trace,
      );

      // The thread claims the event before the event reaches the cache the
      // timeline is drawn from. The other order leaves a moment where the
      // calendar holds an event nothing has claimed, and a list read in that
      // moment draws it as somebody else's meeting sitting next to the
      // thread it actually belongs to.
      await this._store.updateState(userId, slug, {
        timing: { ...timing, calendarEventId: event.id },
      });
      await this._calendar.upsert({ ...event, title: thread.title });
      return;
    }

    await this._calendar.upsert({
      ...(await this._writer.move(eventId, when, trace)),
      title: thread.title,
    });
  }

  private async _require(userId: string, slug: string): Promise<Thread> {
    const thread = await this._store.read(userId, slug);
    if (thread === null) throw new NotFoundException(`No thread "${slug}"`);
    return thread;
  }
}
