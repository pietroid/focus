import { intervalOf, sectionOf } from './thread-timing';

function at(day: number, hour: number, minute = 0): Date {
  return new Date(2026, 8, day, hour, minute, 0, 0);
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

  it('leaves something whose hour has passed in agora, still owed', () => {
    expect(sectionOf(at(21, 16), span(at(21, 9), at(21, 10)))).toBe('agora');
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
