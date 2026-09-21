import { Injectable } from '@nestjs/common';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { calendarSlug } from '../calendar/calendar.types';
import { PlannedBlock } from '../time/scheduling';
import { minutesOf } from '../time/work-hours';
import { CardKind, ThreadSummary } from './entities/thread.entity';
import { intervalOf, sectionOf } from './thread-timing';
import { ThreadsStore } from './threads.store';

/**
 * One block of occupied time, whatever it came from.
 *
 * The layout does not care whether a block is a Google event or a thread
 * somebody gave an hour to: both are time that is spoken for.
 */
export interface TimeBlock extends PlannedBlock {
  kind: CardKind;
  title: string;
}

/**
 * The timeline, assembled.
 *
 * Two sources, one list, ordered by the clock. Threads come off the
 * filesystem and calendar events come off the snapshot the agent pushes, and
 * where a thread *is* the calendar event only the thread is drawn, so the
 * same hour never appears twice.
 *
 * Nothing here decides where a card sits. The card has a start time, the
 * start time picks the section, and that is the whole filing system.
 */
@Injectable()
export class TimelineService {
  constructor(
    private readonly _store: ThreadsStore,
    private readonly _calendar: CalendarReaderService,
  ) {}

  /**
   * Every card the timeline shows, earliest first.
   *
   * Anything whose hour has run out is closed on the way past. The list is
   * read constantly — the app asks again on every minute boundary — so this
   * is where a day closes itself out, with no clock ticking anywhere on the
   * server and nothing to schedule or keep alive.
   */
  async cards(userId: string, now = new Date()): Promise<ThreadSummary[]> {
    await this._store.sweep(userId, now);

    const cards = (await this._store.readAllSummaries(userId, now)).filter(
      (card) =>
        !card.solved &&
        sectionOf(now, {
          start: new Date(card.startTime),
          end: new Date(card.endTime),
        }) !== undefined,
    );

    for (const block of await this._unlinkedEvents(userId)) {
      // A meeting that is over is not owed to anyone, so unlike a thread it
      // simply stops being drawn once it has ended.
      if (block.interval.end <= now) continue;

      const section = sectionOf(now, block.interval);
      if (section === undefined) continue;

      cards.push({
        kind: 'calendar',
        slug: calendarSlug(block.id),
        title: block.title,
        preview: '',
        messageCount: 0,
        solved: false,
        section,
        startTime: block.interval.start.toISOString(),
        endTime: block.interval.end.toISOString(),
        durationMinutes: block.minutes,
        fixed: true,
        createdAt: block.interval.start,
        updatedAt: block.interval.start,
      });
    }

    return cards.sort(
      (a, b) => Date.parse(a.startTime) - Date.parse(b.startTime),
    );
  }

  /**
   * Every block of time that is spoken for, [excludeSlug] aside.
   *
   * The thread being moved is left out, because a thread already on the
   * calendar would otherwise collide with itself the moment anyone tried to
   * move it half an hour.
   */
  async blocks(
    userId: string,
    options: { excludeSlug?: string } = {},
  ): Promise<TimeBlock[]> {
    const blocks: TimeBlock[] = [];

    for (const thread of await this._store.readAll(userId)) {
      if (thread.slug === options.excludeSlug) continue;
      if (thread.solved) continue;

      const interval = intervalOf(thread.timing);
      if (thread.timing === undefined || interval === undefined) continue;

      blocks.push({
        kind: 'thread',
        id: thread.slug,
        title: thread.title,
        minutes: thread.timing.durationMinutes,
        fixed: thread.timing.fixed,
        interval,
      });
    }

    for (const event of await this._unlinkedEvents(userId)) {
      if (calendarSlug(event.id) === options.excludeSlug) continue;
      blocks.push(event);
    }

    return blocks.sort(
      (a, b) => a.interval.start.getTime() - b.interval.start.getTime(),
    );
  }

  /**
   * The events with no thread behind them, as blocks that cannot move.
   *
   * The calendar is read first and the threads after, and that order is the
   * whole of what keeps a freshly booked block from being drawn twice. The
   * calendar queue is writing while this runs: it creates an event, writes
   * the id onto its thread, and puts the event in the cache. Reading the
   * threads first would mean catching a thread before it claimed its event
   * and the cache after the event arrived, and the booking would appear
   * beside the thread it belongs to as somebody else's meeting.
   *
   * This way round, anything the cache did not have yet is simply not drawn
   * this time, and every claim made before the read is seen.
   */
  private async _unlinkedEvents(userId: string): Promise<TimeBlock[]> {
    const events = await this._calendar.events();

    const linked = new Set<string>();
    for (const slug of await this._store.listSlugs(userId)) {
      const state = await this._store.readState(userId, slug);
      const eventId = state.timing?.calendarEventId;
      if (eventId !== undefined) linked.add(eventId);
    }

    const blocks: TimeBlock[] = [];
    for (const event of events) {
      // A booked thread is already in the list above, under its own title.
      if (linked.has(event.id)) continue;

      const interval = {
        start: new Date(event.startTime),
        end: new Date(event.endTime),
      };

      blocks.push({
        kind: 'calendar',
        id: event.id,
        title: event.title,
        minutes: minutesOf(interval),
        // A meeting is somebody else's hour. Nothing here gets to move it.
        fixed: true,
        interval,
      });
    }

    return blocks;
  }
}
