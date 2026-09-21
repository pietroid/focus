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

/** Whether [interval] is the hour being lived through at [now]. */
export function isRunning(now: Date, interval: Interval): boolean {
  return interval.start <= now && now < interval.end;
}

/** Whether [interval] is over at [now]. */
export function isSpent(now: Date, interval: Interval): boolean {
  return interval.end <= now;
}

/**
 * The section [interval] falls in at [now], or undefined when the timeline
 * does not draw it at all.
 *
 * Nothing else in the app decides this. A heading says what time it is, so it
 * has to be worked out from the clock every time the list is read, and this
 * is the one place that does it.
 *
 * An hour that has run out is not a section. A block booked 11:20 to 11:25 is
 * finished at 11:26 — that was the hour, the hour is gone, and leaving it on
 * the screen would make "Agora" mean "now, and also everything now used to
 * be". [ThreadsStore.sweep] marks those done; this keeps them off the screen
 * in the moment before it does.
 */
export function sectionOf(
  now: Date,
  interval: Interval,
): TimelineSection | undefined {
  if (isSpent(now, interval)) return undefined;
  if (isRunning(now, interval)) return 'agora';
  if (sameDay(interval.start, now)) return 'hoje';
  if (sameDay(interval.start, tomorrow(now))) return 'amanha';

  return undefined;
}
