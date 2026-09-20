import { Injectable, NotFoundException } from '@nestjs/common';
import {
  conflictGuard,
  durationGuard,
  guardFailedUi,
  GuardMove,
  scheduleGuard,
  unscheduleGuard,
} from '../a2ui/a2ui.guards';
import { A2uiComponent, TimingAction } from '../a2ui/a2ui.types';
import {
  CalendarWriteError,
  CalendarWriterService,
} from '../calendar/calendar-writer.service';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { Trace } from '../common/trace';
import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  conflictsWith,
  earliestStart,
  Interval,
  nextFreeSlot,
  nextWorkWindowStart,
  roundUpToFiveMinutes,
  workWindowFor,
} from '../time/work-hours';
import { Thread, ThreadSummary, ThreadTiming } from './entities/thread.entity';
import { intervalOf } from './thread-timing';
import { TimeBlock, TimelineService } from './timeline.service';
import { ThreadsStore } from './threads.store';

/** What a move produced: the timeline, and a question if one is still open. */
export interface TimingOutcome {
  cards: ThreadSummary[];
  /** The guard to draw. Absent means the move went through. */
  guard?: A2uiComponent;
}

/**
 * The rules about when things happen, and the guards that enforce them.
 *
 * Everything here is on the server on purpose. The app knows how to draw a
 * guard and how to send back the button that was tapped, and nothing else:
 * not the working day, not the gap between blocks, not what happens to the
 * afternoon when something is dropped into the middle of it. A drag therefore
 * costs a round trip, which the spec accepts, and in exchange there is one
 * copy of these rules rather than two that drift.
 *
 * No model is involved. A guard is the calendar, the clock, and arithmetic.
 */
@Injectable()
export class TimingService {
  constructor(
    private readonly _store: ThreadsStore,
    private readonly _timeline: TimelineService,
    private readonly _writer: CalendarWriterService,
    private readonly _calendar: CalendarReaderService,
  ) {}

  /**
   * Runs a move, asking whatever still needs asking.
   *
   * Called both by a drag, which carries no decision and so usually comes
   * back with a guard, and by a guard's own button, which carries one. The
   * two are the same call because they are the same move: the only difference
   * is how much of it the user has answered.
   */
  async resolve(
    userId: string,
    action: TimingAction,
    trace: Trace,
    now = new Date(),
  ): Promise<TimingOutcome> {
    const thread = await this._store.read(userId, action.slug);
    if (thread === null)
      throw new NotFoundException(`No thread "${action.slug}"`);

    const move: GuardMove = {
      slug: action.slug,
      bucket: action.bucket,
      index: action.index,
      durationMinutes: action.durationMinutes,
      startTime: action.startTime,
    };

    trace.log('timing.resolve', {
      slug: action.slug,
      bucket: action.bucket,
      decision: action.decision,
      durationMinutes: action.durationMinutes,
    });

    try {
      return action.bucket === 'depois'
        ? await this._toLater(userId, thread, move, action, trace)
        : await this._toSoonerOrNow(userId, thread, move, action, trace, now);
    } catch (error) {
      if (!(error instanceof CalendarWriteError)) throw error;

      trace.error('timing.calendarFailed', { error: error.message });
      return {
        cards: await this._timeline.cards(userId, now),
        guard: guardFailedUi('A agenda recusou a mudança. Nada foi alterado.'),
      };
    }
  }

  /**
   * Down to "Depois", which for anything booked means off the calendar.
   *
   * Parking something is the one move that can quietly undo a booking, so it
   * asks first. An untimed thread dropped here is just a drag and goes
   * through without a word.
   */
  private async _toLater(
    userId: string,
    thread: Thread,
    move: GuardMove,
    action: TimingAction,
    trace: Trace,
  ): Promise<TimingOutcome> {
    const interval = intervalOf(thread.timing);

    if (interval !== undefined && action.decision !== 'unschedule') {
      return {
        cards: await this._timeline.cards(userId),
        guard: unscheduleGuard(move, thread.title, interval),
      };
    }

    if (action.decision === 'unschedule') {
      const eventId = thread.timing.calendarEventId;
      if (eventId !== undefined) {
        await this._writer.remove(eventId, trace);
        await this._calendar.remove(eventId);
      }

      // The duration survives. It is the one thing the user told us that is
      // still true after the time is gone.
      await this._store.updateState(userId, thread.slug, {
        timing: { durationMinutes: thread.timing.durationMinutes },
      });
    }

    await this._place(userId, move);
    return { cards: await this._timeline.cards(userId) };
  }

