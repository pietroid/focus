import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface ReplyContext {
  userId: string;
  slug: string;
  message: string;
}

interface AgentReplyResponse {
  text: string;
}

/**
 * Client for the separate Focus agent service.
 *
 * The agent runs in its own container on the internal Docker network. It has
 * read-only access to the thread files and exposes a private /reply endpoint.
 * This service sends the thread reference and the new user message; the agent
 * reads the thread itself and returns a reply.
 */
@Injectable()
export class AgentService {
  constructor(private readonly _config: ConfigService) {}

  async reply(context: ReplyContext): Promise<string> {
    const agentUrl = this._config.get<string>('AGENT_URL') ?? 'http://localhost:3001';

    const response = await fetch(`${agentUrl}/reply`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(context),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => 'unknown error');
      throw new Error(`Agent returned ${response.status}: ${body}`);
    }

    const data = (await response.json()) as AgentReplyResponse;
    return data.text;
  }
}
