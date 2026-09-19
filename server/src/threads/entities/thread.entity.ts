import { Message } from './message.entity';

/** A thread, with every message across every day it spans. */
export class Thread {
  /** The folder name on disk, and the id the API addresses it by. */
  slug: string;
  title: string;
  messages: Message[];
  /** Whether the user considers this thread closed. */
  solved: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** A thread without its messages, for the home screen's list. */
export class ThreadSummary {
  slug: string;
  title: string;
  /** The last message's text, trimmed to a single line. */
  preview: string;
  messageCount: number;
  solved: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** What is stored about a thread beyond its messages. */
export interface ThreadState {
  solved: boolean;
  /** Set when the user or the agent renamed the thread. */
  title?: string;
}
