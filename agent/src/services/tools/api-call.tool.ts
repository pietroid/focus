import { ToolImplementation, UserContext } from './tool.interface.js';
import { ToolDefinition, ToolEffect } from '../../types.js';

/**
 * Generic third-party API call tool.
 *
 * The last resort, for a service that has no tool of its own. Anything the
 * calendar tools cover goes through them instead: they speak Google Calendar
 * properly and they describe themselves in words a person recognises.
 */
export class ApiCallTool implements ToolImplementation {
  readonly name = 'api_call';

  /**
   * Declared as a write, narrowed per call by [effectFor].
   *
   * The prompt groups tools by this constant and has to describe the tool
   * honestly to a model that has not chosen a method yet. Calling it a read
   * would advertise free rein over a tool that can also DELETE.
   */
  readonly effect: ToolEffect = 'write';

  readonly definition: ToolDefinition = {
    type: 'function',
    function: {
      name: 'api_call',
      description:
        'Call a configured third-party API on the user\'s behalf. A GET runs ' +
        'freely; any other method changes something and only runs on a turn ' +
        'the user has confirmed.',
      parameters: {
        type: 'object',
        properties: {
          integration: {
            type: 'string',
            description: 'The configured integration name',
          },
          endpoint: { type: 'string', description: 'Path to call' },
          method: { type: 'string', enum: ['GET', 'POST', 'PUT', 'DELETE'] },
          payload: { type: 'object', description: 'Request body, if any' },
        },
        required: ['integration', 'endpoint', 'method'],
      },
    },
  };

  /** A GET only looks; every other method changes something. */
  effectFor(args: Record<string, unknown>): ToolEffect {
    return String(args.method ?? '').toUpperCase() === 'GET' ? 'read' : 'write';
  }

  summarize(args: Record<string, unknown>): string {
    const method = String(args.method ?? 'GET').toUpperCase();
    const integration = String(args.integration ?? 'an integration');
    const endpoint = String(args.endpoint ?? '');
    return `Enviar uma requisição ${method} para ${integration}${endpoint}`;
  }

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const integration = String(args.integration ?? '');
    const endpoint = String(args.endpoint ?? '');
    const method = String(args.method ?? 'GET').toUpperCase();
    const payload = args.payload;

    if (integration === '' || endpoint === '') {
      throw new Error('integration and endpoint are required');
    }

    if (method !== 'GET' && method !== 'POST' && method !== 'PUT' && method !== 'DELETE') {
      throw new Error(`Unsupported HTTP method "${method}"`);
    }

    const apiKey = process.env.API_INTEGRATION_API_KEY;
    const baseUrl = process.env.API_INTEGRATION_BASE_URL;

    if (!apiKey || !baseUrl) {
      // A stub success used to be returned here, and the model believed it:
      // it told the user an event had been deleted when nothing had been
      // called at all. An unconfigured integration is a failure, loudly.
      throw new Error(
        `Integration "${integration}" is not configured on this deployment`,
      );
    }

    const body = payload !== undefined ? JSON.stringify(payload) : undefined;
    const response = await fetch(`${baseUrl}/${integration}${endpoint}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body,
    });

    if (!response.ok) {
      throw new Error(`API call failed: ${response.status}`);
    }

    return response.json();
  }
}