  /**
   * Up to "Agora" or "Em breve", which is where the questions live.
   *
   * Three things have to be true before a card can sit up here: it takes a
   * known length of time, it has a slot, and the slot is free. Each one the
   * user has not answered yet is a guard, and they are asked in that order.
   */
  private async _toSoonerOrNow(
    userId: string,
    thread: Thread,
    move: GuardMove,
    action: TimingAction,
    trace: Trace,
    now: Date,
  ): Promise<TimingOutcome> {
    const durationMinutes =
      action.durationMinutes ?? thread.timing.durationMinutes;

    if (durationMinutes === undefined || durationMinutes <= 0) {
      return {
        cards: await this._timeline.cards(userId, now),
        guard: durationGuard(move, thread.title),
      };
    }

    const withDuration = { ...move, durationMinutes };
    const busy = await this._timeline.busy(userId, {
      excludeSlug: thread.slug,
    });
    const slot = this._proposeSlot(action, durationMinutes, busy, now);

    if (action.decision === undefined) {
      return {
        cards: await this._timeline.cards(userId, now),
        guard: scheduleGuard(withDuration, thread.title, slot),
      };
    }

    // Keeping it manual is a real answer: the thread moves, it now knows how
    // long it takes, and nothing reaches Google. The spec's "the chaos of
    // life sometimes doesn't allow" case.
    if (action.decision === 'manual') {
      await this._store.updateState(userId, thread.slug, {
        timing: { ...thread.timing, durationMinutes },
      });
      await this._place(userId, move);
      return { cards: await this._timeline.cards(userId, now) };
    }

    const collisions = conflictsWith(
      slot,
      busy.map((block) => block.interval),
    );
    if (collisions.length > 0 && action.decision === 'schedule') {
      const hit = busy.filter((block) =>
        collisions.some(
          (it) => it.start.getTime() === block.interval.start.getTime(),
        ),
      );

      return {
        cards: await this._timeline.cards(userId, now),
        guard: conflictGuard(
          { ...withDuration, startTime: slot.start.toISOString() },
          slot,
          hit.map((block) => ({
            title: block.title,
            interval: block.interval,
          })),
        ),
      };
    }

    if (action.decision === 'postpone') {
      await this._postpone(userId, slot, busy, trace);
    }

    await this._book(userId, thread, slot, trace);
    await this._place(userId, move);

    return { cards: await this._timeline.cards(userId, now) };
  }

  /**
   * The time being offered.
   *
   * "Agora" means now, even when now is busy: someone who drags a card to the
   * top of the screen is saying they are starting it, and the right answer to
   * a collision there is the conflict guard, not a quiet slot two hours
   * later. "Em breve" means the next time it actually fits.
   */
  private _proposeSlot(
    action: TimingAction,
    durationMinutes: number,
    busy: TimeBlock[],
    now: Date,
  ): Interval {
    if (action.startTime !== undefined) {
      const start = new Date(action.startTime);
      if (!Number.isNaN(start.getTime())) {
        return { start, end: addMinutes(start, durationMinutes) };
      }
    }

    if (action.bucket === 'agora') {
      // Not rounded up like every other proposal. "Agora" has to mean this
      // minute: a start five minutes out would put the card the user just
      // dragged to the top of the screen straight back into "Em breve", by
      // the same clock that is supposed to be keeping them honest.
      const start = earliestStart(now);
      start.setSeconds(0, 0);
      return { start, end: addMinutes(start, durationMinutes) };
    }

    return nextFreeSlot(
      now,
      durationMinutes,
      busy.map((block) => block.interval),
    );
  }

