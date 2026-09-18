import { A2uiValidationService } from './a2ui-validation.service';

describe('A2uiValidationService', () => {
  let service: A2uiValidationService;

  beforeEach(() => {
    service = new A2uiValidationService();
  });

  it('preserves _toolCallId on tool actions', () => {
    const result = service.validate({
      a2ui: {
        component: 'AppButton',
        text: 'Confirm',
        action: {
          type: 'tool',
          tool: 'calendar_create_event',
          requiresConfirmation: true,
          _toolCallId: 'call_123',
          arguments: { title: 'Meeting' },
        },
      },
    });

    expect(result.valid).toBe(true);
    expect(result.component.action).toEqual({
      type: 'tool',
      tool: 'calendar_create_event',
      requiresConfirmation: true,
      _toolCallId: 'call_123',
      arguments: { title: 'Meeting' },
    });
  });

  it('rejects tool actions with disallowed tools', () => {
    const result = service.validate({
      a2ui: {
        component: 'AppButton',
        text: 'Confirm',
        action: {
          type: 'tool',
          tool: 'unknown_tool',
          requiresConfirmation: true,
        },
      },
    });

    expect(result.component.action).toBeUndefined();
  });
});
