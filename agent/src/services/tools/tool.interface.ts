/**
 * Common interface for agent tool implementations.
 */
export interface ToolImplementation {
  readonly name: string;
  readonly requiresConfirmation: boolean;
  execute(args: Record<string, unknown>, context: UserContext): Promise<unknown>;
}

/** User context passed to tools. */
export interface UserContext {
  userId: string;
  slug: string;
}
