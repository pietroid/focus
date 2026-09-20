import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CalendarEvent,
  CalendarSnapshot,
  isCalendarEvent,
} from './calendar.types';

/**
 * How long a read of the calendar is reused before going back for another.
 *
 * The timeline is rebuilt on every list and every guard, and a day does not
 * change between two taps. Half a minute keeps the screen honest without
 * turning one person scrolling into a few hundred calls an hour.
 */
const CACHE_TTL_MS = 30_000;

/** How far back a window reaches: enough to keep a running event visible. */
const LOOK_BACK_HOURS = 2;

/** How far ahead: the rest of today and the whole of tomorrow. */
const LOOK_AHEAD_HOURS = 36;

/**
 * The calendar, read through the agent.
 *
 * The server never talks to Google and never holds its credentials. It asks
 * the agent, which is the same direction everything else runs in: the server
 * calls the agent, the agent answers, and the agent has no idea the server
 * exists beyond the request it is answering. Nothing calls in the other way,
 * so there is no inbound route to authenticate and no key to keep in step.
 *
 * The route it calls runs no model and no prompt. It is a list call against
 * one calendar, so a drag costs a round trip and not a generation.
 *
 * A read that fails falls back to the last one that worked, mirrored to disk
 * so a restart does not start from an empty calendar. A timeline that is half
 * a minute stale is a small lie; one that says the afternoon is free because
 * Google timed out is a large one.
 */
@Injectable()
export class CalendarReaderService {
  private readonly _logger = new Logger(CalendarReaderService.name);

  private readonly _file = path.join(
    process.env.FOCUS_DATA_DIR ?? path.join(process.cwd(), 'data', 'threads'),
    'calendar-snapshot.json',
  );

  private _snapshot: CalendarSnapshot = { receivedAt: '', events: [] };
  private _loaded = false;
  private _readAt = 0;
  private _inFlight?: Promise<CalendarEvent[]>;

  constructor(private readonly _config: ConfigService) {}

  /** Every event worth knowing about now, from cache when it is fresh. */
  async events(now = new Date()): Promise<CalendarEvent[]> {
    await this._load();

    if (Date.now() - this._readAt < CACHE_TTL_MS) return this._snapshot.events;

    // One refresh at a time. A list and a guard arriving together are two
    // requests asking the same question, and asking Google twice would answer
    // it no better.
    this._inFlight ??= this._refresh(now).finally(() => {
      this._inFlight = undefined;
    });

    return this._inFlight;
  }

  /** The snapshot itself, for working out how stale the timeline is. */
  async snapshot(): Promise<CalendarSnapshot> {
    await this._load();
    return this._snapshot;
  }

  /**
   * Writes one event into the cache without waiting for the next read.
   *
   * A guard that books a block has changed the calendar and already knows
   * what it did. Waiting half a minute to believe itself would mean the card
   * the user just agreed to sitting in the wrong list while the cache aged
   * out.
   */
  async upsert(event: CalendarEvent): Promise<void> {
    await this._load();
    await this._store([
      ...this._snapshot.events.filter((it) => it.id !== event.id),
      event,
    ]);
  }

  /** Takes one event out of the cache, for the same reason. */
  async remove(eventId: string): Promise<void> {
    await this._load();
    await this._store(this._snapshot.events.filter((it) => it.id !== eventId));
  }

  /** Replaces what is cached. Used by tests to stand in for the agent. */
  async replace(events: CalendarEvent[]): Promise<void> {
    await this._load();
    await this._store(events);
    this._readAt = Date.now();
  }

  private async _refresh(now: Date): Promise<CalendarEvent[]> {
    const from = new Date(now.getTime() - LOOK_BACK_HOURS * 3_600_000);
    const to = new Date(now.getTime() + LOOK_AHEAD_HOURS * 3_600_000);

    try {
      const events = await this._fetchWindow(from, to);
      await this._store(events);
      this._readAt = Date.now();
      return events;
    } catch (error) {
      // Logged, not raised. The caller is drawing a timeline or pricing a
      // slot, and the last good answer is a better input to either than an
      // exception.
      this._logger.warn(`Could not read the calendar: ${String(error)}`);
      this._readAt = Date.now();
      return this._snapshot.events;
    }
  }

  private async _fetchWindow(from: Date, to: Date): Promise<CalendarEvent[]> {
    const agentUrl =
      this._config.get<string>('AGENT_URL') ?? 'http://localhost:3001';

    const query = new URLSearchParams({
      from: from.toISOString(),
      to: to.toISOString(),
    });

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10_000);

    try {
      const response = await fetch(
        `${agentUrl}/calendar/window?${query.toString()}`,
        { signal: controller.signal },
      );

      if (!response.ok) {
        throw new Error(`agent returned ${response.status}`);
      }

      const body = (await response.json()) as { events?: unknown[] };
      return (body.events ?? []).filter(isCalendarEvent);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  /** Keeps [events] in memory and mirrors them for the next restart. */
  private async _store(events: CalendarEvent[]): Promise<void> {
    this._snapshot = { receivedAt: new Date().toISOString(), events };

    try {
      await fs.mkdir(path.dirname(this._file), { recursive: true });
      await fs.writeFile(
        this._file,
        JSON.stringify(this._snapshot, null, 2),
        'utf8',
      );
    } catch (error) {
      // The cache is still good in memory, so a disk that will not take it
      // costs nothing until the next restart.
      this._logger.warn(`Could not persist the calendar: ${String(error)}`);
    }
  }

  /** Reads the mirrored snapshot once, on the first request after a restart. */
  private async _load(): Promise<void> {
    if (this._loaded) return;
    this._loaded = true;

    try {
      const content = await fs.readFile(this._file, 'utf8');
      const parsed = JSON.parse(content) as Partial<CalendarSnapshot>;
      this._snapshot = {
        receivedAt: parsed.receivedAt ?? '',
        events: Array.isArray(parsed.events)
          ? parsed.events.filter(isCalendarEvent)
          : [],
      };
    } catch {
      this._snapshot = { receivedAt: '', events: [] };
    }
  }
}
