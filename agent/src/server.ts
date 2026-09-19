import express, { Request, Response } from 'express';
import {
  AgentUnavailableError,
  generate,
  toolRegistry,
} from './generate.js';
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
 * The agent's HTTP surface.
 *
 * Two routes, all private to the Docker network:
 *   - `GET  /tools`    what this agent can do, so the server never guesses
 *   - `POST /generate` run a prompt the server built, tools and all
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

  return app;
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
