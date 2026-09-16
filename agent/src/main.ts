import { createServer } from './server.js';

const port = parseInt(process.env.PORT ?? '3001', 10);
const dataDir = process.env.FOCUS_DATA_DIR ?? '/app/data/threads';

const app = createServer({ dataDir });

app.listen(port, () => {
  console.log(`Focus agent listening on port ${port}`);
  console.log(`Threads directory: ${dataDir}`);
});
