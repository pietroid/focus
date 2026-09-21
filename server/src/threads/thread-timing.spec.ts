import { intervalOf, sectionOf } from './thread-timing';

function at(day: number, hour: number, minute = 0): Date {
  return new Date(2026, 8, day, hour, minute, 0, 0);
}

/** The same day everything else in this file happens on. */
function on21(hour: number, minute = 0): Date {
  return at(21, hour, minute);
}

function span(start: Date, end: Date) {
  return { start, end };
}

describe('the section the clock puts a card in', () => {
  it('puts something already running in agora', () => {
    expect(sectionOf(at(21, 10, 30), span(at(21, 10), at(21, 11)))).toBe(
      'agora',
    );
  });

  it('draws nothing whose hour has run out', () => {
    expect(sectionOf(at(21, 16), span(at(21, 9), at(21, 10)))).toBeUndefined();
  });

  it('lets go of a block the moment its last minute is up', () => {
    const block = span(on21(11, 20), on21(11, 25));

    expect(sectionOf(on21(11, 24), block)).toBe('agora');
    expect(sectionOf(on21(11, 25), block)).toBeUndefined();
    expect(sectionOf(on21(11, 26), block)).toBeUndefined();
  });

  it('puts the rest of today in hoje', () => {
    expect(sectionOf(at(21, 10), span(at(21, 15), at(21, 16)))).toBe('hoje');
  });

  it('puts the next day in amanha', () => {
    expect(sectionOf(at(21, 10), span(at(22, 9), at(22, 10)))).toBe('amanha');
  });

  it('draws nothing further out than tomorrow', () => {
    expect(sectionOf(at(21, 10), span(at(23, 9), at(23, 10)))).toBeUndefined();
  });

  it('has no interval without timing', () => {
    expect(intervalOf(undefined)).toBeUndefined();
  });
});
