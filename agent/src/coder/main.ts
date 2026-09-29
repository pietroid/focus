import { execFileSync, spawn } from 'node:child_process';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { GitHubReader } from './github.js';
import { CoderTask, coderRules, fixPrompt, taskPrompt } from './prompt.js';
import { Answer, forbiddenPaths, parseAnswer, tail } from './result.js';

/**
 * The coder's entry point. It runs inside the focus-coder container on the
 * Raspberry Pi (agent/coder/Dockerfile), started by agent/coder/host/focus-coder.
 *
 * It reads the issue (or the PR feedback) from GitHub, hands it to pi in the
 * checkout mounted at /workspace, gates pi's work on make check-server and
 * make check-agent, and writes to /out:
 *   result.json      what happened, for the workflow
 *   changes.patch    the diff against the commit the run started from
 *   commit-message   the message the host commits with, when there are changes
 *   transcript.html  pi's whole session, for a human to read
 *   pi-*.log         pi's printed output per round
 * It pushes nothing and posts nothing. The host script (focus-coder) commits
 * and pushes after this process exits, with a key this container never sees.
 *
 * Environment:
 *   CODER_MODE         issue | feedback
 *   CODER_ISSUE        the issue number (optional in feedback mode)
 *   CODER_PR           the pull request number (feedback mode)
 *   CODER_CONTINUING   "true" when the issue's branch already existed
 *   CODER_MODEL        pi model id, default openrouter/anthropic/claude-sonnet-5
 *   CODER_MINUTES      wall-clock budget for pi, default 40
 *   CODER_PROMPT_FILE  run on this prompt instead of a GitHub thread (local tries)
 *   OPENROUTER_API_KEY, GITHUB_REPOSITORY, optional GITHUB_TOKEN (read-only)
 */
const WORKSPACE = process.env.CODER_WORKSPACE ?? '/workspace';
const OUT = process.env.CODER_OUT ?? '/out';
const ANSWER = path.join(OUT, 'answer.json');
const SESSIONS = path.join(OUT, 'session');
const FIX_ROUNDS = 2;

async function main(): Promise<void> {
  const env = (key: string, fallback?: string): string => {
    const value = process.env[key] ?? fallback;
    if (value === undefined || value === '') throw new Error(`${key} is not set.`);
    return value;
  };

  await fs.mkdir(OUT, { recursive: true });
  const promptFile = process.env.CODER_PROMPT_FILE;
  const prompt = promptFile
    ? await fs.readFile(promptFile, 'utf8')
    : taskPrompt(
        await readTask(
          new GitHubReader(env('GITHUB_REPOSITORY'), process.env.GITHUB_TOKEN || undefined),
          env('CODER_MODE'),
        ),
      );
  const base = git(['rev-parse', 'HEAD']).trim();
  const model = env('CODER_MODEL', 'openrouter/anthropic/claude-sonnet-5');
  const deadline = Date.now() + Number(process.env.CODER_MINUTES ?? 40) * 60 * 1000;

  await fs.writeFile(path.join(OUT, 'rules.md'), coderRules(ANSWER), 'utf8');
  await fs.writeFile(path.join(OUT, 'prompt.md'), prompt, 'utf8');

  let round = 1;
  let piOutput = await runPi(model, ['@' + path.join(OUT, 'prompt.md')], round, deadline);
  let answer = await readAnswer(piOutput);

  // pi says it is done; the gate decides. A failing gate goes back to pi in
  // the same session, twice at most, before the run is published as a draft.
  let checks: { ok: boolean; output: string } | undefined;
  while (answer?.kind === 'changes') {
    checks = await runChecks();
    if (checks.ok || round > FIX_ROUNDS || Date.now() > deadline) break;
    round++;
    await fs.rm(ANSWER, { force: true });
    piOutput = await runPi(model, ['--continue', fixPrompt(checks.output, ANSWER)], round, deadline);
    answer = (await readAnswer(piOutput)) ?? answer;
  }

  const result = await describe(answer, base, checks);
  await fs.writeFile(path.join(OUT, 'result.json'), JSON.stringify(result, null, 2), 'utf8');
  await exportTranscript();
  console.log(JSON.stringify({ event: 'coder.done', kind: result.kind, checksPassed: result.checksPassed }));
}

async function readTask(github: GitHubReader, mode: string): Promise<CoderTask> {
  const issueNumber = process.env.CODER_ISSUE ? Number(process.env.CODER_ISSUE) : undefined;
  if (mode === 'feedback') {
    const pull = await github.thread(Number(process.env.CODER_PR));
    const issue = issueNumber ? await github.thread(issueNumber) : undefined;
    return { kind: 'feedback', pull, issue };
  }
  if (issueNumber === undefined) throw new Error('CODER_ISSUE is not set.');
  return {
    kind: 'issue',
    issue: await github.thread(issueNumber),
    continuing: process.env.CODER_CONTINUING === 'true',
  };
}

