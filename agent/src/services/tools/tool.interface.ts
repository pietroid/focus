import { ToolDefinition, ToolEffect, UserContext } from '../../types.js';

/**
 * One tool the agent can run.
 *
 * A tool owns its own OpenRouter definition, its own plain-English summary and
 * its own effect. Keeping all three here means the server never has to
 * hard-code a second copy of any of them: it asks the agent what exists, how to
 * describe it, and which half of the contract it falls under.
 */
export interface ToolImplementation {
  readonly name: string;

  /** The schema the model sees. */
  readonly definition: ToolDefinition;

  /**
   * Whether running this changes anything the user owns.
   *
   * This is the whole basis of the two-tier contract. A `read` runs the moment
   * the model asks: refusing to look at a calendar the agent can plainly see
   * costs the user a turn and buys nothing. A `write` is blocked until the user
   * has confirmed it, because it is theirs to authorise, not the model's.
   *
   * This value is the one the prompt groups by, so it has to be a constant. A
   * tool whose real effect depends on its arguments declares the stricter of
   * the two here and narrows it in [effectFor].
   */
  readonly effect: ToolEffect;

  /**
   * The effect of one particular call, when the arguments decide it.
   *
   * Only `api_call` needs this: a GET reads and a DELETE does not. Everything
   * else inherits [effect].
   */
  effectFor?(args: Record<string, unknown>): ToolEffect;

  /**
   * One line a person would recognise, e.g. "Adicionar 'Standup' na sua agenda
   * em sex., 20 de set., 10:00-11:00". It is what a proposal, a trace and a
   * failure card all read back, so it must never fall back to dumping raw
   * arguments.
   */
  summarize(args: Record<string, unknown>): string;

  execute(args: Record<string, unknown>, context: UserContext): Promise<unknown>;
}

export type { UserContext };
