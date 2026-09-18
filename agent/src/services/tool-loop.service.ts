import { FALLBACK_A2UI } from './a2ui-validation.service.js';
import { OpenRouterService, OpenRouterError } from './openrouter.service.js';
import { PromptAssemblerService } from './prompt-assembler.service.js';
import { ToolExecutorService } from './tool-executor.service.js';
import { ToolRegistryService } from './tool-registry.service.js';
import {
  A2uiAgentResponse,
  A2uiComponent,
  A2uiReply,
  OpenRouterMessage,
  ToolCall,
  ToolDefinition,
  UserContext,
} from '../a2ui/types.js';

/** Result of running the tool loop. */
export interface ToolLoopResult {
  a2ui: A2uiComponent;
  pendingToolCall?: ToolCall;
  latencyMs: number;
}

/**
 * Runs the OpenRouter request/response loop.
 *
 * - Executes read-only tools immediately and feeds results back to the model.
 * - Pauses and returns a confirmation UI when a write/sensitive tool is
 *   requested.
 * - Returns the final A2UI response once the model stops calling tools.
 */
export class ToolLoopService {
  constructor(
    private readonly _openRouter: OpenRouterService,
    private readonly _toolExecutor: ToolExecutorService,
    private readonly _toolRegistry: ToolRegistryService,
    private readonly _promptAssembler: PromptAssemblerService,
    private readonly _allowedTools: ToolDefinition[],
  ) {}

  async run(
    messages: OpenRouterMessage[],
    context: UserContext,
  ): Promise<ToolLoopResult> {
    const maxIterations = 10;
    let iterations = 0;
    let totalLatencyMs = 0;

    while (iterations < maxIterations) {
      iterations++;

      const result = await this._openRouter.generate(messages, this._allowedTools);
      totalLatencyMs += result.latencyMs;

      if (result.outcome.kind === 'final') {
        const parsed = this._parseA2ui(result.outcome.content);
        return { a2ui: parsed, latencyMs: totalLatencyMs };
      }

      // The model requested one or more tool calls.
      const pending = this._processToolCalls(result.outcome.toolCalls, context);

      if (pending.length > 0) {
        // At least one tool requires confirmation: pause the loop and return a
        // confirmation UI for the first pending call.
        const first = pending[0];
        const a2ui = this._buildConfirmationUi(first);
        return { a2ui, pendingToolCall: first, latencyMs: totalLatencyMs };
      }

      // All tool calls were safe and have been executed. OpenRouter/OpenAI
      // requires an assistant message carrying the tool_calls immediately
      // before any tool result messages, so append that first.
      messages.push({
        role: 'assistant',
        content: '',
        tool_calls: result.outcome.toolCalls,
      });

      for (const toolCall of result.outcome.toolCalls) {
        const toolResult = await this._toolExecutor.execute(toolCall, context);
        messages.push({
          role: 'tool',
          content: JSON.stringify(toolResult),
          tool_call_id: toolCall.id,
        });
      }
    }

    return { a2ui: FALLBACK_A2UI, latencyMs: totalLatencyMs };
  }

  private _processToolCalls(
    toolCalls: ToolCall[],
    context: UserContext,
  ): ToolCall[] {
    const pending: ToolCall[] = [];

    for (const toolCall of toolCalls) {
      const tool = this._toolRegistry.get(toolCall.function.name);
      if (tool === undefined) {
        // Unknown tools are treated as pending confirmation so the backend can
        // reject them gracefully.
        pending.push(toolCall);
        continue;
      }

      if (tool.requiresConfirmation) {
        pending.push(toolCall);
      }
    }

    return pending;
  }

  private _buildConfirmationUi(toolCall: ToolCall): A2uiComponent {
    const args = this._safeParseArgs(toolCall.function.arguments);
    const summary = JSON.stringify(args, null, 2);

    return {
      component: 'Column',
      children: [
        {
          component: 'Text',
          text: `Allow ${toolCall.function.name}?`,
          variant: 'title',
        },
        { component: 'Text', text: summary, variant: 'caption' },
        {
          component: 'Row',
          children: [
            {
              component: 'AppButton',
              text: 'Confirm',
              variant: 'primary',
              action: {
                type: 'tool',
                tool: toolCall.function.name,
                arguments: args,
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
    };
  }

  private _parseA2ui(content: string): A2uiComponent {
    try {
      const parsed = JSON.parse(content) as A2uiReply;
      return parsed.a2ui ?? FALLBACK_A2UI;
    } catch {
      return FALLBACK_A2UI;
    }
  }

  private _safeParseArgs(json: string): Record<string, unknown> {
    try {
      return JSON.parse(json) as Record<string, unknown>;
    } catch {
      return {};
    }
  }
}
