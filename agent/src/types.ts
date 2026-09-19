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
  ok: boolean;
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
