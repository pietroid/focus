import { Thread } from './thread-store.js';

export interface ReplyContext {
  thread: Thread;
  newMessage: string;
}

/**
 * Stand-in for the real agent.
 *
 * In the future this can call an LLM using the thread messages and the new
 * user message as context. For now it returns a placeholder after a short
 * delay so the client's loading state remains visible.
 */
export async function agentReply(context: ReplyContext): Promise<string> {
  const replies = [
    'Got it. I have made a note of that.',
    'Sure. Anything else you want to add to this thread?',
    'Noted. I will keep this one open.',
    'Understood. Want me to break that into steps?',
    'Filed. Tell me when something changes.',
  ];

  await new Promise((resolve) => setTimeout(resolve, 600));

  const index = Math.floor(Math.random() * replies.length);
  return replies[index];
}
