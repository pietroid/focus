import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  earliestStart,
  formatRange,
  nextFreeSlot,
  WORK_DAY_END_HOUR,
  WORK_DAY_START_HOUR,
  workWindowFor,
} from './work-hours';

/** A local date, written the way the tests read best. */
function at(day: number, hour: number, minute = 0): Date {
  return new Date(2026, 8, day, hour, minute, 0, 0);
}

describe('the working day', () => {
  it('runs from seven to ten', () => {
    const window = workWindowFor(at(21, 12));

    expect(window.start.getHours()).toBe(WORK_DAY_START_HOUR);
    expect(window.end.getHours()).toBe(WORK_DAY_END_HOUR);
  });

  it('answers the same day before it has started', () => {
    expect(workWindowFor(at(21, 5)).start).toEqual(at(21, 7));
  });

  it('answers tomorrow once it is over', () => {
    expect(workWindowFor(at(21, 23)).start).toEqual(at(22, 7));
  });

  it('never starts anything before the day does', () => {
    expect(earliestStart(at(21, 3))).toEqual(at(21, 7));
    expect(earliestStart(at(21, 9, 12))).toEqual(at(21, 9, 12));
  });
});

describe('finding a slot', () => {
  it('starts at the minute asked for when nothing is booked', () => {
    expect(nextFreeSlot(at(21, 9, 12), 45, [])).toEqual({
      start: at(21, 9, 12),
      end: at(21, 9, 57),
    });
  });

  it('steps over a booked block, keeping the gap', () => {
    const busy = [{ start: at(21, 9, 0), end: at(21, 10, 0) }];

    expect(nextFreeSlot(at(21, 9, 30), 30, busy)).toEqual({
      start: addMinutes(at(21, 10, 0), BLOCK_GAP_MINUTES),
      end: addMinutes(at(21, 10, 35), 0),
    });
  });

  it('walks past a whole run of them', () => {
    const busy = [
      { start: at(21, 9, 0), end: at(21, 10, 0) },
      { start: at(21, 10, 0), end: at(21, 11, 0) },
    ];

    expect(nextFreeSlot(at(21, 8, 55), 30, busy).start).toEqual(at(21, 11, 5));
  });

  it('spills into the next day rather than past ten at night', () => {
    expect(nextFreeSlot(at(21, 21, 30), 60, []).start).toEqual(at(22, 7, 0));
  });
});

describe('writing time down', () => {
  it('writes a range the way a card does', () => {
    expect(formatRange({ start: at(21, 9, 5), end: at(21, 9, 50) })).toBe(
      '09:05-09:50',
    );
  });
});
