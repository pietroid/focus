/**
 * The agent's wire types.
 *
 * The agent knows nothing about A2UI. It takes a prompt the server built, runs
 * the model and its tools, and hands back raw text plus a record of everything
 * the tools did. Rendering that into a UI is the server's job.
 */

/** OpenRouter chat message shape. */
export interface OpenRouterMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  name?: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
}

/** OpenRouter tool call representation. */
export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    /** JSON-encoded arguments, as the model emitted them. */
    arguments: string;
  };
}

/**
 * Whether running a tool changes anything the user owns.
 *
 * A `read` is free: the agent looks, and the answer is grounded. A `write`
 * needs the user's confirmation first, and the executor enforces that rather
 * than trusting the prompt.
 */
export type ToolEffect = 'read' | 'write';

/** OpenRouter tool definition. */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

/** What a tool call did, so the server can explain it without guessing. */
export interface ToolTraceEntry {
  /** The tool call id, matching the model's own id. */
  id: string;
  name: string;
  /** Parsed arguments. Empty when the model emitted invalid JSON. */
  arguments: Record<string, unknown>;
  /** The effect of this particular call. */
  effect: ToolEffect;
  /**
   * The line a person would recognise, from the tool's own `summarize()`.
   *
   * Carried on the entry so the server can name what was attempted without
   * knowing anything about the tool that attempted it.
   */
  summary: string;
  ok: boolean;
  /**
   * True when this was a write the user had not confirmed yet.
   *
   * Not a failure, though it shares `ok: false` with one: nothing was tried, so
   * nothing broke. The server needs the distinction, because a blocked write is
   * an ordinary proposal turn and a failed one is an apology.
   */
  blocked?: boolean;
  result?: unknown;
  error?: string;
  startedAt: string;
  durationMs: number;
}

/** Who the turn belongs to. Passed to tools so they can scope their work. */
export interface UserContext {
  userId: string;
  slug: string;
  traceId: string;
}

/** Name, description and effect, as the server reads them off `GET /tools`. */
export interface ToolDescriptor {
  name: string;
  description: string;
  effect: ToolEffect;
}

/** What the agent hands back for one generation. */
export interface GenerateResult {
  /** The model's final message content, verbatim. */
  raw: string;
  /** Every tool that ran, in order. */
  toolTrace: ToolTraceEntry[];
  model: string;
  latencyMs: number;
  iterations: number;
}
