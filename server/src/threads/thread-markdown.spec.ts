import { Message } from './entities/message.entity';
import {
  dayFolder,
  parseThreadDay,
  serializeThreadDay,
  slugify,
  titleFrom,
} from './thread-markdown';

function message(role: Message['role'], text: string, iso: string): Message {
  return {
    id: `${role}-${new Date(iso).getTime()}`,
    role,
    text,
    createdAt: new Date(iso),
  };
}

describe('thread markdown', () => {
  const messages = [
    message('user', 'Buy milk tomorrow', '2026-09-15T19:23:04.123Z'),
    message('agent', 'Noted.', '2026-09-15T19:23:05.456Z'),
  ];

  it('round-trips a day of conversation', () => {
    const markdown = serializeThreadDay('Buy milk tomorrow', messages);
    const parsed = parseThreadDay(markdown);

    expect(parsed.title).toBe('Buy milk tomorrow');
    expect(parsed.messages).toEqual(messages);
  });

  it('writes a readable file', () => {
    expect(serializeThreadDay('Buy milk tomorrow', messages)).toBe(
      [
        '# Buy milk tomorrow',
        '',
        '## user @ 2026-09-15T19:23:04.123Z',
        '',
        'Buy milk tomorrow',
        '',
        '## agent @ 2026-09-15T19:23:05.456Z',
        '',
        'Noted.',
        '',
      ].join('\n'),
    );
  });

  it('keeps a markdown heading inside a message body', () => {
    const withHeading = [
      message(
        'agent',
        '## Steps\n\n1. Go to the shop\n2. Buy milk',
        '2026-09-15T19:23:05.456Z',
      ),
    ];

    const parsed = parseThreadDay(serializeThreadDay('Buy milk', withHeading));

    expect(parsed.messages).toEqual(withHeading);
  });

  it('parses a file that was hand-edited', () => {
    const parsed = parseThreadDay(
      [
        '# Hand written',
        '',
        'a stray note above the first message',
        '',
        '## user @ 2026-09-15T08:00:00.000Z',
        'no blank line after the header',
        '',
        '',
        '## agent @ 2026-09-15T08:00:01.000Z',
        '',
        'trailing blanks   ',
        '',
      ].join('\n'),
    );

    expect(parsed.title).toBe('Hand written');
    expect(parsed.messages.map((m) => m.text)).toEqual([
      'no blank line after the header',
      'trailing blanks',
    ]);
  });

  it('returns nothing for an empty file', () => {
    expect(parseThreadDay('')).toEqual({ title: '', messages: [] });
  });
});

describe('slugify', () => {
  it('makes a path-safe folder name', () => {
    expect(slugify('Buy milk tomorrow!')).toBe('buy-milk-tomorrow');
  });

  it('strips accents', () => {
    expect(slugify('Reunião às três')).toBe('reuniao-as-tres');
  });

  it('caps the length without a trailing hyphen', () => {
    const slug = slugify('a '.repeat(60));
    expect(slug.length).toBeLessThanOrEqual(48);
    expect(slug.endsWith('-')).toBe(false);
  });

  it('falls back when nothing survives', () => {
    expect(slugify('!!!')).toBe('thread');
    expect(slugify('')).toBe('thread');
  });
});

describe('titleFrom', () => {
  it('takes the first line', () => {
    expect(titleFrom('Buy milk\nand eggs')).toBe('Buy milk');
  });

  it('truncates a long line', () => {
    const title = titleFrom('x'.repeat(200));
    expect(title).toHaveLength(62);
    expect(title.endsWith('...')).toBe(true);
  });
});

describe('dayFolder', () => {
  it('formats the local date', () => {
    expect(dayFolder(new Date(2026, 8, 15, 23, 59))).toBe('2026-09-15');
    expect(dayFolder(new Date(2026, 0, 1, 0, 0))).toBe('2026-01-01');
  });
});
