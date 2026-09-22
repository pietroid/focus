import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { isCalendarId, parseAssignments } from './google-calendar.js';

/**
 * GOOGLE_CALENDAR_MAP is typed by hand into an env file, so it is read
 * forgivingly: one bad pair costs that pair, and an address typed with
 * capitals still matches the one Firebase sends.
 */
describe('calendar assignments', () => {
  it('reads email=calendar pairs', () => {
    const map = parseAssignments(
      'pietro@x.com=Pietro, ana@x.com = abc123@group.calendar.google.com',
    );

    assert.equal(map.get('pietro@x.com'), 'Pietro');
    assert.equal(map.get('ana@x.com'), 'abc123@group.calendar.google.com');
  });

  it('matches addresses without case', () => {
    const map = parseAssignments('Pietro.Teruya@Example.com=Pietro');

    assert.equal(map.get('pietro.teruya@example.com'), 'Pietro');
  });

  it('keeps spaces inside a name', () => {
    assert.equal(parseAssignments('a@x.com=Focus Pietro').get('a@x.com'), 'Focus Pietro');
  });

  it('skips malformed pairs', () => {
    const map = parseAssignments('nobody,=Ana,b@x.com=,c@x.com=Carla,');

    assert.deepEqual([...map.entries()], [['c@x.com', 'Carla']]);
  });

  it('reads nothing from an empty value', () => {
    assert.equal(parseAssignments('').size, 0);
  });

  it('tells an id from a name', () => {
    assert.equal(isCalendarId('abc123@group.calendar.google.com'), true);
    assert.equal(isCalendarId('primary'), true);
    assert.equal(isCalendarId('Pietro'), false);
  });
});
