import { Interval, workWindowFor } from '../time/work-hours';
import { ThreadBucket, ThreadTiming } from './entities/thread.entity';

/** Whether [timing] says when this happens, and not merely how long it takes. */
export function isTimed(timing: ThreadTiming | undefined): boolean {
  return intervalOf(timing) !== undefined;
}

/** [timing] as an interval, when it has both ends. */
export function intervalOf(
  timing: ThreadTiming | undefined,
): Interval | undefined {
  if (timing?.startTime === undefined || timing.endTime === undefined) {
    return undefined;
  }

  const start = new Date(timing.startTime);
  const end = new Date(timing.endTime);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return undefined;
  }

  return { start, end };
}

/**
 * The list a timed thing belongs in at [now], or undefined when it has no
 * time at all.
 *
 * This is the one exception to the rule that nothing derives a bucket. A
 * thread with a time on it is no longer answering the question the buckets
 * ask: the clock has already answered it, and a card that stayed in "em
 * breve" while the meeting on it was running would be the screen disagreeing
 * with the calendar it came from.
 *
 * An untimed thread keeps the old rule entirely: it sits where it was
 * dragged, and nothing moves it.
 */
export function derivedBucket(
  now: Date,
  timing: ThreadTiming | undefined,
): ThreadBucket | undefined {
  const interval = intervalOf(timing);
  if (interval === undefined) return undefined;

  if (now >= interval.start && now < interval.end) return 'agora';

  // Something whose window has closed is not "now" and was never "later": it
  // is the thing you meant to do and did not, so it goes back to the list
  // that means next.
  if (now >= interval.end) return 'em_breve';

  return interval.start < workWindowFor(now).end ? 'em_breve' : 'depois';
}
