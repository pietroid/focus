import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  Interval,
  nextFreeSlot,
  roundUpToFiveMinutes,
} from './work-hours';

/** One thing on the day, as the layout sees it. */
export interface PlannedBlock {
  /** A thread slug, or an event id. */
  id: string;
  minutes: number;
  /** Whether its hour is the point of it, and so cannot be moved. */
  fixed: boolean;
  interval: Interval;
}

/**
 * Where a flexible queue lands, laid out around whatever cannot move.
 *
 * One pass down the queue. Each flexible block takes the first slot that fits
 * after the cursor, the cursor moves past it, and the next one starts looking
 * from there. Fixed blocks and calendar events are never assigned anywhere:
 * they are only obstacles, so the flexible ones flow into the gaps between
 * them, including the gaps that come *before* a fixed block later in the day.
 *
 * That is the whole scheduler. Adding something, dragging something, and
 * closing the hole left by something that was solved are all this function
 * with a different queue, which is why there is no second copy of the rules
 * anywhere and no guard that has to agree with them.
 */
export function relayout(
  queue: PlannedBlock[],
  anchors: Interval[],
  from: Date,
): Map<string, Interval> {
  const placed = new Map<string, Interval>();
  let cursor = from;

  for (const block of queue) {
    if (block.fixed) continue;

    const slot = nextFreeSlot(cursor, block.minutes, anchors);
    placed.set(block.id, slot);
    // Everything after the first block reads off a tidy five minutes; only
    // the one that starts now is allowed an odd number on it.
    cursor = roundUpToFiveMinutes(addMinutes(slot.end, BLOCK_GAP_MINUTES));
  }

  return placed;
}

/** Whether [interval] is somewhere other than where it already was. */
export function moved(block: PlannedBlock, interval: Interval): boolean {
  return (
    block.interval.start.getTime() !== interval.start.getTime() ||
    block.interval.end.getTime() !== interval.end.getTime()
  );
}
