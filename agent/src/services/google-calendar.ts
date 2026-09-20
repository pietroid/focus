import { promises as fs } from 'fs';
import { google, calendar_v3 } from 'googleapis';

/**
 * The Google Calendar client, and the few calls made against it.
 *
 * Shared by the tools, which the model drives, and by the sync routine, which
 * the clock drives. Both need the same authentication and the same notion of
 * which calendar "the calendar" is, and having had two copies of that was how
 * a tool and a routine could disagree about which account they were reading.
 */

/** One event, flattened to what the server is given. */
export interface CalendarEvent {
  id: string;
  title: string;
  startTime: string;
  endTime: string;
}

/**
 * Builds an authenticated Google Calendar client from environment variables.
 *
 * Supports two authentication methods:
 *   1. Service account: set GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON to the raw
 *      JSON key or GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY to a file path.
 *   2. OAuth2 refresh token: set GOOGLE_CALENDAR_REFRESH_TOKEN,
 *      GOOGLE_CALENDAR_CLIENT_ID, and GOOGLE_CALENDAR_CLIENT_SECRET.
 */
export async function getCalendarClient(): Promise<calendar_v3.Calendar> {
  const serviceAccountJson = process.env.GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON;
  const serviceAccountKeyPath = process.env.GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY;
  const refreshToken = process.env.GOOGLE_CALENDAR_REFRESH_TOKEN;

  if (serviceAccountJson !== undefined && serviceAccountJson !== '') {
    try {
      const credentials = JSON.parse(serviceAccountJson) as Record<string, unknown>;
      const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ['https://www.googleapis.com/auth/calendar'],
      });
      return google.calendar({ version: 'v3', auth });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to parse GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON: ${message}`);
    }
  }

  if (serviceAccountKeyPath !== undefined && serviceAccountKeyPath !== '') {
    let content: string;
    try {
      content = await fs.readFile(serviceAccountKeyPath, 'utf8');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to read service account key file "${serviceAccountKeyPath}": ${message}`);
    }
    try {
      const credentials = JSON.parse(content) as Record<string, unknown>;
      const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ['https://www.googleapis.com/auth/calendar'],
      });
      return google.calendar({ version: 'v3', auth });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to parse service account key file "${serviceAccountKeyPath}": ${message}`);
    }
  }

  if (refreshToken !== undefined && refreshToken !== '') {
    const clientId = process.env.GOOGLE_CALENDAR_CLIENT_ID ?? '';
    const clientSecret = process.env.GOOGLE_CALENDAR_CLIENT_SECRET ?? '';

    if (clientId === '' || clientSecret === '') {
      throw new Error(
        'GOOGLE_CALENDAR_CLIENT_ID and GOOGLE_CALENDAR_CLIENT_SECRET are required when using refresh token auth',
      );
    }

    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);
    oauth2Client.setCredentials({ refresh_token: refreshToken });
    return google.calendar({ version: 'v3', auth: oauth2Client });
  }

  throw new Error(
    'Google Calendar credentials are not configured. Set GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON, GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY, or GOOGLE_CALENDAR_REFRESH_TOKEN.',
  );
}

/** Which calendar "the calendar" is. */
export function getCalendarId(): string {
  return process.env.GOOGLE_CALENDAR_ID ?? 'primary';
}

/**
 * Parses an ISO date/time string and returns a date-time or date value
 * suitable for the Google Calendar API.
 */
export function toEventDateTime(value: string): calendar_v3.Schema$EventDateTime {
  // If the value contains a time separator, treat it as a date-time;
  // otherwise treat it as an all-day date.
  if (value.includes('T')) {
    return { dateTime: value, timeZone: process.env.TZ ?? 'UTC' };
  }
  return { date: value };
}

/** Every event between [from] and [to], expanded and in time order. */
export async function listEventsBetween(
  from: Date,
  to: Date,
): Promise<CalendarEvent[]> {
  const calendar = await getCalendarClient();

  const response = await calendar.events.list({
    calendarId: getCalendarId(),
    timeMin: from.toISOString(),
    timeMax: to.toISOString(),
    timeZone: process.env.TZ ?? 'UTC',
    singleEvents: true,
    orderBy: 'startTime',
  });

  return (response.data.items ?? [])
    .map(toEvent)
    .filter((event): event is CalendarEvent => event !== null);
}

/** Books an event and returns it as the server will hold it. */
export async function insertEvent(input: {
  title: string;
  startTime: string;
  endTime: string;
}): Promise<CalendarEvent> {
  const calendar = await getCalendarClient();

  const response = await calendar.events.insert({
    calendarId: getCalendarId(),
    requestBody: {
      summary: input.title,
      start: toEventDateTime(input.startTime),
      end: toEventDateTime(input.endTime),
    },
  });

  const event = toEvent(response.data);
  if (event === null) throw new Error('Calendar returned an unusable event');
  return event;
}

/** Moves an event already on the calendar. */
export async function patchEventTime(
  eventId: string,
  when: { startTime: string; endTime: string },
): Promise<CalendarEvent> {
  const calendar = await getCalendarClient();

  const response = await calendar.events.patch({
    calendarId: getCalendarId(),
    eventId,
    requestBody: {
      start: toEventDateTime(when.startTime),
      end: toEventDateTime(when.endTime),
    },
  });

  const event = toEvent(response.data);
  if (event === null) throw new Error('Calendar returned an unusable event');
  return event;
}

/** Removes an event. */
export async function deleteEvent(eventId: string): Promise<void> {
  const calendar = await getCalendarClient();
  await calendar.events.delete({ calendarId: getCalendarId(), eventId });
}

/**
 * One Google event, or null when it is not something the timeline can draw.
 *
 * An all-day event has a date and no time, so it has no place on a screen
 * that is about the next few hours, and a cancelled one has no place
 * anywhere.
 */
function toEvent(event: calendar_v3.Schema$Event): CalendarEvent | null {
  const start = event.start?.dateTime;
  const end = event.end?.dateTime;

  if (
    typeof event.id !== 'string' ||
    typeof start !== 'string' ||
    typeof end !== 'string' ||
    event.status === 'cancelled'
  ) {
    return null;
  }

  return {
    id: event.id,
    title: event.summary ?? 'Sem título',
    startTime: new Date(start).toISOString(),
    endTime: new Date(end).toISOString(),
  };
}
