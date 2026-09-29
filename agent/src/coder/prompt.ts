import { IssueThread } from './github.js';

/** What the run is for: a fresh issue, or feedback on a PR it opened. */
export type CoderTask =
  | { kind: 'issue'; issue: IssueThread; continuing: boolean }
  | { kind: 'feedback'; issue: IssueThread | undefined; pull: IssueThread };

/**
 * The rules appended to pi's own system prompt.
 *
 * pi already reads AGENTS.md from the checkout, so this only says what is
 * particular to running unattended here: where the answer goes, what is off
 * limits, and what this machine cannot check.
 */
export function coderRules(answerPath: string): string {
  return `You are Focus's coding agent, running unattended in a container on a Raspberry Pi.
The repository is checked out in the current directory. Nobody will answer you during this run.

How you work:
- Read AGENTS.md first. It is the source of truth for the architecture and the house rules.
- Explore before you change anything. Make the smallest change that does the job, and match the surrounding code.
- Add or update tests next to the code you change.
- Check your work with \`make check-server\` and \`make check-agent\`. Flutter is not installed on this machine, so Dart
  cannot be analyzed or tested here. Be careful with Dart, and follow very_good_analysis and \`dart format\` style by hand.
  CI checks the app on the pull request.
- Every string a user reads is Brazilian Portuguese. Code, comments, commits and PR text are English.
- Never touch .github/, .git/, .secrets/ or any .env file. A change there is thrown away, and the run with it.
- Do not commit, push or open anything. Leave your changes in the working tree; the pipeline does the rest.

When you are done, write your answer as JSON to ${answerPath} and stop. Exactly one of:
  {"kind": "changes", "title": "<PR title, short, imperative>", "body": "<PR description: what someone can now do, what to look for in the E2E video, anything left out>", "commit_message": "<conventional commit message>"}
  {"kind": "question", "question": "<one question for the issue author, in the language of the issue>"}
Ask a question instead of guessing when the request is ambiguous or needs a decision that belongs to the author.`;
}

function renderThread(label: string, thread: IssueThread): string {
  const comments = thread.comments
    .map((comment) => `@${comment.author} (${comment.createdAt}):\n${comment.body}`)
    .join('\n\n');
  return `${label} #${thread.number}: ${thread.title}\n\n${thread.body}${
    comments ? `\n\nConversation, oldest first:\n\n${comments}` : ''
  }`;
}

export function taskPrompt(task: CoderTask): string {
  if (task.kind === 'issue') {
    const lead = task.continuing
      ? 'You worked on this issue before and your branch is checked out. The conversation has moved on since; do what it now asks.'
      : 'Implement this issue.';
    return `${lead}\n\n${renderThread('Issue', task.issue)}`;
  }

  const issue = task.issue ? `\n\nThe issue it came from:\n\n${renderThread('Issue', task.issue)}` : '';
  return `This is your pull request, checked out at its head. The latest comments are feedback on it. Change the code to address them.\n\n${renderThread('Pull request', task.pull)}${issue}`;
}

export function fixPrompt(checkOutput: string, answerPath: string): string {
  return `The pipeline ran make check-server and make check-agent after you finished, and they failed. Fix the failure, run the checks yourself until they pass, then write ${answerPath} again.\n\n${checkOutput}`;
}
