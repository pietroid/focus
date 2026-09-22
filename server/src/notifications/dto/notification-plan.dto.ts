/**
 * What a reminder is for.
 *
 * `starting` and `almostFinishing` follow a block. `morning` and `evening`
 * follow the clock alone: one at the start of the day and one near its end,
 * every day, whatever is booked.
 */
export type NotificationKind =
  'starting' | 'almostFinishing' | 'morning' | 'evening';

/** One reminder the phone should have queued. */
export class NotificationItem {
  /**
   * Stable and deterministic. The same reminder always has the same id, and
   * anything that changes what it says or when it fires changes the id, which
   * is what lets the phone reconcile by comparing two sets.
   */
  id: string;
  kind: NotificationKind;
  /** ISO 8601 with the offset of [NotificationPlan.timeZone] at that instant. */
  fireAt: string;
  /** Final text. The app shows it as is and never concatenates. */
  title: string;
  body: string;
  /** Whether it should break through a Focus mode. */
  timeSensitive: boolean;
  /** The conversation a tap opens, when the block has one. */
  threadSlug?: string;
}

/** Every reminder ahead, soonest first. */
export class NotificationPlan {
  /** ISO 8601, when the server worked this out. */
  generatedAt: string;
  /** The IANA zone every [NotificationItem.fireAt] was written in. */
  timeZone: string;
  items: NotificationItem[];
}
