import { ToolCall, ToolTraceEntry, UserContext } from '../types.js';
import { Trace } from '../trace.js';
import { ToolRegistryService } from './tool-registry.service.js';

/**
 * Runs one tool call and records what happened.
 *
 * Every outcome, including a failure, comes back as a [ToolTraceEntry] rather
 * than an exception. The loop needs to feed a failure back to the model as a
 * tool result, and the server needs to be able to tell the user which step
 * broke, so a thrown error here would lose the only useful information.
 */
export class ToolExecutorService {
  constructor(
    private readonly _registry: ToolRegistryService,
    private readonly _trace: Trace,
  ) {}

  async execute(
    toolCall: ToolCall,
    context: UserContext,
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
        ok: false,
        error: 'Tool arguments were not valid JSON',
        durationMs: Date.now() - started,
      };
    }

    this._trace.log('tool.start', { tool: name, toolCallId: toolCall.id, args });

    try {
      const result = await tool.execute(args, context);
      const durationMs = Date.now() - started;
      this._trace.log('tool.ok', { tool: name, toolCallId: toolCall.id, durationMs });
      return { ...base, arguments: args, ok: true, result, durationMs };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const durationMs = Date.now() - started;
      this._trace.error('tool.fail', {
        tool: name,
        toolCallId: toolCall.id,
        durationMs,
        error: message,
      });
      return { ...base, arguments: args, ok: false, error: message, durationMs };
    }
  }
}
