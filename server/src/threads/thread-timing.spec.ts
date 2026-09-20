import { derivedBucket, intervalOf, isTimed } from './thread-timing';

function at(day: number, hour: number, minute = 0): Date {
  return new Date(2026, 8, day, hour, minute, 0, 0);
}

function timing(start: Date, end: Date) {
  return { startTime: start.toISOString(), endTime: end.toISOString() };
}

describe('what the clock decides', () => {
  it('leaves an untimed thread alone', () => {
    expect(derivedBucket(at(21, 10), undefined)).toBeUndefined();
    expect(derivedBucket(at(21, 10), { durationMinutes: 30 })).toBeUndefined();
  });

  it('puts something already running in agora', () => {
    expect(derivedBucket(at(21, 10, 30), timing(at(21, 10), at(21, 11)))).toBe(
      'agora',
    );
  });

  it('puts the rest of today in em breve', () => {
    expect(derivedBucket(at(21, 10), timing(at(21, 15), at(21, 16)))).toBe(
      'em_breve',
    );
  });

  it('puts another day in depois', () => {
    expect(derivedBucket(at(21, 10), timing(at(23, 9), at(23, 10)))).toBe(
      'depois',
    );
  });

  it('brings something that has already finished back to em breve', () => {
    expect(derivedBucket(at(21, 16), timing(at(21, 9), at(21, 10)))).toBe(
      'em_breve',
    );
  });

  it('refuses half a span', () => {
    expect(isTimed({ startTime: at(21, 9).toISOString() })).toBe(false);
    expect(intervalOf({ endTime: at(21, 9).toISOString() })).toBeUndefined();
  });
});
