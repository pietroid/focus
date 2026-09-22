/**
 * The calendar, as the server is allowed to know it.
 *
 * The server never talks to Google. It asks the agent, which holds the
 * credentials; everything here is that answer, flattened to the few fields a
 * day is drawn from.
 *
 * **This is the only record of when anything happens.** Nothing on disk
 * mirrors it, nothing in a thread file remembers an hour, and there is no
 * state to reconcile between two stores. An event is the truth about a block
 * of time; a thread is a conversation, and the two meet only where an event
 * says which conversation it belongs to.
 */

/** Who a calendar call is for. */
export interface CalendarUser {
  /** Their Firebase uid, which names their calendar inside the account. */
  id: string;
  /** Their address, when the request knew it. The agent shares with it once. */
  email?: string;
  /**
   * Their display name, when the request knew it.
   *
   * The agent names their calendar after the first word of it. It travels
   * with every call for the same reason the address does: the agent holds no
   * user table and knows nothing about anyone the request does not tell it.
   */
  name?: string;
}

/** One event on this person's calendar. */
export interface CalendarEvent {
  /** The Google event id. The only name an update or a delete answers to. */
  id: string;
  title: string;
  /** ISO 8601. */
  startTime: string;
  /** ISO 8601. */
  endTime: string;
  /**
   * Whether Focus booked it.
   *
   * An event that arrived any other way is somebody else's arrangement: it is
   * drawn, because the hour is not free, and nothing here ever moves it,
   * renames it or takes it off the calendar.
   */
  managed: boolean;
  /** Whether the hour is the point of it, so a layout leaves it where it is. */
  fixed: boolean;
  /** The conversation about this block, when one has been started. */
  threadSlug?: string;
}

/** What the agent last reported for one person, and when it was asked. */
export interface CalendarSnapshot {
  /** ISO 8601, set by the server when the answer landed. */
  receivedAt: string;
  events: CalendarEvent[];
  /**
   * The IANA zone the calendar itself is kept in, when the agent has said.
   *
   * **The calendar owns the clock.** Every hour Focus reasons about is a wall
   * clock hour — the working day runs seven to ten, "hoje" is a day, a card
   * reads "19:40" — and all of that is only right in one zone. It is the
   * calendar's, because that is the day the user can open in Google and see,
   * not the server's, which is whatever the container was started with.
   */
  timeZone?: string;
}

/** Whether [value] is an event with both ends and an id. */
export function isCalendarEvent(value: unknown): value is CalendarEvent {
  if (value === null || typeof value !== 'object') return false;

  const raw = value as Record<string, unknown>;
  return (
    typeof raw.id === 'string' &&
    raw.id !== '' &&
    typeof raw.startTime === 'string' &&
    typeof raw.endTime === 'string' &&
    !Number.isNaN(Date.parse(raw.startTime)) &&
    !Number.isNaN(Date.parse(raw.endTime))
  );
}

/** [value] as an event, with the flags the agent may not have sent. */
export function readCalendarEvent(value: unknown): CalendarEvent | null {
  if (!isCalendarEvent(value)) return null;

  const raw = value as unknown as Record<string, unknown>;
  const slug = raw.threadSlug;
  const managed = raw.managed === true;

  return {
    id: String(raw.id),
    title: typeof raw.title === 'string' ? raw.title : 'Sem título',
    startTime: String(raw.startTime),
    endTime: String(raw.endTime),
    managed,
    fixed: managed ? raw.fixed === true : true,
    threadSlug: typeof slug === 'string' && slug !== '' ? slug : undefined,
  };
}
