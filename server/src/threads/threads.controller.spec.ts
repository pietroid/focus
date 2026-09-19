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
import { A2uiParserService } from '../a2ui/a2ui-parser.service';
import { A2uiPromptService } from '../a2ui/a2ui-prompt.service';
import { A2uiValidationService } from '../a2ui/a2ui-validation.service';
import {
  AgentService,
  GenerateResult,
  ToolDescriptor,
} from './agent.service';
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

/** Every string the user would actually read in a rendered message. */
function visibleText(message: { metadata?: { a2ui?: unknown } }): string[] {
  const found: string[] = [];

  const walk = (node: unknown): void => {
    if (node === null || typeof node !== 'object') return;
    const record = node as Record<string, unknown>;

    for (const key of ['text', 'title', 'subtitle']) {
      const value = record[key];
      if (typeof value === 'string' && value !== '') found.push(value);
    }

    for (const child of (record.children as unknown[]) ?? []) walk(child);
  };

  walk(message.metadata?.a2ui);
  return found;
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

/**
 * Stands in for the agent container.
 *
 * It answers with the JSON an obedient model would produce, so these tests
 * exercise the server's own path: prompt, parse, validate, store.
 */
class StubAgentService {
  /** Overridden per test to rehearse a particular model reply. */
  raw = JSON.stringify({
    a2ui: { component: 'Text', text: 'Noted.' },
  });

  tools(): Promise<ToolDescriptor[]> {
    return Promise.resolve([
      { name: 'calendar_create_event', description: 'Create an event' },
    ]);
  }

  generate(): Promise<GenerateResult> {
    return Promise.resolve({
      raw: this.raw,
      toolTrace: [],
      model: 'stub',
      latencyMs: 0,
      iterations: 1,
    });
  }
}

describe('ThreadsController', () => {
  let app: INestApplication<App>;
  let root: string;
  let agent: StubAgentService;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-api-'));
    process.env.FOCUS_DATA_DIR = root;

    const moduleRef = await Test.createTestingModule({
      controllers: [ThreadsController],
      providers: [
        ThreadsService,
        ThreadsStore,
        AgentService,
        A2uiPromptService,
        A2uiParserService,
        A2uiValidationService,
      ],
    })
      .overrideGuard(FirebaseAuthGuard)
      .useClass(StubAuthGuard)
      .overrideProvider(AgentService)
      .useClass(StubAgentService)
      .compile();

    agent = moduleRef.get(AgentService) as unknown as StubAgentService;

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
      metadata: { contentType: 'a2ui' },
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
    expect(markdown).toContain('"component":"Text"');
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

  it('drops an action type the catalog does not have', async () => {
    agent.raw = JSON.stringify({
      a2ui: {
        component: 'Column',
        children: [
          { component: 'Text', text: 'Shall I?' },
          {
            component: 'AppButton',
            text: 'Do it',
            action: {
              type: 'confirmTool',
              toolCallId: 'made-up',
              decision: 'confirm',
            },
          },
        ],
      },
    });

    const created = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Schedule something' })
      .expect(201);

    const reply = thread(created).messages[1];
    expect(JSON.stringify(reply.metadata?.a2ui)).not.toContain('made-up');
    expect(visibleText(reply)).toContain('Shall I?');
    // The button lost its action, so it is dropped rather than rendered dead.
    expect(visibleText(reply)).not.toContain('Do it');
  });

  it('keeps tool names and raw JSON out of what the user reads', async () => {
    agent.raw = JSON.stringify({
      a2ui: {
        component: 'Column',
        children: [
          {
            component: 'Text',
            text: 'I called calendar_create_event for you.',
          },
          {
            component: 'Text',
            text: '{"busy":[{"start":"2026-09-20T10:00:00Z"}]}',
          },
        ],
      },
    });

    const created = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Book it' })
      .expect(201);

    const rendered = visibleText(thread(created).messages[1]).join(' ');
    expect(rendered).not.toContain('calendar_create_event');
    expect(rendered).not.toContain('busy');
    expect(rendered).toContain('I called that for you.');
  });

  it('recovers a reply the model wrapped in a code fence', async () => {
    agent.raw =
      'Sure!\n```json\n{"a2ui":{"component":"Text","text":"On it."}}\n```';

    const created = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Remind me' })
      .expect(201);

    const reply = thread(created).messages[1];
    expect(reply.metadata?.parseStrategy).toBe('fenced');
    expect(visibleText(reply)).toContain('On it.');
  });

  it('marks a thread solved without calling the agent', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Tidy up' })
      .expect(201);

    const response = await request(app.getHttpServer())
      .post('/threads/tidy-up/actions')
      .send({ action: { type: 'thread', op: 'solve' } })
      .expect(201);

    const updated = (response.body as { thread: Thread }).thread;
    expect(updated.solved).toBe(true);
    // Nothing was said: solving is a state change, not a turn.
    expect(updated.messages).toHaveLength(2);
  });

  it('rejects an action the server does not route', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Anything' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/threads/anything/actions')
      .send({ action: { type: 'dismiss' } })
      .expect(400);
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
