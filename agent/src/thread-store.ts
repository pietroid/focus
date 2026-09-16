import { promises as fs } from 'fs';
import * as path from 'path';

export interface Message {
  id: string;
  role: 'user' | 'agent';
  text: string;
  createdAt: Date;
}

export interface Thread {
  slug: string;
  title: string;
  messages: Message[];
  createdAt: Date;
  updatedAt: Date;
}

const HEADER = /^## (user|agent) @ (\d{4}-\d{2}-\d{2}T[\d:.]+Z)$/;
const TITLE = /^# (.+)$/;

/**
 * Reads a thread from disk, merging every day folder in date order.
 *
 * Returns `null` when the thread does not exist.
 */
export async function readThread(
  root: string,
  userId: string,
  slug: string,
): Promise<Thread | null> {
  const dir = path.join(root, sanitizeSegment(userId), sanitizeSegment(slug));
  if (!(await exists(dir))) return null;

  const days = (await readDirNames(dir)).sort();
  const messages: Message[] = [];
  let title = '';

  for (const day of days) {
    const file = path.join(dir, day, 'thread.md');
    const markdown = await readFileOrNull(file);
    if (markdown === null) continue;

    const parsed = parseThreadDay(markdown);
    if (parsed.title !== '') title = parsed.title;
    messages.push(...parsed.messages);
  }

  messages.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

  return {
    slug,
    title: title === '' ? slug : title,
    messages,
    createdAt: messages[0]?.createdAt ?? new Date(),
    updatedAt: messages[messages.length - 1]?.createdAt ?? new Date(),
  };
}

function parseThreadDay(markdown: string): { title: string; messages: Message[] } {
  const lines = markdown.split('\n');

  let title = '';
  const messages: Message[] = [];
  let current: { role: 'user' | 'agent'; createdAt: Date; body: string[] } | null =
    null;

  const flush = () => {
    if (current === null) return;
    messages.push({
      id: `${current.role}-${current.createdAt.getTime()}`,
      role: current.role,
      text: current.body.join('\n').trim(),
      createdAt: current.createdAt,
    });
    current = null;
  };

  for (const line of lines) {
    const header = HEADER.exec(line);
    if (header !== null) {
      flush();
      current = {
        role: header[1] as 'user' | 'agent',
        createdAt: new Date(header[2]),
        body: [],
      };
      continue;
    }

    if (current !== null) {
      current.body.push(line);
      continue;
    }

    const titleMatch = TITLE.exec(line);
    if (titleMatch !== null && title === '') {
      title = titleMatch[1].trim();
    }
  }

  flush();

  return { title, messages };
}

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
    return entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);
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
