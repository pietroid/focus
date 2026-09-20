import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import { ConfigService } from '@nestjs/config';
import { CalendarReaderService } from './calendar-reader.service';

/** One event, an hour long, starting [inMinutes] from now. */
function event(id: string, inMinutes: number) {
  const start = new Date(Date.now() + inMinutes * 60_000);

  return {
    id,
    title: id,
    startTime: start.toISOString(),
    endTime: new Date(start.getTime() + 3_600_000).toISOString(),
  };
}

describe('reading the calendar through the agent', () => {
  let root: string;
  let reader: CalendarReaderService;
  const fetchMock = jest.fn();

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-cal-'));
    process.env.FOCUS_DATA_DIR = root;

    fetchMock.mockReset();
    global.fetch = fetchMock as typeof fetch;

    reader = new CalendarReaderService(new ConfigService());
  });

  afterEach(async () => {
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  /** An agent that answers with [events]. */
  function answers(events: unknown[]) {
    fetchMock.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ events }),
    });
  }

  it('asks the agent for a window around now', async () => {
    answers([event('a', 30)]);

    expect(await reader.events()).toHaveLength(1);

    const [target] = fetchMock.mock.calls[0] as [string];
    const url = new URL(target);
    expect(url.pathname).toBe('/calendar/window');
    expect(Date.parse(url.searchParams.get('from')!)).toBeLessThan(Date.now());
    expect(Date.parse(url.searchParams.get('to')!)).toBeGreaterThan(Date.now());
  });

  it('reuses the answer rather than asking twice in a row', async () => {
    answers([event('a', 30)]);

    await reader.events();
    await reader.events();

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('asks once when two callers arrive together', async () => {
    answers([event('a', 30)]);

    await Promise.all([reader.events(), reader.events()]);

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('keeps the last good answer when the agent cannot be reached', async () => {
    answers([event('a', 30)]);
    await reader.events();

    fetchMock.mockRejectedValue(new Error('ECONNREFUSED'));
    const fresh = new CalendarReaderService(new ConfigService());

    // A calendar that reads as empty would tell every guard the day was free.
    expect(await fresh.events()).toHaveLength(1);
  });

  it('drops an event it cannot read a time off', async () => {
    answers([event('a', 30), { id: 'b', title: 'b' }]);

    expect((await reader.events()).map((it) => it.id)).toEqual(['a']);
  });

  it('shows a booking before the next read confirms it', async () => {
    answers([]);
    await reader.events();

    await reader.upsert(event('booked', 15));
    expect((await reader.events()).map((it) => it.id)).toEqual(['booked']);

    await reader.remove('booked');
    expect(await reader.events()).toHaveLength(0);
  });
});
