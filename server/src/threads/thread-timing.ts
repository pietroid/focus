import { Interval } from '../time/work-hours';
import { ThreadTiming, TimelineSection } from './entities/thread.entity';

/** [timing] as an interval, when it has one. */
export function intervalOf(
  timing: ThreadTiming | undefined,
): Interval | undefined {
  if (timing === undefined) return undefined;

  const start = new Date(timing.startTime);
  const end = new Date(timing.endTime);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return undefined;
  }

  return { start, end };
}

/** Whether [a] and [b] are the same calendar day. */
function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/** The day after [at], at the same time. */
function tomorrow(at: Date): Date {
  const next = new Date(at);
  next.setDate(next.getDate() + 1);
  return next;
}

/**
 * The section [interval] falls in at [now], or undefined when it is further
 * out than the timeline draws.
 *
 * Nothing else in the app decides this. A heading says what time it is, so it
 * has to be worked out from the clock every time the list is read, and this
 * is the one place that does it.
 *
 * Something whose hour has already passed and which nobody has closed is
 * still owed, and the only honest place for it is "Agora": that is when it
 * would be done if it were done.
 */
export function sectionOf(
  now: Date,
  interval: Interval,
): TimelineSection | undefined {
  if (interval.start <= now) return 'agora';
  if (sameDay(interval.start, now)) return 'hoje';
  if (sameDay(interval.start, tomorrow(now))) return 'amanha';

  return undefined;
}
