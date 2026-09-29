/**
 * The little of the GitHub API the coder reads.
 *
 * Read-only on purpose. The coder runs on the Raspberry Pi with no GitHub
 * write credentials at all; posting comments and opening pull requests is
 * the publish job's work, on GitHub, after it has checked the patch. The
 * repository is public, so no token is needed; one only raises the rate
 * limit.
 */
export interface IssueThread {
  number: number;
  title: string;
  body: string;
  comments: ThreadComment[];
}

export interface ThreadComment {
  author: string;
  body: string;
  createdAt: string;
}

export class GitHubReader {
  constructor(
    private readonly _repository: string,
    private readonly _token?: string,
    private readonly _api = 'https://api.github.com',
  ) {}

  /** An issue or a pull request, with its conversation, oldest first. */
  async thread(number: number): Promise<IssueThread> {
    const issue = await this._get<{ number: number; title: string; body: string | null }>(
      `/repos/${this._repository}/issues/${number}`,
    );
    const comments = await this._get<
      Array<{ user: { login: string } | null; body: string | null; created_at: string }>
    >(`/repos/${this._repository}/issues/${number}/comments?per_page=100`);

    return {
      number: issue.number,
      title: issue.title,
      body: issue.body ?? '',
      comments: comments.map((comment) => ({
        author: comment.user?.login ?? 'unknown',
        body: comment.body ?? '',
        createdAt: comment.created_at,
      })),
    };
  }

  private async _get<T>(route: string): Promise<T> {
    const response = await fetch(`${this._api}${route}`, {
      headers: {
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        ...(this._token ? { Authorization: `Bearer ${this._token}` } : {}),
      },
    });
    if (!response.ok) {
      throw new Error(`GitHub ${route} answered ${response.status}`);
    }
    return (await response.json()) as T;
  }
}
