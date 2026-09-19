import { createServer } from './server.js';
import { toolRegistry } from './generate.js';

const port = parseInt(process.env.PORT ?? '3001', 10);

createServer().listen(port, () => {
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      level: 'info',
      svc: 'agent',
      event: 'listening',
      port,
      tools: toolRegistry().names,
      model: process.env.OPENROUTER_MODEL ?? 'openai/gpt-4o-mini',
    }),
  );
});
