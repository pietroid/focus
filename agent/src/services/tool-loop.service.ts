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
 * Reads run the moment the model asks for them and their results go straight
 * back, so the answer the user finally sees is grounded in real data rather
 * than in a guess. Writes run only when [allowWrites] says the user has
 * confirmed this turn; otherwise the executor refuses them and the model is
 * told to propose instead. Either way the outcome goes back as a tool result,
 * and the model gets to write the sentence with the truth already in hand.
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
    allowWrites: boolean,
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
        const entry = await this._toolExecutor.execute(call, context, allowWrites);
        toolTrace.push(entry);
        messages.push({
          role: 'tool',
          content: JSON.stringify(entry.ok ? entry.result : { error: entry.error }),
          tool_call_id: call.id,
        });
      }
    }

    // Out of round-trips with nothing said. Returning an empty reply here used
    // to lose the turn entirely, even when a write had already gone through and
    // the user deserved to hear about it. One last call, tools withheld, leaves
    // the model no option but to answer in words.
    this._trace.warn('model.iterationLimit', { iterations });

    const closing = await this._forceAnswer(messages);
    latencyMs += closing.latencyMs;

    return {
      raw: closing.raw,
      toolTrace,
      model: this._openRouter.model,
      latencyMs,
      iterations,
    };
  }

  /** One tool-free call, to turn an exhausted loop into a sentence. */
  private async _forceAnswer(
    messages: OpenRouterMessage[],
  ): Promise<{ raw: string; latencyMs: number }> {
    try {
      const result = await this._openRouter.generate(
        [
          ...messages,
          {
            role: 'system',
            content:
              'Stop calling tools and answer now, from what the tool results ' +
              'above actually say. Report only what succeeded. If something ' +
              'failed or never ran, say so plainly.',
          },
        ],
        [],
      );

      if (result.outcome.kind === 'final') {
        return { raw: result.outcome.content, latencyMs: result.latencyMs };
      }

      return { raw: '', latencyMs: result.latencyMs };
    } catch (error) {
      // The turn is already degraded; the server has a written fallback for an
      // empty reply and losing it to a second failure helps nobody.
      this._trace.warn('model.forceAnswerFailed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { raw: '', latencyMs: 0 };
    }
  }
}
