/**
 * One-line JSON logging, keyed by trace id.
 *
 * Every turn carries a trace id minted by the server. Both processes log under
 * the same id, so one `grep <traceId>` across the two containers replays the
 * whole turn in order instead of leaving you to line up timestamps by eye.
 */

/** The fields every log line carries. */
export interface TraceFields {
  traceId: string;
  userId?: string;
  slug?: string;
}

/** A logger bound to one turn. */
export class Trace {
  constructor(private readonly _fields: TraceFields) {}

  /** The trace id this logger writes under. */
  get id(): string {
    return this._fields.traceId;
  }

  /** Records a normal step. */
  log(event: string, data: Record<string, unknown> = {}): void {
    this._write('info', event, data);
  }

  /** Records something that went wrong but did not stop the turn. */
  warn(event: string, data: Record<string, unknown> = {}): void {
    this._write('warn', event, data);
  }

  /** Records a failure. */
  error(event: string, data: Record<string, unknown> = {}): void {
    this._write('error', event, data);
  }

  /** Times [work] and logs how long it took, whether or not it threw. */
  async span<T>(
    event: string,
    data: Record<string, unknown>,
    work: () => Promise<T>,
  ): Promise<T> {
    const startedAt = Date.now();
    this.log(`${event}.start`, data);

    try {
      const result = await work();
      this.log(`${event}.ok`, { ...data, durationMs: Date.now() - startedAt });
      return result;
    } catch (error) {
      this.error(`${event}.fail`, {
        ...data,
        durationMs: Date.now() - startedAt,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  private _write(
    level: 'info' | 'warn' | 'error',
    event: string,
    data: Record<string, unknown>,
  ): void {
    const line = JSON.stringify({
      ts: new Date().toISOString(),
      level,
      svc: 'agent',
      event,
      ...this._fields,
      ...data,
    });

    if (level === 'error') {
      console.error(line);
      return;
    }
    console.log(line);
  }
}

/** A trace id, for the rare case the agent is called without one. */
export function newTraceId(): string {
  return `agt_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
