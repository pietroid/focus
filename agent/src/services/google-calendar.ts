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
const PAUSED_AT_KEY = 'focusPausedAt';
const REMAINING_KEY = 'focusRemaining';
const PAUSED_TOTAL_KEY = 'focusPausedTotal';
const STARTED_KEY = 'focusStarted';
const NOT_BEFORE_KEY = 'focusNotBefore';
const ROUTINE_KEY = 'focusRoutine';

/**
 * Which days a routine repeats on.
 *
 * The repetition itself is Google's: a routine is one recurring event, and
 * this key only says it is one of Focus's, so the timeline can tell lunch
 * apart from a block somebody wrote down this morning.
 */
export type RoutineDays = 'daily' | 'weekdays' | 'weekend';

const ROUTINE_DAYS: readonly RoutineDays[] = ['daily', 'weekdays', 'weekend'];

/** The RRULE Google repeats a routine with. */
export function recurrenceFor(days: RoutineDays): string[] {
  switch (days) {
    case 'weekdays':
      return ['RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'];
    case 'weekend':
      return ['RRULE:FREQ=WEEKLY;BYDAY=SA,SU'];
    default:
      return ['RRULE:FREQ=DAILY'];
  }
}

/** [value] as routine days, or undefined when it is not one. */
export function routineDaysOf(value: unknown): RoutineDays | undefined {
  return ROUTINE_DAYS.includes(value as RoutineDays)
    ? (value as RoutineDays)
    : undefined;
}

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
  /** ISO 8601, when the block was paused. Absent while it runs. */
  pausedAt?: string;
  /** Seconds of work still owed when it was paused. */
  remainingSeconds?: number;
  /** Seconds it spent paused before the current pause, if any. */
  pausedSeconds?: number;
  /** Whether the user confirmed they began it. */
  started?: boolean;
  /** ISO 8601. A layout never starts it earlier than this. */
  notBefore?: string;
  /** Set on every instance of a routine, and on the routine itself. */
  routine?: RoutineDays;
}

