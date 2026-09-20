// firebase-admin pulls an ESM-only dependency that Jest cannot require on
// Node 22. Nothing here verifies a token, so the module is stubbed and the
// guard it backs is overridden below.
jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));

import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { A2uiParserService } from '../a2ui/a2ui-parser.service';
import { A2uiPromptService } from '../a2ui/a2ui-prompt.service';
import { A2uiValidationService } from '../a2ui/a2ui-validation.service';
import { A2uiComponent } from '../a2ui/a2ui.types';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { CalendarSyncService } from '../calendar/calendar-sync.service';
import {
  CalendarWriteError,
  CalendarWriterService,
} from '../calendar/calendar-writer.service';
import { CalendarEvent } from '../calendar/calendar.types';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AgentService, GenerateResult, ToolDescriptor } from './agent.service';
import { ThreadSummary } from './entities/thread.entity';
import { ThreadsController } from './threads.controller';
import { SyncOutcome, ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';
import { TimelineService } from './timeline.service';
import { TimingService } from './timing.service';

class StubAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = {
      uid: 'test-user',
    };
    return true;
  }
}

/** An agent that answers with one sentence and never runs a tool. */
class StubAgentService {
  tools(): Promise<ToolDescriptor[]> {
    return Promise.resolve([]);
  }

  generate(): Promise<GenerateResult> {
    return Promise.resolve({
      raw: JSON.stringify({ a2ui: { component: 'Text', text: 'Ok' } }),
      toolTrace: [],
      model: 'stub',
      latencyMs: 0,
      iterations: 1,
    });
  }
}

/** A calendar that accepts everything and remembers what it was told. */
class StubCalendarWriter {
  created: { title: string; startTime: string; endTime: string }[] = [];
  moved: { id: string; startTime: string; endTime: string }[] = [];
  removed: string[] = [];

  private _next = 1;

  /** Set by a test that wants to see what a refused booking does. */
  failCreates = false;

  create(event: {
    title: string;
    startTime: string;
    endTime: string;
  }): Promise<CalendarEvent> {
    if (this.failCreates) {
      return Promise.reject(new CalendarWriteError('ECONNREFUSED'));
    }

    this.created.push(event);
    return Promise.resolve({ id: `ev-${this._next++}`, ...event });
  }

  /** Set by a test that wants to see what a refused rebooking does. */
  failMoves = false;

  move(
    eventId: string,
    when: { startTime: string; endTime: string },
  ): Promise<CalendarEvent> {
    if (this.failMoves) {
      return Promise.reject(new CalendarWriteError('ECONNREFUSED'));
    }

    this.moved.push({ id: eventId, ...when });
    return Promise.resolve({ id: eventId, title: 'moved', ...when });
  }

  remove(eventId: string): Promise<void> {
    this.removed.push(eventId);
    return Promise.resolve();
  }
}

interface Outcome {
  cards: ThreadSummary[];
  guard?: A2uiComponent;
}

function outcome(response: { body: unknown }): Outcome {
  return response.body as Outcome;
}

/** Every button in a guard, as the pair a test cares about. */
function buttons(
  guard: A2uiComponent | undefined,
): { text: string; action: Record<string, unknown> }[] {
  return (guard?.children ?? [])
    .filter((child) => child.component === 'AppButton')
    .map((child) => ({
      text: child.text as string,
      action: (child.action ?? {}) as unknown as Record<string, unknown>,
    }));
}

/** The first line of a guard, which is the question it is asking. */
function question(guard: A2uiComponent | undefined): string {
  const item = (guard?.children ?? []).find(
    (child) => child.component === 'ListItem',
  );
  return (item?.title as string) ?? '';
}

/**
 * The calendar, standing still.
 *
 * Overridden so no test reaches for the agent that is not running: the real
 * reader would spend every timeline on a connection refused and fall back to
 * the same empty list this returns outright.
 */
class StubCalendarReader {
  private _events: CalendarEvent[] = [];

  events(): Promise<CalendarEvent[]> {
    return Promise.resolve(this._events);
  }

  replace(events: CalendarEvent[]): Promise<void> {
    this._events = events;
    return Promise.resolve();
  }

  upsert(event: CalendarEvent): Promise<void> {
    this._events = [...this._events.filter((it) => it.id !== event.id), event];
    return Promise.resolve();
  }

  remove(eventId: string): Promise<void> {
    this._events = this._events.filter((it) => it.id !== eventId);
    return Promise.resolve();
  }
}

