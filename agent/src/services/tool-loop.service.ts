import { OpenRouterService } from './openrouter.service.js';
import { ToolExecutorService } from './tool-executor.service.js';
import { ToolRegistryService } from './tool-registry.service.js';
import { Trace } from '../trace.js';
import {
  GenerateResult,
  OpenRouterMessage,
  ToolTraceEntry,
  UserContext,
} from '../types.js';

/** How many model round-trips one turn is allowed. */
const MAX_ITERATIONS = 8;

/**
 * The model loop.
 *
 * Every tool the model asks for runs immediately and its result goes straight
 * back to the model, so the answer the user finally sees is grounded in real
 * data rather than in a proposal. A tool that fails comes back as a result too,
 * and the model gets to say so in its own words.
 *
 * The loop never builds UI. It returns the model's text verbatim, and the
 * server decides what to do with it.
 */
export class ToolLoopService {
  constructor(
    private readonly _openRouter: OpenRouterService,
    private readonly _toolExecutor: ToolExecutorService,
    private readonly _toolRegistry: ToolRegistryService,
    private readonly _trace: Trace,
  ) {}

  async run(
    messages: OpenRouterMessage[],
    context: UserContext,
  ): Promise<GenerateResult> {
    const definitions = this._toolRegistry.definitions;
    const toolTrace: ToolTraceEntry[] = [];
    let latencyMs = 0;
    let iterations = 0;

    while (iterations < MAX_ITERATIONS) {
      iterations++;

      const result = await this._openRouter.generate(messages, definitions);
      latencyMs += result.latencyMs;

      this._trace.log('model.response', {
        iteration: iterations,
        kind: result.outcome.kind,
        latencyMs: result.latencyMs,
      });

      if (result.outcome.kind === 'final') {
        return {
          raw: result.outcome.content,
          toolTrace,
          model: result.model,
          latencyMs,
          iterations,
        };
      }

      const calls = result.outcome.toolCalls;

      // OpenAI-compatible APIs require the assistant message carrying the
      // tool_calls to sit immediately before the tool results.
      messages.push({ role: 'assistant', content: '', tool_calls: calls });

      for (const call of calls) {
        const entry = await this._toolExecutor.execute(call, context);
        toolTrace.push(entry);
        messages.push({
          role: 'tool',
          content: JSON.stringify(entry.ok ? entry.result : { error: entry.error }),
          tool_call_id: call.id,
        });
      }
    }

    this._trace.warn('model.iterationLimit', { iterations });

    return {
      raw: '',
      toolTrace,
      model: this._openRouter.model,
      latencyMs,
      iterations,
    };
  }
}
