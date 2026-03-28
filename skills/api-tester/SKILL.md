---
name: api-tester
description: >
  API testing for Cloudflare Workers endpoints using Vitest and the workerd runtime. Covers
  endpoint validation, auth testing with Clerk, D1 query verification, R2 operations, error
  handling, and contract testing. Use when writing API tests, validating endpoints, testing
  auth flows, or verifying API contracts. Triggers on: "API test", "endpoint test",
  "integration test", "test the API", "validate endpoint", "contract test", "auth test",
  or any request to test server-side functionality.
---

# API Tester Skill

Adapted from agency-agents `testing-api-tester.md` — rewritten for Workers
fetch handlers tested in the workerd runtime via Vitest.

## Test Setup

Tests run inside workerd via `@cloudflare/vitest-pool-workers`, not Node.js.

```typescript
// src/routes/api/projects.test.ts
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect, beforeEach } from 'vitest';
import app from '../../index';

describe('GET /api/projects', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM projects');
    await env.DB.prepare('INSERT INTO projects (id, name, user_id) VALUES (?, ?, ?)')
      .bind('p1', 'Test Project', 'user_123')
      .run();
  });

  it('returns projects for authenticated user', async () => {
    const req = new Request('http://localhost/api/projects', {
      headers: { Authorization: 'Bearer valid-test-token' },
    });
    const ctx = createExecutionContext();
    const res = await app.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.projects).toHaveLength(1);
    expect(body.projects[0].name).toBe('Test Project');
  });

  it('returns 401 without auth header', async () => {
    const req = new Request('http://localhost/api/projects');
    const res = await app.fetch(req, env, createExecutionContext());
    expect(res.status).toBe(401);
  });

  it('returns 404 for nonexistent project', async () => {
    const req = new Request('http://localhost/api/projects/nonexistent', {
      headers: { Authorization: 'Bearer valid-test-token' },
    });
    const res = await app.fetch(req, env, createExecutionContext());
    expect(res.status).toBe(404);
  });
});
```

## Test Categories

### Functional (every endpoint)
- Happy path returns correct status + body
- Missing/invalid params return 400 with error message
- Non-existent resources return 404
- Method not allowed returns 405

### Auth (Clerk integration)
- Missing token → 401
- Expired token → 401
- Valid token → proceeds with correct userId
- Wrong user accessing another's resource → 403

### D1 Operations
- INSERT creates record, returns it
- UPDATE modifies only specified fields
- DELETE removes record, returns confirmation
- Batch operations complete atomically
- Concurrent writes don't corrupt data

### R2 Operations
- Upload stores file with correct metadata
- Download streams file with correct Content-Type
- Delete removes object
- Non-existent key returns 404

### Error Handling
- Malformed JSON body → 400, not 500
- D1 constraint violation → 409 Conflict
- Internal errors → 500 with generic message (no stack traces)
- Rate limited → 429 with Retry-After header

## Validation Testing Pattern

```typescript
describe('POST /api/projects', () => {
  const validBody = { name: 'My Project', description: 'A test project' };

  it('rejects empty name', async () => {
    const res = await postJSON('/api/projects', { ...validBody, name: '' });
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error).toContain('name');
  });

  it('rejects name over 100 chars', async () => {
    const res = await postJSON('/api/projects', { ...validBody, name: 'x'.repeat(101) });
    expect(res.status).toBe(400);
  });

  it('accepts valid body', async () => {
    const res = await postJSON('/api/projects', validBody);
    expect(res.status).toBe(201);
  });
});
```

## Test Report Format

```markdown
## API Test Results
- Endpoints tested: 24/24
- Pass rate: 100%
- Avg response time: 12ms
- Auth coverage: all routes verified
- Error handling: all error codes verified
```

## Relationship to Other Skills

- **Depends on**: `cf-workers-api` (patterns being tested)
- **Feeds into**: `reality-checker` (Gate 2 evidence), `test-analyzer` (metrics)
- **Runs in**: Vitest with `@cloudflare/vitest-pool-workers`
