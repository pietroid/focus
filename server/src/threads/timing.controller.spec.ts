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
import { CalendarWriterService } from '../calendar/calendar-writer.service';
import { CalendarEvent } from '../calendar/calendar.types';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AgentService, GenerateResult, ToolDescriptor } from './agent.service';
import { ThreadSummary } from './entities/thread.entity';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
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

  create(event: {
    title: string;
    startTime: string;
    endTime: string;
  }): Promise<CalendarEvent> {
    this.created.push(event);
    return Promise.resolve({ id: `ev-${this._next++}`, ...event });
  }

  move(
    eventId: string,
    when: { startTime: string; endTime: string },
  ): Promise<CalendarEvent> {
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

describe('the guards', () => {
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

    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Revisar proposta' })
      .expect(201);
  });

  afterEach(async () => {
    await app.close();
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  /** Drags the one thread into [bucket]. */
  function drag(bucket: string) {
    return request(app.getHttpServer())
      .post('/threads/placements')
      .send({ placements: [{ slug: 'revisar-proposta', bucket, index: 0 }] });
  }

  /** Answers a guard with one of its buttons. */
  function answer(action: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/threads/timing')
      .send({ action });
  }

  it('asks how long it takes before letting anything into agora', async () => {
    const response = await drag('agora').expect(201);

    expect(question(outcome(response).guard)).toBe('Quanto tempo isso leva?');
    expect(buttons(outcome(response).guard).map((b) => b.text)).toEqual([
      '15 min',
      '30 min',
      '45 min',
      '1 h',
      '1h30',
      '2 h',
      'Cancelar',
    ]);
  });

  it('leaves the thread where it was while it is asking', async () => {
    await drag('agora').expect(201);

    const response = await request(app.getHttpServer())
      .get('/threads')
      .expect(200);

    expect((response.body as ThreadSummary[])[0]).toMatchObject({
      slug: 'revisar-proposta',
      bucket: 'em_breve',
    });
  });

  it('proposes a time once it knows the duration', async () => {
    const asked = await drag('em_breve').expect(201);
    expect(outcome(asked).guard).toBeUndefined();

    const withDuration = await drag('agora').expect(201);
    const duration = buttons(outcome(withDuration).guard).find(
      (b) => b.text === '45 min',
    );

    const proposed = await answer(duration!.action).expect(201);

    expect(question(outcome(proposed).guard)).toMatch(
      /^Reservar \d\d:\d\d-\d\d:\d\d\?$/,
    );
    expect(buttons(outcome(proposed).guard).map((b) => b.text)).toEqual([
      'Colocar na agenda',
      'Deixar sem horário',
      'Cancelar',
    ]);
  });

  it('keeps the duration and skips the calendar when told to', async () => {
    const asked = await drag('agora').expect(201);
    const proposed = await answer(
      buttons(outcome(asked).guard).find((b) => b.text === '30 min')!.action,
    ).expect(201);

    const done = await answer(
      buttons(outcome(proposed).guard).find(
        (b) => b.text === 'Deixar sem horário',
      )!.action,
    ).expect(201);

    expect(outcome(done).guard).toBeUndefined();
    expect(outcome(done).cards[0]).toMatchObject({
      slug: 'revisar-proposta',
      bucket: 'agora',
      durationMinutes: 30,
    });
    expect(outcome(done).cards[0].startTime).toBeUndefined();
    expect(calendar.created).toHaveLength(0);
  });

  it('books the proposed time when told to', async () => {
    const asked = await drag('agora').expect(201);
    const proposed = await answer(
      buttons(outcome(asked).guard).find((b) => b.text === '30 min')!.action,
    ).expect(201);

    const done = await answer(
      buttons(outcome(proposed).guard).find(
        (b) => b.text === 'Colocar na agenda',
      )!.action,
    ).expect(201);

    expect(outcome(done).guard).toBeUndefined();
    expect(calendar.created).toHaveLength(1);
    expect(calendar.created[0].title).toBe('Revisar proposta');

    const card = outcome(done).cards.find(
      (it) => it.slug === 'revisar-proposta',
    );
    expect(card?.startTime).toBeDefined();
    expect(card?.durationMinutes).toBe(30);
  });

  it('asks before taking a booked thread off the calendar', async () => {
    const asked = await drag('agora').expect(201);
    const proposed = await answer(
      buttons(outcome(asked).guard).find((b) => b.text === '30 min')!.action,
    ).expect(201);
    await answer(
      buttons(outcome(proposed).guard).find(
        (b) => b.text === 'Colocar na agenda',
      )!.action,
    ).expect(201);

    const parked = await drag('depois').expect(201);
    expect(question(outcome(parked).guard)).toBe('Tirar da agenda?');

    const done = await answer(
      buttons(outcome(parked).guard).find((b) => b.text === 'Tirar da agenda')!
        .action,
    ).expect(201);

    expect(calendar.removed).toEqual(['ev-1']);
    const card = outcome(done).cards.find(
      (it) => it.slug === 'revisar-proposta',
    );
    expect(card).toMatchObject({ bucket: 'depois', durationMinutes: 30 });
    expect(card?.startTime).toBeUndefined();
  });

  it('draws what is on the calendar beside the threads', async () => {
    const start = new Date(Date.now() + 30 * 60_000);
    const end = new Date(start.getTime() + 60 * 60_000);

    await agenda.replace([
      {
        id: 'ev-google',
        title: 'Daily',
        startTime: start.toISOString(),
        endTime: end.toISOString(),
      },
    ]);

    const response = await request(app.getHttpServer())
      .get('/threads')
      .expect(200);

    const cards = response.body as ThreadSummary[];
    const event = cards.find((it) => it.slug === 'gcal-ev-google');

    expect(event).toMatchObject({
      kind: 'calendar',
      title: 'Daily',
      durationMinutes: 60,
    });
    expect(cards.some((it) => it.kind === 'thread')).toBe(true);
  });

  it('proposes a slot after what is already on the calendar', async () => {
    const busyStart = new Date(Date.now() + 5 * 60_000);
    const busyEnd = new Date(busyStart.getTime() + 60 * 60_000);

    await agenda.replace([
      {
        id: 'ev-google',
        title: 'Daily',
        startTime: busyStart.toISOString(),
        endTime: busyEnd.toISOString(),
      },
    ]);

    // Into "Depois" first, so the move into "Em breve" is a bucket change and
    // reaches the guards at all.
    await drag('depois').expect(201);

    const asked = await drag('em_breve').expect(201);
    const proposed = await answer(
      buttons(outcome(asked).guard).find((b) => b.text === '30 min')!.action,
    ).expect(201);

    const scheduling = buttons(outcome(proposed).guard).find(
      (b) => b.text === 'Colocar na agenda',
    )!.action;

    // Five minutes of air after the meeting, and never on top of it.
    expect(
      new Date(scheduling.startTime as string).getTime(),
    ).toBeGreaterThanOrEqual(busyEnd.getTime() + 5 * 60_000 - 60_000);
  });

  it('never asks anything about a reorder', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Outra coisa' })
      .expect(201);

    const reordered = await request(app.getHttpServer())
      .post('/threads/placements')
      .send({
        placements: [
          { slug: 'outra-coisa', bucket: 'em_breve', index: 0 },
          { slug: 'revisar-proposta', bucket: 'em_breve', index: 1 },
        ],
      })
      .expect(201);

    expect(outcome(reordered).guard).toBeUndefined();
    expect(outcome(reordered).cards.map((it) => it.slug)).toEqual([
      'outra-coisa',
      'revisar-proposta',
    ]);
  });
});
