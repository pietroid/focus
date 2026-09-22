import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import * as adminAuth from 'firebase-admin/auth';
import {
  TimingAction,
  TimingDecision,
  TIMING_DECISIONS,
} from '../a2ui/a2ui.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { Thread } from '../threads/entities/thread.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { MoveEventDto } from './dto/move-event.dto';
import { TimingDto } from './dto/timing.dto';
import { EventCard, EventRequest } from './entities/event.entity';
import { EventLayoutService, TimingOutcome } from './event-layout.service';
import { EventsService, SyncOutcome } from './events.service';
import { EventThreadsService } from './event-threads.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

/**
 * The day: what is on it, and everything that changes it.
 *
 * Every route here is about a block of time, which is to say about a Google
 * event. Conversations are `/threads` and have no opinion about hours; the
 * one place the two meet is [startThread], where talking about a block
 * creates the conversation and writes its name onto the event.
 */
@Controller('events')
@UseGuards(FirebaseAuthGuard)
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly layout: EventLayoutService,
    private readonly threads: EventThreadsService,
  ) {}

  /** Every card the timeline draws, earliest first. */
  @Get()
  async findAll(@CurrentUser() user: DecodedIdToken): Promise<EventCard[]> {
    return this.events.cards(owner(user));
  }

  /**
   * Waits for the calendar to catch up, and says whether it did.
   *
   * The app calls this after a change, off the path the finger is on. It
   * answers `{ ok: true }` the moment the queue is empty, which is almost
   * always and almost immediately; when something did not make it, it answers
   * with the popup to draw instead.
   *
   * Declared before the `:id` routes so `sync` is read as this route and not
   * as an event called "sync".
   */
  @Get('sync')
  async sync(@CurrentUser() user: DecodedIdToken): Promise<SyncOutcome> {
    return this.events.awaitSync(user.uid, Trace.start(user.uid));
  }

  /** Pushes everything that did not make it to Google again. */
  @Post('sync')
  async retrySync(@CurrentUser() user: DecodedIdToken): Promise<SyncOutcome> {
    const trace = Trace.start(user.uid);
    trace.log('sync.retry', {});

    return this.events.retrySync(user.uid, trace);
  }

  /**
   * Answers a guard.
   *
   * Its own route rather than an action on an event, because a guard is about
   * where a card goes and not about one event in particular. Nothing here
   * reaches the agent: the answer is arithmetic over the calendar, and the
   * only thing that crosses to the other container is the booking itself.
   */
  @Post('timing')
  async applyTiming(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: TimingDto,
  ): Promise<TimingOutcome> {
    const action = requireTiming(dto.action ?? {});
    const trace = Trace.start(user.uid, action.eventId);
    trace.log('timing.received', {
      index: action.index,
      decision: action.decision,
    });

    return this.layout.move(owner(user), action, trace);
  }

  /** Writes something down on the timeline, with its hour. */
  @Post()
  async create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateEventDto,
  ): Promise<EventCard[]> {
    const trace = Trace.start(user.uid);
    trace.log('turn.begin', { kind: 'event' });

    return this.layout.create(owner(user), requireEvent(dto), trace);
  }

  /** Moves a card to a new place in the day's list. */
  @Post(':id/move')
  async move(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: MoveEventDto,
  ): Promise<TimingOutcome> {
    const trace = Trace.start(user.uid, id);

    return this.layout.move(
      owner(user),
      { type: 'timing', eventId: id, index: requireIndex(dto.index) },
      trace,
    );
  }

  /**
   * Takes a block off the day.
   *
   * Separate from the move route because it is a different question: a move
   * is when something happens, this is whether it still happens at all.
   */
  @Post(':id/done')
  async finish(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.finish(owner(user), id, Trace.start(user.uid, id));
  }

  /**
   * The conversation about this block, started if there is not one yet.
   *
   * A block has no thread by default: most of the day is hours, not
   * discussions. Tapping into one is the moment that changes, and the event
   * is where the pairing is written down.
   */
  @Post(':id/thread')
  async startThread(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<Thread> {
    return this.threads.open(owner(user), id, Trace.start(user.uid, id));
  }
}

/** The person this request is for, and how to reach them on Google. */
function owner(user: DecodedIdToken): CalendarUser {
  const name = typeof user.name === 'string' ? user.name : undefined;
  return { id: user.uid, email: user.email, name };
}

/** A non-negative place in the day's list. */
function requireIndex(index: number | undefined): number {
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0) {
    throw new BadRequestException('index must be a non-negative integer');
  }

  return index;
}

/** Reads what the creation sheet said, refusing anything unusable. */
function requireEvent(dto: CreateEventDto): EventRequest {
  const title = dto.title?.trim() ?? '';
  if (title === '') throw new BadRequestException('title is required');

  const durationMinutes = dto.durationMinutes;
  if (
    typeof durationMinutes !== 'number' ||
    !Number.isFinite(durationMinutes) ||
    durationMinutes <= 0
  ) {
    throw new BadRequestException('durationMinutes must be positive');
  }

  const fixed = dto.fixed === true;
  const startTime = dto.startTime;
  if (startTime !== undefined && Number.isNaN(Date.parse(startTime))) {
    throw new BadRequestException('startTime must be an ISO 8601 date-time');
  }

  // Only a fixed block names its hour. Carrying one on a flexible block would
  // be the app asking for a slot the server is about to pick anyway.
  return {
    title,
    durationMinutes,
    fixed,
    startTime: fixed ? startTime : undefined,
  };
}

/** Reads a guard's answer off the wire, refusing anything it cannot trust. */
function requireTiming(action: {
  eventId?: string;
  index?: number;
  decision?: string;
}): TimingAction {
  const eventId = action.eventId?.trim() ?? '';
  if (eventId === '') throw new BadRequestException('eventId is required');

  const decision = action.decision;
  if (
    decision !== undefined &&
    !TIMING_DECISIONS.includes(decision as TimingDecision)
  ) {
    throw new BadRequestException(`Unknown decision "${decision}"`);
  }

  return {
    type: 'timing',
    eventId,
    index: requireIndex(action.index ?? 0),
    decision: decision as TimingDecision | undefined,
  };
}
