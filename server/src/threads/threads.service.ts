import { Injectable, NotFoundException } from '@nestjs/common';
import { A2uiValidationService } from './a2ui-validation.service';
import { AgentService, AgentReplyPayload } from './agent.service';
import {
  A2uiComponent,
  Message,
  MessageMetadata,
  ToolCall,
} from './entities/message.entity';
import { Thread, ThreadSummary } from './entities/thread.entity';
import { messageId, slugify, titleFrom } from './thread-markdown';
import { ThreadsStore } from './threads.store';

@Injectable()
export class ThreadsService {
  constructor(
    private readonly store: ThreadsStore,
    private readonly agent: AgentService,
    private readonly validator: A2uiValidationService,
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

    console.log('[threads.create] starting thread', { userId, slug, title });
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

    console.log('[threads.addMessage] appending message', { userId, slug, textLength: text.length });
    await this._exchange(userId, slug, thread.title, text);

    return this.findOne(userId, slug);
  }

  /** Confirms or rejects a pending tool call. */
  async confirmTool(
    userId: string,
    slug: string,
    toolCallId: string,
    confirmed: boolean,
    argumentOverride?: Record<string, unknown>,
  ): Promise<Thread> {
    console.log('[threads.confirmTool] start', { userId, slug, toolCallId, confirmed, hasArgumentOverride: argumentOverride !== undefined });
    const thread = await this.findOne(userId, slug);

    const pending = await this.store.findPendingToolCall(userId, slug, toolCallId);
    if (pending === null) {
      console.error('[threads.confirmTool] pending tool call not found', { userId, slug, toolCallId });
      throw new NotFoundException(`No pending tool call "${toolCallId}"`);
    }

    console.log('[threads.confirmTool] found pending tool call', { toolCallId, tool: pending.function.name });
    await this.store.removePendingToolCall(userId, slug, toolCallId);

    if (!confirmed) {
      await this.store.append(userId, slug, thread.title, [
        message(
          'system',
          JSON.stringify({
            a2ui: {
              component: 'Text',
              text: 'Action cancelled.',
            },
          }),
          new Date(),
          { contentType: 'a2ui' },
        ),
      ]);

      return this.findOne(userId, slug);
    }

    const toolCall: ToolCall =
      argumentOverride !== undefined
        ? {
            ...pending,
            function: {
              ...pending.function,
              arguments: JSON.stringify(argumentOverride),
            },
          }
        : pending;

    console.log('[threads.confirmTool] executing tool via agent', { toolCallId, tool: toolCall.function.name, arguments: toolCall.function.arguments });
    const payload = await this.agent.executeTool({
      userId,
      slug,
      toolCall,
    });
    console.log('[threads.confirmTool] agent executeTool result', { toolCallId, model: payload.metadata.model, hasA2ui: payload.a2ui !== undefined });

    await this._appendAgentReply(userId, slug, thread.title, payload);

    return this.findOne(userId, slug);
  }

  /** Writes the user's message, asks the agent, then writes the answer. */
  private async _exchange(
    userId: string,
    slug: string,
    title: string,
    text: string,
  ): Promise<void> {
    console.log('[threads._exchange] asking agent', { userId, slug, textLength: text.length });
    const prompt = message('user', text, new Date());
    await this.store.append(userId, slug, title, [prompt]);

    const answer = await this.agent.reply({ userId, slug, message: text });
    console.log('[threads._exchange] agent replied', { userId, slug, model: answer.metadata.model, hasPendingToolCall: answer.pendingToolCall !== undefined });

    await this._appendAgentReply(userId, slug, title, answer);
  }

  private async _appendAgentReply(
    userId: string,
    slug: string,
    title: string,
    payload: AgentReplyPayload,
  ): Promise<void> {
    console.log('[threads._appendAgentReply] validating agent payload', {
      userId,
      slug,
      model: payload.metadata.model,
      hasPendingToolCall: payload.pendingToolCall !== undefined,
    });

    const validated = this.validator.validate({ a2ui: payload.a2ui });
    let component = validated.component;

    const metadata: MessageMetadata = {
      contentType: 'a2ui',
      model: payload.metadata.model,
      latencyMs: payload.metadata.latencyMs,
      a2ui: component,
    };

    if (payload.pendingToolCall !== undefined) {
      metadata.pendingToolCall = payload.pendingToolCall;
      component = this._injectToolCallId(component, payload.pendingToolCall.id);
      metadata.a2ui = component;
      console.log('[threads._appendAgentReply] injected _toolCallId into confirmation UI', {
        toolCallId: payload.pendingToolCall.id,
        tool: payload.pendingToolCall.function.name,
      });
    }

    await this.store.append(userId, slug, title, [
      message(
        'agent',
        JSON.stringify({ a2ui: component }),
        new Date(),
        metadata,
      ),
    ]);
  }

  private _injectToolCallId(
    component: A2uiComponent,
    toolCallId: string,
  ): A2uiComponent {
    const action = component.action as
      | { type: string; requiresConfirmation?: boolean; _toolCallId?: string }
      | undefined;
    if (
      action?.type === 'tool' &&
      action.requiresConfirmation === true &&
      action._toolCallId === undefined
    ) {
      console.log('[threads._injectToolCallId] injecting _toolCallId into confirmation action', {
        component: component.component,
        tool: action,
        toolCallId,
      });
      return {
        ...component,
        action: { ...action, _toolCallId: toolCallId },
      };
    }

    if (Array.isArray(component.children)) {
      return {
        ...component,
        children: component.children.map((child) =>
          this._injectToolCallId(child as A2uiComponent, toolCallId),
        ),
      };
    }

    return component;
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
  metadata?: MessageMetadata,
): Message {
  return {
    id: messageId(role, createdAt),
    role,
    text,
    createdAt,
    metadata,
  };
}