/** What an event is created or patched with. */
export interface EventInput {
  title?: string;
  startTime?: string;
  endTime?: string;
  fixed?: boolean;
  /** Set to link a conversation to this event. Never unset. */
  threadSlug?: string;
  /** When the block was paused. An empty string resumes it. */
  pausedAt?: string;
  remainingSeconds?: number;
  pausedSeconds?: number;
  started?: boolean;
  /** An empty string lifts it. */
  notBefore?: string;
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
  /**
   * Their display name, when the server knows it.
   *
   * The calendar is named after this, because the name is what shows up in
   * anyone else's Google once the calendar is shared, and a Firebase uid
   * reads as a database key rather than a person.
   */
  name?: string;
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

/**
 * The name Focus gives a person's calendar: their first name, and nothing
 * else.
 *
 * This is a title somebody reads, not a key. The calendar is shared with the
 * person and with whoever else they add it to, and what those people see in
 * their own Google is this string, so "Pietro" is the whole of it. Two people
 * called the same thing would get the same title and that is fine: nothing
 * looks a calendar up by it once the id is known, and the map on disk is what
 * keeps them apart.
 *
 * The uid is the last resort, for a call that arrived without a name and
 * without an address. It is the old behaviour, and it is renamed the first
 * time a request does know who this is.
 */
function calendarSummary(user: CalendarUser): string {
  return firstNameOf(user) ?? user.id;
}

/** The legacy title, still looked for so an existing calendar is found. */
function legacySummary(userId: string): string {
  return `Focus · ${userId}`;
}

/**
 * The uid, written into the calendar's description.
 *
 * The title used to be the uid and so could be searched on; a first name
 * cannot, because two people may share one. The description is where the
 * machine-readable half went, so a lost map is still rebuilt against the
 * right calendar and never against somebody else's.
 */
function ownerMark(userId: string): string {
  return `Focus · ${userId}`;
}

/**
 * The first name of [user], from whatever the request knew.
 *
 * The display name when there is one, and otherwise the local part of the
 * address up to the first separator, capitalised: "pietro.teruya@..." is a
 * person called Pietro, and a calendar named after them reads better than one
 * named after their inbox.
 */
function firstNameOf(user: CalendarUser): string | undefined {
  const given = user.name?.trim().split(/\s+/)[0];
  if (given !== undefined && given !== '') return given;

  const local = user.email?.split('@')[0]?.split(/[._-]/)[0];
  if (local === undefined || local === '') return undefined;

  return local.charAt(0).toUpperCase() + local.slice(1);
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
 *
 * Next comes GOOGLE_CALENDAR_MAP, which assigns a Google address to a
 * calendar by name or by id. It is how a person is put on a calendar
 * somebody chose, rather than the one Focus would have made them.
 */
export async function calendarIdFor(user: CalendarUser): Promise<string> {
  const configured = process.env.GOOGLE_CALENDAR_ID;
  if (configured !== undefined && configured !== '') return configured;

  await loadMap();

  const assigned = await assignedCalendarFor(user);
  if (assigned !== undefined) return assigned;

  const known = _calendars.get(user.id);
  if (known !== undefined) {
    // The map survives restarts, so a calendar found here never goes through
    // [resolveCalendar] again and would keep whatever title it was created
    // with forever.
    await ensureNamed(known, user);
    return known;
  }

  const inFlight = _resolving.get(user.id);
  if (inFlight !== undefined) return inFlight;

  const resolution = resolveCalendar(user).finally(() => {
    _resolving.delete(user.id);
  });

  _resolving.set(user.id, resolution);
  return resolution;
}

/** The assignments, read once per process. Undefined until then. */
let _assignments: Map<string, string> | undefined;

/** The id each assigned address resolved to, so a name is listed once. */
const _assignedIds = new Map<string, string>();

/** Calendars this process has already put in order for an assignment. */
const _prepared = new Set<string>();

/**
 * Reads GOOGLE_CALENDAR_MAP: `email=calendar` pairs, separated by commas.
 *
 *     pietro@example.com=Pietro,ana@example.com=abc123@group.calendar.google.com
 *
 * A calendar is an id when it looks like one (it has an `@`, or it is
 * `primary`) and a name otherwise. The pair splits on its first `=`, which an
 * address never contains, so a name is free to have spaces. Addresses are
 * matched without case, because Firebase and a hand-written line will not
 * agree on it. A malformed pair is skipped rather than failing the others.
 */
export function parseAssignments(value: string): Map<string, string> {
  const assignments = new Map<string, string>();

  for (const pair of value.split(',')) {
    const at = pair.indexOf('=');
    if (at < 0) continue;

    const email = pair.slice(0, at).trim().toLowerCase();
    const calendar = pair.slice(at + 1).trim();
    if (email === '' || calendar === '') continue;

    assignments.set(email, calendar);
  }

  return assignments;
}

/** Whether an assignment names a calendar by id rather than by name. */
export function isCalendarId(value: string): boolean {
  return value === 'primary' || value.includes('@');
}

function loadAssignments(): Map<string, string> {
  _assignments ??= parseAssignments(process.env.GOOGLE_CALENDAR_MAP ?? '');
  return _assignments;
}

/**
 * The calendar this person's address was assigned in GOOGLE_CALENDAR_MAP.
 *
 * An assignment beats the uid map, because it is somebody's decision and the
 * uid map is only a memory of an older one. The answer is written into the
 * uid map as well, since the model's tools call with a uid and no address and
 * have to land on the same calendar the timeline reads.
 */
async function assignedCalendarFor(user: CalendarUser): Promise<string | undefined> {
  const email = user.email?.trim().toLowerCase();
  if (email === undefined || email === '') return undefined;

  const known = _assignedIds.get(email);
  if (known !== undefined) return known;

  const assigned = loadAssignments().get(email);
  if (assigned === undefined) return undefined;

  // Keyed apart from the uid resolutions, which share the map but not this
  // path, so two reads cannot both create the named calendar.
  const key = `assigned:${email}`;
  const inFlight = _resolving.get(key);
  if (inFlight !== undefined) return inFlight;

  const resolution = resolveAssigned(assigned, email, user).finally(() => {
    _resolving.delete(key);
  });

  _resolving.set(key, resolution);
  return resolution;
}

async function resolveAssigned(
  assigned: string,
  email: string,
  user: CalendarUser,
): Promise<string> {
  const id = isCalendarId(assigned)
    ? assigned
    : await calendarNamed(assigned, user);

  await prepareAssigned(id, email);
  if (_calendars.get(user.id) !== id) await rememberCalendar(user.id, id);
  _assignedIds.set(email, id);
  return id;
}

/**
 * The calendar called [name] in the account, created if there is none.
 *
 * Only calendars in the service account's own list are found, which is the
 * ones it created and the ones added to its list by id. A calendar somebody
 * else owns and merely shared is not in that list until it has been assigned
 * by id once.
 */
async function calendarNamed(name: string, user: CalendarUser): Promise<string> {
  const calendar = await getCalendarClient();
  const listed = await calendar.calendarList.list({ maxResults: 250 });
  const found = (listed.data.items ?? []).find((entry) => entry.summary === name);

  if (typeof found?.id === 'string') return found.id;

  const created = await calendar.calendars.insert({
    requestBody: {
      summary: name,
      description: ownerMark(user.id),
      timeZone: fallbackTimeZone(),
    },
  });

  if (typeof created.data.id !== 'string') {
    throw new Error(`Could not create the calendar "${name}"`);
  }
  return created.data.id;
}

/**
 * Makes an assigned calendar usable and visible, once per process.
 *
 * It goes into the service account's calendar list, so a calendar shared in
 * from another account can be named rather than id'd from then on. And when
 * the service account owns it, the person it is assigned to is given write
 * access, so they can open it in their own Google. A share that is already
 * there is left alone, which is what keeps a restart from mailing them again.
 *
 * Best effort: Focus can read and write the calendar whether or not either
 * of these went through.
 */
async function prepareAssigned(calendarId: string, email: string): Promise<void> {
  const key = `${calendarId} ${email}`;
  if (_prepared.has(key)) return;
  _prepared.add(key);

  const calendar = await getCalendarClient();

  try {
    await calendar.calendarList.insert({ requestBody: { id: calendarId } });
  } catch {
    // Already in the list, or not shared with the service account at all, in
    // which case the read that follows says so far more clearly.
  }

  try {
    const entry = await calendar.calendarList.get({ calendarId });
    if (entry.data.accessRole !== 'owner') return;

    const ruleId = `user:${email}`;
    try {
      await calendar.acl.get({ calendarId, ruleId });
      return;
    } catch {
      // No rule for them yet.
    }

    await calendar.acl.insert({
      calendarId,
      requestBody: { role: 'writer', scope: { type: 'user', value: email } },
    });
  } catch (error) {
    console.warn('[calendar] could not share the assigned calendar', calendarId, email, String(error));
  }
}

/** Finds this person's calendar by name, or makes them one. */
async function resolveCalendar(user: CalendarUser): Promise<string> {
  const calendar = await getCalendarClient();
  const summary = calendarSummary(user);

  // The description first, because it is the only unambiguous half: two
  // people called Pietro would both answer to the title. The old uid title
  // comes next, so a calendar created before the rename is found and renamed
  // rather than duplicated, and the current title last.
  const listed = await calendar.calendarList.list({ maxResults: 250 });
  const entries = listed.data.items ?? [];

  const found =
    entries.find((entry) => entry.description === ownerMark(user.id)) ??
    entries.find((entry) => entry.summary === legacySummary(user.id)) ??
    entries.find((entry) => entry.summary === summary);

  if (found?.id !== undefined && found.id !== null) {
    await rememberCalendar(user.id, found.id);
    await ensureNamed(found.id, user, found);
    return found.id;
  }

  const created = await calendar.calendars.insert({
    requestBody: {
      summary,
      description: ownerMark(user.id),
      timeZone: fallbackTimeZone(),
    },
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

/** Calendars this process has already checked the title of. */
const _named = new Set<string>();

/**
 * Renames [calendarId] to this person's first name, once per process.
 *
 * Only a title Focus itself wrote is replaced: the uid, or the old
 * `Focus · <uid>`. A calendar somebody has renamed by hand is theirs and is
 * left exactly as they left it, which is also what stops this from undoing
 * their choice on every restart.
 *
 * Best effort throughout. A title is cosmetic, and failing a read of the day
 * over one would be the wrong trade.
 */
async function ensureNamed(
  calendarId: string,
  user: CalendarUser,
  current?: calendar_v3.Schema$CalendarListEntry,
): Promise<void> {
  if (_named.has(calendarId)) return;
  _named.add(calendarId);

  const summary = calendarSummary(user);
  // Nothing better than the uid to offer, so nothing to say.
  if (summary === user.id) return;

  try {
    const calendar = await getCalendarClient();
    const found =
      current ?? (await calendar.calendars.get({ calendarId })).data;

    const title = found.summary ?? '';
    const mark = ownerMark(user.id);

    // Already right, which is every call after the first one.
    if (title === summary && found.description === mark) return;

    // Not a title Focus wrote. Somebody renamed their own calendar and that
    // is theirs to have done; putting the first name back on every restart
    // would be undoing their choice on a schedule.
    if (title !== summary && title !== user.id && title !== legacySummary(user.id)) {
      return;
    }

    // The description goes on with the title, so the next lookup after a lost
    // map has something to match that is not a first name.
    await calendar.calendars.patch({
      calendarId,
      requestBody: { summary, description: mark },
    });
  } catch (error) {
    console.warn('[calendar] could not rename calendar', calendarId, String(error));
  }
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
 * The zone the deployment was told to use, if it was told one.
 *
 * FOCUS_TIMEZONE or TZ, and nothing inferred. This is the difference that
 * matters: `Intl` in a container that was never given a zone answers UTC with
 * complete confidence, so a guessed zone and a configured one cannot be
 * treated the same. Only a configured one is allowed to overrule Google.
 */
function configuredTimeZone(): string | undefined {
  for (const value of [process.env.FOCUS_TIMEZONE, process.env.TZ]) {
    if (value !== undefined && value.trim() !== '') return value.trim();
  }

  return undefined;
}

/**
 * The zone to fall back on when Google has not been asked yet.
 *
 * The configured zone, and otherwise the machine's own rather than UTC: a
 * container that forgot to set TZ is a container whose clock still knows what
 * hour it is, and answering UTC there is how an evening turned into the
 * following morning.
 */
function fallbackTimeZone(): string {
  return (
    configuredTimeZone() ??
    Intl.DateTimeFormat().resolvedOptions().timeZone ??
    'UTC'
  );
}

/**
 * The timezone this person's calendar is kept in.
 *
 * **The calendar decides, unless the deployment has said otherwise.** The day
 * someone sees in Google is the day Focus has to reason about, so normally
 * the zone is read off the calendar itself and everything downstream is
 * measured against that.
 *
 * FOCUS_TIMEZONE (or TZ) overrules it, and that is not a detail. These
 * calendars live inside one service account, and a calendar created by a
 * container running in UTC is a UTC calendar no matter where its owner lives.
 * Reading that setting back and believing it is how the working day ended up
 * starting at four in the morning in São Paulo and how an evening block was
 * pushed to the next day. So when the deployment names a zone, that zone
 * wins, and the calendar is patched to agree with it so Google shows the same
 * hours Focus does.
 *
 * Cached per person for the life of the process: a zone is a setting somebody
 * changed once, and a timeline rebuild asks for it a few hundred times.
 */
export async function calendarTimeZoneFor(user: CalendarUser): Promise<string> {
  const known = _zones.get(user.id);
  if (known !== undefined) return known;

  const wanted = configuredTimeZone();

  try {
    const calendar = await getCalendarClient();
    const calendarId = await calendarIdFor(user);
    const found = await calendar.calendars.get({ calendarId });
    const zone = found.data.timeZone;

    if (wanted !== undefined) {
      if (zone !== wanted) await retimeCalendar(calendarId, wanted);
      _zones.set(user.id, wanted);
      return wanted;
    }

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

/** Moves [calendarId] onto [timeZone], so Google reads the hours Focus does. */
async function retimeCalendar(calendarId: string, timeZone: string): Promise<void> {
  try {
    const calendar = await getCalendarClient();
    await calendar.calendars.patch({ calendarId, requestBody: { timeZone } });
  } catch (error) {
    // Cosmetic on Google's side. Focus already has the zone it is going to
    // use, and every instant it writes carries its own offset.
    console.warn('[calendar] could not set the calendar timezone', calendarId, String(error));
  }
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
  if (input.pausedAt !== undefined) props[PAUSED_AT_KEY] = input.pausedAt;
  if (input.remainingSeconds !== undefined) {
    props[REMAINING_KEY] = String(Math.round(input.remainingSeconds));
  }
  if (input.pausedSeconds !== undefined) {
    props[PAUSED_TOTAL_KEY] = String(Math.round(input.pausedSeconds));
  }
  if (input.started !== undefined) props[STARTED_KEY] = String(input.started);
  if (input.notBefore !== undefined) props[NOT_BEFORE_KEY] = input.notBefore;

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
  const notBefore = props[NOT_BEFORE_KEY];
  const routine = routineDaysOf(props[ROUTINE_KEY]);

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
    ...pauseOf(props),
    ...(props[STARTED_KEY] === 'true' ? { started: true } : {}),
    ...(typeof notBefore === 'string' && !Number.isNaN(Date.parse(notBefore))
      ? { notBefore: new Date(notBefore).toISOString() }
      : {}),
    ...(routine === undefined ? {} : { routine }),
  };
}

/** The pause Focus wrote on an event, read back. An empty key means none. */
function pauseOf(
  props: Record<string, string>,
): Pick<CalendarEvent, 'pausedAt' | 'remainingSeconds' | 'pausedSeconds'> {
  const pausedAt = props[PAUSED_AT_KEY];
  const remaining = Number(props[REMAINING_KEY]);
  const total = Number(props[PAUSED_TOTAL_KEY]);
  const paused =
    typeof pausedAt === 'string' && !Number.isNaN(Date.parse(pausedAt));

  return {
    pausedAt: paused ? new Date(pausedAt).toISOString() : undefined,
    remainingSeconds: paused && Number.isFinite(remaining) ? remaining : undefined,
    pausedSeconds: Number.isFinite(total) && total > 0 ? total : undefined,
  };
}

/** What a routine is created or changed with. */
export interface RoutineInput {
  title?: string;
  /** ISO 8601, the first occurrence. Its wall-clock hour is every day's. */
  startTime?: string;
  endTime?: string;
  days?: RoutineDays;
}

/** One routine, as the menu that edits it reads it. */
export interface Routine {
  /** The recurring event's own id, not an instance's. */
  id: string;
  title: string;
  /** ISO 8601, the first occurrence. */
  startTime: string;
  endTime: string;
  days: RoutineDays;
}

/**
 * Every routine on this person's calendar.
 *
 * The recurring events themselves rather than their instances, which is what
 * `singleEvents: false` asks for. A routine is edited once and Google repeats
 * the change, so the menu never has to know how many days it spans.
 */
export async function listRoutines(user: CalendarUser): Promise<Routine[]> {
  const calendar = await getCalendarClient();
  const calendarId = await calendarIdFor(user);
  const routines: Routine[] = [];

  // One query per kind: Google filters on an exact key=value pair, and three
  // small lists are cheaper than reading every event ever booked.
  for (const days of ROUTINE_DAYS) {
    const response = await calendar.events.list({
      calendarId,
      singleEvents: false,
      showDeleted: false,
      privateExtendedProperty: [`${ROUTINE_KEY}=${days}`],
    });

    for (const event of response.data.items ?? []) {
      const routine = toRoutine(event);
      if (routine !== null) routines.push(routine);
    }
  }

  return routines;
}

/** Books a routine: one event that Google repeats on [input.days]. */
export async function insertRoutine(
  user: CalendarUser,
  input: RoutineInput,
): Promise<Routine> {
  if (
    input.title === undefined ||
    input.startTime === undefined ||
    input.endTime === undefined ||
    input.days === undefined
  ) {
    throw new Error('title, startTime, endTime and days are required');
  }

  const calendar = await getCalendarClient();
  const timeZone = await calendarTimeZoneFor(user);

  const response = await calendar.events.insert({
    calendarId: await calendarIdFor(user),
    requestBody: {
      summary: input.title,
      // The zone is what makes "every day at noon" noon in every season: a
      // recurrence expands in the zone its start names.
      start: toEventDateTime(input.startTime, timeZone),
      end: toEventDateTime(input.endTime, timeZone),
      recurrence: recurrenceFor(input.days),
      extendedProperties: {
        private: {
          [OWNED_KEY]: 'true',
          [FIXED_KEY]: 'true',
          [ROUTINE_KEY]: input.days,
        },
      },
    },
  });

  const routine = toRoutine(response.data);
  if (routine === null) throw new Error('Calendar returned an unusable routine');
  return routine;
}

/**
 * Changes a routine, and so every day it repeats on.
 *
 * Instances somebody already changed by hand in Google keep their change,
 * which is Google's rule and the right one.
 */
export async function patchRoutine(
  user: CalendarUser,
  routineId: string,
  input: RoutineInput,
): Promise<Routine> {
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
  if (input.days !== undefined) {
    requestBody.recurrence = recurrenceFor(input.days);
    const current = await calendar.events.get({ calendarId, eventId: routineId });
    requestBody.extendedProperties = {
      private: {
        ...(current.data.extendedProperties?.private ?? {}),
        [ROUTINE_KEY]: input.days,
      },
    };
  }

  const response = await calendar.events.patch({
    calendarId,
    eventId: routineId,
    requestBody,
  });

  const routine = toRoutine(response.data);
  if (routine === null) throw new Error('Calendar returned an unusable routine');
  return routine;
}

/** A recurring Google event, or null when it is not one of Focus's routines. */
function toRoutine(event: calendar_v3.Schema$Event): Routine | null {
  const start = event.start?.dateTime;
  const end = event.end?.dateTime;
  const days = routineDaysOf(event.extendedProperties?.private?.[ROUTINE_KEY]);

  if (
    typeof event.id !== 'string' ||
    typeof start !== 'string' ||
    typeof end !== 'string' ||
    event.status === 'cancelled' ||
    days === undefined
  ) {
    return null;
  }

  return {
    id: event.id,
    title: event.summary ?? 'Sem título',
    startTime: new Date(start).toISOString(),
    endTime: new Date(end).toISOString(),
    days,
  };
}
