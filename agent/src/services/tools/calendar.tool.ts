import { calendar_v3 } from 'googleapis';
import { ToolDefinition, ToolEffect } from '../../types.js';
import {
  getCalendarClient,
  getCalendarId,
  toEventDateTime,
} from '../google-calendar.js';
import { ToolImplementation, UserContext } from './tool.interface.js';

/**
 * Formats an ISO date-time the way a person would read it back.
 *
 * The proposal is the last thing between the model and the user's real
 * calendar, so it says "sex., 20 de set., 10:00" rather than echoing the ISO
 * string the model produced.
 */
function humanDateTime(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;

  const timeZone = process.env.TZ ?? 'UTC';
  return parsed.toLocaleString('pt-BR', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    timeZone,
  });
}

/** The time half of [humanDateTime], for the end of a same-day range. */
function humanTime(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;

  return parsed.toLocaleString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: process.env.TZ ?? 'UTC',
  });
}

/**
 * Calendar check availability tool backed by Google Calendar.
 *
 * Returns busy intervals for the requested date so the model can suggest free
 * slots. In production this calls the Google Calendar freebusy endpoint.
 */
export class CalendarCheckAvailabilityTool implements ToolImplementation {
  readonly name = 'calendar_check_availability';

  readonly effect: ToolEffect = 'read';

  readonly definition: ToolDefinition = {
    type: 'function',
    function: {
      name: 'calendar_check_availability',
      description:
        "Check busy times on the user's calendar for one date. Always call " +
        'this before proposing a meeting time.',
      parameters: {
        type: 'object',
        properties: {
          date: {
            type: 'string',
            description: 'ISO 8601 date, e.g. 2026-09-20',
          },
          durationMinutes: {
            type: 'number',
            description: 'How long the event will last, in minutes',
          },
        },
        required: ['date', 'durationMinutes'],
      },
    },
  };

  summarize(args: Record<string, unknown>): string {
    return `Consultar sua agenda em ${String(args.date ?? 'uma data')}`;
  }

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const rawDate = String(args.date ?? '');
    const durationMinutes = Number(args.durationMinutes ?? 60);

    // The model sometimes passes a full ISO datetime; extract the date part.
    const date = rawDate.includes('T') ? rawDate.split('T')[0] : rawDate;

    console.log('[calendar_check_availability] called', { rawDate, date, durationMinutes });

    if (date === '') {
      throw new Error('date is required');
    }

    let calendar: calendar_v3.Calendar;
    try {
      calendar = await getCalendarClient();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_check_availability] failed to create calendar client:', message);
      throw new Error(`Calendar auth failed: ${message}`);
    }

    const calendarId = getCalendarId();

    // Build a freebusy request for the full day in the configured timezone.
    const timeZone = process.env.TZ ?? 'UTC';
    const dayStart = new Date(`${date}T00:00:00`);
    const dayEnd = new Date(`${date}T23:59:59`);

    const requestBody = {
      timeMin: dayStart.toISOString(),
      timeMax: dayEnd.toISOString(),
      timeZone,
      items: [{ id: calendarId }],
    };
    console.log('[calendar_check_availability] freebusy request', { calendarId, requestBody });

    let response;
    try {
      response = await calendar.freebusy.query({ requestBody });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_check_availability] freebusy query failed:', message);
      throw new Error(`Calendar freebusy query failed: ${message}`);
    }

    const busy = response.data.calendars?.[calendarId]?.busy ?? [];
    const result = {
      date,
      durationMinutes,
      timeZone,
      busyIntervals: busy.map((interval) => ({
        start: interval.start,
        end: interval.end,
      })),
    };
    console.log('[calendar_check_availability] result', result);
    return result;
  }
}

/**
 * Calendar create event tool backed by Google Calendar.
 *
 * A write: the executor refuses it until the user has confirmed the turn.
 */
export class CalendarCreateEventTool implements ToolImplementation {
  readonly name = 'calendar_create_event';

  readonly effect: ToolEffect = 'write';

