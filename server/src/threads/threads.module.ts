import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { A2uiModule } from '../a2ui/a2ui.module';
import { AuthModule } from '../auth/auth.module';
import { AgentService } from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';

@Module({
  imports: [ConfigModule, AuthModule, A2uiModule],
  controllers: [ThreadsController],
  providers: [ThreadsService, ThreadsStore, AgentService],
  exports: [ThreadsService],
})
export class ThreadsModule {}
