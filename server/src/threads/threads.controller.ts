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
import { ConfirmToolDto } from './dto/confirm-tool.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { CreateThreadDto } from './dto/create-thread.dto';
import { Thread, ThreadSummary } from './entities/thread.entity';
import { ThreadsService } from './threads.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

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

  @Post()
  async create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateThreadDto,
  ): Promise<Thread> {
    return this.threadsService.create(user.uid, requireMessage(dto.message));
  }

  @Post(':slug/messages')
  async addMessage(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
    @Body() dto: CreateMessageDto,
  ): Promise<Thread> {
    return this.threadsService.addMessage(
      user.uid,
      slug,
      requireMessage(dto.message),
    );
  }

  @Post(':slug/tools/:toolCallId/confirm')
  async confirmTool(
    @CurrentUser() user: DecodedIdToken,
    @Param('slug') slug: string,
    @Param('toolCallId') toolCallId: string,
    @Body() dto: ConfirmToolDto,
  ): Promise<Thread> {
    console.log('[threads.controller] confirmTool called', {
      userId: user.uid,
      slug,
      toolCallId,
      confirmed: dto.confirmed,
      hasArguments: dto.arguments !== undefined,
    });
    return this.threadsService.confirmTool(
      user.uid,
      slug,
      toolCallId,
      dto.confirmed === true,
      dto.arguments,
    );
  }
}

function requireMessage(message: string | undefined): string {
  const text = message?.trim() ?? '';
  if (text === '') throw new BadRequestException('message is required');
  return text;
}
