import { Controller, Get, HttpCode } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  /**
   * Lightweight endpoint for verifying that the server is reachable and
   * that CORS headers are returned correctly from the browser. The deploy
   * workflows poll it after a restart.
   */
  @Get('health')
  @HttpCode(200)
  getHealth(): {
    status: string;
    env: string;
    version: string;
    timestamp: string;
  } {
    // env and version let a deploy check which build answers on which host:
    // the same image reports whichever FOCUS_ENV it was started with.
    return {
      status: 'ok',
      env: process.env.FOCUS_ENV ?? 'local',
      version: process.env.FOCUS_VERSION ?? 'dev',
      timestamp: new Date().toISOString(),
    };
  }
}
