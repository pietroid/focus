import { ToolCall, ToolTraceEntry, UserContext } from '../types.js';
import { Trace } from '../trace.js';
import { ToolRegistryService } from './tool-registry.service.js';

/**
 * What the model is told when it reaches for a write it has not earned yet.
 *
 * Phrased as an instruction rather than an error, because it is not a failure
 * and the model's next move matters: it should describe the change and offer
 * the confirm action, not apologise or try a different tool.
 */
const NOT_CONFIRMED =
  'NOT EXECUTED. Nothing was changed. This action modifies the user\'s data ' +
  'and they have not confirmed it on this turn. Do not try it again in this ' +
  'turn and do not claim it happened. Reply with a short proposal naming ' +
  'exactly what you are about to do, and a button carrying ' +
  '{"type":"confirm","text":"..."} whose text restates the whole action. ' +
  'Running it is then a single tap away.';

/**
 * Runs one tool call and records what happened.
 *
 * Two jobs. It decides whether a call is allowed to run at all, and it records
 * the outcome.
 *
 * The gate is here rather than in the prompt because a prompt is a request and
 * this is a rule. A read runs the moment the model asks for it: the agent can
 * see the calendar, so making the user grant permission to look at it costs a
 * turn and buys nothing. A write does not run until the user has confirmed the
 * turn, whatever the model believes about its own authority.
 *
 * Every outcome, including a refusal and a failure, comes back as a
 * [ToolTraceEntry] rather than an exception. The loop needs to feed it back to
 * the model as a tool result, and the server needs to be able to tell the user
 * which step broke, so a thrown error here would lose the only useful
 * information.
 */
export class ToolExecutorService {
  constructor(
    private readonly _registry: ToolRegistryService,
    private readonly _trace: Trace,
  ) {}

  async execute(
    toolCall: ToolCall,
    context: UserContext,
    allowWrites: boolean,
  ): Promise<ToolTraceEntry> {
    const name = toolCall.function.name;
    const startedAt = new Date();
    const started = Date.now();

    const base = {
      id: toolCall.id,
      name,
      startedAt: startedAt.toISOString(),
    };

    const tool = this._registry.get(name);
    if (tool === undefined) {
      this._trace.error('tool.unknown', {
        tool: name,
        registered: this._registry.names,
      });
      return {
        ...base,
        arguments: {},
        effect: 'write',
        summary: `Run ${name}`,
        ok: false,
        error: `Tool "${name}" is not registered`,
        durationMs: Date.now() - started,
      };
    }

    let args: Record<string, unknown>;
    try {
      args = JSON.parse(toolCall.function.arguments) as Record<string, unknown>;
    } catch {
      this._trace.error('tool.badArguments', {
        tool: name,
        raw: toolCall.function.arguments,
      });
      return {
        ...base,
        arguments: {},
        effect: tool.effect,
        summary: this._registry.summarize(name, {}),
        ok: false,
        error: 'Tool arguments were not valid JSON',
        durationMs: Date.now() - started,
      };
    }

    const effect = this._registry.effectOf(name, args);
    const summary = this._registry.summarize(name, args);

    if (effect === 'write' && !allowWrites) {
      this._trace.log('tool.blocked', { tool: name, toolCallId: toolCall.id, args });
      return {
        ...base,
        arguments: args,
        effect,
        summary,
        ok: false,
        blocked: true,
        error: NOT_CONFIRMED,
        durationMs: Date.now() - started,
      };
    }

    this._trace.log('tool.start', {
      tool: name,
      toolCallId: toolCall.id,
      effect,
      args,
    });

    try {
      const result = await tool.execute(args, context);
      const durationMs = Date.now() - started;
      this._trace.log('tool.ok', {
        tool: name,
        toolCallId: toolCall.id,
        effect,
        durationMs,
      });
      return { ...base, arguments: args, effect, summary, ok: true, result, durationMs };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const durationMs = Date.now() - started;
      this._trace.error('tool.fail', {
        tool: name,
        toolCallId: toolCall.id,
        effect,
        durationMs,
        error: message,
      });
      return {
        ...base,
        arguments: args,
        effect,
        summary,
        ok: false,
        error: message,
        durationMs,
      };
    }
  }
}
