import { promises as fs } from 'fs';
import * as path from 'path';
import { google, calendar_v3 } from 'googleapis';

/**
 * The Google Calendar client, and the few calls made against it.
 *
 * Shared by the tools, which the model drives, and by the routes the server
 * calls. Both need the same authentication and the same notion of which
 * calendar a given person's calendar is, and having had two copies of that
 * was how a tool and a routine could disagree about which account they were
 * reading.
 *
 * **This is the database.** Nothing about when something happens is stored
 * anywhere else: no mirror in the thread files, no table of hours, nothing to
 * keep in step. An hour exists because Google holds an event for it, and the
 * only way to change one is to change it here.
 */

/** Extended properties Focus writes onto the events it owns. */
const OWNED_KEY = 'focusOwned';
const THREAD_KEY = 'focusThread';
const FIXED_KEY = 'focusFixed';

/** One event, flattened to what the server is given. */
export interface CalendarEvent {
  id: string;
  title: string;
  startTime: string;
  endTime: string;
  /**
   * Whether Focus created this event.
   *
   * An event that arrived some other way is somebody else's arrangement. It
   * is drawn, because the day is not free at that hour, and it is never
   * moved, renamed or deleted by a layout.
   */
  managed: boolean;
  /** Whether the hour is the point of it, so a layout must leave it alone. */
  fixed: boolean;
  /** The conversation about this block, once there is one. */
  threadSlug?: string;
}

/** What an event is created or patched with. */
export interface EventInput {
  title?: string;
  startTime?: string;
  endTime?: string;
  fixed?: boolean;
  /** Set to link a conversation to this event. Never unset. */
  threadSlug?: string;
}

/**
 * Builds an authenticated Google Calendar client from environment variables.
 *
 * The credential is read from the file pointed to by GOOGLE_APPLICATION_CREDENTIALS,
 * matching the backend's Application Default Credentials style. On the Pi the
 * JSON key is mounted into the container at a known path.
 */