/** One pi round, printed mode, in the run's own session directory. */
function runPi(model: string, args: string[], round: number, deadline: number): Promise<string> {
  const argv = [
    '--print',
    '--model',
    model,
    // A branch the agent wrote must not be able to load its own pi config.
    '--no-approve',
    '--session-dir',
    SESSIONS,
    '--append-system-prompt',
    path.join(OUT, 'rules.md'),
    ...args,
  ];
  const timeoutMs = Math.max(60_000, deadline - Date.now());
  return new Promise((resolve) => {
    // stdin closed: pi reads piped stdin into the prompt and would wait on it.
    const child = spawn('pi', argv, { cwd: WORKSPACE, env: process.env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    child.stdout.on('data', (chunk: Buffer) => {
      stdout += chunk.toString();
      process.stdout.write(chunk);
    });
    child.stderr.on('data', (chunk: Buffer) => process.stderr.write(chunk));
    const timer = setTimeout(() => child.kill('SIGTERM'), timeoutMs);
    child.on('close', (code) => {
      clearTimeout(timer);
      console.log(JSON.stringify({ event: 'coder.pi', round, exit: code }));
      void fs.writeFile(path.join(OUT, `pi-${round}.log`), stdout, 'utf8').then(() => resolve(stdout));
    });
  });
}

async function readAnswer(stdout: string): Promise<Answer | undefined> {
  const file = await fs.readFile(ANSWER, 'utf8').catch(() => undefined);
  return parseAnswer(file, stdout);
}

/**
 * The part of make check this machine can run. Flutter is not on the Pi,
 * so check-app runs in CI on the pull request instead. The model's key is
 * kept out of the checks' environment.
 */
async function runChecks(): Promise<{ ok: boolean; output: string }> {
  const env = { ...process.env };
  delete env.OPENROUTER_API_KEY;
  delete env.GITHUB_TOKEN;
  return new Promise((resolve) => {
    const child = spawn('make', ['check-server', 'check-agent'], { cwd: WORKSPACE, env, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', (chunk: Buffer) => (output += chunk.toString()));
    child.stderr.on('data', (chunk: Buffer) => (output += chunk.toString()));
    child.on('close', (code) => {
      console.log(JSON.stringify({ event: 'coder.gate', ok: code === 0 }));
      resolve({ ok: code === 0, output: tail(output.trim(), 150) });
    });
  });
}

/** What the publish job needs to know, whatever happened. */
async function describe(
  answer: Answer | undefined,
  base: string,
  checks: { ok: boolean; output: string } | undefined,
): Promise<Record<string, unknown>> {
  if (answer?.kind === 'question') return { kind: 'question', question: answer.question };

  git(['add', '-A']);
  const changed = git(['diff', '--cached', '--name-only', base])
    .split('\n')
    .filter((line) => line !== '');
  if (answer === undefined) {
    return { kind: 'gave_up', reason: 'pi ended without writing an answer.', changed: changed.length > 0 };
  }
  if (changed.length === 0) {
    return { kind: 'gave_up', reason: 'pi said it was done but changed no file.', changed: false };
  }
  const forbidden = forbiddenPaths(changed);
  if (forbidden.length > 0) {
    return { kind: 'gave_up', reason: `pi changed files it may not touch: ${forbidden.join(', ')}`, changed: true };
  }

  await fs.writeFile(path.join(OUT, 'changes.patch'), git(['diff', '--cached', '--binary', base]), 'utf8');
  await fs.writeFile(path.join(OUT, 'commit-message'), answer.commitMessage.trim() + '\n', 'utf8');
  return {
    kind: 'changes',
    title: answer.title,
    body: answer.body,
    commitMessage: answer.commitMessage,
    checksPassed: checks?.ok ?? false,
    checksOutput: checks?.ok ? '' : (checks?.output ?? ''),
  };
}

/** pi's session as one HTML page, for whoever wants to know why. */
async function exportTranscript(): Promise<void> {
  const files = await fs.readdir(SESSIONS, { recursive: true }).catch(() => [] as string[]);
  const sessions = files.filter((file) => file.endsWith('.jsonl'));
  const latest = sessions.sort().at(-1);
  if (latest === undefined) return;
  try {
    execFileSync('pi', ['--export', path.join(SESSIONS, latest), path.join(OUT, 'transcript.html')], {
      stdio: 'ignore',
    });
  } catch {
    // A missing transcript is not worth failing the run over.
  }
}

function git(args: string[]): string {
  return execFileSync('git', args, { cwd: WORKSPACE, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
