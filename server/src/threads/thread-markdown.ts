import { A2uiComponent } from '../a2ui/a2ui.types';
import {
  Message,
  MessageContentType,
  MessageMetadata,
  MessageRole,
} from './entities/message.entity';

/**
 * The on-disk format for one day of a thread.
 *
 * ```markdown
 * # Buy milk tomorrow
 *
 * ## user @ 2026-09-15T19:23:04.123Z
 *
 * Buy milk tomorrow
 *
 * ## agent @ 2026-09-15T19:23:05.456Z
 *
 * {"a2ui":{"component":"Text","text":"Noted."}}
 * ```
 *
 * Markdown rather than JSON so a day of conversation stays readable, diffable,
 * and editable by hand. An agent message stores its A2UI tree in the body,
 * alongside a `meta` object carrying the trace id, the model and what the
 * validator had to fix. Keeping that in the file rather than only in a log
 * means a turn can still be explained days later, after the container that
 * logged it is gone.
 */

/** Matches a message header, and only a message header. */
const HEADER = /^## (user|agent|system) @ (\d{4}-\d{2}-\d{2}T[\d:.]+Z)$/;

/** Matches the thread title heading. */
const TITLE = /^# (.+)$/;

/** The body of an agent message, as written into the file. */
interface StoredBody {
  a2ui?: A2uiComponent;
  meta?: Omit<MessageMetadata, 'contentType' | 'a2ui'>;
}

/**
 * Reads an agent message body back, when it holds an A2UI payload.
 */
function parseBody(text: string): StoredBody | undefined {
  const trimmed = text.trim();
  if (!trimmed.startsWith('{')) return undefined;

  try {
    const parsed = JSON.parse(trimmed) as StoredBody;
    return parsed.a2ui === undefined ? undefined : parsed;
  } catch {
    return undefined;
  }
}

/**
 * Renders [title] and [messages] as the markdown for one day file.
 */
export function serializeThreadDay(title: string, messages: Message[]): string {
  const blocks = messages.map((message) => {
    return `## ${message.role} @ ${message.createdAt.toISOString()}\n\n${serializeBody(message)}`;
  });

  return [`# ${title}`, ...blocks].join('\n\n') + '\n';
}

/** One message body: the A2UI payload plus its metadata, or plain text. */
function serializeBody(message: Message): string {
  const metadata = message.metadata;
  if (metadata?.contentType !== 'a2ui' || metadata.a2ui === undefined) {
    return message.text.trim();
  }

  const { contentType: _contentType, a2ui, ...meta } = metadata;
  const body: StoredBody = { a2ui };
  if (Object.keys(meta).length > 0) body.meta = meta;

  return JSON.stringify(body);
}

/**
 * Reads one day file back into a title and its messages.
 *
 * A line only opens a new message when it matches [HEADER] exactly, so a `##`
 * inside a message body stays part of that body.
 */
export function parseThreadDay(markdown: string): {
  title: string;
  messages: Message[];
} {
  const lines = markdown.split('\n');

  let title = '';
  const messages: Message[] = [];
  let current: { role: MessageRole; createdAt: Date; body: string[] } | null =
    null;

  const flush = () => {
    if (current === null) return;

    const text = current.body.join('\n').trim();
    const stored = current.role === 'user' ? undefined : parseBody(text);
    const contentType: MessageContentType =
      stored === undefined ? 'text' : 'a2ui';

    const message: Message = {
      id: messageId(current.role, current.createdAt),
      role: current.role,
      text,
      createdAt: current.createdAt,
    };

    if (stored !== undefined) {
      message.metadata = { ...stored.meta, contentType, a2ui: stored.a2ui };
    }

    messages.push(message);
    current = null;
  };

  for (const line of lines) {
    const header = HEADER.exec(line);
    if (header !== null) {
      flush();
      current = {
        role: header[1] as MessageRole,
        createdAt: new Date(header[2]),
        body: [],
      };
      continue;
    }

    if (current !== null) {
      current.body.push(line);
      continue;
    }

    // Before the first header, the only line that carries meaning is the
    // title. Anything else is whitespace or a note someone left at the top.
    const titleMatch = TITLE.exec(line);
    if (titleMatch !== null && title === '') {
      title = titleMatch[1].trim();
    }
  }

  flush();

  return { title, messages };
}

/**
 * A message's id.
 *
 * Derived from the role and timestamp rather than stored, so the id survives a
 * hand-edit of the file and no counter has to be kept anywhere.
 */
export function messageId(role: MessageRole, createdAt: Date): string {
  return `${role}-${createdAt.getTime()}`;
}

/**
 * Turns the first message of a thread into a folder name.
 *
 * Lowercase, ASCII, hyphen-separated, and capped so a long first message does
 * not become a path the filesystem refuses.
 */
export function slugify(text: string): string {
  const slug = text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48)
    .replace(/-+$/g, '');

  return slug === '' ? 'thread' : slug;
}

/**
 * Turns the first message into a thread title: one line, trimmed to length.
 */
export function titleFrom(text: string): string {
  const line = text.trim().split('\n')[0].trim();
  return line.length > 60 ? `${line.slice(0, 59).trimEnd()}...` : line;
}

/**
 * The day folder a message belongs in, as `YYYY-MM-DD` in the server's local
 * timezone, so folders line up with the user's sense of a day rather than UTC's.
 */
export function dayFolder(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Extracts a human-readable preview from a message.
 *
 * For A2UI agent messages, the preview is taken from the first Text component.
 */
export function previewFrom(message: Message): string {
  if (message.metadata?.contentType === 'a2ui' && message.metadata.a2ui) {
    const text = firstTextInTree(message.metadata.a2ui);
    if (text !== undefined) return text.split('\n')[0].trim();
  }

  return message.text.split('\n')[0].trim();
}

function firstTextInTree(component: A2uiComponent): string | undefined {
  for (const key of ['text', 'title']) {
    const value = component[key];
    if (typeof value === 'string' && value.trim() !== '') return value;
  }

  if (Array.isArray(component.children)) {
    for (const child of component.children) {
      const found = firstTextInTree(child as A2uiComponent);
      if (found !== undefined) return found;
    }
  }

  return undefined;
}
