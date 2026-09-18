import { ToolImplementation, UserContext } from './tool.interface.js';

interface SearchResult {
  title: string;
  link: string;
  snippet: string;
}

/**
 * Web search tool.
 *
 * Recommended providers (configure one):
 *   - Serper.dev (default): set WEB_SEARCH_API_KEY and optionally
 *     WEB_SEARCH_API_BASE_URL=https://google.serper.dev/search
 *   - Brave Search API: set WEB_SEARCH_API_KEY and
 *     WEB_SEARCH_API_BASE_URL=https://api.search.brave.com/res/v1/web/search
 *
 * If no API key is configured, the tool falls back to DuckDuckGo's HTML
 * results page. This is convenient for local development but can break if
 * DuckDuckGo changes their markup or blocks the request.
 */
export class WebSearchTool implements ToolImplementation {
  readonly name = 'web_search';
  readonly requiresConfirmation = false;

  async execute(
    args: Record<string, unknown>,
    _context: UserContext,
  ): Promise<unknown> {
    const query = String(args.query ?? '');
    if (query === '') {
      throw new Error('query is required');
    }

    const apiKey = process.env.WEB_SEARCH_API_KEY;
    const baseUrl = process.env.WEB_SEARCH_API_BASE_URL;

    if (apiKey !== undefined && apiKey !== '' && baseUrl !== undefined && baseUrl !== '') {
      return this._searchApi(query, baseUrl, apiKey);
    }

    return this._searchDuckDuckGo(query);
  }

  private async _searchApi(
    query: string,
    baseUrl: string,
    apiKey: string,
  ): Promise<unknown> {
    const isBrave = baseUrl.includes('brave.com');
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(isBrave
        ? { 'X-Subscription-Token': apiKey }
        : { 'X-API-KEY': apiKey }),
    };

    const url = isBrave
      ? `${baseUrl}?q=${encodeURIComponent(query)}&count=5`
      : baseUrl;

    const body = isBrave
      ? undefined
      : JSON.stringify({ q: query, num: 5 });

    const response = await fetch(url, {
      method: isBrave ? 'GET' : 'POST',
      headers,
      body,
    });

    if (!response.ok) {
      throw new Error(`Web search API failed: ${response.status}`);
    }

    const data = (await response.json()) as Record<string, unknown>;

    if (isBrave) {
      const web = (data.web ?? {}) as Record<string, unknown>;
      const braveResults = (web.results ?? []) as Array<{
        title?: string;
        url?: string;
        description?: string;
      }>;
      return {
        results: braveResults.map((item) => ({
          title: item.title ?? '',
          link: item.url ?? '',
          snippet: item.description ?? '',
        })),
      };
    }

    // Serper.dev format
    const organic = (data.organic ?? []) as Array<{
      title?: string;
      link?: string;
      snippet?: string;
    }>;
    return {
      results: organic.map((item) => ({
        title: item.title ?? '',
        link: item.link ?? '',
        snippet: item.snippet ?? '',
      })),
    };
  }

  private async _searchDuckDuckGo(query: string): Promise<unknown> {
    const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;

    const response = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new Error(`DuckDuckGo search failed: ${response.status}`);
    }

    const html = await response.text();
    const results = this._parseDuckDuckGoHtml(html);

    if (results.length === 0) {
      return {
        results: [
          {
            title: 'No web search results',
            link: '',
            snippet:
              'No API key is configured and DuckDuckGo returned no parseable results.',
          },
        ],
      };
    }

    return { results };
  }

  private _parseDuckDuckGoHtml(html: string): SearchResult[] {
    const results: SearchResult[] = [];

    // DuckDuckGo HTML results are in .result blocks.
    const resultBlocks = html.split('class="result results_links"');

    for (let i = 1; i < resultBlocks.length && results.length < 5; i++) {
      const block = resultBlocks[i];

      const titleMatch = /class="result__a"[^>]*>([\s\S]*?)<\/a>/.exec(block);
      const linkMatch = /class="result__a"[^>]*href="([^"]*)"/.exec(block);
      const snippetMatch =
        /class="result__snippet"[^>]*>([\s\S]*?)<\/a>/.exec(block);

      if (titleMatch && linkMatch) {
        results.push({
          title: this._stripHtml(titleMatch[1]),
          link: this._unescapeHtml(linkMatch[1]),
          snippet: snippetMatch
            ? this._stripHtml(snippetMatch[1])
            : '',
        });
      }
    }

    return results;
  }

  private _stripHtml(html: string): string {
    return html
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private _unescapeHtml(html: string): string {
    return html
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ');
  }
}
