import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { A2uiComponent, ToolCall } from './entities/message.entity';

export interface ReplyContext {
  userId: string;
  slug: string;
  message: string;
}

export interface ExecuteToolContext {
  userId: string;
  slug: string;
  toolCall: ToolCall;
}

export interface AgentReplyPayload {
  /** Always present. Root A2UI component tree. */
  a2ui: A2uiComponent;
  /** Present when the model requested a tool that requires confirmation. */
  pendingToolCall?: ToolCall;
  /** If true, the backend may mark the thread as solved. */
  solved?: boolean;
  metadata: {
    model: string;
    latencyMs: number;
  };
}

/**
 * Client for the separate Focus agent service.
 *
 * The agent runs in its own container on the internal Docker network. It has
 * read-only access to the thread files and exposes private /reply and
 * /execute-tool endpoints. This service sends the thread reference and the new
 * user message; the agent reads the thread itself and returns an A2UI tree.
 */
@Injectable()
export class AgentService {
  constructor(private readonly _config: ConfigService) {}

  async reply(context: ReplyContext): Promise<AgentReplyPayload> {
    return this._post('/reply', context, 'AGENT_REPLY_TIMEOUT_MS', 60_000);
  }

  async executeTool(context: ExecuteToolContext): Promise<AgentReplyPayload> {
    return this._post(
      '/execute-tool',
      context,
      'AGENT_EXECUTE_TOOL_TIMEOUT_MS',
      30_000,
    );
  }

  private async _post(
    path: string,
    body: unknown,
    timeoutEnv: string,
    defaultTimeout: number,
  ): Promise<AgentReplyPayload> {
    const agentUrl = this._config.get<string>('AGENT_URL') ?? 'http://localhost:3001';
    const timeout = this._config.get<number>(timeoutEnv) ?? defaultTimeout;
    const slug = (body as { slug?: string }).slug;

    console.log('[agent.service] POST', { path, slug, agentUrl, timeoutEnv });

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      const response = await fetch(`${agentUrl}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      if (!response.ok) {
        const errorBody = await response.text().catch(() => 'unknown error');
        throw new Error(`Agent returned ${response.status}: ${errorBody}`);
      }

      const data = (await response.json()) as AgentReplyPayload;

      if (data.a2ui === undefined) {
        throw new Error('Agent reply is missing a2ui field');
      }

      console.log('[agent.service] POST success', { path, slug, model: data.metadata.model });
      return data;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const stack = error instanceof Error ? error.stack : undefined;
      const toolCall = (body as { toolCall?: { id?: string; function?: { name?: string } } }).toolCall;
      console.error('[agent.service] POST failed:', {
        path,
        slug,
        tool: toolCall?.function?.name,
        toolCallId: toolCall?.id,
        error: message,
        stack,
      });

      return fallbackPayload();
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

function fallbackPayload(): AgentReplyPayload {
  return {
    a2ui: {
      component: 'Text',
      text: "I'm unable to reply right now. Please try again in a moment.",
    },
    metadata: { model: 'fallback', latencyMs: 0 },
  };
}