export async function getCalendarClient(): Promise<calendar_v3.Calendar> {
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (credentialsPath === undefined || credentialsPath === '') {
    throw new Error('Google Calendar credentials are not configured. Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON key file.');
  }

  let content: string;
  try {
    content = await fs.readFile(credentialsPath, 'utf8');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to read GOOGLE_APPLICATION_CREDENTIALS file "${credentialsPath}": ${message}`);
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
    throw new Error(`Failed to parse GOOGLE_APPLICATION_CREDENTIALS file "${credentialsPath}": ${message}`);
  }
}

/** Who a calendar call is for. */
export interface CalendarUser {
  id: string;
  /** Their Google address, when the server knows it. Used to share once. */
  email?: string;
}

/** Where the userId-to-calendar map is kept between restarts. */
const MAP_FILE = path.join(
  process.env.AGENT_DATA_DIR ?? path.join(process.cwd(), 'data'),
  'calendars.json',
);

/** The resolved calendar per user, so a read costs no lookup. */
const _calendars = new Map<string, string>();
let _loaded = false;

/** One resolution at a time per user, so two reads cannot both create one. */
const _resolving = new Map<string, Promise<string>>();

/**
 * The timezone each person's calendar is kept in.
 *
 * Cached for the life of the process. A calendar's zone is a setting someone
 * changed once, not a fact that moves, and asking Google for it on every read
 * would put a round trip in front of every timeline.
 */
const _zones = new Map<string, string>();

/** The name Focus gives a person's calendar. */
function calendarSummary(userId: string): string {
  return `Focus · ${userId}`;
}

/**
 * The calendar that is this person's calendar, created if it is not there yet.
 *
 * One Google account holds the whole ecosystem and every person in it gets a
 * calendar of their own inside it. That is what keeps one person's afternoon
 * out of another's timeline while leaving Focus a single account that can see
 * across all of them.
 *
 * GOOGLE_CALENDAR_ID still wins when it is set, which is the single-person
 * deployment: one calendar, shared with the service account by hand, and no
 * calendars created behind anyone's back.
 */
export async function calendarIdFor(user: CalendarUser): Promise<string> {
  const configured = process.env.GOOGLE_CALENDAR_ID;
  if (configured !== undefined && configured !== '') return configured;

  await loadMap();

  const known = _calendars.get(user.id);
  if (known !== undefined) return known;

  const inFlight = _resolving.get(user.id);
  if (inFlight !== undefined) return inFlight;

  const resolution = resolveCalendar(user).finally(() => {
    _resolving.delete(user.id);
  });

  _resolving.set(user.id, resolution);
  return resolution;
}

/** Finds this person's calendar by name, or makes them one. */
async function resolveCalendar(user: CalendarUser): Promise<string> {
  const calendar = await getCalendarClient();
  const summary = calendarSummary(user.id);

  const listed = await calendar.calendarList.list({ maxResults: 250 });
  const found = (listed.data.items ?? []).find(
    (entry) => entry.summary === summary,
  );

  if (found?.id !== undefined && found.id !== null) {
    await rememberCalendar(user.id, found.id);
    return found.id;
  }

  const created = await calendar.calendars.insert({
    requestBody: { summary, timeZone: fallbackTimeZone() },
  });

  const id = created.data.id;
  if (id === undefined || id === null) {
    throw new Error(`Could not create a calendar for ${user.id}`);
  }

  // Shared with the person the moment it exists, so the calendar Focus writes
  // to is one they can open in Google and read on their phone. A calendar
  // only the service account can see would be a database pretending to be a
  // calendar.
  if (user.email !== undefined && user.email !== '') {
    try {
      await calendar.acl.insert({
        calendarId: id,
        requestBody: {
          role: 'writer',
          scope: { type: 'user', value: user.email },
        },
      });
    } catch (error) {
      // Worth knowing about and not worth failing over: the calendar exists
      // and Focus can use it, the person just cannot see it yet.
      console.warn('[calendar] could not share calendar', user.email, String(error));
    }
  }

  await rememberCalendar(user.id, id);
  return id;
}

/** Keeps the mapping in memory and on disk. */
async function rememberCalendar(userId: string, calendarId: string): Promise<void> {
  _calendars.set(userId, calendarId);

  try {
    await fs.mkdir(path.dirname(MAP_FILE), { recursive: true });
    await fs.writeFile(
      MAP_FILE,
      JSON.stringify(Object.fromEntries(_calendars), null, 2),
      'utf8',
    );
  } catch (error) {
    // The map is still good in memory, so a disk that will not take it costs
    // one extra lookup after the next restart.
    console.warn('[calendar] could not persist the calendar map:', String(error));
  }
}

/** Reads the mapping once, on the first call after a restart. */
async function loadMap(): Promise<void> {
  if (_loaded) return;
  _loaded = true;

  try {
    const content = await fs.readFile(MAP_FILE, 'utf8');
    const parsed = JSON.parse(content) as Record<string, unknown>;

    for (const [userId, calendarId] of Object.entries(parsed)) {
      if (typeof calendarId === 'string') _calendars.set(userId, calendarId);
    }
  } catch {
    // No map yet. Every calendar will be found by name on first use.
  }
}

/**
 * The zone to fall back on when Google has not been asked yet.
 *
 * TZ if the process was given one, and otherwise the machine's own zone
 * rather than UTC: a container that forgot to set TZ is a container whose
 * clock still knows what hour it is, and answering UTC there is how an
 * evening turned into the following morning.
 */
function fallbackTimeZone(): string {
  const configured = process.env.TZ;
  if (configured !== undefined && configured !== '') return configured;

  return (
    Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'
  );
}

/**
 * The timezone this person's calendar is kept in.
 *
 * **The calendar decides.** Not the server's clock, not the container's TZ:
 * the day someone sees in Google is the day Focus has to reason about, so
 * where the working day starts and ends is read off the calendar itself and
 * everything downstream is measured against that. A zone Google will not
 * give up falls back to the process's own, which is the old behaviour and no
 * worse than it was.
 */
export async function calendarTimeZoneFor(user: CalendarUser): Promise<string> {
  const known = _zones.get(user.id);
  if (known !== undefined) return known;

  try {
    const calendar = await getCalendarClient();
    const calendarId = await calendarIdFor(user);
    const found = await calendar.calendars.get({ calendarId });
    const zone = found.data.timeZone;

    if (typeof zone === 'string' && zone !== '') {
      _zones.set(user.id, zone);
      return zone;
    }
  } catch (error) {
    // Worth a line and not worth failing a read over: the events are still
    // correct instants, and the fallback is what every call used before.
    console.warn('[calendar] could not read the calendar timezone', String(error));
  }

  return fallbackTimeZone();
}

/**
 * Parses an ISO date/time string and returns a date-time or date value
 * suitable for the Google Calendar API.
 *
 * [timeZone] names the calendar's zone. Every instant Focus sends carries its
 * own offset, so this only tells Google which zone to render it back in.
 */
export function toEventDateTime(
  value: string,
  timeZone: string,
): calendar_v3.Schema$EventDateTime {
  // If the value contains a time separator, treat it as a date-time;
  // otherwise treat it as an all-day date.
  if (value.includes('T')) {
    return { dateTime: value, timeZone };
  }
  return { date: value };
}

/** Every event on this person's calendar between [from] and [to]. */
export async function listEventsBetween(
  user: CalendarUser,
  from: Date,
  to: Date,
): Promise<CalendarEvent[]> {
  const calendar = await getCalendarClient();

  const response = await calendar.events.list({
    calendarId: await calendarIdFor(user),
    timeMin: from.toISOString(),
    timeMax: to.toISOString(),
    timeZone: await calendarTimeZoneFor(user),
    singleEvents: true,
    orderBy: 'startTime',
  });

  return (response.data.items ?? [])
    .map(toEvent)
    .filter((event): event is CalendarEvent => event !== null);
}

/** Books an event and returns it as the server will hold it. */
export async function insertEvent(
  user: CalendarUser,
  input: EventInput,
): Promise<CalendarEvent> {
  const calendar = await getCalendarClient();

  if (
    input.title === undefined ||
    input.startTime === undefined ||
    input.endTime === undefined
  ) {
    throw new Error('title, startTime and endTime are required');
  }

  const timeZone = await calendarTimeZoneFor(user);

  const response = await calendar.events.insert({
    calendarId: await calendarIdFor(user),
    requestBody: {
      summary: input.title,
      start: toEventDateTime(input.startTime, timeZone),
      end: toEventDateTime(input.endTime, timeZone),
      extendedProperties: {
        // Stamped on creation and never removed, so an event Focus booked is
        // recognisable as one even after the conversation behind it is gone.
        private: { ...privateProps(input), [OWNED_KEY]: 'true', [FIXED_KEY]: String(input.fixed === true) },
      },
    },
  });

  const event = toEvent(response.data);
  if (event === null) throw new Error('Calendar returned an unusable event');
  return event;
}

/**
 * Changes an event already on the calendar.
 *
 * A patch, so what is not named is left alone: moving a block by half an hour
 * never blanks its title, and linking a conversation to it never moves it.
 */
export async function patchEvent(
  user: CalendarUser,
  eventId: string,
  input: EventInput,
): Promise<CalendarEvent> {
  const calendar = await getCalendarClient();
  const calendarId = await calendarIdFor(user);
  const timeZone = await calendarTimeZoneFor(user);

  const requestBody: calendar_v3.Schema$Event = {};
  if (input.title !== undefined) requestBody.summary = input.title;
  if (input.startTime !== undefined) {
    requestBody.start = toEventDateTime(input.startTime, timeZone);
  }
  if (input.endTime !== undefined) {
    requestBody.end = toEventDateTime(input.endTime, timeZone);
  }

  // Google replaces the whole private bag on a patch, so anything already on
  // the event is read first and carried across. Writing only the new key
  // would be how a move quietly loses the thread behind the block.
  const props = privateProps(input);
  if (Object.keys(props).length > 0) {
    const current = await calendar.events.get({ calendarId, eventId });
    requestBody.extendedProperties = {
      private: {
        ...(current.data.extendedProperties?.private ?? {}),
        ...props,
      },
    };
  }

  const response = await calendar.events.patch({
    calendarId,
    eventId,
    requestBody,
  });

  const event = toEvent(response.data);
  if (event === null) throw new Error('Calendar returned an unusable event');
  return event;
}

/** Removes an event. */
export async function deleteEvent(
  user: CalendarUser,
  eventId: string,
): Promise<void> {
  const calendar = await getCalendarClient();
  await calendar.events.delete({
    calendarId: await calendarIdFor(user),
    eventId,
  });
}

/** What Focus writes into an event's private bag. */
function privateProps(input: EventInput): Record<string, string> {
  const props: Record<string, string> = {};

  if (input.threadSlug !== undefined) props[THREAD_KEY] = input.threadSlug;
  if (input.fixed !== undefined) props[FIXED_KEY] = String(input.fixed);

  return props;
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

  const props = event.extendedProperties?.private ?? {};
  const slug = props[THREAD_KEY];
  const managed = props[OWNED_KEY] === 'true' || slug !== undefined || props[FIXED_KEY] !== undefined;

  return {
    id: event.id,
    title: event.summary ?? 'Sem título',
    startTime: new Date(start).toISOString(),
    endTime: new Date(end).toISOString(),
    managed,
    // Somebody else's meeting is an anchor by definition: nothing Focus does
    // is allowed to move it.
    fixed: managed ? props[FIXED_KEY] === 'true' : true,
    threadSlug: typeof slug === 'string' && slug !== '' ? slug : undefined,
  };
}
