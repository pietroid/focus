/** Who wrote a message. */
export type MessageRole = 'user' | 'agent';

/** A single turn in a thread. */
export class Message {
  /** Stable id, derived from the role and timestamp. */
  id: string;
  role: MessageRole;
  /** The message body, as written in the markdown file. */
  text: string;
  createdAt: Date;
}
