/**
 * Every test runs in São Paulo, whatever the machine's own zone.
 *
 * This has to happen here, before Jest starts its workers. A test file that
 * sets `process.env.TZ` only changes the sandbox's copy of the environment:
 * `systemZone()` reads the new zone while the worker's `Date` keeps answering
 * `getHours()` in the old one, which on a UTC CI runner puts every hour three
 * off. Workers inherit this process's environment, so set here, both agree.
 */
module.exports = () => {
  process.env.TZ = 'America/Sao_Paulo';
};
