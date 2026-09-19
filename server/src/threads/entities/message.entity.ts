import { A2uiComponent, A2uiIssue } from '../../a2ui/a2ui.types';

/** Who wrote a message. */
export type MessageRole = 'user' | 'agent' | 'system';

/** Content type stored in the message body. */
export type MessageContentType = 'text' | 'a2ui';

/** What a tool did, kept for observability rather than for display. */
export interface ToolRun {
  name: string;
  ok: boolean;
  durationMs: number;
  error?: string;
}

/** Extra metadata attached to a message. */
export interface MessageMetadata {
  contentType: MessageContentType;
  model?: string;
  latencyMs?: number;
  a2ui?: A2uiComponent;
  /** The turn this message belongs to. Present on every agent message. */
  traceId?: string;
  /** Tools that ran while producing it. */
  toolRuns?: ToolRun[];
  /** What the validator had to repair or reject, if anything. */
  a2uiIssues?: A2uiIssue[];
  /** How the raw model output was read: direct, fenced, salvaged, wrapped. */
  parseStrategy?: string;
}

/** A single turn in a thread. */
export class Message {
  /** Stable id, derived from the role and timestamp. */
  id: string;
  role: MessageRole;
  /** The message body, as written in the markdown file. */
  text: string;
  createdAt: Date;
  metadata?: MessageMetadata;
}
