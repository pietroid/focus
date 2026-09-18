import { readFile } from 'fs/promises';
import * as path from 'path';
import { buildCatalogDescription, buildExampleResponse } from '../a2ui/catalog.js';
import {
  OpenRouterMessage,
  ToolDefinition,
} from '../a2ui/types.js';

/**
 * Builds the system prompt and message list for OpenRouter.
 */
export class PromptAssemblerService {
  private _systemPrompt?: string;

  /** Loads the base system prompt and appends the catalog/tools appendix. */
  async buildSystemPrompt(allowedTools: ToolDefinition[]): Promise<string> {
    const base = await this._loadBasePrompt();
    const toolDescriptions = allowedTools
      .map((tool) => `- ${tool.function.name}: ${tool.function.description}`)
      .join('\n');

    return [
      base,
      '',
      `Current date and time: ${new Date().toISOString()}`,
      `Configured timezone: ${process.env.TZ ?? 'UTC'}`,
      '',
      buildCatalogDescription(),
      '',
      'Available tool definitions:',
      toolDescriptions,
      '',
      buildExampleResponse(),
      '',
      'Remember: every reply must be valid JSON with a top-level "a2ui" field.',
    ].join('\n');
  }

  /**
   * Builds the OpenRouter message list from thread history and the new user
   * message. Agent messages that contain A2UI JSON are sent as the JSON string
   * so the model can reason about its own prior outputs.
   */
  buildMessages(
    systemPrompt: string,
    threadMessages: Array<{ role: 'user' | 'agent'; text: string }>,
    newMessage: string,
  ): OpenRouterMessage[] {
    const messages: OpenRouterMessage[] = [
      { role: 'system', content: systemPrompt },
    ];

    for (const message of threadMessages) {
      messages.push({
        role: message.role === 'agent' ? 'assistant' : 'user',
        content: message.text,
      });
    }

    messages.push({ role: 'user', content: newMessage });
    return messages;
  }

  private async _loadBasePrompt(): Promise<string> {
    if (this._systemPrompt !== undefined) return this._systemPrompt;

    const file = path.join(__dirname, '..', '..', 'prompts', 'system-prompt.txt');

    try {
      this._systemPrompt = await readFile(file, 'utf8');
    } catch {
      this._systemPrompt = 'You are Focus, a productivity assistant.';
    }

    return this._systemPrompt;
  }
}
