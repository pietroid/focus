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

  it('orders summaries by most recently updated', async () => {
    await store.append('u1', 'old', 'Old', [
      message('user', 'old', new Date(2026, 8, 14, 10, 0)),
    ]);
    await store.append('u1', 'new', 'New', [
      message('user', 'new', new Date(2026, 8, 16, 10, 0)),
    ]);

    const summaries = await store.readAllSummaries('u1');
    expect(summaries.map((s) => s.slug)).toEqual(['new', 'old']);
    expect(summaries[0].preview).toBe('new');
    expect(summaries[0].messageCount).toBe(1);
  });

  it('stores and retrieves pending tool calls by tool call id', async () => {
    const at = new Date(2026, 8, 15, 10, 0);
    const toolCallId = 'call-schedule-123';
    const metadata: MessageMetadata = {
      contentType: 'a2ui',
      pendingToolCall: {
        id: toolCallId,
        type: 'function',
        function: {
          name: 'calendar_create_event',
          arguments: JSON.stringify({ title: 'Standup', startTime: '2026-09-16T10:00:00', endTime: '2026-09-16T11:00:00' }),
        },
      },
    };

    await store.append('u1', 'schedule', 'Schedule', [
      message('agent', 'Confirm?', at, metadata),
    ]);

    const found = await store.findPendingToolCall('u1', 'schedule', toolCallId);
    expect(found).not.toBeNull();
    expect(found?.id).toBe(toolCallId);
    expect(found?.function.name).toBe('calendar_create_event');
  });
});
