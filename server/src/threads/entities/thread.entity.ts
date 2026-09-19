import { Message } from './message.entity';

/**
 * Which of the home screen's three lists a thread sits in.
 *
 * The bucket is the user's own judgement about when something happens, not
 * something derived from a date. The agent never sets it and nothing infers
 * it: a thread lands in `em_breve` when it is created and moves only because
 * someone dragged it.
 */
export type ThreadBucket = 'agora' | 'em_breve' | 'depois';

/** Every bucket, in the order the home screen draws them. */
export const THREAD_BUCKETS: ThreadBucket[] = ['agora', 'em_breve', 'depois'];

/** The bucket a thread starts life in. */
export const DEFAULT_BUCKET: ThreadBucket = 'em_breve';

/** Whether [value] names a bucket. */
export function isThreadBucket(value: unknown): value is ThreadBucket {
  return (
    typeof value === 'string' && THREAD_BUCKETS.includes(value as ThreadBucket)
  );
}

/** A thread, with every message across every day it spans. */
export class Thread {
  /** The folder name on disk, and the id the API addresses it by. */
  slug: string;
  title: string;
  messages: Message[];
  /** Whether the user considers this thread closed. */
  solved: boolean;
  /** Which of the home screen's lists it sits in. */
  bucket: ThreadBucket;
  /** Its place inside that list, ascending. */
  order: number;
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
  bucket: ThreadBucket;
  order: number;
  createdAt: Date;
  updatedAt: Date;
}

/** What is stored about a thread beyond its messages. */
export interface ThreadState {
  solved: boolean;
  /** Set when the user or the agent renamed the thread. */
  title?: string;
  /** Set once the thread has been placed; absent means [DEFAULT_BUCKET]. */
  bucket?: ThreadBucket;
  /**
   * Set once the thread has been dragged.
   *
   * A thread that has never moved falls back to when it was created, so the
   * list an untouched account shows is oldest-first rather than arbitrary.
   */
  order?: number;
}
