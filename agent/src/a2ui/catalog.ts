import { A2uiComponent, ComponentName, ToolDefinition } from './types.js';

/** Component schemas used for validation and prompt generation. */
export const A2UI_CATALOG: Record<
  ComponentName,
  { props: string[]; children?: boolean }
> = {
  Column: {
    props: ['mainAxisAlignment', 'crossAxisAlignment'],
    children: true,
  },
  Row: {
    props: ['mainAxisAlignment', 'crossAxisAlignment'],
    children: true,
  },
  Spacer: {
    props: ['width', 'height'],
  },
  Text: {
    props: ['text', 'variant'],
  },
  Icon: {
    props: ['icon', 'size', 'color'],
  },
  Image: {
    props: ['src', 'width', 'height', 'fit'],
  },
  AppButton: {
    props: ['text', 'variant', 'expand', 'icon', 'action'],
  },
  AppIconButton: {
    props: ['icon', 'size', 'color', 'action', 'accessibilityLabel'],
  },
};

/** Allowed component names. */
export const COMPONENT_NAMES = Object.keys(A2UI_CATALOG) as ComponentName[];

/** Allowed tool names. */
export const ALLOWED_TOOLS: readonly string[] = [
  'web_search',
  'calendar_check_availability',
  'calendar_create_event',
  'api_call',
];

/** Allowed text variants. */
export const TEXT_VARIANTS = ['headline', 'title', 'body', 'caption', 'label'];

/** Allowed icon colors. */
export const ICON_COLORS = ['accent', 'ink', 'ink2', 'ink3', 'error'];

/** Allowed image fits. */
export const IMAGE_FITS = ['cover', 'contain', 'fill', 'fitWidth', 'fitHeight', 'none'];

/** Allowed button variants. */
export const BUTTON_VARIANTS = ['primary', 'secondary', 'text'];

/** Allowed main axis alignments. */
export const MAIN_AXIS_ALIGNMENTS = [
  'start',
  'end',
  'center',
  'spaceBetween',
  'spaceAround',
  'spaceEvenly',
];

/** Allowed cross axis alignments. */
export const CROSS_AXIS_ALIGNMENTS = ['start', 'end', 'center', 'stretch'];

/** Tool definitions registered with OpenRouter. */
export const TOOL_DEFINITIONS: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'web_search',
      description: 'Search the web for current information.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'calendar_check_availability',
      description:
        'Check free/busy times on the user\'s calendar for a specific date. Call this before proposing a meeting time.',
      parameters: {
        type: 'object',
        properties: {
          date: {
            type: 'string',
            description: 'ISO 8601 date, e.g. 2026-09-20',
          },
          durationMinutes: {
            type: 'number',
            description: 'How long the event will last, in minutes',
          },
        },
        required: ['date', 'durationMinutes'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'calendar_create_event',
      description:
        'Create a calendar event. Only call this after the user has explicitly confirmed a specific date and time. The system will ask the user for confirmation before executing.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Event title' },
          startTime: {
            type: 'string',
            description: 'ISO 8601 date-time, e.g. 2026-09-20T10:00:00',
          },
          endTime: {
            type: 'string',
            description: 'ISO 8601 date-time, e.g. 2026-09-20T11:00:00',
          },
        },
        required: ['title', 'startTime', 'endTime'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'api_call',
      description: 'Call a configured third-party API.',
      parameters: {
        type: 'object',
        properties: {
          integration: { type: 'string' },
          endpoint: { type: 'string' },
          method: { type: 'string', enum: ['GET', 'POST', 'PUT', 'DELETE'] },
          payload: { type: 'object' },
        },
        required: ['integration', 'endpoint', 'method'],
      },
    },
  },
];

/**
 * Builds a plain-text catalog description for injection into the system prompt.
 */
export function buildCatalogDescription(): string {
  const lines: string[] = [
    'A2UI Component Catalog (flat discriminator format):',
    '',
    ...COMPONENT_NAMES.map((name) => {
      const schema = A2UI_CATALOG[name];
      const props = schema.props.length > 0 ? ` { ${schema.props.join(', ')} }` : '';
      const children = schema.children ? ' children: A2uiComponent[]' : '';
      return `- ${name}:${props}${children}`;
    }),
    '',
    `Available tools: ${ALLOWED_TOOLS.join(', ')}.`,
    '',
    'Rules:',
    '- Every reply must be valid JSON with a top-level "a2ui" field.',
    '- Wrap every displayed string in a Text component.',
    '- The root a2ui value is usually a Column or Row.',
    '- Interactive components may include an "action" object.',
    '- Tool actions reference one of the available tools by name.',
  ];
  return lines.join('\n');
}

/**
 * Builds a small example of a valid A2UI response for the prompt.
 */
export function buildExampleResponse(): string {
  const example: { a2ui: A2uiComponent } = {
    a2ui: {
      component: 'Column',
      children: [
        { component: 'Text', text: 'Your message here.', variant: 'body' },
        {
          component: 'Row',
          children: [
            {
              component: 'AppButton',
              text: 'Confirm',
              variant: 'primary',
              action: {
                type: 'tool',
                tool: 'calendar_create_event',
                arguments: {
                  title: 'Standup',
                  startTime: '2026-09-20T10:00:00',
                  endTime: '2026-09-20T11:00:00',
                },
                requiresConfirmation: true,
              },
            },
            { component: 'Spacer', width: 8 },
            {
              component: 'AppButton',
              text: 'Cancel',
              variant: 'text',
              action: { type: 'dismiss' },
            },
          ],
        },
      ],
    },
  };
  return `Example response:\n${JSON.stringify(example, null, 2)}`;
}
