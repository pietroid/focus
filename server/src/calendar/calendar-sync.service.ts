import { Injectable } from '@nestjs/common';
import { Trace } from '../common/trace';

/** Why the calendar is not saying what the timeline says. */
export interface SyncFailure {
  /** The thread whose hour did not make it across. */
  slug: string;
  /** The raw error, for the trace. Never shown to anyone. */
  error: string;
}

/** One piece of work: push a thread's stored hour to Google. */
type SyncJob = () => Promise<void>;

/**
 * The calendar, kept up to date behind the user's back.
 *
 * The rule used to be that Google went first: nothing was stored until the
 * event existed, so the timeline could never point at an hour the calendar
 * did not have. It was correct and it felt broken. Every drag paid for a
 * round trip to Google before the card would settle, and a card that takes
 * half a second to land does not feel like a card, it feels like a form.
 *
 * So the order is inverted. The store is written first and answers the
 * request; the calendar catches up from here. What makes that safe is that
 * the jobs are not instructions but reconciliations: each one reads the
 * thread as it now stands and makes Google match it. Two drags of the same
 * card queue two jobs, and the second one sees the same final state as the
 * first, so there is no order to get wrong and nothing to undo.
 *
 * Jobs run one at a time per user, in the order they arrived, because two
 * reconciliations of the same thread at once could both decide to create the
 * event.
 *
 * When one fails the failure is kept rather than thrown: the request that
 * queued it has long since answered. The app asks for it on [settle], and
 * the user gets a popup and a retry.
 */
@Injectable()
export class CalendarSyncService {
  /** The tail of each user's queue. Awaiting it awaits everything before it. */
  private readonly _queues = new Map<string, Promise<void>>();

  /** The last failure since anyone asked, per user. */
  private readonly _failures = new Map<string, SyncFailure>();

  /** Everything that failed, kept so a retry has something to run again. */
  private readonly _pending = new Map<string, Map<string, SyncJob>>();

  /**
   * Queues [job] and returns at once.
   *
   * Nothing waits on the result here, which is the whole point: the caller
   * has a request to answer and the calendar is not on its critical path.
   */
  enqueue(userId: string, slug: string, job: SyncJob, trace: Trace): void {
    const previous = this._queues.get(userId) ?? Promise.resolve();

    const next = previous.then(async () => {
      try {
        await job();
        this._forget(userId, slug);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        trace.error('calendar.sync.fail', { slug, error: message });

        this._failures.set(userId, { slug, error: message });
        this._remember(userId, slug, job);
      }
    });

    this._queues.set(userId, next);
  }

  /**
   * Waits for the queue to empty and reports the first failure in it.
   *
   * The app calls this straight after a drag, off the path the finger is on.
   * It usually returns nothing a moment later and the user never learns that
   * any of this happened, which is the point.
   */
  async settle(userId: string): Promise<SyncFailure | undefined> {
    await (this._queues.get(userId) ?? Promise.resolve());

    const failure = this._failures.get(userId);
    this._failures.delete(userId);

    return failure;
  }

  /**
   * Runs everything that failed again, and says how it went.
   *
   * The jobs are the same closures that failed, and they read the thread
   * fresh, so a retry after three more drags pushes the day as it is now
   * rather than as it was when Google first refused.
   */
  async retry(userId: string, trace: Trace): Promise<SyncFailure | undefined> {
    const pending = [...(this._pending.get(userId)?.entries() ?? [])];
    trace.log('calendar.sync.retry', { jobs: pending.length });

    for (const [slug, job] of pending) {
      this.enqueue(userId, slug, job, trace);
    }

    return this.settle(userId);
  }

  /** Whether anything is still waiting to reach Google. */
  hasPending(userId: string): boolean {
    return (this._pending.get(userId)?.size ?? 0) > 0;
  }

  private _remember(userId: string, slug: string, job: SyncJob): void {
    const jobs = this._pending.get(userId) ?? new Map<string, SyncJob>();
    // One job per thread. An older failed reconciliation of the same thread
    // would only push the same state twice.
    jobs.set(slug, job);
    this._pending.set(userId, jobs);
  }

  private _forget(userId: string, slug: string): void {
    this._pending.get(userId)?.delete(slug);
  }
}
