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
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { THREAD_OPS } from '../a2ui/a2ui.catalog';
import {
  ThreadOp,
  TimingAction,
  TimingDecision,
  TIMING_DECISIONS,
} from '../a2ui/a2ui.types';
import { Trace } from '../common/trace';
import { ActionDto } from './dto/action.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { CreateThreadDto } from './dto/create-thread.dto';
import { PlacementsDto } from './dto/placements.dto';
import { SolvedDto } from './dto/solved.dto';
import { TimingDto } from './dto/timing.dto';
import {
  isThreadBucket,
  Thread,
  ThreadBucket,
  ThreadSummary,
} from './entities/thread.entity';
import { ThreadsService } from './threads.service';
import { TimingOutcome } from './timing.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

/** What an action returns: the thread, or nothing when it deleted one. */
interface ActionResult {
  thread: Thread | null;
  traceId: string;
}

@Controller('threads')
@UseGuards(FirebaseAuthGuard)
export class ThreadsController {
  constructor(private readonly threadsService: ThreadsService) {}

  @Get()
  async findAll(@CurrentUser() user: DecodedIdToken): Promise<ThreadSummary[]> {
    return this.threadsService.findAll(user.uid);
  }

  @Get(':slug')
  async findOne(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
  ): Promise<Thread> {
    return this.threadsService.findOne(user.uid, slug);
  }

  /** One turn's trace, for working out why a reply looked the way it did. */
  @Get(':slug/traces/:traceId')
  async findTrace(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
    @Param('traceId') traceId: string,
  ): Promise<unknown> {
    return this.threadsService.findTrace(user.uid, slug, traceId);
  }

  /**
   * Rewrites where threads sit on the home screen after a drag.
   *
   * Declared before the `:slug` routes so `placements` is read as this route
   * and not as a thread called "placements".
   */
  @Post('placements')
  async setPlacements(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: PlacementsDto,
  ): Promise<TimingOutcome> {
    const trace = Trace.start(user.uid);

    return this.threadsService.setPlacements(
      user.uid,
      (dto.placements ?? []).map(requirePlacement),
      trace,
    );
  }

  /**
   * Answers a guard.
   *
   * Its own route rather than an action on a thread, because a guard is about
   * where a card goes and not about what a conversation said. Nothing here
   * reaches the agent: the answer is arithmetic over the calendar, and the
   * only thing that crosses to the other container is the booking itself.
   *
   * Declared before the `:slug` routes for the same reason `placements` is.
   */
  @Post('timing')
  async applyTiming(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: TimingDto,
  ): Promise<TimingOutcome> {
    const action = requireTiming(dto.action ?? {});
    const trace = Trace.start(user.uid, action.slug);
    trace.log('timing.received', {
      bucket: action.bucket,
      decision: action.decision,
    });

    return this.threadsService.applyTiming(user.uid, action, trace);
  }

  /**
   * Marks a thread solved, or puts a solved one back on the timeline.
   *
   * Separate from the placement route because it is a different question:
   * placement is where something sits, this is whether it is still there at
   * all.
   */
  @Post(':slug/solved')
  async setSolved(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
    @Body() dto: SolvedDto,
  ): Promise<ThreadSummary[]> {
    if (typeof dto.solved !== 'boolean') {
      throw new BadRequestException('solved must be a boolean');
    }

    const trace = Trace.start(user.uid, slug);

    return this.threadsService.setSolved(user.uid, slug, dto.solved, trace);
  }