  /**
   * Pushes everything [slot] runs into later, in order, keeping the gap.
   *
   * The cascade stops at the first block that already starts after the
   * cursor: the afternoon closes back up on its own from there, and moving
   * things that did not need moving would be the guard rearranging a day it
   * was only asked to make room in.
   */
  private async _postpone(
    userId: string,
    slot: Interval,
    busy: TimeBlock[],
    trace: Trace,
  ): Promise<void> {
    let cursor = addMinutes(slot.end, BLOCK_GAP_MINUTES);

    for (const block of busy) {
      if (block.interval.start >= cursor) break;
      if (block.interval.end <= slot.start) continue;

      const minutes = Math.round(
        (block.interval.end.getTime() - block.interval.start.getTime()) /
          60_000,
      );
      const moved = this._placeAfter(cursor, minutes);

      trace.log('timing.postpone', {
        kind: block.kind,
        id: block.id,
        from: block.interval.start.toISOString(),
        to: moved.start.toISOString(),
      });

      if (block.kind === 'calendar') {
        const event = await this._writer.move(
          block.id,
          {
            startTime: moved.start.toISOString(),
            endTime: moved.end.toISOString(),
          },
          trace,
        );
        await this._calendar.upsert({ ...event, title: block.title });
      } else {
        await this._moveThread(userId, block.id, moved, trace);
      }

      cursor = addMinutes(moved.end, BLOCK_GAP_MINUTES);
    }
  }

  /** [minutes] starting at [at], or at the top of the next day if it spills. */
  private _placeAfter(at: Date, minutes: number): Interval {
    const start = roundUpToFiveMinutes(at);
    const end = addMinutes(start, minutes);
    const window = workWindowFor(start);

    if (end <= window.end) return { start, end };

    const tomorrow = nextWorkWindowStart(window);
    return { start: tomorrow, end: addMinutes(tomorrow, minutes) };
  }

  /** Moves a timed thread, and the event behind it when there is one. */
  private async _moveThread(
    userId: string,
    slug: string,
    to: Interval,
    trace: Trace,
  ): Promise<void> {
    const state = await this._store.readState(userId, slug);
    const eventId = state.timing?.calendarEventId;

    if (eventId !== undefined) {
      const event = await this._writer.move(
        eventId,
        { startTime: to.start.toISOString(), endTime: to.end.toISOString() },
        trace,
      );
      await this._calendar.upsert(event);
    }

    await this._store.updateState(userId, slug, {
      timing: {
        ...state.timing,
        startTime: to.start.toISOString(),
        endTime: to.end.toISOString(),
      },
    });
  }

  /** Puts [thread] on the calendar at [slot], creating or moving the event. */
  private async _book(
    userId: string,
    thread: Thread,
    slot: Interval,
    trace: Trace,
  ): Promise<void> {
    const when = {
      startTime: slot.start.toISOString(),
      endTime: slot.end.toISOString(),
    };

    const event =
      thread.timing.calendarEventId === undefined
        ? await this._writer.create({ title: thread.title, ...when }, trace)
        : await this._writer.move(thread.timing.calendarEventId, when, trace);

    await this._calendar.upsert({ ...event, title: thread.title });

    const timing: ThreadTiming = {
      durationMinutes: Math.round(
        (slot.end.getTime() - slot.start.getTime()) / 60_000,
      ),
      startTime: when.startTime,
      endTime: when.endTime,
      calendarEventId: event.id,
    };

    await this._store.updateState(userId, thread.slug, { timing });
  }

  /**
   * Writes where the card ended up.
   *
   * The bucket is still stored for a timed thread even though the clock
   * overrules it, because it is where the thread goes back to on the day its
   * time is taken away again.
   */
  private async _place(userId: string, move: GuardMove): Promise<void> {
    await this._store.updateState(userId, move.slug, {
      bucket: move.bucket,
      order: move.index,
    });
  }
}
