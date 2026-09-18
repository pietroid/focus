import express, { Request, Response } from 'express';
import { agentExecuteTool, agentReply, fallbackReply } from './reply.js';
import { ToolCall } from './a2ui/types.js';

export interface ServerConfig {
  dataDir: string;
}

interface ReplyBody {
  userId?: string;
  slug?: string;
  message?: string;
}

interface ExecuteToolBody {
  userId?: string;
  slug?: string;
  toolCall?: ToolCall;
}

export function createServer(config: ServerConfig): express.Express {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req: Request, res: Response) => {
    res.json({ status: 'ok' });
  });

  app.post('/reply', async (req: Request, res: Response) => {
    const { userId, slug, message } = req.body as ReplyBody;

    if (!userId || typeof userId !== 'string') {
      res.status(400).json({ error: 'userId is required' });
      return;
    }
    if (!slug || typeof slug !== 'string') {
      res.status(400).json({ error: 'slug is required' });
      return;
    }
    if (message === undefined || typeof message !== 'string') {
      res.status(400).json({ error: 'message is required' });
      return;
    }

    const result = await agentReply({
      userId,
      slug,
      message,
      dataDir: config.dataDir,
    });

    res.json(result);
  });

  app.post('/execute-tool', async (req: Request, res: Response) => {
    const { userId, slug, toolCall } = req.body as ExecuteToolBody;

    if (!userId || typeof userId !== 'string') {
      res.status(400).json({ error: 'userId is required' });
      return;
    }
    if (!slug || typeof slug !== 'string') {
      res.status(400).json({ error: 'slug is required' });
      return;
    }
    if (toolCall === null || typeof toolCall !== 'object') {
      res.status(400).json({ error: 'toolCall is required' });
      return;
    }
    if (
      typeof toolCall.id !== 'string' ||
      toolCall.type !== 'function' ||
      typeof toolCall.function?.name !== 'string' ||
      typeof toolCall.function?.arguments !== 'string'
    ) {
      res.status(400).json({ error: 'toolCall is malformed' });
      return;
    }

    const result = await agentExecuteTool({
      userId,
      slug,
      toolCall,
      dataDir: config.dataDir,
    });

    res.json(result);
  });

  return app;
}

/** Health-check response helper for tests. */
export { fallbackReply };
