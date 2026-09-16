import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { AgentService } from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';

@Module({
  imports: [ConfigModule, AuthModule],
  controllers: [ThreadsController],
  providers: [ThreadsService, ThreadsStore, AgentService],
  exports: [ThreadsService],
})
export class ThreadsModule {}
