/**
 * The working day, and the arithmetic every timed thing in Focus is measured
 * against.
 *
 * One file owns the hours because three places need the same answer: the
 * bucket a timed card derives, the start time a guard proposes, and the shift
 * applied when blocks are postponed. Three copies of "the day ends at ten"
 * would have disagreed the first time one of them changed.
 */

/** The first hour of the working day. Nothing is proposed before it. */
export const WORK_DAY_START_HOUR = 7;

/** The hour the working day ends. Nothing is proposed to start after it. */
export const WORK_DAY_END_HOUR = 22;

/**
 * The breathing room between two blocks.
 *
 * Blocks are proposed and postponed with this gap already in them, so a day
 * built by the guards never has one thing ending exactly as the next begins.
 */
export const BLOCK_GAP_MINUTES = 5;

/** The durations a guard offers, in minutes. */
export const DURATION_CHOICES_MINUTES = [15, 30, 45, 60, 90, 120] as const;

/** A span of time, start inclusive and end exclusive. */
export interface Interval {
  start: Date;
  end: Date;
}

/** [at] moved by [minutes], which may be negative. */
export function addMinutes(at: Date, minutes: number): Date {
  return new Date(at.getTime() + minutes * 60_000);
}

/** How many minutes [interval] lasts, rounded to the nearest minute. */
export function minutesOf(interval: Interval): number {
  return Math.round(
    (interval.end.getTime() - interval.start.getTime()) / 60_000,
  );
}

/** The same day as [at], at [hour] o'clock exactly. */
function atHour(at: Date, hour: number): Date {
  const result = new Date(at);
  result.setHours(hour, 0, 0, 0);
  return result;
}

/** Whether [at] falls inside a working day. */
export function withinWorkHours(at: Date): boolean {
  return (
    at >= atHour(at, WORK_DAY_START_HOUR) && at < atHour(at, WORK_DAY_END_HOUR)
  );
}

/**
 * The working window [at] is in, or the next one if it is outside them.
 *
 * Late evening and the small hours both answer "tomorrow morning", which is
 * what makes a thread created at midnight propose a time someone could
 * actually keep.
 */
export function workWindowFor(at: Date): Interval {
  const start = atHour(at, WORK_DAY_START_HOUR);
  const end = atHour(at, WORK_DAY_END_HOUR);

  if (at < start) return { start, end };
  if (at < end) return { start, end };

  const tomorrow = new Date(at);
  tomorrow.setDate(tomorrow.getDate() + 1);
  return {
    start: atHour(tomorrow, WORK_DAY_START_HOUR),
    end: atHour(tomorrow, WORK_DAY_END_HOUR),
  };
}

/**
 * The start of the working day after [window].
 *
 * Written out rather than asked of [workWindowFor], because the end of a
 * window and the start of the next one are a day and nine hours apart, and
 * feeding one into the other lands on the morning after the one meant.
 */
export function nextWorkWindowStart(window: Interval): Date {
  const day = new Date(window.end);
  day.setDate(day.getDate() + 1);
  day.setHours(WORK_DAY_START_HOUR, 0, 0, 0);
  return day;
}

/**
 * The earliest moment something could start, given [now].
 *
 * Always a fresh date, never the one that was passed in: callers trim the
 * seconds off the result, and handing back the caller's own clock would let
 * that trim travel backwards into whatever else is reading it.
 */
export function earliestStart(now: Date): Date {
  const window = workWindowFor(now);
  return new Date(now < window.start ? window.start : now);
}

/** Whether two intervals share any time at all. */
export function overlaps(a: Interval, b: Interval): boolean {
  return a.start < b.end && b.start < a.end;
}

/** Everything in [busy] that [candidate] runs into, earliest first. */
export function conflictsWith(
  candidate: Interval,
  busy: Interval[],
): Interval[] {
  return busy
    .filter((interval) => overlaps(candidate, interval))
    .sort((a, b) => a.start.getTime() - b.start.getTime());
}

/** The first thing in [busy] that starts at or after [at]. */
export function nextAfter(at: Date, busy: Interval[]): Interval | undefined {
  return busy
    .filter((interval) => interval.end > at)
    .sort((a, b) => a.start.getTime() - b.start.getTime())[0];
}

/** The next minute divisible by five, so a proposal never reads "14:07". */
export function roundUpToFiveMinutes(at: Date): Date {
  const result = new Date(at);
  result.setSeconds(0, 0);
  const remainder = result.getMinutes() % 5;
  if (remainder !== 0) result.setMinutes(result.getMinutes() + (5 - remainder));
  return result;
}

/**
 * The first slot of [durationMinutes] that fits, from [from] onwards.
 *
 * Walks forward through [busy] rather than searching: each collision moves the
 * candidate to the end of whatever it hit, plus the gap, and a candidate that
 * runs past the end of the working day starts again at the top of the next
 * one. Days are short and calendars are small, so the simple pass is fast
 * enough and says exactly what it did.
 */
export function nextFreeSlot(
  from: Date,
  durationMinutes: number,
  busy: Interval[],
): Interval {
  let start = roundUpToFiveMinutes(earliestStart(from));

  // One iteration per block it has to step over, and one more per day it
  // spills out of. The bound is what keeps a pathological calendar from
  // turning this into a hang.
  for (let attempt = 0; attempt < 500; attempt++) {
    const candidate = { start, end: addMinutes(start, durationMinutes) };
    const window = workWindowFor(start);

    if (candidate.end > window.end) {
      start = nextWorkWindowStart(window);
      continue;
    }

    const hit = conflictsWith(candidate, busy)[0];
    if (hit === undefined) return candidate;

    start = roundUpToFiveMinutes(addMinutes(hit.end, BLOCK_GAP_MINUTES));
  }

  return { start, end: addMinutes(start, durationMinutes) };
}

/** "14:30", in the server's timezone. */
export function formatTime(at: Date): string {
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`;
}

/** "14:30-15:15", the way a card and a guard both write a span. */
export function formatRange(interval: Interval): string {
  return `${formatTime(interval.start)}-${formatTime(interval.end)}`;
}

/** "45 min", "1 h", "1 h 30", as the duration buttons are labelled. */
export function formatDuration(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;

  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0
    ? `${hours} h`
    : `${hours}h${String(rest).padStart(2, '0')}`;
}
