import { Message, MessageRole } from './entities/message.entity';

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
 * Noted.
 * ```
 *
 * Markdown rather than JSON so a day of conversation stays readable, diffable,
 * and editable by hand. The title repeats in every day file: it costs one line
 * and means any single file makes sense on its own, without the folder around
 * it.
 */

/** Matches a message header, and only a message header. */
const HEADER = /^## (user|agent) @ (\d{4}-\d{2}-\d{2}T[\d:.]+Z)$/;

/** Matches the thread title heading. */
const TITLE = /^# (.+)$/;

/**
 * Renders [title] and [messages] as the markdown for one day file.
 */
export function serializeThreadDay(title: string, messages: Message[]): string {
  const blocks = messages.map(
    (message) =>
      `## ${message.role} @ ${message.createdAt.toISOString()}\n\n${message.text.trim()}`,
  );

  return [`# ${title}`, ...blocks].join('\n\n') + '\n';
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
    messages.push({
      id: messageId(current.role, current.createdAt),
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
