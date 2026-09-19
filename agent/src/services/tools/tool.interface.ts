import { ToolDefinition, UserContext } from '../../types.js';

/**
 * One tool the agent can run.
 *
 * A tool owns its own OpenRouter definition and its own plain-English summary.
 * Keeping both here means the server never has to hard-code a second copy of
 * either: it asks the agent what exists and how to describe it.
 */
export interface ToolImplementation {
  readonly name: string;

  /** The schema the model sees. */
  readonly definition: ToolDefinition;

  /**
   * One line a person would recognise, e.g. "Adicionar 'Standup' na sua agenda
   * em sex., 20 de set., 10:00-11:00". It is what a trace and any future
   * receipt read back, so it must never fall back to dumping raw arguments.
   */
  summarize(args: Record<string, unknown>): string;

  execute(args: Record<string, unknown>, context: UserContext): Promise<unknown>;
}

export type { UserContext };
