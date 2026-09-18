import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { Message, ToolCall } from './entities/message.entity';
import { Thread, ThreadSummary } from './entities/thread.entity';
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
 * <root>/<userId>/<thread-slug>/pending-tool-calls.json
 * ```
 *
 * A thread is a folder of days, so appending to a conversation only ever
 * rewrites today's file no matter how long the thread has run. Threads are
 * filed under the user who owns them: the layout below that is exactly the
 * per-thread shape, and the extra segment keeps one user's threads from being
 * readable by another.
 *
 * Pending tool calls are stored in a sidecar file keyed by message id.
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

  private _pendingToolCallsFile(userId: string, slug: string): string {
    return path.join(this._threadDir(userId, slug), 'pending-tool-calls.json');
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

    const pendingToolCalls = await this._readPendingToolCalls(userId, slug);
    for (const message of messages) {
      const pending = pendingToolCalls[message.id];
      if (pending !== undefined) {
        message.metadata = message.metadata ?? { contentType: 'text' };
        message.metadata.pendingToolCall = pending;
      }
    }

    if (title === '') {
      const first = messages.find((message) => message.role === 'user');
      title = first === undefined ? slug : titleFrom(first.text);
    }

    return {
      slug,
      title,
      messages,
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

    await this._updatePendingToolCalls(userId, slug, messages);
  }

  /**
   * Finds a pending tool call by id for a thread.
   */
  async findPendingToolCall(
    userId: string,
    slug: string,
    toolCallId: string,
  ): Promise<ToolCall | null> {
    const calls = await this._readPendingToolCalls(userId, slug);
    return calls[toolCallId] ?? null;
  }

  /**
   * Removes a pending tool call after it has been confirmed or rejected.
   */
  async removePendingToolCall(
    userId: string,
    slug: string,
    toolCallId: string,
  ): Promise<void> {
    const calls = await this._readPendingToolCalls(userId, slug);
    if (calls[toolCallId] === undefined) return;

    delete calls[toolCallId];
    await this._writePendingToolCalls(userId, slug, calls);
  }

  private async _readPendingToolCalls(
    userId: string,
    slug: string,
  ): Promise<Record<string, ToolCall>> {
    const file = this._pendingToolCallsFile(userId, slug);
    const content = await readFileOrNull(file);
    if (content === null) return {};

    try {
      return JSON.parse(content) as Record<string, ToolCall>;
    } catch {
      return {};
    }
  }

  private async _writePendingToolCalls(
    userId: string,
    slug: string,
    calls: Record<string, ToolCall>,
  ): Promise<void> {
    const file = this._pendingToolCallsFile(userId, slug);
    await fs.writeFile(file, JSON.stringify(calls, null, 2), 'utf8');
  }

  private async _updatePendingToolCalls(
    userId: string,
    slug: string,
    messages: Message[],
  ): Promise<void> {
    const calls = await this._readPendingToolCalls(userId, slug);
    let changed = false;

    for (const message of messages) {
      const pending = message.metadata?.pendingToolCall;
      if (pending !== undefined) {
        calls[pending.id] = pending;
        changed = true;
      }
    }

    if (changed) {
      await this._writePendingToolCalls(userId, slug, calls);
    }
  }
}

function toSummary(thread: Thread): ThreadSummary {
  const last = thread.messages[thread.messages.length - 1];

  return {
    slug: thread.slug,
    title: thread.title,
    preview: last === undefined ? '' : previewFrom(last),
    messageCount: thread.messages.length,
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
