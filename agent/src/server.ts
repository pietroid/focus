import express, { Request, Response } from 'express';
import {
  AgentUnavailableError,
  generate,
  toolRegistry,
} from './generate.js';
import {
  CalendarUser,
  deleteEvent,
  insertEvent,
  calendarTimeZoneFor,
  listEventsBetween,
  patchEvent,
} from './services/google-calendar.js';
import { Trace, newTraceId } from './trace.js';
import { OpenRouterMessage, UserContext } from './types.js';

/** Header the server uses to hand its trace id to the agent. */
const TRACE_HEADER = 'x-focus-trace-id';

interface GenerateBody {
  userId?: string;
  slug?: string;
  messages?: OpenRouterMessage[];
  /** Absent means no. A write needs the server to say yes out loud. */
  allowWrites?: boolean;
}

/**
 * The agent's HTTP surface, all private to the Docker network.
 *
 *   - `GET  /tools`            what this agent can do, so the server never guesses
 *   - `POST /generate`         run a prompt the server built, tools and all
 *   - `GET  /calendar/window`  what is on the calendar between two moments
 *   - `/calendar/events`       book, move and cancel
 *
 * The calendar routes exist because the credentials live here and nowhere
 * else. They run no prompt and cost no generation: the server's guards do the
 * arithmetic and call these to make it true.
 *
 * Every calendar route names the person it is for. One Google account holds
 * the whole ecosystem and each person has a calendar of their own inside it,
 * so a call with no user is a call that cannot be answered rather than one
 * that quietly reads everybody's day at once.
 *
 * Every call arrives from the server. The agent never calls out to it, has no
 * idea where it is, and holds no key for it: the one direction is what keeps
 * this a service the server uses rather than two processes with opinions
 * about each other.
 *
 * The agent has no opinion about UI and no access to the thread files. Every
 * byte of context arrives in the request.
 */
export function createServer(): express.Express {
  const app = express();
  app.use(express.json({ limit: '2mb' }));

  app.get('/health', (_req: Request, res: Response) => {
    res.json({ status: 'ok', tools: toolRegistry().names });
  });

  app.get('/tools', (_req: Request, res: Response) => {
    res.json({ tools: toolRegistry().describe() });
  });

  app.post('/generate', async (req: Request, res: Response) => {
    const trace = traceFrom(req);
    const body = req.body as GenerateBody;
    const context = readContext(body, trace);

    if (context === null) {
      res.status(400).json({ error: 'userId and slug are required' });
      return;
    }
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      res.status(400).json({ error: 'messages must be a non-empty array' });
      return;
    }

    try {
      const result = await generate({
        context,
        messages: body.messages,
        allowWrites: body.allowWrites === true,
        trace,
      });
      res.json(result);
    } catch (error) {
      respondWithFailure(res, trace, error);
    }
  });

  app.get('/calendar/window', async (req: Request, res: Response) => {
    const from = new Date(String(req.query.from ?? ''));
    const to = new Date(String(req.query.to ?? ''));
    const user = userFromQuery(req);

    if (user === null) {
      res.status(400).json({ error: 'userId is required' });
      return;
    }
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      res.status(400).json({ error: 'from and to must be ISO 8601 date-times' });
      return;
    }

    try {
      // The zone travels with the events. The server's arithmetic about when
      // a working day starts and ends is only right if it is done in the
      // calendar's zone, and this is the one answer that already knows it.
      res.json({
        events: await listEventsBetween(user, from, to),
        timeZone: await calendarTimeZoneFor(user),
      });
    } catch (error) {
      res.status(502).json({ error: messageOf(error) });
    }
  });

  app.post('/calendar/events', async (req: Request, res: Response) => {
    const body = req.body as EventBody;
    const user = userFromBody(body);

    if (user === null) {
      res.status(400).json({ error: 'userId is required' });
      return;
    }
    if (
      typeof body.title !== 'string' ||
      typeof body.startTime !== 'string' ||
      typeof body.endTime !== 'string'
    ) {
      res.status(400).json({ error: 'title, startTime and endTime are required' });
      return;
    }

    try {
      res.json(
        await insertEvent(user, {
          title: body.title,
          startTime: body.startTime,
          endTime: body.endTime,
          fixed: body.fixed === true,
          threadSlug: body.threadSlug,
        }),
      );
    } catch (error) {
      res.status(502).json({ error: messageOf(error) });
    }
  });

  app.patch('/calendar/events/:id', async (req: Request, res: Response) => {
    const body = req.body as EventBody;
    const user = userFromBody(body);

    if (user === null) {
      res.status(400).json({ error: 'userId is required' });
      return;
    }

    try {
      res.json(
        await patchEvent(user, eventId(req), {
          title: body.title,
          startTime: body.startTime,
          endTime: body.endTime,
          fixed: body.fixed,
          threadSlug: body.threadSlug,
        }),
      );
    } catch (error) {
      res.status(502).json({ error: messageOf(error) });
    }
  });

  app.delete('/calendar/events/:id', async (req: Request, res: Response) => {
    const user = userFromQuery(req);

    if (user === null) {
      res.status(400).json({ error: 'userId is required' });
      return;
    }

    try {
      const id = eventId(req);
      await deleteEvent(user, id);
      res.json({ id, deleted: true });
    } catch (error) {
      res.status(502).json({ error: messageOf(error) });
    }
  });

  return app;
}

/** What a create or a patch carries, beyond the person it is for. */
interface EventBody {
  userId?: string;
  userEmail?: string;
  userName?: string;
  title?: string;
  startTime?: string;
  endTime?: string;
  fixed?: boolean;
  threadSlug?: string;
}

/** The person a calendar write is for, or null when none was named. */
function userFromBody(body: EventBody): CalendarUser | null {
  if (typeof body.userId !== 'string' || body.userId === '') return null;
  return { id: body.userId, email: body.userEmail, name: body.userName };
}

/** The same, for the routes that carry it in the query string. */
function userFromQuery(req: Request): CalendarUser | null {
  const id = String(req.query.userId ?? '');
  if (id === '') return null;

  const email = String(req.query.userEmail ?? '');
  const name = String(req.query.userName ?? '');
  return {
    id,
    email: email === '' ? undefined : email,
    name: name === '' ? undefined : name,
  };
}

/** The `:id` segment, which Express types as possibly repeated. */
function eventId(req: Request): string {
  const raw = req.params.id;
  return Array.isArray(raw) ? (raw[0] ?? '') : raw;
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function traceFrom(req: Request): Trace {
  const header = req.header(TRACE_HEADER);
  const body = req.body as { userId?: string; slug?: string };

  return new Trace({
    traceId: header !== undefined && header !== '' ? header : newTraceId(),
    userId: body?.userId,
    slug: body?.slug,
  });
}

function readContext(
  body: { userId?: string; slug?: string },
  trace: Trace,
): UserContext | null {
  if (typeof body.userId !== 'string' || body.userId === '') return null;
  if (typeof body.slug !== 'string' || body.slug === '') return null;

  return { userId: body.userId, slug: body.slug, traceId: trace.id };
}

function respondWithFailure(res: Response, trace: Trace, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  trace.error('request.fail', { error: message });

  const status = error instanceof AgentUnavailableError ? 502 : 500;
  res.status(status).json({ error: message, traceId: trace.id });
}
