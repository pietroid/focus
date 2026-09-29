import assert from 'node:assert/strict';
import { test } from 'node:test';
import { taskPrompt } from './prompt.js';
import { forbiddenPaths, parseAnswer, tail } from './result.js';

test('the answer file wins over the printed output', () => {
  const file = JSON.stringify({ kind: 'question', question: 'Qual cor?' });
  const stdout = '{"kind":"changes","title":"t","body":"b","commit_message":"c"}';
  assert.deepEqual(parseAnswer(file, stdout), { kind: 'question', question: 'Qual cor?' });
});

test('without a file, the last JSON object in the output is the answer', () => {
  const stdout = [
    'I looked at {"not": "an answer"} first.',
    'Done: {"kind": "changes", "title": "Rename heading", "body": "It says {Meus projetos}", "commit_message": "feat: rename"}',
  ].join('\n');
  assert.deepEqual(parseAnswer(undefined, stdout), {
    kind: 'changes',
    title: 'Rename heading',
    body: 'It says {Meus projetos}',
    commitMessage: 'feat: rename',
  });
});

test('a malformed or incomplete answer is no answer', () => {
  assert.equal(parseAnswer('{"kind": "changes", "title": "t"}', 'no json here'), undefined);
  assert.equal(parseAnswer('not json', ''), undefined);
});

test('workflows, git, secrets and env files are off limits', () => {
  assert.deepEqual(
    forbiddenPaths([
      '.github/workflows/ci.yml',
      'app/lib/main.dart',
      'server/.env.production',
      'server/.env.example',
      '.secrets/key.json',
      'agent/src/coder/main.ts',
    ]),
    ['.github/workflows/ci.yml', 'server/.env.production', '.secrets/key.json'],
  );
});

test('tail keeps the end, where failures are', () => {
  assert.equal(tail('a\nb', 5), 'a\nb');
  assert.match(tail('1\n2\n3\n4', 2), /2 earlier lines cut\n3\n4$/);
});

test('the task names the issue and its conversation', () => {
  const prompt = taskPrompt({
    kind: 'issue',
    continuing: false,
    issue: {
      number: 7,
      title: 'Renomear Projetos',
      body: 'O título deve ser Meus projetos.',
      comments: [{ author: 'pietroid', body: 'Só o título.', createdAt: '2026-09-28T12:00:00Z' }],
    },
  });
  assert.match(prompt, /^Implement this issue\./);
  assert.match(prompt, /Issue #7: Renomear Projetos/);
  assert.match(prompt, /@pietroid .*:\nSó o título\./);
});
