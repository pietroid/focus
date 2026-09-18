import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { A2uiValidationService, FALLBACK_A2UI } from './a2ui-validation.service.js';

describe('A2uiValidationService', () => {
  const validator = new A2uiValidationService();

  it('accepts a valid A2UI tree', () => {
    const result = validator.validate({
      a2ui: {
        component: 'Column',
        children: [
          { component: 'Text', text: 'Hello' },
          {
            component: 'AppButton',
            text: 'Go',
            action: { type: 'dismiss' },
          },
        ],
      },
    });

    assert.equal(result.valid, true);
    assert.equal(result.component.component, 'Column');
  });

  it('rejects a reply without a top-level a2ui field', () => {
    const result = validator.validate({ text: 'plain text' });

    assert.equal(result.valid, false);
    assert.deepEqual(result.component, FALLBACK_A2UI);
  });

  it('replies with fallback for unknown components', () => {
    const result = validator.validate({
      a2ui: { component: 'UnknownWidget' },
    });

    assert.equal(result.valid, false);
    assert.deepEqual(result.component, FALLBACK_A2UI);
  });

  it('rejects disallowed tool actions', () => {
    const result = validator.validate({
      a2ui: {
        component: 'AppButton',
        text: 'Bad',
        action: { type: 'tool', tool: 'forbidden_tool' },
      },
    });

    assert.equal(result.valid, false);
    assert.equal(result.component.action, undefined);
  });
});
