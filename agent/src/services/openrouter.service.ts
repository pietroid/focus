import { OpenRouterMessage, ToolCall, ToolDefinition } from '../types.js';

/** Outcome of a single OpenRouter generation call. */
export type OpenRouterOutcome =
  | { kind: 'final'; content: string }
  | { kind: 'tool_calls'; toolCalls: ToolCall[] };

/** Result from OpenRouterService.generate, including metadata. */
export interface OpenRouterResult {
  outcome: OpenRouterOutcome;
  model: string;
  latencyMs: number;
}

/** Raw upstream error metadata returned by OpenRouter. */
export interface OpenRouterErrorMetadata {
  provider_name?: string;
  raw?: string;
  [key: string]: unknown;
}

/** Typed error for OpenRouter failures. */
export class OpenRouterError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly metadata?: OpenRouterErrorMetadata,
  ) {
    super(message);
  }
}

/**
 * Thin client for the OpenRouter chat completions API.
 */
export class OpenRouterService {
  private readonly _url = 'https://openrouter.ai/api/v1/chat/completions';

  constructor(
    private readonly _apiKey: string,
    private readonly _model: string,
    private readonly _appUrl = 'https://focus.pietroid.dev',
    private readonly _appName = 'Focus',
  ) {}

  /** The model this client is pinned to. */
  get model(): string {
    return this._model;
  }

  async generate(
    messages: OpenRouterMessage[],
    tools: ToolDefinition[],
  ): Promise<OpenRouterResult> {
    const startedAt = Date.now();

    const response = await fetch(this._url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this._apiKey}`,
        'HTTP-Referer': this._appUrl,
        'X-Title': this._appName,
      },
      body: JSON.stringify({
        model: this._model,
        messages,
        tools,
        tool_choice: 'auto',
        temperature: 0.7,
      }),
    });

    const latencyMs = Date.now() - startedAt;
    const data = (await response.json()) as Record<string, unknown>;

    if (!response.ok) {
      const error = data.error as
        | { message?: string; metadata?: OpenRouterErrorMetadata }
        | undefined;
      const errorMessage =
        error?.message ?? `OpenRouter returned ${response.status}`;
      throw new OpenRouterError(
        errorMessage,
        response.status,
        error?.metadata,
      );
    }

    const choice = (data.choices as Array<Record<string, unknown>> | undefined)?.[0];
    const message = choice?.message as Record<string, unknown> | undefined;
    const finishReason = choice?.finish_reason;

    if (finishReason === 'tool_calls' || Array.isArray(message?.tool_calls)) {
      const toolCalls = this._parseToolCalls(message?.tool_calls);
      return { outcome: { kind: 'tool_calls', toolCalls }, model: this._model, latencyMs };
    }

    const content = message?.content;
    if (typeof content !== 'string') {
      throw new OpenRouterError('OpenRouter returned an empty reply');
    }

    return {
      outcome: { kind: 'final', content },
      model: this._model,
      latencyMs,
    };
  }

  private _parseToolCalls(value: unknown): ToolCall[] {
    if (!Array.isArray(value)) return [];

    return value
      .map((item) => {
        const toolCall = item as Record<string, unknown>;
        const func = toolCall.function as Record<string, unknown> | undefined;
        if (typeof toolCall.id !== 'string' || func === undefined) return null;
        return {
          id: toolCall.id,
          type: 'function' as const,
          function: {
            name: String(func.name ?? ''),
            arguments: String(func.arguments ?? '{}'),
          },
        };
      })
      .filter((tc): tc is ToolCall => tc !== null);
  }
}
