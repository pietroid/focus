import { ToolImplementation, UserContext } from './tool.interface.js';

/**
 * Generic third-party API call tool.
 *
 * Requires confirmation by default. Read-only GET endpoints can be whitelisted
 * via the API_INTEGRATION_READONLY_WHITELIST environment variable as a
 * comma-separated list of `integration:endpoint` patterns.
 */
export class ApiCallTool implements ToolImplementation {
  readonly name = 'api_call';
  readonly requiresConfirmation = true;

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
      return {
        integration,
        endpoint,
        method,
        note: 'API integration is not configured; returning a stub response.',
      };
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

  /**
   * Returns true if the given integration/endpoint/method is read-only and
   * does not require user confirmation.
   */
  isReadOnly(integration: string, endpoint: string, method: string): boolean {
    if (method !== 'GET') return false;

    const whitelist = process.env.API_INTEGRATION_READONLY_WHITELIST ?? '';
    if (whitelist === '') return false;

    const patterns = whitelist.split(',').map((p) => p.trim());
    const key = `${integration}:${endpoint}`;

    return patterns.some((pattern) => {
      if (pattern === key) return true;
      if (pattern.endsWith(':*') && key.startsWith(pattern.slice(0, -1))) {
        return true;
      }
      return false;
    });
  }
}