  readonly definition: ToolDefinition = {
    type: 'function',
    function: {
      name: 'calendar_create_event',
      description:
        'Create a calendar event. This changes the calendar, so it only runs ' +
        'on a turn the user has confirmed. On any other turn it is refused ' +
        'and you must propose it instead.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Event title' },
          startTime: {
            type: 'string',
            description: 'ISO 8601 date-time, e.g. 2026-09-20T10:00:00',
          },
          endTime: {
            type: 'string',
            description: 'ISO 8601 date-time, e.g. 2026-09-20T11:00:00',
          },
        },
        required: ['title', 'startTime', 'endTime'],
      },
    },
  };

  summarize(args: Record<string, unknown>): string {
    const title = String(args.title ?? 'Untitled');
    const start = String(args.startTime ?? '');
    const end = String(args.endTime ?? '');
    if (start === '') return `Adicionar "${title}" na sua agenda`;

    const sameDay = start.slice(0, 10) === end.slice(0, 10);
    const when = sameDay
      ? `${humanDateTime(start)}-${humanTime(end)}`
      : `${humanDateTime(start)} to ${humanDateTime(end)}`;

    return `Adicionar "${title}" na sua agenda em ${when}`;
  }

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const title = String(args.title ?? '');
    const startTime = String(args.startTime ?? '');
    const endTime = String(args.endTime ?? '');

    console.log('[calendar_create_event] called', { title, startTime, endTime });

    if (title === '' || startTime === '' || endTime === '') {
      throw new Error('title, startTime, and endTime are required');
    }

    let calendar: calendar_v3.Calendar;
    try {
      calendar = await getCalendarClient();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_create_event] failed to create calendar client:', message);
      throw new Error(`Calendar auth failed: ${message}`);
    }

    const calendarId = getCalendarId();
    const requestBody = {
      summary: title,
      start: toEventDateTime(startTime),
      end: toEventDateTime(endTime),
    };
    console.log('[calendar_create_event] events.insert request', { calendarId, requestBody });

    let response;
    try {
      response = await calendar.events.insert({
        calendarId,
        requestBody,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_create_event] events.insert failed:', message);
      throw new Error(`Calendar event creation failed: ${message}`);
    }

    const result = {
      id: response.data.id,
      title: response.data.summary,
      startTime: response.data.start?.dateTime ?? response.data.start?.date,
      endTime: response.data.end?.dateTime ?? response.data.end?.date,
      htmlLink: response.data.htmlLink,
    };
    console.log('[calendar_create_event] result', result);
    return result;
  }
}

/**
 * Calendar list events tool backed by Google Calendar.
 *
 * Changing an event means naming it, and the only name the Google API takes is
 * an opaque id. The model cannot invent one, so every edit starts here: this
 * returns what is actually on the day, ids included, and the update and delete
 * tools take one of those ids verbatim.
 */
export class CalendarListEventsTool implements ToolImplementation {
  readonly name = 'calendar_list_events';

  readonly effect: ToolEffect = 'read';

  readonly definition: ToolDefinition = {
    type: 'function',
    function: {
      name: 'calendar_list_events',
      description:
        "List the events on the user's calendar for one date, with their ids. " +
        'Always call this before moving, renaming, or deleting an event: the ' +
        'id it returns is the only way to name the event afterwards.',
      parameters: {
        type: 'object',
        properties: {
          date: {
            type: 'string',
            description: 'ISO 8601 date, e.g. 2026-09-20',
          },
        },
        required: ['date'],
      },
    },
  };

  summarize(args: Record<string, unknown>): string {
    return `Ver seus compromissos em ${String(args.date ?? 'uma data')}`;
  }

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const rawDate = String(args.date ?? '');
    const date = rawDate.includes('T') ? rawDate.split('T')[0] : rawDate;

    console.log('[calendar_list_events] called', { rawDate, date });

    if (date === '') {
      throw new Error('date is required');
    }

    let calendar: calendar_v3.Calendar;
    try {
      calendar = await getCalendarClient();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_list_events] failed to create calendar client:', message);
      throw new Error(`Calendar auth failed: ${message}`);
    }

    const calendarId = getCalendarId();
    const timeZone = process.env.TZ ?? 'UTC';
    const dayStart = new Date(`${date}T00:00:00`);
    const dayEnd = new Date(`${date}T23:59:59`);

    let response;
    try {
      response = await calendar.events.list({
        calendarId,
        timeMin: dayStart.toISOString(),
        timeMax: dayEnd.toISOString(),
        timeZone,
        singleEvents: true,
        orderBy: 'startTime',
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_list_events] events.list failed:', message);
      throw new Error(`Calendar event listing failed: ${message}`);
    }

    const result = {
      date,
      timeZone,
      events: (response.data.items ?? []).map((event) => ({
        id: event.id,
        title: event.summary,
        startTime: event.start?.dateTime ?? event.start?.date,
        endTime: event.end?.dateTime ?? event.end?.date,
      })),
    };
    console.log('[calendar_list_events] result', result);
    return result;
  }
}

/**
 * Calendar update event tool backed by Google Calendar.
 *
 * Patches only the fields that were given, so moving an event by half an hour
 * does not quietly blank its title. A write: the executor refuses it until the
 * user has confirmed the turn.
 */
export class CalendarUpdateEventTool implements ToolImplementation {
  readonly name = 'calendar_update_event';

  readonly effect: ToolEffect = 'write';

