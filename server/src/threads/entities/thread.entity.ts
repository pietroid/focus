import { Message } from './message.entity';

/** A thread, with every message across every day it spans. */
export class Thread {
  /** The folder name on disk, and the id the API addresses it by. */
  slug: string;
  title: string;
  messages: Message[];
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
  createdAt: Date;
  updatedAt: Date;
}
