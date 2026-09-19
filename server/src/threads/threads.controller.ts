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
import { ThreadOp } from '../a2ui/a2ui.types';
import { Trace } from '../common/trace';
import { ActionDto } from './dto/action.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { CreateThreadDto } from './dto/create-thread.dto';
import { Thread, ThreadSummary } from './entities/thread.entity';
import { ThreadsService } from './threads.service';

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

function requireMessage(message: string | undefined): string {
  const text = message?.trim() ?? '';
  if (text === '') throw new BadRequestException('message is required');
  return text;
}
