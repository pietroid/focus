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
 * One card on the timeline.
 *
 * Every card is a calendar event, because every hour of the day is. Some of
 * them have a conversation behind them and most do not; a card says which by
 * carrying the thread's slug, and that pairing is stored on the event itself
 * and nowhere else.
 */
export class EventCard {
  /** The Google event id, and the id the API addresses it by. */
  id: string;
  title: string;
  /** The section it falls in, worked out from the clock when it was read. */
  section: TimelineSection;
  /** ISO 8601 start. */
  startTime: string;
  /** ISO 8601 end. */
  endTime: string;
  durationMinutes: number;
  /** Whether the hour is the point of it, so a rearrangement leaves it be. */
  fixed: boolean;
  /**
   * Whether Focus booked it.
   *
   * A card that is not managed is somebody else's meeting: it is drawn so the
   * screen says what the calendar says, and it cannot be dragged, finished or
   * talked to, because none of that is Focus's to do with it.
   */
  managed: boolean;
  /** The conversation about this block, when there is one. */
  threadSlug?: string;
  /** The last thing said in that conversation, on one line. */
  preview: string;
  /** How many messages it holds. Zero when nothing has been said yet. */
  messageCount: number;
}

/** What the creation sheet said when the user wrote something down. */
export interface EventRequest {
  title: string;
  durationMinutes: number;
  /** Whether the hour is the point of it. */
  fixed: boolean;
  /** ISO 8601. Only a fixed block gets to name one. */
  startTime?: string;
}