  readonly definition: ToolDefinition = {
    type: 'function',
    function: {
      name: 'calendar_update_event',
      description:
        'Move, reschedule, or rename an existing calendar event. Get the ' +
        'eventId from calendar_list_events first. Only pass the fields that ' +
        'change; everything else is left as it is. This changes the calendar, ' +
        'so it only runs on a turn the user has confirmed.',
      parameters: {
        type: 'object',
        properties: {
          eventId: {
            type: 'string',
            description: 'The event id returned by calendar_list_events',
          },
          title: {
            type: 'string',
            description: 'New event title. Omit to keep the current one',
          },
          startTime: {
            type: 'string',
            description: 'New ISO 8601 start, e.g. 2026-09-20T10:30:00',
          },
          endTime: {
            type: 'string',
            description: 'New ISO 8601 end, e.g. 2026-09-20T11:30:00',
          },
          currentTitle: {
            type: 'string',
            description:
              "The event's current title, used only to describe the change " +
              'to the user',
          },
        },
        required: ['eventId'],
      },
    },
  };

  summarize(args: Record<string, unknown>): string {
    const name = String(args.currentTitle ?? args.title ?? 'esse compromisso');
    const start = String(args.startTime ?? '');
    const end = String(args.endTime ?? '');
    const newTitle = String(args.title ?? '');

    if (start !== '') {
      const sameDay = end !== '' && start.slice(0, 10) === end.slice(0, 10);
      const when = sameDay
        ? `${humanDateTime(start)}-${humanTime(end)}`
        : humanDateTime(start);
      return `Mover "${name}" para ${when}`;
    }

    if (newTitle !== '' && args.currentTitle !== undefined) {
      return `Renomear "${name}" para "${newTitle}"`;
    }

    return `Alterar "${name}" na sua agenda`;
  }

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const eventId = String(args.eventId ?? '');
    const title = args.title === undefined ? '' : String(args.title);
    const startTime = args.startTime === undefined ? '' : String(args.startTime);
    const endTime = args.endTime === undefined ? '' : String(args.endTime);

    console.log('[calendar_update_event] called', { eventId, title, startTime, endTime });

    if (eventId === '') {
      throw new Error('eventId is required');
    }
    if (title === '' && startTime === '' && endTime === '') {
      throw new Error('one of title, startTime, or endTime is required');
    }

    let calendar: calendar_v3.Calendar;
    try {
      calendar = await getCalendarClient();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_update_event] failed to create calendar client:', message);
      throw new Error(`Calendar auth failed: ${message}`);
    }

    const calendarId = getCalendarId();
    const requestBody: calendar_v3.Schema$Event = {};
    if (title !== '') requestBody.summary = title;
    if (startTime !== '') requestBody.start = toEventDateTime(startTime);
    if (endTime !== '') requestBody.end = toEventDateTime(endTime);

    console.log('[calendar_update_event] events.patch request', { calendarId, eventId, requestBody });

    let response;
    try {
      response = await calendar.events.patch({
        calendarId,
        eventId,
        requestBody,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_update_event] events.patch failed:', message);
      throw new Error(`Calendar event update failed: ${message}`);
    }

    const result = {
      id: response.data.id,
      title: response.data.summary,
      startTime: response.data.start?.dateTime ?? response.data.start?.date,
      endTime: response.data.end?.dateTime ?? response.data.end?.date,
      htmlLink: response.data.htmlLink,
    };
    console.log('[calendar_update_event] result', result);
    return result;
  }
}

/**
 * Calendar delete event tool backed by Google Calendar.
 *
 * A write: the executor refuses it until the user has confirmed the turn.
 */
export class CalendarDeleteEventTool implements ToolImplementation {
  readonly name = 'calendar_delete_event';

  readonly effect: ToolEffect = 'write';

  readonly definition: ToolDefinition = {
    type: 'function',
    function: {
      name: 'calendar_delete_event',
      description:
        'Delete an event from the calendar. Get the eventId from ' +
        'calendar_list_events first. This changes the calendar, so it only ' +
        'runs on a turn the user has confirmed.',
      parameters: {
        type: 'object',
        properties: {
          eventId: {
            type: 'string',
            description: 'The event id returned by calendar_list_events',
          },
          title: {
            type: 'string',
            description:
              "The event's title, used only to describe the deletion to the " +
              'user',
          },
        },
        required: ['eventId'],
      },
    },
  };

  summarize(args: Record<string, unknown>): string {
    const title = String(args.title ?? '');
    if (title === '') return 'Excluir esse compromisso da sua agenda';
    return `Excluir "${title}" da sua agenda`;
  }

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const eventId = String(args.eventId ?? '');
    const title = String(args.title ?? '');

    console.log('[calendar_delete_event] called', { eventId, title });

    if (eventId === '') {
      throw new Error('eventId is required');
    }

    let calendar: calendar_v3.Calendar;
    try {
      calendar = await getCalendarClient();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_delete_event] failed to create calendar client:', message);
      throw new Error(`Calendar auth failed: ${message}`);
    }

    const calendarId = getCalendarId();
    console.log('[calendar_delete_event] events.delete request', { calendarId, eventId });

    try {
      await calendar.events.delete({ calendarId, eventId });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[calendar_delete_event] events.delete failed:', message);
      throw new Error(`Calendar event deletion failed: ${message}`);
    }

    const result = { id: eventId, deleted: true, title };
    console.log('[calendar_delete_event] result', result);
    return result;
  }
}
