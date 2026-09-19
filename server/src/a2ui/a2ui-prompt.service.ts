import { Injectable } from '@nestjs/common';
import { ToolDescriptor } from '../threads/agent.service';
import { Message } from '../threads/entities/message.entity';
import { buildActionPrompt, buildCatalogPrompt } from './a2ui.catalog';
import { A2uiComponent } from './a2ui.types';

/** One message in the OpenRouter format the agent forwards. */
export interface PromptMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

/** What the prompt is built from. */
export interface PromptInput {
  /** The thread so far, oldest first, not including [userMessage]. */
  history: Message[];
  /** The message being answered. Empty when composing after a tool ran. */
  userMessage: string;
  /** The tools the agent reported, so the prompt matches what can actually run. */
  tools: ToolDescriptor[];
  /** Appended verbatim as a final system note, for post-tool composition. */
  note?: string;
}

/** How the assistant is told to behave, before anything about format. */
const PERSONA = `You are Focus, the user's personal productivity assistant.

Your job is to close open loops. Be concrete, be brief, and prefer doing over
explaining. When the user mentions a task, a meeting, a deadline or anything
with a time attached, put it on their calendar rather than describing how they
could.

Act in the turn you are asked. If you have everything a tool needs, call it now
and then say what you did. Do not ask "posso agendar?" and do not offer a
button that only means yes: there is no approval step, so a question like that
just costs the user a turn. Buttons are for a choice you cannot make for them,
such as which of three free slots to take.

Never say something is done unless a tool actually ran in this turn and came
back ok. If a tool failed, or you never called one, say that instead. Claiming
an event was created when nothing was called is the worst thing you can do
here.

Interpret "today", "tomorrow" and "next Monday" against the current time given
below, and always pass absolute ISO 8601 date-times to tools.

Write in Brazilian Portuguese. That is the default for this product and you
stay in it even when a tool answers in English. Switch languages only if the
user writes to you in another one, and go back to Portuguese as soon as they
do.`;

/** The rules that keep machine detail out of what the user reads. */
const HYGIENE = `## What the user must never see

The user reads only what is inside your Text, Badge and ListItem strings. That
text is a person talking to a person. It must never contain:

- JSON, braces, brackets, or anything that looks like a payload
- tool names (calendar_create_event), function names, ids, or argument dumps
- the words "tool", "function call", "API", "schema", "A2UI", or "component"
- apologies for being a language model, or descriptions of your own process
- markdown fences, backticks, asterisks, or heading marks

Say "dei uma olhada na sua agenda", never "rodei calendar_check_availability".
Say "quinta às 10 está livre", never a list of busy intervals in ISO format.
If a tool failed, say plainly what did not work and what you need, in one line.`;

/** How to use the catalog well, rather than merely legally. */
const STYLE = `## Composing a reply

Start with a Column. Lead with one short Text that answers the question, then
add structure only where it earns its place.

- Two or three sentences beat a paragraph. One idea per Text.
- Use ListItem for anything that is a list: options, results, steps. Give each
  one an icon and a colour that carries its meaning.
- Use Card to group one proposal or one result the user has to judge.
- Use Badge for a status word, not for a sentence.
- Offer at most one primary button. Everything else is secondary or tertiary.
- Colour is meaning, not decoration: success for done and available, warning
  for something needing attention, danger for destructive or blocked, info for
  neutral context, accent for the thing you want tapped.
- A reply with nothing to decide needs no buttons at all.`;

/**
 * Builds the prompt the agent runs.
 *
 * The server owns this end to end: the persona, the catalog, the hygiene rules
 * and the history. The agent adds only its tool schemas. One owner means the
 * prompt and the validator that judges its output are written against the same
 * catalog, and a change to the catalog reaches both at once.
 */
@Injectable()
export class A2uiPromptService {
  /** The full message list, system prompt first. */
  build(input: PromptInput): PromptMessage[] {
    const messages: PromptMessage[] = [
      { role: 'system', content: this._systemPrompt(input.tools) },
    ];

    for (const message of input.history) {
      const content = this._historyContent(message);
      if (content === '') continue;

      messages.push({
        role: message.role === 'user' ? 'user' : 'assistant',
        content,
      });
    }

    if (input.userMessage.trim() !== '') {
      messages.push({ role: 'user', content: input.userMessage });
    }

    if (input.note !== undefined && input.note !== '') {
      messages.push({ role: 'system', content: input.note });
    }

    return messages;
  }

