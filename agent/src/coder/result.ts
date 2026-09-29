/** What pi wrote to the answer file, once checked. */
export type Answer =
  | { kind: 'changes'; title: string; body: string; commitMessage: string }
  | { kind: 'question'; question: string };

/**
 * Reads pi's answer: the answer file when it wrote one, otherwise the last
 * JSON object in its final message. Anything else is no answer.
 */
export function parseAnswer(file: string | undefined, stdout: string): Answer | undefined {
  const candidates = [file, ...jsonObjectsIn(stdout).reverse()].filter(
    (text): text is string => text !== undefined && text.trim() !== '',
  );
  for (const text of candidates) {
    try {
      const value = JSON.parse(text) as Record<string, unknown>;
      if (value.kind === 'question' && typeof value.question === 'string') {
        return { kind: 'question', question: value.question };
      }
      if (
        value.kind === 'changes' &&
        typeof value.title === 'string' &&
        typeof value.body === 'string' &&
        typeof value.commit_message === 'string'
      ) {
        return {
          kind: 'changes',
          title: value.title,
          body: value.body,
          commitMessage: value.commit_message,
        };
      }
    } catch {
      // Not this one.
    }
  }
  return undefined;
}

/** Top-level {...} spans in [text], outermost first, in order. */
function jsonObjectsIn(text: string): string[] {
  const found: string[] = [];
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;
  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === '"') inString = false;
      continue;
    }
    if (char === '"' && depth > 0) inString = true;
    else if (char === '{') {
      if (depth === 0) start = index;
      depth++;
    } else if (char === '}' && depth > 0) {
      depth--;
      if (depth === 0) found.push(text.slice(start, index + 1));
    }
  }
  return found;
}

/**
 * The paths in a change that no agent may touch. The publish job checks the
 * same list again before it pushes; this copy fails the run early, with a
 * reason, instead of at the last step.
 */
export function forbiddenPaths(paths: string[]): string[] {
  return paths.filter((file) => {
    const parts = file.split('/');
    const base = parts[parts.length - 1] ?? '';
    return (
      parts[0] === '.github' ||
      parts.includes('.git') ||
      parts.includes('.secrets') ||
      (base.startsWith('.env') && !base.endsWith('.example'))
    );
  });
}

/** The last [lines] lines of [text]. Check failures are at the end. */
export function tail(text: string, lines: number): string {
  const all = text.split('\n');
  if (all.length <= lines) return text;
  return `… ${all.length - lines} earlier lines cut\n${all.slice(-lines).join('\n')}`;
}
