import { readThread, Thread } from '../thread-store.js';

/**
 * Builds the thread context used by the prompt assembler.
 */
export class ContextBuilderService {
  constructor(private readonly _dataDir: string) {}

  async build(userId: string, slug: string): Promise<Thread | null> {
    return readThread(this._dataDir, userId, slug);
  }
}
