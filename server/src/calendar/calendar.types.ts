/**
 * The calendar, as the server is allowed to know it.
 *
 * The server never talks to Google. It asks the agent, which holds the
 * credentials; everything here is that answer, flattened to the four fields
 * the timeline needs.
 */

/** One event on the focus calendar. */
export interface CalendarEvent {
  /** The Google event id. The only name an update or a delete answers to. */
  id: string;
  title: string;
  /** ISO 8601. */
  startTime: string;
  /** ISO 8601. */
  endTime: string;
}

/** What the agent last reported, and when it was asked. */
export interface CalendarSnapshot {
  /** ISO 8601, set by the server when the answer landed. */
  receivedAt: string;
  events: CalendarEvent[];
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

/** The slug prefix a calendar card is addressed by. Never a folder on disk. */
const CALENDAR_SLUG_PREFIX = 'gcal-';

/** The slug a calendar card is addressed by. */
export function calendarSlug(eventId: string): string {
  return `${CALENDAR_SLUG_PREFIX}${eventId}`;
}

/**
 * Whether [slug] names a calendar card rather than a thread.
 *
 * Used to refuse a move: an event is drawn from the calendar, so the only way
 * to change one is to change it there.
 */
export function isCalendarSlug(slug: string): boolean {
  return slug.startsWith(CALENDAR_SLUG_PREFIX);
}
