import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ApiCallTool } from './api-call.tool.js';

/**
 * An unconfigured integration has to fail.
 *
 * This tool used to answer with a stub object when no base URL was set. The
 * model read that as a success and told the user their event had been deleted
 * when nothing had been called at all, so the honest failure is worth a test.
 */
describe('ApiCallTool', () => {
  const context = { userId: 'u1', slug: 't', traceId: 't_test' };

  it('fails rather than faking a result when nothing is configured', async () => {
    delete process.env.API_INTEGRATION_API_KEY;
    delete process.env.API_INTEGRATION_BASE_URL;

    await assert.rejects(
      () =>
        new ApiCallTool().execute(
          { integration: 'calendar', endpoint: '/events', method: 'DELETE' },
          context,
        ),
      /not configured/,
    );
  });
});
