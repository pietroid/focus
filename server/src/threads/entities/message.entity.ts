/** Who wrote a message. */
export type MessageRole = 'user' | 'agent' | 'system';

/** Content type stored in the message body. */
export type MessageContentType = 'text' | 'a2ui';

/** Pending tool call stored alongside an A2UI confirmation message. */
export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string;
  };
}

/** A2UI component node. */
export interface A2uiComponent {
  component: string;
  children?: A2uiComponent[];
  [key: string]: unknown;
}

/** Extra metadata attached to a message. */
export interface MessageMetadata {
  contentType: MessageContentType;
  model?: string;
  latencyMs?: number;
  pendingToolCall?: ToolCall;
  a2ui?: A2uiComponent;
}

/** A single turn in a thread. */
export class Message {
  /** Stable id, derived from the role and timestamp. */
  id: string;
  role: MessageRole;
  /** The message body, as written in the markdown file. */
  text: string;
  createdAt: Date;
  /** Optional metadata, including content type and A2UI tree. */
  metadata?: MessageMetadata;
}
