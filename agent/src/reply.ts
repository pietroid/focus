import { A2uiValidationService, FALLBACK_A2UI } from './services/a2ui-validation.service.js';
import { ContextBuilderService } from './services/context-builder.service.js';
import { OpenRouterError, OpenRouterService } from './services/openrouter.service.js';
import { PromptAssemblerService } from './services/prompt-assembler.service.js';
import { ToolExecutorService } from './services/tool-executor.service.js';
import { ToolLoopService } from './services/tool-loop.service.js';
import { ToolRegistryService } from './services/tool-registry.service.js';
import { TOOL_DEFINITIONS } from './a2ui/catalog.js';
import {
  A2uiAgentResponse,
  ToolCall,
  UserContext,
} from './a2ui/types.js';

export interface ReplyContext {
  userId: string;
  slug: string;
  message: string;
  dataDir: string;
}

export interface ReplyResult {
  a2ui: A2uiAgentResponse['a2ui'];
  pendingToolCall?: ToolCall;
  solved?: boolean;
  metadata: {
    model: string;
    latencyMs: number;
  };
}

export interface ExecuteToolContext {
  userId: string;
  slug: string;
  toolCall: ToolCall;
  dataDir: string;
}

/**
 * Shared service composition.
 */
function createServices(dataDir: string): {
  contextBuilder: ContextBuilderService;
  promptAssembler: PromptAssemblerService;
  toolRegistry: ToolRegistryService;
  toolExecutor: ToolExecutorService;
  validator: A2uiValidationService;
} {
  const registry = new ToolRegistryService();
  return {
    contextBuilder: new ContextBuilderService(dataDir),
    promptAssembler: new PromptAssemblerService(),
    toolRegistry: registry,
    toolExecutor: new ToolExecutorService(registry),
    validator: new A2uiValidationService(),
  };
}

/**
 * Generates the next A2UI reply for a thread.
 */
export async function agentReply(context: ReplyContext): Promise<ReplyResult> {
  const services = createServices(context.dataDir);
  const apiKey = process.env.OPENROUTER_API_KEY;
  const model = process.env.OPENROUTER_MODEL ?? 'openai/gpt-4o-mini';

  if (!apiKey) {
    console.warn('OPENROUTER_API_KEY is not configured; returning fallback');
    return fallbackReply();
  }

  const startedAt = Date.now();

  try {
    const thread = await services.contextBuilder.build(
      context.userId,
      context.slug,
    );

    if (thread === null) {
      throw new Error(`Thread "${context.slug}" not found`);
    }

    const userContext: UserContext = {
      userId: context.userId,
      slug: context.slug,
    };

    const openRouter = new OpenRouterService(apiKey, model);
    const toolExecutor = new ToolExecutorService(services.toolRegistry);
    const toolLoop = new ToolLoopService(
      openRouter,
      toolExecutor,
      services.toolRegistry,
      services.promptAssembler,
      TOOL_DEFINITIONS,
    );

    const systemPrompt = await services.promptAssembler.buildSystemPrompt(
      TOOL_DEFINITIONS,
    );
    const messages = services.promptAssembler.buildMessages(
      systemPrompt,
      thread.messages.map((m) => ({ role: m.role, text: m.text })),
      context.message,
    );

    const loopResult = await toolLoop.run(messages, userContext);

    const validated = services.validator.validate({ a2ui: loopResult.a2ui });
    const latencyMs = Date.now() - startedAt;

    return {
      a2ui: validated.component,
      pendingToolCall: loopResult.pendingToolCall,
      metadata: { model, latencyMs },
    };
  } catch (error) {
    const latencyMs = Date.now() - startedAt;
    const logPayload: Record<string, unknown> = {
      userId: context.userId,
      slug: context.slug,
      error: error instanceof Error ? error.message : String(error),
    };
    if (error instanceof OpenRouterError) {
      logPayload.status = error.status;
      logPayload.metadata = error.metadata;
    }
    console.error('Agent reply failed:', logPayload);

    return {
      a2ui: FALLBACK_A2UI,
      metadata: { model: 'fallback', latencyMs },
    };
  }
}

/**
 * Executes a confirmed tool call and returns the final A2UI response.
 */
export async function agentExecuteTool(
  context: ExecuteToolContext,
): Promise<ReplyResult> {
  const services = createServices(context.dataDir);
  const apiKey = process.env.OPENROUTER_API_KEY;
  const model = process.env.OPENROUTER_MODEL ?? 'openai/gpt-4o-mini';

  if (!apiKey) {
    console.warn('OPENROUTER_API_KEY is not configured; returning fallback');
    return fallbackReply();
  }

  const startedAt = Date.now();

  try {
    const thread = await services.contextBuilder.build(
      context.userId,
      context.slug,
    );

    if (thread === null) {
      throw new Error(`Thread "${context.slug}" not found`);
    }

    const userContext: UserContext = {
      userId: context.userId,
      slug: context.slug,
    };

    const toolResult = await services.toolExecutor.execute(
      context.toolCall,
      userContext,
    );

    const openRouter = new OpenRouterService(apiKey, model);
    const toolExecutor = new ToolExecutorService(services.toolRegistry);
    const toolLoop = new ToolLoopService(
      openRouter,
      toolExecutor,
      services.toolRegistry,
      services.promptAssembler,
      TOOL_DEFINITIONS,
    );

    const systemPrompt = await services.promptAssembler.buildSystemPrompt(
      TOOL_DEFINITIONS,
    );
    const messages = services.promptAssembler.buildMessages(
      systemPrompt,
      thread.messages.map((m) => ({ role: m.role, text: m.text })),
      '',
    );

    // OpenRouter expects a tool_calls assistant message immediately before the
    // tool result. Synthesize one from the confirmed tool call so the loop can
    // continue cleanly.
    messages.push({
      role: 'assistant',
      content: '',
      tool_calls: [context.toolCall],
    });

    // Append the tool result as the latest context.
    messages.push({
      role: 'tool',
      content: JSON.stringify(toolResult),
      tool_call_id: context.toolCall.id,
    });

    const loopResult = await toolLoop.run(messages, userContext);

    const validated = services.validator.validate({ a2ui: loopResult.a2ui });
    const latencyMs = Date.now() - startedAt;

    return {
      a2ui: validated.component,
      pendingToolCall: loopResult.pendingToolCall,
      metadata: { model, latencyMs },
    };
  } catch (error) {
    const latencyMs = Date.now() - startedAt;
    const logPayload: Record<string, unknown> = {
      userId: context.userId,
      slug: context.slug,
      tool: context.toolCall.function.name,
      error: error instanceof Error ? error.message : String(error),
    };
    if (error instanceof OpenRouterError) {
      logPayload.status = error.status;
      logPayload.metadata = error.metadata;
    }
    console.error('Agent execute-tool failed:', logPayload);

    return {
      a2ui: FALLBACK_A2UI,
      metadata: { model: 'fallback', latencyMs },
    };
  }
}

/** Fallback reply used when the agent cannot reach OpenRouter. */
export function fallbackReply(): ReplyResult {
  return {
    a2ui: FALLBACK_A2UI,
    metadata: { model: 'fallback', latencyMs: 0 },
  };
}
