// firebase-admin pulls an ESM-only dependency that Jest cannot require on
// Node 22. Nothing here verifies a token, so the module is stubbed and the
// guard it backs is overridden below.
jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));

import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AgentService } from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';
import { Thread, ThreadSummary } from './entities/thread.entity';

/** supertest types `body` as `any`; these keep the assertions typed. */
function thread(response: { body: unknown }): Thread {
  return response.body as Thread;
}

function summaries(response: { body: unknown }): ThreadSummary[] {
  return response.body as ThreadSummary[];
}

/** Signs every request in as a fixed user, standing in for Firebase. */
class StubAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = {
      uid: 'test-user',
    };
    return true;
  }
}

/** Answers instantly, so the suite does not pay the agent's fake latency. */
class StubAgentService {
  reply(): Promise<string> {
    return Promise.resolve('Noted.');
  }
}

describe('ThreadsController', () => {
  let app: INestApplication<App>;
  let root: string;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-api-'));
    process.env.FOCUS_DATA_DIR = root;

    const moduleRef = await Test.createTestingModule({
      controllers: [ThreadsController],
      providers: [ThreadsService, ThreadsStore, AgentService],
    })
      .overrideGuard(FirebaseAuthGuard)
      .useClass(StubAuthGuard)
      .overrideProvider(AgentService)
      .useClass(StubAgentService)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  it('starts a thread and answers it', async () => {
    const response = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Buy milk tomorrow' })
      .expect(201);

    expect(thread(response)).toMatchObject({
      slug: 'buy-milk-tomorrow',
      title: 'Buy milk tomorrow',
    });
    expect(thread(response).messages).toHaveLength(2);
    expect(thread(response).messages[0]).toMatchObject({
      role: 'user',
      text: 'Buy milk tomorrow',
    });
    expect(thread(response).messages[1]).toMatchObject({
      role: 'agent',
      text: 'Noted.',
    });
  });

  it('writes the thread as markdown on disk', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Buy milk' })
      .expect(201);

    const [day] = await fs.readdir(path.join(root, 'test-user', 'buy-milk'));
    const markdown = await fs.readFile(
      path.join(root, 'test-user', 'buy-milk', day, 'thread.md'),
      'utf8',
    );

    expect(markdown).toContain('# Buy milk');
    expect(markdown).toMatch(/## user @ /);
    expect(markdown).toMatch(/## agent @ /);
  });

  it('appends to an existing thread', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Buy milk' })
      .expect(201);

    const response = await request(app.getHttpServer())
      .post('/threads/buy-milk/messages')
      .send({ message: 'And eggs' })
      .expect(201);

    expect(thread(response).messages).toHaveLength(4);
    expect(thread(response).messages[2].text).toBe('And eggs');
  });

  it('gives a second thread with the same first message its own folder', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Standup' })
      .expect(201);

    const second = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Standup' })
      .expect(201);

    expect(thread(second).slug).toBe('standup-2');
  });

  it('lists threads most recently updated first', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'First' })
      .expect(201);
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Second' })
      .expect(201);

    const response = await request(app.getHttpServer())
      .get('/threads')
      .expect(200);

    expect(summaries(response).map((t) => t.slug)).toEqual(['second', 'first']);
    expect(summaries(response)[0]).toMatchObject({
      title: 'Second',
      preview: 'Noted.',
      messageCount: 2,
    });
  });

  it('404s an unknown thread', async () => {
    await request(app.getHttpServer()).get('/threads/nothing').expect(404);
  });

  it('400s an empty message', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: '   ' })
      .expect(400);
  });
});
