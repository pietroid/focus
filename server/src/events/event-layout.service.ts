import { BadRequestException, Injectable } from '@nestjs/common';
import { startNowGuard } from '../a2ui/a2ui.guards';
import { A2uiComponent, TimingAction } from '../a2ui/a2ui.types';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { ThreadsStore } from '../threads/threads.store';
import { moved, PlannedBlock, relayout } from '../time/scheduling';
import {
  addMinutes,
  earliestStart,
  Interval,
  nextFreeSlot,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import { Zone } from '../time/zone';
import { EventCard, EventRequest } from './entities/event.entity';
import { isRunning } from './event-sections';
import { EventsService, TimeBlock } from './events.service';

/** What a move produced: the timeline, and a question if one is still open. */
export interface TimingOutcome {
  cards: EventCard[];
  /** The guard to draw. Absent means the move went through. */
  guard?: A2uiComponent;
}

/**
 * When things happen.
 *
 * Three operations, and one rule underneath all of them. The rule is that the
 * day is a queue of flexible blocks flowing around a handful of fixed ones,
 * packed as close to now as they will go. Adding drops something into the
 * first gap that fits without disturbing anybody; dragging rewrites the queue
 * order and lets the whole thing repack; finishing something takes it out and
 * closes the hole it left.
 *
 * No model is involved, and nothing is asked that arithmetic can answer. The
 * single surviving question is what to do with the thing that was already
 * running when something else was dragged on top of it.
 *
 * Every hour this works out is written to the calendar, because the calendar
 * is the only place an hour is kept. The write does not hold up the drop: see
 * [EventsService] for the order, and [CalendarSyncService] for what the user
 * sees on the rare occasion Google will not take it.
 */
@Injectable()
export class EventLayoutService {
  constructor(
    private readonly _events: EventsService,
    private readonly _threads: ThreadsStore,
  ) {}

  /**
   * Writes something down and puts it on the timeline.
   *
   * A flexible block takes the first gap that fits, which is what "as close
   * to now as possible without moving anything" means in one line. A fixed
   * one takes the hour it was given, whatever else is there: the user named
   * it, so it is not the server's to negotiate.
   *
   * Nothing is said and no thread is started. It is a block of time, and a
   * block of time that nobody has anything to say about yet is the normal
   * case rather than a thread waiting to happen.
   */
  async create(
    user: CalendarUser,
    request: EventRequest,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const blocks = await this._events.blocks(user);
    const slot = slotFor(
      request,
      blocks,
      now,
      await this._events.zone(user, now),
    );

    trace.log('event.create', {
      fixed: request.fixed,
      start: slot.start.toISOString(),
    });

    await this._events.book(
      user,
      { title: request.title, slot, fixed: request.fixed },
      trace,
    );

    return this._events.cards(user, now);
  }

  /**
   * Moves one block to [index] in the day's queue and repacks around it.
   *
   * The index is a place in the whole timeline rather than in a section,
   * because the sections are only the clock reading itself back: there is one
   * list, and a drop is a place in it.
   */
  async move(
    user: CalendarUser,
    action: TimingAction,
    trace: Trace,
    now = new Date(),
  ): Promise<TimingOutcome> {
    const event = await this._events.require(user, action.eventId);
    if (!event.managed) {
      throw new BadRequestException('A meeting cannot be moved here');
    }

    const zone = await this._events.zone(user, now);
    const cards = await this._events.cards(user, now);
    const running = cards.find(
      (card) =>
        card.managed &&
        card.id !== action.eventId &&
        Date.parse(card.startTime) <= now.getTime() &&
        Date.parse(card.endTime) > now.getTime(),
    );

    // The only destructive drag there is: something else is happening, and
    // the user has just said this is what they are doing instead.
    if (action.index === 0 && running !== undefined && !action.decision) {
      return {
        cards,
        guard: startNowGuard(
          action.eventId,
          action.index,
          {
            title: running.title,
            interval: {
              start: new Date(running.startTime),
              end: new Date(running.endTime),
            },
          },
          zone,
        ),
      };
    }

    const closed =
      action.decision === 'solve_current' && running !== undefined
        ? running.id
        : undefined;

    // The two blocks a drag is allowed to move out of their hour. Normally it
    // is just the card under the finger; when the user chose to keep what was
    // running and do it later, it is that one instead, because pushing it
    // down the day is the whole of what they asked for.
    const thawed =
      action.decision === 'postpone_current' ? running?.id : action.eventId;

    if (closed !== undefined) await this._finish(user, closed, trace);

    // The block that was just closed is out of the day, so it is out of the
    // queue too. Laying it out again would leave a hole in the afternoon the
    // shape of something nobody is going to do.
    await this._repack(
      user,
      queueOf(cards, action, now, { closed, thawed }),
      trace,
      now,
      zone,
    );

    return { cards: await this._events.cards(user, now) };
  }

  /**
   * Takes a block off the day and closes the hole it leaves.
   *
   * Finishing something early gives its hour back, and an afternoon with a
   * gap in it where a finished thing used to be is a day that has stopped
   * describing itself. So the rest of the queue is laid out again from now:
   * everything flexible moves up into the space, around whatever is fixed, by
   * the same function a drag uses. Finishing is a rearrangement like any
   * other; it just happens to be the one where a block leaves the queue.
   *
   * A calendar that refuses does not put the block back. It is done whatever
   * Google thinks, and having the card spring back onto the timeline because
   * a rebooking timed out would be the app arguing with the user about
   * something they already know.
   */
  async finish(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const zone = await this._events.zone(user, now);
    const cards = await this._events.cards(user, now);

    await this._finish(user, eventId, trace);

    try {
      await this._repack(
        user,
        blocksOf(cards, now, { closed: eventId }),
        trace,
        now,
        zone,
      );
    } catch (error) {
      trace.warn('event.repackFailed', {
        eventId,
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return this._events.cards(user, now);
  }

  /**
   * Off the calendar, and the conversation about it closed with it.
   *
   * The thread is not a mirror of the block, but it is about it: a block the
   * user has finished with is not something they still have an open question
   * about, and leaving the conversation in Coisas would be the app asking
   * them to close the same thing twice.
   */
  private async _finish(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
  ): Promise<void> {
    const event = await this._events.require(user, eventId);
    if (!event.managed) {
      throw new BadRequestException('A meeting cannot be finished here');
    }

    trace.log('event.finish', { eventId, slug: event.threadSlug });

    await this._events.erase(user, event, trace);

    if (event.threadSlug !== undefined) {
      await this._threads.updateState(user.id, event.threadSlug, {
        solved: true,
      });
    }
  }

  /** Lays the queue out from [now] and writes everything that moved. */
  private async _repack(
    user: CalendarUser,
    queue: PlannedBlock[],
    trace: Trace,
    now: Date,
    zone: Zone,
  ): Promise<void> {
    const anchors = queue
      .filter((block) => block.fixed)
      .map((block) => block.interval);

    const placed = relayout(queue, anchors, earliestStart(now, zone), zone);

    for (const block of queue) {
      const slot = placed.get(block.id);
      if (slot === undefined || !moved(block, slot)) continue;

      trace.log('event.repack', {
        eventId: block.id,
        from: block.interval.start.toISOString(),
        to: slot.start.toISOString(),
      });

      await this._events.moveTo(
        user,
        await this._events.require(user, block.id),
        slot,
        trace,
      );
    }
  }
}

/** The hour a new block gets. */
function slotFor(
  request: EventRequest,
  blocks: TimeBlock[],
  now: Date,
  zone: Zone,
): Interval {
  if (request.fixed && request.startTime !== undefined) {
    const start = roundUpToFiveMinutes(new Date(request.startTime));
    return { start, end: addMinutes(start, request.durationMinutes) };
  }

  return nextFreeSlot(
    earliestStart(now, zone),
    request.durationMinutes,
    blocks.map((block) => block.interval),
    zone,
  );
}

/**
 * The day as a queue: every card in screen order, [closed] left out.
 *
 * The order on screen is the order of the queue, which is the whole of what
 * the sections are. Nothing here decides an hour; that is the layout's job,
 * and this only says what is in the day, in what order, and which of it is
 * allowed to move.
 */
function blocksOf(
  cards: EventCard[],
  now: Date,
  options: { closed?: string; thawed?: string } = {},
): PlannedBlock[] {
  return cards
    .filter((card) => card.id !== options.closed)
    .map((card): PlannedBlock => {
      const interval = {
        start: new Date(card.startTime),
        end: new Date(card.endTime),
      };

      return {
        id: card.id,
        minutes: card.durationMinutes,
        fixed: anchored(card, interval, now, options.thawed),
        interval,
      };
    });
}

/**
 * Whether a layout has to leave this block exactly where it is.
 *
 * Three reasons, and the third is the subtle one. A meeting is somebody
 * else's hour and a pinned block's hour is the point of it — neither is the
 * layout's to move. And **a block that has already started keeps the hour it
 * started at**: "Agora" says what the user is working on, not that they began
 * it this second, so rearranging the afternoon must not quietly rewrite a
 * block that has been running since eleven to say it began now. Its start is
 * a fact by then, not a plan.
 *
 * [thawed] is the one block the user has just said to move anyway: the card
 * under their finger, or the running one they chose to push down. Being asked
 * to move something beats every reason it would otherwise hold still.
 */
function anchored(
  card: EventCard,
  interval: Interval,
  now: Date,
  thawed?: string,
): boolean {
  if (card.id === thawed) return card.fixed;

  return card.fixed || !card.managed || isRunning(now, interval);
}

/**
 * The day's queue after the drop: every card in screen order, with the
 * dragged one lifted out and put back at [action.index].
 *
 * Meetings stay in the queue so a drop counted past one lands where the
 * finger was, but they are anchors and so nothing ever assigns them a new
 * hour.
 */
function queueOf(
  cards: EventCard[],
  action: TimingAction,
  now: Date,
  options: { closed?: string; thawed?: string } = {},
): PlannedBlock[] {
  const blocks = blocksOf(cards, now, options);

  const from = blocks.findIndex((block) => block.id === action.eventId);
  if (from === -1) return blocks;

  const [dragged] = blocks.splice(from, 1);
  // Dropping a card at the top is the user saying "now", which overrules the
  // hour it was pinned to. Nothing else about the drop can.
  const landing = action.index === 0 ? { ...dragged, fixed: false } : dragged;
  blocks.splice(Math.min(action.index, blocks.length), 0, landing);

  return blocks;
}
