import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { A2uiModule } from '../a2ui/a2ui.module';
import { AuthModule } from '../auth/auth.module';
import { AgentService } from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';

/**
 * Conversations, and nothing about the clock.
 *
 * It does not import the calendar. A thread has no hour to keep in step with
 * one, which is the point: the only module that talks to both is the one that
 * draws the day.
 */
@Module({
  imports: [ConfigModule, AuthModule, A2uiModule],
  controllers: [ThreadsController],
  providers: [ThreadsService, ThreadsStore, AgentService],
  exports: [ThreadsService, ThreadsStore],
})
export class ThreadsModule {}
