import { ToolDefinition } from '../types.js';
import { ToolImplementation } from './tools/tool.interface.js';
import { ApiCallTool } from './tools/api-call.tool.js';
import {
  CalendarCheckAvailabilityTool,
  CalendarCreateEventTool,
  CalendarDeleteEventTool,
  CalendarListEventsTool,
  CalendarUpdateEventTool,
} from './tools/calendar.tool.js';
import { WebSearchTool } from './tools/web-search.tool.js';

/** What the server needs to know about a tool without owning it. */
export interface ToolDescriptor {
  name: string;
  description: string;
}

/**
 * Every tool the agent can run.
 *
 * This is the only place tools are declared. The server asks for the list over
 * `GET /tools` rather than keeping a copy, so a tool added here shows up
 * everywhere without a second edit.
 */
export class ToolRegistryService {
  private readonly _tools = new Map<string, ToolImplementation>(
    [
      new WebSearchTool(),
      new CalendarCheckAvailabilityTool(),
      new CalendarListEventsTool(),
      new CalendarCreateEventTool(),
      new CalendarUpdateEventTool(),
      new CalendarDeleteEventTool(),
      new ApiCallTool(),
    ].map((tool) => [tool.name, tool]),
  );

  /** The implementation for a tool name, or undefined. */
  get(name: string): ToolImplementation | undefined {
    return this._tools.get(name);
  }

  /** All registered tool names. */
  get names(): string[] {
    return [...this._tools.keys()];
  }

  /** The schemas handed to the model. */
  get definitions(): ToolDefinition[] {
    return [...this._tools.values()].map((tool) => tool.definition);
  }

  /** The shape the server consumes over `GET /tools`. */
  describe(): ToolDescriptor[] {
    return [...this._tools.values()].map((tool) => ({
      name: tool.name,
      description: tool.definition.function.description,
    }));
  }

  /**
   * A plain-English line for a call, falling back to the tool name.
   *
   * Never returns raw JSON: this string is shown to the user.
   */
  summarize(name: string, args: Record<string, unknown>): string {
    const tool = this._tools.get(name);
    if (tool === undefined) return `Run ${name}`;

    try {
      const summary = tool.summarize(args).trim();
      return summary === '' ? `Run ${name}` : summary;
    } catch {
      return `Run ${name}`;
    }
  }
}
