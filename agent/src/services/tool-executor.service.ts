import { ToolCall, UserContext } from '../a2ui/types.js';
import { ToolRegistryService } from './tool-registry.service.js';

/** Structured result of executing a tool. */
export interface ToolResult {
  ok: boolean;
  name: string;
  result?: unknown;
  error?: string;
}

/**
 * Executes confirmed tool calls.
 */
export class ToolExecutorService {
  constructor(private readonly _registry: ToolRegistryService) {}

  async execute(toolCall: ToolCall, context: UserContext): Promise<ToolResult> {
    const name = toolCall.function.name;
    console.log('[tool-executor] executing tool', { name, id: toolCall.id, arguments: toolCall.function.arguments });

    const tool = this._registry.get(name);

    if (tool === undefined) {
      const registered = this._registry.names.join(', ');
      console.error(`[tool-executor] tool "${name}" is not registered. Registered tools: ${registered}`);
      return { ok: false, name, error: `Tool "${name}" is not registered` };
    }

    let args: Record<string, unknown>;
    try {
      args = JSON.parse(toolCall.function.arguments) as Record<string, unknown>;
    } catch {
      console.error('[tool-executor] tool arguments are not valid JSON', { name, arguments: toolCall.function.arguments });
      return { ok: false, name, error: 'Tool arguments are not valid JSON' };
    }

    try {
      const result = await tool.execute(args, context);
      console.log('[tool-executor] tool executed successfully', { name, result });
      return { ok: true, name, result };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[tool-executor] tool execution failed', { name, error: message });
      return { ok: false, name, error: message };
    }
  }
}
