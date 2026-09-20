import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { A2uiModule } from '../a2ui/a2ui.module';
import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { AgentService } from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';
import { TimelineService } from './timeline.service';
import { TimingService } from './timing.service';

@Module({
  imports: [ConfigModule, AuthModule, A2uiModule, CalendarModule],
  controllers: [ThreadsController],
  providers: [
    ThreadsService,
    ThreadsStore,
    AgentService,
    TimelineService,
    TimingService,
  ],
  exports: [ThreadsService],
})
export class ThreadsModule {}
