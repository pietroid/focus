import { Thread } from './thread-store.js';

export interface ReplyContext {
  thread: Thread;
  newMessage: string;
}

interface OpenRouterMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface OpenRouterResponse {
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
  error?: {
    message: string;
  };
}

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

function getEnv(name: string): string | undefined {
  return process.env[name];
}

function buildMessages(thread: Thread, newMessage: string): OpenRouterMessage[] {
  const messages: OpenRouterMessage[] = [
    {
      role: 'system',
      content:
        'You are Focus, a concise personal productivity assistant. You help the user think through tasks, capture notes, and make progress on their threads. Keep replies brief and actionable.',
    },
  ];

  for (const message of thread.messages) {
    messages.push({
      role: message.role === 'agent' ? 'assistant' : 'user',
      content: message.text,
    });
  }

  messages.push({ role: 'user', content: newMessage });
  return messages;
}

async function callOpenRouter(messages: OpenRouterMessage[]): Promise<string> {
  const apiKey = getEnv('OPENROUTER_API_KEY');
  const model = getEnv('OPENROUTER_MODEL') ?? 'openai/gpt-4o-mini';

  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY is not configured');
  }

  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages,
    }),
  });

  const data = (await response.json()) as OpenRouterResponse;

  if (!response.ok || data.error) {
    const message = data.error?.message ?? `OpenRouter returned ${response.status}`;
    throw new Error(`OpenRouter request failed: ${message}`);
  }

  const content = data.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.trim() === '') {
    throw new Error('OpenRouter returned an empty reply');
  }

  return content.trim();
}

/**
 * Generates a reply for the given thread and new user message.
 *
 * The reply is produced by calling OpenRouter using the thread history as
 * context. If OpenRouter is not configured or the request fails, a short
 * fallback message is returned so the endpoint remains usable.
 */
export async function agentReply(context: ReplyContext): Promise<string> {
  const messages = buildMessages(context.thread, context.newMessage);

  try {
    return await callOpenRouter(messages);
  } catch (error) {
    console.error('Agent reply failed:', error);
    return 'Sorry, I could not generate a reply right now. Please try again in a moment.';
  }
}