  @Post()
  async create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateThreadDto,
  ): Promise<Thread> {
    const trace = Trace.start(user.uid);
    trace.log('turn.begin', { kind: 'create' });

    return this.threadsService.create(
      user.uid,
      requireMessage(dto.message),
      trace,
    );
  }

  @Post(':slug/messages')
  async addMessage(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
    @Body() dto: CreateMessageDto,
  ): Promise<Thread> {
    const trace = Trace.start(user.uid, slug);
    trace.log('turn.begin', { kind: 'message' });

    return this.threadsService.addMessage(
      user.uid,
      slug,
      requireMessage(dto.message),
      trace,
    );
  }

  /**
   * Every action a rendered component can fire.
   *
   * One route rather than one per action type. The app posts the action object
   * it was given and gets a thread back, so adding an action to the catalog
   * needs no new endpoint and no new client code.
   */
  @Post(':slug/actions')
  async runAction(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
    @Body() dto: ActionDto,
  ): Promise<ActionResult> {
    const action = dto.action ?? {};
    const trace = Trace.start(user.uid, slug);
    trace.log('action.received', { type: action.type, op: action.op });

    switch (action.type) {
      // Both land as a message from the user. The difference is that a confirm
      // also says "and yes, do the thing you just described", which is the only
      // way a tool that changes their data is ever allowed to run.
      case 'reply':
      case 'confirm': {
        return {
          thread: await this.threadsService.addMessage(
            user.uid,
            slug,
            requireMessage(action.text),
            trace,
            action.type === 'confirm',
          ),
          traceId: trace.id,
        };
      }

      case 'thread': {
        const op = action.op;
        if (typeof op !== 'string' || !THREAD_OPS.includes(op as never)) {
          throw new BadRequestException(`Unknown thread op "${String(op)}"`);
        }

        return {
          thread: await this.threadsService.applyThreadOp(
            user.uid,
            slug,
            op as ThreadOp,
            action.title,
            trace,
          ),
          traceId: trace.id,
        };
      }

      // `dismiss` and `openUrl` never reach the server: the app handles both
      // without needing anything from here. One arriving means the app sent
      // something it should have swallowed, which is worth saying out loud.
      default:
        trace.warn('action.unroutable', { type: action.type });
        throw new BadRequestException(
          `Action "${String(action.type)}" is not handled by the server`,
        );
    }
  }
}

function requirePlacement(placement: {
  slug?: string;
  bucket?: string;
  index?: number;
}): { slug: string; bucket: ThreadBucket; index: number } {
  const slug = placement.slug?.trim() ?? '';
  if (slug === '') throw new BadRequestException('slug is required');

  if (!isThreadBucket(placement.bucket)) {
    throw new BadRequestException(
      `Unknown bucket "${String(placement.bucket)}"`,
    );
  }

  const index = placement.index;
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0) {
    throw new BadRequestException('index must be a non-negative integer');
  }

  return { slug, bucket: placement.bucket, index };
}

/** Reads a guard's answer off the wire, refusing anything it cannot trust. */
function requireTiming(action: {
  slug?: string;
  bucket?: string;
  index?: number;
  durationMinutes?: number;
  startTime?: string;
  decision?: string;
}): TimingAction {
  const slug = action.slug?.trim() ?? '';
  if (slug === '') throw new BadRequestException('slug is required');

  if (!isThreadBucket(action.bucket)) {
    throw new BadRequestException(`Unknown bucket "${String(action.bucket)}"`);
  }

  const index = action.index ?? 0;
  if (!Number.isInteger(index) || index < 0) {
    throw new BadRequestException('index must be a non-negative integer');
  }

  const decision = action.decision;
  if (
    decision !== undefined &&
    !TIMING_DECISIONS.includes(decision as TimingDecision)
  ) {
    throw new BadRequestException(`Unknown decision "${decision}"`);
  }

  const durationMinutes = action.durationMinutes;
  if (
    durationMinutes !== undefined &&
    (!Number.isFinite(durationMinutes) || durationMinutes <= 0)
  ) {
    throw new BadRequestException('durationMinutes must be positive');
  }

  const startTime = action.startTime;
  if (startTime !== undefined && Number.isNaN(Date.parse(startTime))) {
    throw new BadRequestException('startTime must be an ISO 8601 date-time');
  }

  return {
    type: 'timing',
    slug,
    bucket: action.bucket,
    index,
    durationMinutes,
    startTime,
    decision: decision as TimingDecision | undefined,
  };
}

function requireMessage(message: string | undefined): string {
  const text = message?.trim() ?? '';
  if (text === '') throw new BadRequestException('message is required');
  return text;
}
