import { promises as fs } from 'fs';
import { google, calendar_v3 } from 'googleapis';
import { ToolImplementation, UserContext } from './tool.interface.js';

/**
 * Builds an authenticated Google Calendar client from environment variables.
 *
 * Supports two authentication methods:
 *   1. Service account: set GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON to the raw
 *      JSON key or GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY to a file path.
 *   2. OAuth2 refresh token: set GOOGLE_CALENDAR_REFRESH_TOKEN,
 *      GOOGLE_CALENDAR_CLIENT_ID, and GOOGLE_CALENDAR_CLIENT_SECRET.
 */
async function getCalendarClient(): Promise<calendar_v3.Calendar> {
  const serviceAccountJson = process.env.GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON;
  const serviceAccountKeyPath = process.env.GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY;
  const refreshToken = process.env.GOOGLE_CALENDAR_REFRESH_TOKEN;

  console.log('[calendar] auth method check', {
    hasServiceAccountJson: serviceAccountJson !== undefined && serviceAccountJson !== '',
    hasServiceAccountKeyPath: serviceAccountKeyPath !== undefined && serviceAccountKeyPath !== '',
    hasRefreshToken: refreshToken !== undefined && refreshToken !== '',
  });

  if (serviceAccountJson !== undefined && serviceAccountJson !== '') {
    try {
      const credentials = JSON.parse(serviceAccountJson) as Record<string, unknown>;
      const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ['https://www.googleapis.com/auth/calendar'],
      });
      console.log('[calendar] using service account JSON auth');
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
      console.log('[calendar] using service account key file auth');
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
    console.log('[calendar] using OAuth2 refresh token auth');
    return google.calendar({ version: 'v3', auth: oauth2Client });
  }

  throw new Error(
    'Google Calendar credentials are not configured. Set GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON, GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY, or GOOGLE_CALENDAR_REFRESH_TOKEN.',
  );
}

function getCalendarId(): string {
  const calendarId = process.env.GOOGLE_CALENDAR_ID ?? 'primary';
  console.log('[calendar] using calendar ID', calendarId);
  return calendarId;
}

/**
 * Parses an ISO date/time string and returns a date-time or date value
 * suitable for the Google Calendar API.
 */
function toEventDateTime(value: string): calendar_v3.Schema$EventDateTime {
  // If the value contains a time separator, treat it as a date-time;
  // otherwise treat it as an all-day date.
  if (value.includes('T')) {
    return { dateTime: value, timeZone: process.env.TZ ?? 'UTC' };
  }
  return { date: value };
}

/**
 * Calendar check availability tool backed by Google Calendar.
 *
 * Returns busy intervals for the requested date so the model can suggest free
 * slots. In production this calls the Google Calendar freebusy endpoint.
 */
export class CalendarCheckAvailabilityTool implements ToolImplementation {
  readonly name = 'calendar_check_availability';
  readonly requiresConfirmation = false;

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
 * Requires user confirmation before executing.
 */
export class CalendarCreateEventTool implements ToolImplementation {
  readonly name = 'calendar_create_event';
  readonly requiresConfirmation = true;

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
