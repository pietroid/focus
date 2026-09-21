import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ToolExecutorService } from './tool-executor.service.js';
import { ToolRegistryService } from './tool-registry.service.js';
import { Trace } from '../trace.js';
import { ToolCall } from '../types.js';

/**
 * The write gate, checked rather than trusted.
 *
 * This is the only thing standing between a model that has decided to be
 * helpful and someone's real calendar. The prompt asks; this enforces. A
 * regression here is silent and expensive, so every branch of it is pinned.
 */
describe('ToolExecutorService', () => {
  const context = { userId: 'u1', slug: 't', traceId: 't_test' };
  const registry = new ToolRegistryService();
  const executor = new ToolExecutorService(registry, new Trace({ traceId: 't_test' }));

  const call = (name: string, args: Record<string, unknown>): ToolCall => ({
    id: `call_${name}`,
    type: 'function',
    function: { name, arguments: JSON.stringify(args) },
  });

  it('refuses a write on an unconfirmed turn without touching the tool', async () => {
    const entry = await executor.execute(
      call('calendar_create_event', {
        title: 'Standup',
        startTime: '2026-09-20T10:00:00',
        endTime: '2026-09-20T11:00:00',
      }),
      context,
      false,
    );

    assert.equal(entry.ok, false);
    assert.equal(entry.blocked, true);
    assert.equal(entry.effect, 'write');
    // The refusal has to tell the model what to do next, not just say no.
    assert.match(entry.error ?? '', /NOT EXECUTED/);
    assert.match(entry.error ?? '', /confirm/);
    // And it carries the sentence the proposal will be built from.
    assert.match(entry.summary, /^Adicionar "Standup" na sua agenda/);
  });

  it('lets a write through once the turn is confirmed', async () => {
    // No calendar credentials in a test run, so the call reaches the tool and
    // fails there. That is the point: it was attempted, not blocked.
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;

    const entry = await executor.execute(
      call('calendar_create_event', {
        title: 'Standup',
        startTime: '2026-09-20T10:00:00',
        endTime: '2026-09-20T11:00:00',
      }),
      context,
      true,
    );

    assert.equal(entry.ok, false);
    assert.notEqual(entry.blocked, true);
    assert.match(entry.error ?? '', /Calendar auth failed/);
  });

  it('runs a read on an unconfirmed turn', async () => {
    const entry = await executor.execute(
      call('calendar_list_events', { date: '2026-09-20' }),
      context,
      false,
    );

    assert.equal(entry.effect, 'read');
    assert.notEqual(entry.blocked, true);
  });

  it('treats an api_call GET as a read and a DELETE as a write', async () => {
    const read = await executor.execute(
      call('api_call', { integration: 'x', endpoint: '/y', method: 'GET' }),
      context,
      false,
    );
    assert.equal(read.effect, 'read');
    assert.notEqual(read.blocked, true);

    const write = await executor.execute(
      call('api_call', { integration: 'x', endpoint: '/y', method: 'DELETE' }),
      context,
      false,
    );
    assert.equal(write.effect, 'write');
    assert.equal(write.blocked, true);
  });

  it('blocks a tool it has never heard of', async () => {
    const entry = await executor.execute(call('drop_database', {}), context, false);

    assert.equal(entry.ok, false);
    assert.equal(entry.effect, 'write');
    assert.match(entry.error ?? '', /not registered/);
  });
});
