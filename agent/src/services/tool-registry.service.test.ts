import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ToolRegistryService } from './tool-registry.service.js';

/**
 * The summaries are what a proposal reads back, in the product's language.
 *
 * This is the last thing between a model's sentence and someone's real
 * calendar, so it is checked here rather than trusted: a summary that falls
 * back to dumping arguments would put raw JSON in front of the user at exactly
 * the moment they are being asked to trust it.
 */
describe('ToolRegistryService', () => {
  const registry = new ToolRegistryService();

  it('describes every registered tool', () => {
    const described = registry.describe();

    assert.deepEqual(
      described.map((tool) => tool.name).sort(),
      [
        'api_call',
        'calendar_check_availability',
        'calendar_create_event',
        'calendar_delete_event',
        'calendar_list_events',
        'calendar_update_event',
        'web_search',
      ],
    );

    for (const tool of described) {
      assert.ok(tool.description.length > 0, `${tool.name} has no description`);
    }
  });

  it('classifies every tool as a read or a write', () => {
    const effects = Object.fromEntries(
      registry.describe().map((tool) => [tool.name, tool.effect]),
    );

    assert.deepEqual(effects, {
      api_call: 'write',
      calendar_check_availability: 'read',
      calendar_create_event: 'write',
      calendar_delete_event: 'write',
      calendar_list_events: 'read',
      calendar_update_event: 'write',
      web_search: 'read',
    });
  });

  it('narrows api_call to a read only for a GET', () => {
    assert.equal(registry.effectOf('api_call', { method: 'GET' }), 'read');
    assert.equal(registry.effectOf('api_call', { method: 'POST' }), 'write');
    // No method named yet: the stricter answer is the only safe one.
    assert.equal(registry.effectOf('api_call', {}), 'write');
  });

  it('treats an unregistered tool as a write', () => {
    assert.equal(registry.effectOf('not_a_tool', {}), 'write');
  });

  it('summarises a calendar event as a person would say it', () => {
    process.env.TZ = 'UTC';

    const summary = registry.summarize('calendar_create_event', {
      title: 'Standup',
      startTime: '2026-09-18T10:00:00Z',
      endTime: '2026-09-18T11:00:00Z',
    });

    assert.match(summary, /^Adicionar "Standup" na sua agenda em /);
    assert.match(summary, /10:00/);
    assert.match(summary, /11:00/);
    assert.doesNotMatch(summary, /[{}[\]]/);
  });

  it('never returns JSON, even for arguments it cannot read', () => {
    for (const name of registry.names) {
      const summary = registry.summarize(name, {});
      assert.ok(summary.length > 0, `${name} produced an empty summary`);
      assert.doesNotMatch(summary, /[{}[\]]/, `${name} leaked JSON`);
    }
  });

  it('summarises an unknown tool rather than throwing', () => {
    assert.equal(registry.summarize('not_a_tool', {}), 'Run not_a_tool');
  });

  it('hands the model one definition per registered tool', () => {
    assert.equal(registry.definitions.length, registry.names.length);
    for (const definition of registry.definitions) {
      assert.equal(definition.type, 'function');
      assert.ok(definition.function.description.length > 0);
    }
  });
});
