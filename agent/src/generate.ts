import { OpenRouterError, OpenRouterService } from './services/openrouter.service.js';
import { ToolExecutorService } from './services/tool-executor.service.js';
import { ToolRegistryService } from './services/tool-registry.service.js';
import { Trace } from './trace.js';
import {
  GenerateResult,
  OpenRouterMessage,
  ToolCall,
  UserContext,
} from './types.js';
import { ToolLoopService } from './services/tool-loop.service.js';

/** One generation request, as the server sends it. */
export interface GenerateRequest {
  context: UserContext;
  /** The full prompt the server built. The agent does not add to it. */
  messages: OpenRouterMessage[];
  trace: Trace;
}

/** Raised when the agent cannot reach the model at all. */
export class AgentUnavailableError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
  }
}

/** The shared tool registry. Tools are stateless, so one instance is enough. */
const registry = new ToolRegistryService();

/** The registry, for the `/tools` route. */
export function toolRegistry(): ToolRegistryService {
  return registry;
}

/**
 * Runs one turn: model, tools, model again, until there is an answer.
 *
 * Failures are raised rather than papered over with a placeholder. The server
 * owns what the user sees, and it can say something far more useful than the
 * agent can from in here.
 */
export async function generate(
  request: GenerateRequest,
): Promise<GenerateResult> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  const model = process.env.OPENROUTER_MODEL ?? 'openai/gpt-4o-mini';

  if (apiKey === undefined || apiKey === '') {
    request.trace.error('model.notConfigured', {});
    throw new AgentUnavailableError('OPENROUTER_API_KEY is not configured');
  }

  const openRouter = new OpenRouterService(apiKey, model);
  const executor = new ToolExecutorService(registry, request.trace);
  const loop = new ToolLoopService(openRouter, executor, registry, request.trace);

  request.trace.log('generate.start', {
    model,
    messageCount: request.messages.length,
  });

  try {
    const result = await loop.run([...request.messages], request.context);

    request.trace.log('generate.ok', {
      model: result.model,
      iterations: result.iterations,
      latencyMs: result.latencyMs,
      toolCalls: result.toolTrace.map((entry) => entry.name),
      rawLength: result.raw.length,
    });

    return result;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = error instanceof OpenRouterError ? error.status : undefined;

    request.trace.error('generate.fail', {
      model,
      error: message,
      status,
      metadata: error instanceof OpenRouterError ? error.metadata : undefined,
    });

    throw new AgentUnavailableError(message, status);
  }
}
