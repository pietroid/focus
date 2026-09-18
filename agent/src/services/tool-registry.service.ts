import { ToolImplementation } from './tools/tool.interface.js';
import { ApiCallTool } from './tools/api-call.tool.js';
import {
  CalendarCheckAvailabilityTool,
  CalendarCreateEventTool,
} from './tools/calendar.tool.js';
import { WebSearchTool } from './tools/web-search.tool.js';

/**
 * Registry of available agent tool implementations.
 */
export class ToolRegistryService {
  private readonly _tools = new Map<string, ToolImplementation>(
    [
      new WebSearchTool(),
      new CalendarCheckAvailabilityTool(),
      new CalendarCreateEventTool(),
      new ApiCallTool(),
    ].map((tool) => [tool.name, tool]),
  );

  /** Returns the implementation for a tool name, or undefined. */
  get(name: string): ToolImplementation | undefined {
    return this._tools.get(name);
  }

  /** All registered tool names. */
  get names(): string[] {
    return [...this._tools.keys()];
  }
}
