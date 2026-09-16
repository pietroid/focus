import express, { Request, Response } from 'express';
import { agentReply } from './reply.js';
import { readThread } from './thread-store.js';

export interface ServerConfig {
  dataDir: string;
}

interface ReplyBody {
  userId?: string;
  slug?: string;
  message?: string;
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

    const thread = await readThread(config.dataDir, userId, slug);
    if (thread === null) {
      res.status(404).json({ error: `Thread "${slug}" not found` });
      return;
    }

    const text = await agentReply({ thread, newMessage: message });
    res.json({ text });
  });

  return app;
}
