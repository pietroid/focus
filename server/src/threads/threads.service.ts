import { Injectable, NotFoundException } from '@nestjs/common';
import { AgentService } from './agent.service';
import { Message } from './entities/message.entity';
import { Thread, ThreadSummary } from './entities/thread.entity';
import { messageId, slugify, titleFrom } from './thread-markdown';
import { ThreadsStore } from './threads.store';

@Injectable()
export class ThreadsService {
  constructor(
    private readonly store: ThreadsStore,
    private readonly agent: AgentService,
  ) {}

  async findAll(userId: string): Promise<ThreadSummary[]> {
    return this.store.readAllSummaries(userId);
  }

  async findOne(userId: string, slug: string): Promise<Thread> {
    const thread = await this.store.read(userId, slug);
    if (thread === null) throw new NotFoundException(`No thread "${slug}"`);
    return thread;
  }

  /**
   * Starts a thread from its first message and answers it.
   *
   * The slug comes from the message, so a thread's folder says what it is
   * without anything having to open it.
   */
  async create(userId: string, text: string): Promise<Thread> {
    const slug = await this._freeSlug(userId, slugify(text));
    const title = titleFrom(text);

    await this._exchange(userId, slug, title, text);

    return this.findOne(userId, slug);
  }

  /** Appends a message to an existing thread and answers it. */
  async addMessage(
    userId: string,
    slug: string,
    text: string,
  ): Promise<Thread> {
    const thread = await this.findOne(userId, slug);

    await this._exchange(userId, slug, thread.title, text);

    return this.findOne(userId, slug);
  }

  /** Writes the user's message and the agent's answer as one append. */
  private async _exchange(
    userId: string,
    slug: string,
    title: string,
    text: string,
  ): Promise<void> {
    const prompt = message('user', text, new Date());
    const answer = await this.agent.reply();

    await this.store.append(userId, slug, title, [
      prompt,
      message('agent', answer, new Date()),
    ]);
  }

  /**
   * The first slug not already taken, suffixed `-2`, `-3`, and so on.
   *
   * Two threads can genuinely start with the same sentence, and neither should
   * silently land in the other's folder.
   */
  private async _freeSlug(userId: string, base: string): Promise<string> {
    if (!(await this.store.exists(userId, base))) return base;

    for (let suffix = 2; suffix < 1000; suffix++) {
      const candidate = `${base}-${suffix}`;
      if (!(await this.store.exists(userId, candidate))) return candidate;
    }

    return `${base}-${Date.now()}`;
  }
}

function message(
  role: Message['role'],
  text: string,
  createdAt: Date,
): Message {
  return { id: messageId(role, createdAt), role, text, createdAt };
}
