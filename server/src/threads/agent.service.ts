import { Injectable } from '@nestjs/common';

/**
 * Stands in for the real agent.
 *
 * Returns a placeholder after a short delay. The delay is deliberate: it is
 * roughly what a model call will cost, and without it the client's loading
 * state would never render long enough to be worth having.
 *
 * The real agent will take the whole thread rather than a single prompt, so
 * this takes nothing until there is something to give it.
 */
@Injectable()
export class AgentService {
  private readonly _replies = [
    'Got it. I have made a note of that.',
    'Sure. Anything else you want to add to this thread?',
    'Noted. I will keep this one open.',
    'Understood. Want me to break that into steps?',
    'Filed. Tell me when something changes.',
  ];

  async reply(): Promise<string> {
    await new Promise((resolve) => setTimeout(resolve, 600));

    const index = Math.floor(Math.random() * this._replies.length);
    return this._replies[index];
  }
}
