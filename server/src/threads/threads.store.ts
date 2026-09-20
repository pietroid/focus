import { randomBytes } from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { Message } from './entities/message.entity';
import {
  Thread,
  ThreadItem,
  ThreadState,
  ThreadSummary,
  ThreadTiming,
} from './entities/thread.entity';
import {
  dayFolder,
  parseThreadDay,
  previewFrom,
  serializeThreadDay,
  titleFrom,
} from './thread-markdown';
import { intervalOf, sectionOf } from './thread-timing';

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

  /** The newest queued write per thread, so two never interleave. */
  private readonly _writes = new Map<string, Promise<void>>();

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

    const createdAt = messages[0]?.createdAt ?? new Date();

    return {
      slug,
      title,
      messages,
      solved: state.solved,
      timing: state.timing,
      createdAt,
      updatedAt: messages[messages.length - 1]?.createdAt ?? new Date(),
    };
  }

  /** Every thread the user owns, whether or not it happens at an hour. */
  async readAll(userId: string): Promise<Thread[]> {
    const slugs = await this.listSlugs(userId);
    const threads = await Promise.all(
      slugs.map((slug) => this.read(userId, slug)),
    );

    return threads.filter((thread): thread is Thread => thread !== null);
  }

  /**
   * Every thread that is on the timeline, earliest first.
   *
   * A thread with no timing is left out. It exists, it is in Coisas, and it
   * is simply not a thing that happens at an hour yet.
   */
  async readAllSummaries(
    userId: string,
    now = new Date(),
  ): Promise<ThreadSummary[]> {
    return (await this.readAll(userId))
      .map((thread) => toSummary(thread, now))
      .filter((summary): summary is ThreadSummary => summary !== null)
      .sort((a, b) => Date.parse(a.startTime) - Date.parse(b.startTime));
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

      await writeAtomic(
        file,
        serializeThreadDay(title, [...previous, ...dayMessages]),
      );
    }
  }

  /** The thread's stored state, defaulting to an open thread. */
  async readState(userId: string, slug: string): Promise<ThreadState> {
    const content = await readFileOrNull(this._stateFile(userId, slug));
    if (content === null) return { solved: false };

    try {
      const parsed = JSON.parse(content) as Partial<ThreadState>;
      return {
        solved: parsed.solved === true,
        title: parsed.title,
        timing: readTiming(parsed.timing),
      };
    } catch {
      return { solved: false };
    }
  }

  /**
   * Merges [changes] into the thread's state.
   *
   * Read, merge, write — and one thread at a time, because that sequence is
   * not atomic and no longer has the luxury of being the only thing running.
   * A request laying the day out and a calendar job writing back the event id
   * it was just given are two of these on the same file, and interleaved they
   * lose whichever change read first: the id lands on top of the old hour, or
   * the hour lands on top of the missing id, and the thread ends up pointing
   * at an event that is somewhere else.
   *
   * Serialising per thread rather than globally, so one slow thread does not
   * hold up the rest of the day. One process holds the lock, which is all
   * there is: the store is a directory on a Pi with a single backend on it.
   */
  async updateState(
    userId: string,
    slug: string,
    changes: Partial<ThreadState>,
  ): Promise<ThreadState> {
    const key = `${sanitizeSegment(userId)}/${sanitizeSegment(slug)}`;
    const previous = this._writes.get(key) ?? Promise.resolve();

    const next = previous
      .catch(() => undefined)
      .then(() => this._writeState(userId, slug, changes));

    // The tail swallows failures: one write that throws must not take the
    // writes queued behind it with it.
    const tail = next.then(
      () => undefined,
      () => undefined,
    );
    this._writes.set(key, tail);

    try {
      return await next;
    } finally {
      // Only the last write for a thread clears the entry. One that is still
      // holding a queue keeps its place, and the map stays the size of what
      // is actually in flight.
      if (this._writes.get(key) === tail) this._writes.delete(key);
    }
  }

  private async _writeState(
    userId: string,
    slug: string,
    changes: Partial<ThreadState>,
  ): Promise<ThreadState> {
    const next = { ...(await this.readState(userId, slug)), ...changes };
    await fs.mkdir(this._threadDir(userId, slug), { recursive: true });
    await writeAtomic(
      this._stateFile(userId, slug),
      JSON.stringify(next, null, 2),
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

/**
 * The stored timing, or undefined when it is not all there.
 *
 * Timing is all or nothing on purpose. Half a span was the old half-planned
 * state, and it is what let a card sit under a heading that was not true of
 * it.
 */
function readTiming(value: unknown): ThreadTiming | undefined {
  if (value === null || typeof value !== 'object') return undefined;

  const raw = value as Record<string, unknown>;
  if (
    typeof raw.durationMinutes !== 'number' ||
    raw.durationMinutes <= 0 ||
    typeof raw.startTime !== 'string' ||
    typeof raw.endTime !== 'string'
  ) {
    return undefined;
  }

  const timing: ThreadTiming = {
    durationMinutes: raw.durationMinutes,
    startTime: raw.startTime,
    endTime: raw.endTime,
    fixed: raw.fixed === true,
    calendarEventId:
      typeof raw.calendarEventId === 'string' ? raw.calendarEventId : undefined,
  };

  return intervalOf(timing) === undefined ? undefined : timing;
}

/** [thread] as a card, or null when it has no hour to be drawn at. */
function toSummary(thread: Thread, now: Date): ThreadSummary | null {
  const interval = intervalOf(thread.timing);
  if (thread.timing === undefined || interval === undefined) return null;

  // Out past tomorrow the timeline draws nothing, which the caller decides by
  // asking the same question. Here it only has to be some section, so the
  // furthest one stands in.
  const section = sectionOf(now, interval) ?? 'amanha';
  const last = thread.messages[thread.messages.length - 1];

  return {
    kind: 'thread',
    slug: thread.slug,
    title: thread.title,
    preview: last === undefined ? '' : previewFrom(last),
    messageCount: thread.messages.length,
    solved: thread.solved,
    section,
    startTime: thread.timing.startTime,
    endTime: thread.timing.endTime,
    durationMinutes: thread.timing.durationMinutes,
    fixed: thread.timing.fixed,
    createdAt: thread.createdAt,
    updatedAt: thread.updatedAt,
  };
}

/** [thread] in a plain list, hour or no hour. */
export function toItem(thread: Thread): ThreadItem {
  const last = thread.messages[thread.messages.length - 1];

  return {
    slug: thread.slug,
    title: thread.title,
    preview: last === undefined ? '' : previewFrom(last),
    messageCount: thread.messages.length,
    solved: thread.solved,
    startTime: thread.timing?.startTime,
    endTime: thread.timing?.endTime,
    durationMinutes: thread.timing?.durationMinutes,
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

/**
 * Writes [contents] to [file] in one step, as far as any reader can tell.
 *
 * Through a temporary file and a rename, because a plain write is not one
 * step: it truncates and then fills, and anything reading in between gets
 * half a file. That used to be impossible here, when every write was awaited
 * by the only thing running. Now the calendar queue writes while requests
 * read, and a torn `state.json` parses as a thread with no hour, which is a
 * card silently dropping off the timeline. Rename is atomic on the same
 * filesystem, so a reader sees either the old file whole or the new one.
 */
async function writeAtomic(file: string, contents: string): Promise<void> {
  const temp = `${file}.${randomBytes(6).toString('hex')}.tmp`;

  try {
    await fs.writeFile(temp, contents, 'utf8');
    await fs.rename(temp, file);
  } catch (error) {
    await fs.rm(temp, { force: true });
    throw error;
  }
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
