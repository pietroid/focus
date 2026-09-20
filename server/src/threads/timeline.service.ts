import { Injectable } from '@nestjs/common';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { calendarSlug } from '../calendar/calendar.types';
import { Interval, workWindowFor } from '../time/work-hours';
import { CardKind, ThreadSummary } from './entities/thread.entity';
import { derivedBucket, intervalOf } from './thread-timing';
import { compareCards, ThreadsStore } from './threads.store';

/**
 * One block of occupied time, whatever it came from.
 *
 * The guards do not care whether a block is a Google event or a thread
 * somebody gave a time to: both are time that is spoken for, and proposing
 * over either one would be proposing over something real.
 */
export interface TimeBlock {
  kind: CardKind;
  /** The event id, or the thread slug. */
  id: string;
  title: string;
  interval: Interval;
}

/**
 * The home screen, assembled.
 *
 * Two sources, one list. Threads come off the filesystem and calendar events
 * come off the snapshot the agent pushes, and where a thread is the calendar
 * event — because a guard booked it — only the thread is drawn. Otherwise the
 * same hour would appear twice and the screen would disagree with itself.
 */
@Injectable()
export class TimelineService {
  constructor(
    private readonly _store: ThreadsStore,
    private readonly _calendar: CalendarReaderService,
  ) {}

  /** Every card the timeline shows, in the order it draws them. */
  async cards(userId: string, now = new Date()): Promise<ThreadSummary[]> {
    const threads = await this._store.readAllSummaries(userId);
    const events = await this._unlinkedEvents(userId, now);

    const cards = [
      ...threads,
      ...events.map((event) => this._eventCard(event, now)),
    ];

    return cards.filter((card) => card !== null).sort(compareCards);
  }

  /**
   * Every block of time that is already spoken for, [excludeSlug] aside.
   *
   * The thread being moved is left out, because a thread already on the
   * calendar would otherwise collide with itself the moment anyone tried to
   * move it half an hour.
   */
  async busy(
    userId: string,
    options: { excludeSlug?: string } = {},
  ): Promise<TimeBlock[]> {
    const linked = new Map<string, string>();
    const blocks: TimeBlock[] = [];

    for (const thread of await this._store.readAllSummaries(userId)) {
      const state = await this._store.readState(userId, thread.slug);
      const eventId = state.timing?.calendarEventId;
      if (eventId !== undefined) linked.set(eventId, thread.slug);

      if (thread.slug === options.excludeSlug) continue;
      if (thread.solved) continue;

      const interval = intervalOf(state.timing);
      if (interval === undefined) continue;

      blocks.push({
        kind: 'thread',
        id: thread.slug,
        title: thread.title,
        interval,
      });
    }

    for (const event of await this._calendar.events()) {
      // A booked thread is already in the list above, under its own title.
      if (linked.has(event.id)) continue;
      if (calendarSlug(event.id) === options.excludeSlug) continue;

      blocks.push({
        kind: 'calendar',
        id: event.id,
        title: event.title,
        interval: {
          start: new Date(event.startTime),
          end: new Date(event.endTime),
        },
      });
    }

    return blocks.sort(
      (a, b) => a.interval.start.getTime() - b.interval.start.getTime(),
    );
  }

  /** The events with no thread behind them, that are worth drawing now. */
  private async _unlinkedEvents(userId: string, now: Date) {
    const linked = new Set<string>();
    for (const slug of await this._store.listSlugs(userId)) {
      const state = await this._store.readState(userId, slug);
      const eventId = state.timing?.calendarEventId;
      if (eventId !== undefined) linked.add(eventId);
    }

    // Only what is still ahead, and only as far as the end of the working day
    // being lived. The timeline answers "now" and "soon"; next Tuesday's
    // stand-up is the calendar's business and not this screen's.
    const horizon = workWindowFor(now).end;

    return (await this._calendar.events()).filter((event) => {
      if (linked.has(event.id)) return false;

      const end = new Date(event.endTime);
      const start = new Date(event.startTime);
      return end > now && start < horizon;
    });
  }

  /** One calendar event, as a card that cannot be touched. */
  private _eventCard(
    event: { id: string; title: string; startTime: string; endTime: string },
    now: Date,
  ): ThreadSummary {
    const start = new Date(event.startTime);
    const end = new Date(event.endTime);

    return {
      kind: 'calendar',
      slug: calendarSlug(event.id),
      title: event.title,
      preview: '',
      messageCount: 0,
      solved: false,
      bucket: derivedBucket(now, event) ?? 'em_breve',
      // Sorted by its start like every timed card, so the order it is given
      // here only has to be stable.
      order: start.getTime(),
      startTime: event.startTime,
      endTime: event.endTime,
      durationMinutes: Math.round((end.getTime() - start.getTime()) / 60_000),
      createdAt: start,
      updatedAt: start,
    };
  }
}
