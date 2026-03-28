# Testing in CI/CD

## Core Rule: Tests Run in workerd

All tests execute inside the Cloudflare workerd runtime via
`@cloudflare/vitest-pool-workers`. This matches production behavior exactly.
Never test Workers code in plain Node.js — runtime differences cause false
positives.

## Setup

### Install Dependencies

```bash
npm install -D vitest @cloudflare/vitest-pool-workers
```

### vitest.config.ts

```typescript
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          // Override bindings for test isolation
          kvNamespaces: ['MY_KV'],
          d1Databases: ['DB'],
          r2Buckets: ['MY_BUCKET'],
        },
      },
    },
    coverage: {
      provider: 'istanbul',
      reporter: ['text', 'json', 'html'],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 70,
      },
    },
  },
});
```

### Key Behaviors

- **Per-file isolation**: Each test file gets its own isolated KV/D1/R2 state.
  Tests cannot leak state between files.
- **Bindings via `cloudflare:test`**: Access `env` from the test module, not
  from global scope.
- **No Jest**: The Vitest pool is incompatible with Jest. Migrate all tests.
- **No Service Worker format**: Only Module Worker format is supported.

## Test Patterns

### Unit Test (Worker Handler)

```typescript
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import worker from '../src/index';

describe('API handler', () => {
  it('returns 200 for health check', async () => {
    const request = new Request('http://localhost/health');
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(response.status).toBe(200);
  });
});
```

### Integration Test (D1)

```typescript
import { env } from 'cloudflare:test';

describe('User repository', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM users');
  });

  it('creates a user', async () => {
    await env.DB.prepare('INSERT INTO users (name, email) VALUES (?, ?)')
      .bind('Carl', 'carl@axiom.ai')
      .run();

    const result = await env.DB.prepare('SELECT * FROM users WHERE email = ?')
      .bind('carl@axiom.ai')
      .first();

    expect(result.name).toBe('Carl');
  });
});
```

### Integration Test (R2)

```typescript
import { env } from 'cloudflare:test';

describe('Asset storage', () => {
  it('stores and retrieves files', async () => {
    await env.MY_BUCKET.put('test.txt', 'hello world');
    const obj = await env.MY_BUCKET.get('test.txt');
    expect(await obj.text()).toBe('hello world');
  });
});
```

### Migration Test

```typescript
import { env } from 'cloudflare:test';
import { readD1Migrations, applyD1Migrations } from '@cloudflare/vitest-pool-workers/d1';

describe('Database migrations', () => {
  beforeAll(async () => {
    const migrations = readD1Migrations('migrations');
    await applyD1Migrations(env.DB, migrations);
  });

  it('creates all expected tables', async () => {
    const { results } = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name != 'd1_migrations'"
    ).all();
    const tables = results.map(r => r.name);

    expect(tables).toContain('users');
    expect(tables).toContain('sessions');
  });
});
```

## CI Workflow Integration

```yaml
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    - run: npm ci --frozen-lockfile
    - run: npx vitest run --reporter=verbose --coverage
    - name: Check coverage thresholds
      run: npx vitest run --coverage --coverage.thresholds.lines=80
    - uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results
        path: |
          coverage/
          test-results/
```

## Flaky Test Quarantine

Track flaky tests and auto-quarantine them:

```typescript
// vitest.config.ts
export default defineWorkersConfig({
  test: {
    retry: 2,  // Retry failed tests up to 2 times
    reporters: ['verbose', 'json'],
    outputFile: 'test-results/results.json',
  },
});
```

In CI, parse results and flag tests that pass on retry as flaky:
```yaml
- name: Flag flaky tests
  if: always()
  run: |
    if [ -f test-results/results.json ]; then
      FLAKY=$(jq '[.testResults[].testResults[] | select(.retryReasons | length > 0)] | length' test-results/results.json)
      if [ "$FLAKY" -gt "0" ]; then
        echo "::warning::$FLAKY flaky test(s) detected — passed on retry"
      fi
    fi
```