/** "14:30", so a test can say what it expects in the words the app uses. */
function hhmm(iso: string): string {
  const at = new Date(iso);
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`;
}

/** How many minutes apart two cards are, end to start. */
function gapBetween(first: ThreadSummary, second: ThreadSummary): number {
  return Math.round(
    (Date.parse(second.startTime) - Date.parse(first.endTime)) / 60_000,
  );
}

/**
 * The timeline, end to end.
 *
 * The clock these run against is the real one, so nothing here asserts an
 * absolute hour: the arithmetic that produces hours is covered by
 * `scheduling.spec.ts`, where the clock stands still. What is checked here is
 * what the routes do to each other — the order, the gaps, the calendar, and
 * the one question that is left.
 */
describe('the timeline', () => {
  let app: INestApplication<App>;
  let root: string;
  let calendar: StubCalendarWriter;
  let agenda: StubCalendarReader;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-timing-'));
    process.env.FOCUS_DATA_DIR = root;

    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [ThreadsController],
      providers: [
        ThreadsService,
        ThreadsStore,
        AgentService,
        A2uiPromptService,
        A2uiParserService,
        A2uiValidationService,
        TimelineService,
        TimingService,
        CalendarReaderService,
        CalendarSyncService,
        CalendarWriterService,
      ],
    })
      .overrideGuard(FirebaseAuthGuard)
      .useClass(StubAuthGuard)
      .overrideProvider(AgentService)
      .useClass(StubAgentService)
      .overrideProvider(CalendarWriterService)
      .useClass(StubCalendarWriter)
      .overrideProvider(CalendarReaderService)
      .useClass(StubCalendarReader)
      .compile();

    calendar = moduleRef.get(CalendarWriterService);
    agenda = moduleRef.get(CalendarReaderService);

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  /** Writes something down on the timeline, the way the sheet does. */
  function add(
    message: string,
    durationMinutes: number,
    extra: Record<string, unknown> = {},
  ) {
    return request(app.getHttpServer())
      .post('/threads/scheduled')
      .send({ message, durationMinutes, ...extra });
  }

  /** Drags a card to [index] in the day's one list. */
  function drag(slug: string, index: number) {
    return request(app.getHttpServer())
      .post(`/threads/${slug}/move`)
      .send({ index });
  }

  /** Answers a guard with one of its buttons. */
  function answer(action: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/threads/timing')
      .send({ action });
  }

  /** Waits for the calendar queue, the way the app does after a change. */
  async function sync(): Promise<SyncOutcome> {
    const response = await request(app.getHttpServer())
      .get('/threads/sync')
      .expect(200);

    return response.body as SyncOutcome;
  }

  async function timeline(): Promise<ThreadSummary[]> {
    const response = await request(app.getHttpServer())
      .get('/threads')
      .expect(200);

    return response.body as ThreadSummary[];
  }

  it('gives everything an hour the moment it is written down', async () => {
    const response = await add('Revisar proposta', 30).expect(201);
    const [card] = response.body as ThreadSummary[];

    expect(card.slug).toBe('revisar-proposta');
    expect(card.durationMinutes).toBe(30);
    expect(card.fixed).toBe(false);
    expect(hhmm(card.endTime)).not.toBe(hhmm(card.startTime));
    expect(card.section).toBe('agora');

    // The booking is made behind the response, so this waits for it the way
    // the app does rather than assuming it has already happened.
    await sync();
    expect(calendar.created).toHaveLength(1);
  });

  it('puts the next thing after the first, without moving it', async () => {
    const first = (
      (await add('Primeiro', 30).expect(201)).body as ThreadSummary[]
    )[0];

    const cards = (await add('Segundo', 45).expect(201))
      .body as ThreadSummary[];

    expect(cards.map((card) => card.slug)).toEqual(['primeiro', 'segundo']);
    expect(cards[0].startTime).toBe(first.startTime);
    expect(gapBetween(cards[0], cards[1])).toBeGreaterThanOrEqual(5);
  });

  it('keeps the hour a fixed block was given', async () => {
    await add('Primeiro', 60).expect(201);

    const at = new Date();
    at.setHours(at.getHours() + 3, 0, 0, 0);

    const cards = (
      await add('Reunião', 30, {
        fixed: true,
        startTime: at.toISOString(),
      }).expect(201)
    ).body as ThreadSummary[];

    const meeting = cards.find((card) => card.slug === 'reuniao');
    expect(meeting?.fixed).toBe(true);
    expect(hhmm(meeting!.startTime)).toBe(hhmm(at.toISOString()));
  });

  it('never moves a fixed block when the day is rearranged', async () => {
    const at = new Date();
    at.setHours(at.getHours() + 3, 0, 0, 0);

    await add('Reunião', 30, {
      fixed: true,
      startTime: at.toISOString(),
    }).expect(201);
    await add('Primeiro', 30).expect(201);
    await add('Segundo', 30).expect(201);

    await drag('segundo', 1).expect(201);

    const cards = await timeline();
    const meeting = cards.find((card) => card.slug === 'reuniao');
    expect(hhmm(meeting!.startTime)).toBe(hhmm(at.toISOString()));
  });

  it('asks what to do with what is running before starting something else', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);

    const response = await drag('outra-coisa', 0).expect(201);

    expect(question(outcome(response).guard)).toBe('Começar agora?');
    expect(buttons(outcome(response).guard).map((b) => b.text)).toEqual([
      'Concluir o atual',
      'Deixar para depois',
      'Cancelar',
    ]);
  });

  it('changes nothing while it is asking', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);

    const before = await timeline();
    await drag('outra-coisa', 0).expect(201);

    expect(await timeline()).toEqual(before);
  });

  it('closes the running thread and gives its hour back', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);

    const guard = outcome(await drag('outra-coisa', 0)).guard;
    const solve = buttons(guard).find((b) => b.text === 'Concluir o atual');
    await answer(solve!.action).expect(201);

    const cards = await timeline();
    expect(cards.map((card) => card.slug)).toEqual(['outra-coisa']);

    await sync();
    expect(calendar.removed).toHaveLength(1);
  });

  it('pushes the running thread down when told to keep it', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);

    const guard = outcome(await drag('outra-coisa', 0)).guard;
    const later = buttons(guard).find((b) => b.text === 'Deixar para depois');
    await answer(later!.action).expect(201);

    const cards = await timeline();
    expect(cards.map((card) => card.slug)).toEqual([
      'outra-coisa',
      'em-andamento',
    ]);
    expect(gapBetween(cards[0], cards[1])).toBeGreaterThanOrEqual(5);
  });

  it('rearranges without asking anything when nothing is displaced', async () => {
    await add('Primeiro', 30).expect(201);
    await add('Segundo', 30).expect(201);
    await add('Terceiro', 30).expect(201);

    const response = await drag('terceiro', 1).expect(201);

    expect(outcome(response).guard).toBeUndefined();
    expect(outcome(response).cards.map((card) => card.slug)).toEqual([
      'primeiro',
      'terceiro',
      'segundo',
    ]);
  });

  it('draws what is on the calendar beside the threads', async () => {
    const at = new Date();
    at.setHours(at.getHours() + 2, 0, 0, 0);
    const end = new Date(at.getTime() + 30 * 60_000);

    await agenda.replace([
      {
        id: 'ev-external',
        title: 'Daily',
        startTime: at.toISOString(),
        endTime: end.toISOString(),
      },
    ]);
    await add('Revisar proposta', 30).expect(201);

    const cards = await timeline();
    const event = cards.find((card) => card.slug === 'gcal-ev-external');
    expect(event?.kind).toBe('calendar');
    expect(event?.fixed).toBe(true);
  });

  it('schedules around a meeting it did not create', async () => {
    const at = new Date();
    at.setMinutes(at.getMinutes() + 10, 0, 0);
    const end = new Date(at.getTime() + 120 * 60_000);

    await agenda.replace([
      {
        id: 'ev-external',
        title: 'Workshop',
        startTime: at.toISOString(),
        endTime: end.toISOString(),
      },
    ]);

    const [card] = (await add('Revisar proposta', 60).expect(201))
      .body as ThreadSummary[];

    const scheduled = card.slug === 'revisar-proposta' ? card : undefined;
    const placed = scheduled ?? (await timeline())[1];
    expect(Date.parse(placed.startTime)).toBeGreaterThanOrEqual(end.getTime());
  });

  it('takes a solved thread out of the calendar', async () => {
    await add('Revisar proposta', 30).expect(201);

    await request(app.getHttpServer())
      .post('/threads/revisar-proposta/solved')
      .send({ solved: true })
      .expect(201);

    await sync();
    expect(calendar.removed).toHaveLength(1);
    expect(await timeline()).toEqual([]);
  });

  it('closes the day up over something that was solved', async () => {
    await add('Primeiro', 60).expect(201);
    await add('Segundo', 30).expect(201);
    const before = (await add('Terceiro', 30).expect(201))
      .body as ThreadSummary[];

    expect(before.map((card) => card.slug)).toEqual([
      'primeiro',
      'segundo',
      'terceiro',
    ]);

    await request(app.getHttpServer())
      .post('/threads/primeiro/solved')
      .send({ solved: true })
      .expect(201);

    const after = await timeline();

    // The hour the finished thing had is the hour the rest of the day moves
    // into: "Segundo" takes the top of the queue, and "Terceiro" follows it
    // up rather than sitting where it was.
    expect(after.map((card) => card.slug)).toEqual(['segundo', 'terceiro']);
    expect(Date.parse(after[0].startTime)).toBeLessThan(
      Date.parse(before[1].startTime),
    );
    expect(Date.parse(after[1].startTime)).toBeLessThan(
      Date.parse(before[2].startTime),
    );
    expect(gapBetween(after[0], after[1])).toBeGreaterThanOrEqual(5);
  });

  it('leaves a fixed block where it is when the day closes up', async () => {
    await add('Primeiro', 60).expect(201);

    const at = new Date();
    at.setHours(at.getHours() + 3, 0, 0, 0);
    await add('Reunião', 30, {
      fixed: true,
      startTime: at.toISOString(),
    }).expect(201);
    await add('Segundo', 30).expect(201);

    await request(app.getHttpServer())
      .post('/threads/primeiro/solved')
      .send({ solved: true })
      .expect(201);

    const meeting = (await timeline()).find((card) => card.slug === 'reuniao');

    expect(hhmm(meeting!.startTime)).toBe(hhmm(at.toISOString()));
  });

  it('stays solved when the calendar will not take the rearrangement', async () => {
    await add('Primeiro', 60).expect(201);
    await add('Segundo', 30).expect(201);

    calendar.failMoves = true;

    await request(app.getHttpServer())
      .post('/threads/primeiro/solved')
      .send({ solved: true })
      .expect(201);

    // The thread is done whether or not Google agrees. Springing the card
    // back onto the timeline over a failed rebooking would be arguing with
    // the user about something they already know.
    expect((await timeline()).map((card) => card.slug)).toEqual(['segundo']);
  });

  it('refuses a move without a place to move to', async () => {
    await add('Revisar proposta', 30).expect(201);

    await request(app.getHttpServer())
      .post('/threads/revisar-proposta/move')
      .send({})
      .expect(400);
  });

  it('writes it down even when the calendar will not take it', async () => {
    calendar.failCreates = true;

    const cards = (await add('Revisar proposta', 30).expect(201))
      .body as ThreadSummary[];

    // The drag does not wait for Google and does not answer for it. The day
    // is the user's; the booking is a copy of it that can be behind.
    expect(cards.map((card) => card.slug)).toEqual(['revisar-proposta']);
    expect(await timeline()).toHaveLength(1);
  });

  it('says so, once, when the calendar did not keep up', async () => {
    calendar.failCreates = true;
    await add('Revisar proposta', 30).expect(201);

    const failed = await sync();
    expect(failed.ok).toBe(false);
    expect(question(failed.guard)).toBe('Sua agenda não acompanhou');
    expect(buttons(failed.guard).map((b) => b.text)).toEqual([
      'Tentar de novo',
      'Agora não',
    ]);

    // Asking twice does not ask again: the popup is on screen by now, and a
    // second one behind it would be the same failure twice.
    expect((await sync()).ok).toBe(true);
  });

  it('pushes the day again when the retry is tapped', async () => {
    calendar.failCreates = true;
    await add('Revisar proposta', 30).expect(201);
    await sync();

    calendar.failCreates = false;

    const retried = await request(app.getHttpServer())
      .post('/threads/sync')
      .expect(201);

    expect((retried.body as SyncOutcome).ok).toBe(true);
    expect(calendar.created).toHaveLength(1);
    // The booking the thread never had is now on it, so the next change
    // moves that event rather than creating a second one.
    const [card] = await timeline();
    expect(card.startTime).toBe(calendar.created[0].startTime);
  });

  it('keeps the drop when the calendar refuses a move', async () => {
    await add('Primeiro', 30).expect(201);
    await add('Segundo', 30).expect(201);
    await sync();

    calendar.failMoves = true;

    // Index 1 rather than 0: dropping at the top is the one move that asks a
    // question first, and this is about the calendar refusing, not the guard.
    await request(app.getHttpServer())
      .post('/threads/primeiro/move')
      .send({ index: 1 })
      .expect(201);

    expect((await timeline()).map((card) => card.slug)).toEqual([
      'segundo',
      'primeiro',
    ]);
    expect((await sync()).ok).toBe(false);
  });

  it('refuses something written down with no length', async () => {
    await add('Revisar proposta', 0).expect(400);
  });
});
