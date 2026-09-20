import { Message } from './message.entity';

/**
 * Which of the home screen's three lists a card sits in.
 *
 * For an untimed thread the bucket is the user's own judgement: the agent
 * never sets it, nothing infers it, and it moves only because someone dragged
 * it. For anything with a time on it the clock decides instead, because the
 * question the buckets ask has already been answered by the calendar.
 */
export type ThreadBucket = 'agora' | 'em_breve' | 'depois';

/** Every bucket, in the order the home screen draws them. */
export const THREAD_BUCKETS: ThreadBucket[] = ['agora', 'em_breve', 'depois'];

/** The bucket a thread starts life in. */
export const DEFAULT_BUCKET: ThreadBucket = 'em_breve';

/** Whether [value] names a bucket. */
export function isThreadBucket(value: unknown): value is ThreadBucket {
  return (
    typeof value === 'string' && THREAD_BUCKETS.includes(value as ThreadBucket)
  );
}

/**
 * Where a card on the timeline came from.
 *
 * A `calendar` card is a Google event with no thread behind it: it is drawn
 * so the screen matches the calendar, and it cannot be dragged, solved or
 * opened, because there is nothing here to open.
 */
export type CardKind = 'thread' | 'calendar';

/**
 * What is known about when a thread happens.
 *
 * Every field is optional and they arrive in that order: a thread is untimed,
 * then it has a duration, then it has a time, then that time is in the
 * calendar. The finest planning is the one that reached Google; everything
 * before it is the user saying as much as they knew at the time.
 */
export interface ThreadTiming {
  /** How long it takes, once someone has said. */
  durationMinutes?: number;
  /** ISO 8601 start, set when it was given a time. */
  startTime?: string;
  /** ISO 8601 end. Always start plus the duration. */
  endTime?: string;
  /** The Google event this thread is, once it was put in the calendar. */
  calendarEventId?: string;
}

/** A thread, with every message across every day it spans. */
export class Thread {
  /** The folder name on disk, and the id the API addresses it by. */
  slug: string;
  title: string;
  messages: Message[];
  /** Whether the user considers this thread closed. */
  solved: boolean;
  /** Which of the home screen's lists it sits in. */
  bucket: ThreadBucket;
  /** Its place inside that list, ascending. */
  order: number;
  /** When it happens, as far as anyone has said. */
  timing: ThreadTiming;
  createdAt: Date;
  updatedAt: Date;
}

/** One card on the home screen: a thread without its messages, or an event. */
export class ThreadSummary {
  /** Whether there is a thread behind this card. */
  kind: CardKind;
  /** The thread's folder name, or `gcal-<eventId>` for a calendar card. */
  slug: string;
  title: string;
  /** The last message's text, trimmed to a single line. */
  preview: string;
  messageCount: number;
  solved: boolean;
  bucket: ThreadBucket;
  order: number;
  /** ISO 8601 start, when this card has a time. */
  startTime?: string;
  /** ISO 8601 end, when this card has a time. */
  endTime?: string;
  /** How long it takes, when anyone has said. */
  durationMinutes?: number;
  createdAt: Date;
  updatedAt: Date;
}

/** What is stored about a thread beyond its messages. */
export interface ThreadState {
  solved: boolean;
  /** Set when the user or the agent renamed the thread. */
  title?: string;
  /** Set once the thread has been placed; absent means [DEFAULT_BUCKET]. */
  bucket?: ThreadBucket;
  /**
   * Set once the thread has been dragged.
   *
   * A thread that has never moved falls back to when it was created, so the
   * list an untouched account shows is oldest-first rather than arbitrary.
   */
  order?: number;
  /**
   * When the thread happens, once it has been given a duration or a time.
   *
   * Absent means untimed, which is where everything starts: a thread is a
   * pre-calendar thing, and this is filled in as the guards get answers out
   * of the user.
   */
  timing?: ThreadTiming;
}
