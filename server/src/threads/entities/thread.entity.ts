import { Message } from './message.entity';

/**
 * Which of the timeline's sections a card sits in.
 *
 * A section is a stretch of clock, not a judgement. Nothing stores one and
 * nothing drags a card between them: a card is in "Amanhã" because it starts
 * tomorrow, and the only way to move it is to change when it happens.
 *
 * Three of them today, one per stretch of time the screen draws. They are
 * meant to become one per day, which is why they are derived from a start
 * time rather than named in the data.
 */
export type TimelineSection = 'agora' | 'hoje' | 'amanha';

/**
 * Where a card on the timeline came from.
 *
 * A `calendar` card is a Google event with no thread behind it: it is drawn
 * so the screen matches the calendar, and it cannot be dragged, solved or
 * opened, because there is nothing here to open.
 */
export type CardKind = 'thread' | 'calendar';

/**
 * When a thread happens.
 *
 * Either a thread has all of this or it has none of it. A thread with timing
 * is on the timeline, at a concrete hour, for a concrete length; a thread
 * without it is not on the timeline at all. There is no half-planned state in
 * between, which is what lets every section heading be literally true.
 */
export interface ThreadTiming {
  /** How long it takes. */
  durationMinutes: number;
  /** ISO 8601 start. */
  startTime: string;
  /** ISO 8601 end. Always the start plus the duration. */
  endTime: string;
  /**
   * Whether this hour is the point of it.
   *
   * A fixed block is an anchor: rearranging the day flows everything else
   * around it and never moves it. Everything is flexible unless the user
   * said otherwise when they wrote it down.
   */
  fixed: boolean;
  /** The Google event this thread is. */
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
  /** When it happens, or undefined when it is not on the timeline. */
  timing?: ThreadTiming;
  createdAt: Date;
  updatedAt: Date;
}

/** One card on the timeline: a thread without its messages, or an event. */
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
  /** The section it falls in, worked out from the clock when it was read. */
  section: TimelineSection;
  /** ISO 8601 start. */
  startTime: string;
  /** ISO 8601 end. */
  endTime: string;
  durationMinutes: number;
  /** Whether a rearrangement is allowed to move it. */
  fixed: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * A thread in a plain list, with no claim about when it happens.
 *
 * What the concluded items are drawn from, and what Coisas will be drawn
 * from: a thread that is not on the timeline still exists, and a list of them
 * cannot be made of cards that insist on an hour.
 */
export class ThreadItem {
  slug: string;
  title: string;
  preview: string;
  messageCount: number;
  solved: boolean;
  /** ISO 8601, when it has an hour at all. */
  startTime?: string;
  endTime?: string;
  durationMinutes?: number;
  createdAt: Date;
  updatedAt: Date;
}

/** What is stored about a thread beyond its messages. */
export interface ThreadState {
  solved: boolean;
  /** Set when the user or the agent renamed the thread. */
  title?: string;
  /** When the thread happens. Absent means it is not on the timeline. */
  timing?: ThreadTiming;
}