  /**
   * Flattens a stored A2UI tree back into the sentence it was.
   *
   * History is replayed as prose rather than as the JSON it is stored in. The
   * model needs to remember what it said, not how it was laid out, and prose
   * costs a fraction of the tokens.
   */
  flattenToText(component: A2uiComponent): string {
    const parts: string[] = [];

    const walk = (node: A2uiComponent): void => {
      const text = node.text;
      const title = node.title;
      const subtitle = node.subtitle;

      if (typeof text === 'string' && text.trim() !== '') parts.push(text.trim());
      if (typeof title === 'string' && title.trim() !== '') parts.push(title.trim());
      if (typeof subtitle === 'string' && subtitle.trim() !== '') {
        parts.push(subtitle.trim());
      }

      for (const child of node.children ?? []) walk(child);
    };

    walk(component);
    return parts.join('\n');
  }

  private _systemPrompt(tools: ToolDescriptor[]): string {
    return [
      PERSONA,
      '',
      this._now(),
      '',
      this._toolsPrompt(tools),
      '',
      '# Reply format',
      '',
      'Reply with one JSON object and nothing else. No prose before it, no code',
      'fence around it. The object has exactly one key, "a2ui", whose value is a',
      'component tree built only from the catalog below.',
      '',
      buildCatalogPrompt(),
      buildActionPrompt(),
      '',
      HYGIENE,
      '',
      STYLE,
      '',
      this._example(),
    ].join('\n');
  }

  /**
   * Today, spelled out.
   *
   * A bare ISO timestamp was not enough: models were answering "amanhã" with
   * dates a year and a half in the past. Naming the two dates it will actually
   * need leaves nothing to arithmetic.
   */
  private _now(): string {
    const timeZone = process.env.TZ ?? 'UTC';
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const day = (date: Date): string =>
      date.toLocaleDateString('en-CA', { timeZone });

    return [
      `Current time: ${now.toISOString()} (timezone ${timeZone})`,
      `Today is ${day(now)}. Tomorrow is ${day(tomorrow)}.`,
      'Every date you send to a tool starts with one of those two unless the',
      'user named another one. A date in a different year is always a mistake.',
    ].join('\n');
  }

  private _toolsPrompt(tools: ToolDescriptor[]): string {
    if (tools.length === 0) {
      return '# Tools\n\nNo tools are available right now. Answer from what you know.';
    }

    return [
      '# Tools',
      '',
      'Call these directly. Never describe a call in your reply text.',
      '',
      ...tools.map((tool) => `- ${tool.name}: ${tool.description}`),
      '',
      'They all run immediately, so do not ask "quer que eu faça?" first: do it ' +
        'and then say what you did, in one short sentence. Prefer the tool ' +
        'built for the job over api_call, which is a last resort for a service ' +
        'nothing else covers.',
    ].join('\n');
  }

  private _example(): string {
    const example = {
      a2ui: {
        component: 'Column',
        gap: 'normal',
        children: [
          {
            component: 'Text',
            text: 'Quinta está livre depois do almoço. Dois horários servem:',
            variant: 'body',
          },
          {
            component: 'Card',
            color: 'success',
            children: [
              {
                component: 'ListItem',
                icon: 'clock',
                color: 'success',
                title: '14:00 - 15:00',
                subtitle: 'Nada antes nem depois',
                action: {
                  type: 'reply',
                  text: 'Agendar reunião quinta, 14:00 às 15:00',
                },
              },
              {
                component: 'ListItem',
                icon: 'clock',
                color: 'info',
                title: '16:30 - 17:30',
                subtitle: 'Logo depois da sua review',
                action: {
                  type: 'reply',
                  text: 'Agendar reunião quinta, 16:30 às 17:30',
                },
              },
            ],
          },
          {
            component: 'Row',
            gap: 'tight',
            children: [
              {
                component: 'AppButton',
                text: 'Ver outro dia',
                variant: 'tertiary',
                action: { type: 'reply', text: 'Me mostra a sexta' },
              },
            ],
          },
        ],
      },
    };

    return `## Example\n\n${JSON.stringify(example)}`;
  }

  private _historyContent(message: Message): string {
    if (message.role === 'user') return message.text.trim();

    const tree = message.metadata?.a2ui;
    if (tree !== undefined) {
      return this.flattenToText(tree as A2uiComponent).trim();
    }

    return message.text.trim();
  }
}
