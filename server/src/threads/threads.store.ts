import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { Message } from './entities/message.entity';
import { Thread, ThreadState, ThreadSummary } from './entities/thread.entity';
import {
  dayFolder,
  parseThreadDay,
  previewFrom,
  serializeThreadDay,
  titleFrom,
} from './thread-markdown';

/**
 * The thread store: a directory of markdown files.
 *
 * ```
 * <root>/<userId>/<thread-slug>/<YYYY-MM-DD>/thread.md
 * <root>/<userId>/<thread-slug>/state.json
 * ```
 *
 * A thread is a folder of days, so appending to a conversation only ever
 * rewrites today's file no matter how long the thread has run. Threads are
 * filed under the user who owns them: the layout below that is exactly the
 * per-thread shape, and the extra segment keeps one user's threads from being
 * readable by another.
 *
 */
@Injectable()
export class ThreadsStore {
  /** Overridable so a deployment can point at a mounted volume. */
  private readonly _root =
    process.env.FOCUS_DATA_DIR ?? path.join(process.cwd(), 'data', 'threads');

  private _userDir(userId: string): string {
    return path.join(this._root, sanitizeSegment(userId));
  }

  private _threadDir(userId: string, slug: string): string {
    return path.join(this._userDir(userId), sanitizeSegment(slug));
  }

  private _stateFile(userId: string, slug: string): string {
    return path.join(this._threadDir(userId, slug), 'state.json');
  }

  /** Whether a thread folder already exists. */
  async exists(userId: string, slug: string): Promise<boolean> {
    return exists(this._threadDir(userId, slug));
  }

  /** Every thread slug the user owns. */
  async listSlugs(userId: string): Promise<string[]> {
    return readDirNames(this._userDir(userId));
  }

  /**
   * Reads a thread whole, merging every day folder in date order.
   *
   * Returns `null` when the thread does not exist, so the caller decides
   * whether that is a 404 or a thread to create.
   */
  async read(userId: string, slug: string): Promise<Thread | null> {
    const dir = this._threadDir(userId, slug);
    if (!(await exists(dir))) return null;

    const days = (await readDirNames(dir)).sort();
    const messages: Message[] = [];
    let title = '';

    for (const day of days) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) continue;

      const file = path.join(dir, day, 'thread.md');
      const markdown = await readFileOrNull(file);
      if (markdown === null) continue;

      const parsed = parseThreadDay(markdown);
      if (parsed.title !== '') title = parsed.title;
      messages.push(...parsed.messages);
    }

    messages.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

    const state = await this.readState(userId, slug);

    if (state.title !== undefined && state.title !== '') {
      title = state.title;
    } else if (title === '') {
      const first = messages.find((message) => message.role === 'user');
      title = first === undefined ? slug : titleFrom(first.text);
    }

    return {
      slug,
      title,
      messages,
      solved: state.solved,
      createdAt: messages[0]?.createdAt ?? new Date(),
      updatedAt: messages[messages.length - 1]?.createdAt ?? new Date(),
    };
  }

  /** Every thread the user owns, most recently updated first. */
  async readAllSummaries(userId: string): Promise<ThreadSummary[]> {
    const slugs = await this.listSlugs(userId);
    const threads = await Promise.all(
      slugs.map((slug) => this.read(userId, slug)),
    );

    return threads
      .filter((thread): thread is Thread => thread !== null)
      .map(toSummary)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  /**
   * Appends [messages] to the thread, writing each into the day file it
   * belongs to.
   *
   * Grouping by day before writing means a batch that straddles midnight lands
   * in two files rather than backdating the later message.
   */
  async append(
    userId: string,
    slug: string,
    title: string,
    messages: Message[],
  ): Promise<void> {
    const byDay = new Map<string, Message[]>();
    for (const message of messages) {
      const day = dayFolder(message.createdAt);
      byDay.set(day, [...(byDay.get(day) ?? []), message]);
    }

    for (const [day, dayMessages] of byDay) {
      const dir = path.join(this._threadDir(userId, slug), day);
      await fs.mkdir(dir, { recursive: true });

      const file = path.join(dir, 'thread.md');
      const existing = await readFileOrNull(file);
      const previous =
        existing === null ? [] : parseThreadDay(existing).messages;

      await fs.writeFile(
        file,
        serializeThreadDay(title, [...previous, ...dayMessages]),
        'utf8',
      );
    }
  }

  /** The thread's stored state, defaulting to an open thread. */
  async readState(userId: string, slug: string): Promise<ThreadState> {
    const content = await readFileOrNull(this._stateFile(userId, slug));
    if (content === null) return { solved: false };

    try {
      const parsed = JSON.parse(content) as Partial<ThreadState>;
      return { solved: parsed.solved === true, title: parsed.title };
    } catch {
      return { solved: false };
    }
  }

  /** Merges [changes] into the thread's state. */
  async updateState(
    userId: string,
    slug: string,
    changes: Partial<ThreadState>,
  ): Promise<ThreadState> {
    const next = { ...(await this.readState(userId, slug)), ...changes };
    await fs.mkdir(this._threadDir(userId, slug), { recursive: true });
    await fs.writeFile(
      this._stateFile(userId, slug),
      JSON.stringify(next, null, 2),
      'utf8',
    );
    return next;
  }

  /** Writes a turn's trace next to the thread it explains. */
  async saveTrace(
    userId: string,
    slug: string,
    traceId: string,
    payload: unknown,
  ): Promise<void> {
    const dir = path.join(this._threadDir(userId, slug), 'traces');
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(
      path.join(dir, `${sanitizeSegment(traceId)}.json`),
      JSON.stringify(payload, null, 2),
      'utf8',
    );
  }

  /** Reads one stored trace back, or null when it has been cleaned up. */
  async readTrace(
    userId: string,
    slug: string,
    traceId: string,
  ): Promise<unknown | null> {
    const file = path.join(
      this._threadDir(userId, slug),
      'traces',
      `${sanitizeSegment(traceId)}.json`,
    );
    const content = await readFileOrNull(file);
    if (content === null) return null;

    try {
      return JSON.parse(content) as unknown;
    } catch {
      return null;
    }
  }

  /** Removes a thread and everything in it. */
  async remove(userId: string, slug: string): Promise<void> {
    await fs.rm(this._threadDir(userId, slug), {
      recursive: true,
      force: true,
    });
  }
}

function toSummary(thread: Thread): ThreadSummary {
  const last = thread.messages[thread.messages.length - 1];

  return {
    slug: thread.slug,
    title: thread.title,
    preview: last === undefined ? '' : previewFrom(last),
    messageCount: thread.messages.length,
    solved: thread.solved,
    createdAt: thread.createdAt,
    updatedAt: thread.updatedAt,
  };
}

/**
 * Keeps a slug or user id to one path segment.
 *
 * Both reach the store from the request, so neither is allowed to contain a
 * separator or a `..` that would walk out of the data directory.
 */
function sanitizeSegment(value: string): string {
  const cleaned = value.replace(/[^a-zA-Z0-9._-]/g, '-').replace(/^\.+/, '');
  if (cleaned === '') throw new Error('Invalid path segment');
  return cleaned;
}

async function exists(target: string): Promise<boolean> {
  try {
    await fs.access(target);
    return true;
  } catch {
    return false;
  }
}

async function readDirNames(dir: string): Promise<string[]> {
  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch {
    return [];
  }
}

async function readFileOrNull(file: string): Promise<string | null> {
  try {
    return await fs.readFile(file, 'utf8');
  } catch {
    return null;
  }
}
