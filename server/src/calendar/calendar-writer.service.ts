import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Trace } from '../common/trace';
import { CalendarEvent } from './calendar.types';

/** Raised when the calendar could not be changed. */
export class CalendarWriteError extends Error {}

/**
 * Changes to the calendar, made through the agent.
 *
 * The rule that the server never holds an integration secret still stands:
 * this asks the agent to do it, over the same private network and with the
 * same lack of ceremony as `/generate`. The routes it calls run no model and
 * have no prompt, so a guard that reserves a block is a plain HTTP call and
 * not a turn, which is what keeps a reorder from costing a generation.
 */
@Injectable()
export class CalendarWriterService {
  constructor(private readonly _config: ConfigService) {}

  /** Books [event] on the focus calendar and returns it with its new id. */
  async create(
    event: { title: string; startTime: string; endTime: string },
    trace: Trace,
  ): Promise<CalendarEvent> {
    return trace.span('calendar.create', { title: event.title }, async () =>
      this._fetch<CalendarEvent>('POST', '/calendar/events', event),
    );
  }

  /** Moves an event already on the calendar. */
  async move(
    eventId: string,
    when: { startTime: string; endTime: string },
    trace: Trace,
  ): Promise<CalendarEvent> {
    return trace.span('calendar.move', { eventId }, async () =>
      this._fetch<CalendarEvent>(
        'PATCH',
        `/calendar/events/${encodeURIComponent(eventId)}`,
        when,
      ),
    );
  }

  /** Takes an event off the calendar entirely. */
  async remove(eventId: string, trace: Trace): Promise<void> {
    await trace.span('calendar.remove', { eventId }, async () =>
      this._fetch<unknown>(
        'DELETE',
        `/calendar/events/${encodeURIComponent(eventId)}`,
      ),
    );
  }

  private async _fetch<T>(
    method: 'POST' | 'PATCH' | 'DELETE',
    path: string,
    body?: unknown,
  ): Promise<T> {
    const agentUrl =
      this._config.get<string>('AGENT_URL') ?? 'http://localhost:3001';

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15_000);

    try {
      const response = await fetch(`${agentUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });

      if (!response.ok) {
        const detail = await response.text().catch(() => '');
        throw new CalendarWriteError(
          `Agent ${path} returned ${response.status}: ${detail.slice(0, 300)}`,
        );
      }

      return (await response.json()) as T;
    } catch (error) {
      if (error instanceof CalendarWriteError) throw error;
      const message = error instanceof Error ? error.message : String(error);
      throw new CalendarWriteError(`Agent ${path} failed: ${message}`);
    } finally {
      clearTimeout(timeoutId);
    }
  }
}
