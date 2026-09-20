import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import { Message, MessageMetadata } from './entities/message.entity';
import { dayFolder, messageId } from './thread-markdown';
import { ThreadsStore } from './threads.store';

function message(
  role: Message['role'],
  text: string,
  createdAt: Date,
  metadata?: MessageMetadata,
): Message {
  return { id: messageId(role, createdAt), role, text, createdAt, metadata };
}

describe('ThreadsStore', () => {
  let root: string;
  let store: ThreadsStore;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-threads-'));
    process.env.FOCUS_DATA_DIR = root;
    store = new ThreadsStore();
  });

  afterEach(async () => {
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  it('returns null for a thread that does not exist', async () => {
    expect(await store.read('u1', 'nope')).toBeNull();
  });

  it('writes to <user>/<slug>/<day>/thread.md', async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    await store.append('u1', 'buy-milk', 'Buy milk', [
      message('user', 'Buy milk', at),
    ]);

    const file = path.join(root, 'u1', 'buy-milk', dayFolder(at), 'thread.md');
    await expect(fs.readFile(file, 'utf8')).resolves.toContain('Buy milk');
  });

  it('merges every day of a thread in order', async () => {
    const day1 = new Date(2026, 8, 15, 10, 0);
    const day2 = new Date(2026, 8, 16, 9, 0);

    await store.append('u1', 'buy-milk', 'Buy milk', [
      message('user', 'first', day1),
    ]);
    await store.append('u1', 'buy-milk', 'Buy milk', [
      message('user', 'second', day2),
    ]);

    const thread = await store.read('u1', 'buy-milk');
    expect(thread?.messages.map((m) => m.text)).toEqual(['first', 'second']);
    expect(thread?.createdAt).toEqual(day1);
    expect(thread?.updatedAt).toEqual(day2);
  });

  it('appends to an existing day without dropping what is there', async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    const later = new Date(2026, 8, 15, 10, 1);

    await store.append('u1', 't', 'T', [message('user', 'first', at)]);
    await store.append('u1', 't', 'T', [message('agent', 'second', later)]);

    const thread = await store.read('u1', 't');
    expect(thread?.messages.map((m) => m.text)).toEqual(['first', 'second']);
  });

  it('splits a batch that straddles midnight into two day files', async () => {
    const before = new Date(2026, 8, 15, 23, 59, 59);
    const after = new Date(2026, 8, 16, 0, 0, 1);

    await store.append('u1', 't', 'T', [
      message('user', 'before', before),
      message('agent', 'after', after),
    ]);

    const days = await fs.readdir(path.join(root, 'u1', 't'));
    expect(days.sort()).toEqual(['2026-09-15', '2026-09-16']);
  });

  it('keeps one user out of another user thread', async () => {
    await store.append('u1', 'private', 'Private', [
      message('user', 'secret', new Date(2026, 8, 15, 10, 0)),
    ]);

    expect(await store.read('u2', 'private')).toBeNull();
    expect(await store.listSlugs('u2')).toEqual([]);
  });

  it('refuses a slug that walks out of the data directory', async () => {
    const escaped = await store.read('u1', '../../etc');
    expect(escaped).toBeNull();
    await expect(fs.readdir(root)).resolves.toEqual([]);
  });

  it('leaves a thread with no hour off the timeline', async () => {
    await store.append('u1', 'idea', 'Idea', [
      message('user', 'some day', new Date(2026, 8, 14, 10, 0)),
    ]);

    expect(await store.readAllSummaries('u1')).toEqual([]);
    expect((await store.readAll('u1')).map((t) => t.slug)).toEqual(['idea']);
  });

  it('orders the timeline by the clock', async () => {
    const now = new Date(2026, 8, 15, 9, 0);

    for (const [slug, hour] of [
      ['later', 14],
      ['sooner', 10],
    ] as const) {
      await store.append('u1', slug, slug, [
        message('user', slug, new Date(2026, 8, 15, 8, 0)),
      ]);
      await store.updateState('u1', slug, {
        timing: {
          durationMinutes: 30,
          startTime: new Date(2026, 8, 15, hour, 0).toISOString(),
          endTime: new Date(2026, 8, 15, hour, 30).toISOString(),
          fixed: false,
        },
      });
    }

    const summaries = await store.readAllSummaries('u1', now);
    expect(summaries.map((s) => s.slug)).toEqual(['sooner', 'later']);
    expect(summaries.map((s) => s.section)).toEqual(['hoje', 'hoje']);
  });

  it('drops timing that is not all there', async () => {
    await store.append('u1', 'half', 'Half', [
      message('user', 'half', new Date(2026, 8, 15, 8, 0)),
    ]);
    await store.updateState('u1', 'half', {
      timing: {
        startTime: new Date(2026, 8, 15, 10, 0).toISOString(),
      } as never,
    });

    expect((await store.read('u1', 'half'))?.timing).toBeUndefined();
  });

  it('remembers that a thread was solved', async () => {
    await store.append('u1', 'done', 'Done', [
      message('user', 'ship it', new Date(2026, 8, 15, 10, 0)),
    ]);

    expect((await store.read('u1', 'done'))?.solved).toBe(false);

    await store.updateState('u1', 'done', { solved: true });
    expect((await store.read('u1', 'done'))?.solved).toBe(true);
  });

  it("keeps a message's trace id across a round trip to disk", async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    await store.append('u1', 'traced', 'Traced', [
      message('agent', '', at, {
        contentType: 'a2ui',
        a2ui: { component: 'Text', text: 'Noted.' },
        traceId: 't_abc',
        model: 'stub',
        parseStrategy: 'direct',
      }),
    ]);

    const thread = await store.read('u1', 'traced');
    expect(thread?.messages[0].metadata).toMatchObject({
      traceId: 't_abc',
      model: 'stub',
      parseStrategy: 'direct',
    });
  });
});
