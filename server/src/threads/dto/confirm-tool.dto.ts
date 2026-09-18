export class ConfirmToolDto {
  /** Whether the user confirmed the tool call. */
  confirmed: boolean;

  /** Optional override of the original tool arguments. */
  arguments?: Record<string, unknown>;
}
