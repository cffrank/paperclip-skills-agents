---
name: cf-workers-api
description: >
  Cloudflare Workers API development patterns including request handling, D1 database
  operations, R2 storage, KV caching, Hono router, middleware, error handling, and
  environment typing. Use when building API routes, Workers handlers, server-side logic,
  database queries, or any backend code running on Cloudflare Workers. Triggers on:
  "API", "endpoint", "handler", "route", "Workers", "D1 query", "R2 bucket", "KV",
  "middleware", "Hono", "fetch handler", "binding", "env", "server", "backend", or any
  request to build server-side functionality.
---

# Cloudflare Workers API Skill

Adapted from agency-agents `engineering-backend-architect.md` — rewritten from
Express/PostgreSQL/AWS to Cloudflare Workers + D1 + R2 + Hono.

## Mandatory Stack

- **Runtime**: Cloudflare Workers (Module Worker format, never Service Worker)
- **Router**: Hono (lightweight, Workers-native) or SvelteKit API routes
- **Database**: D1 via Drizzle ORM (never Prisma, never raw SQL in handlers)
- **Storage**: R2 for files, KV for cache/config, Durable Objects for state
- **Auth**: Clerk (JWT validation via `@clerk/backend`)
- **Validation**: Zod for request/response schemas

## Environment Typing

```typescript
// src/types/env.ts
export interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
  CACHE: KVNamespace;
  AI: Ai;
  CLERK_SECRET_KEY: string;
  STRIPE_SECRET_KEY: string;
  ENVIRONMENT: string;
}
```

## Hono Router Pattern

```typescript
// src/index.ts
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import type { Env } from './types/env';
import { authMiddleware } from './middleware/auth';
import { usersRouter } from './routes/users';
import { projectsRouter } from './routes/projects';

const app = new Hono<{ Bindings: Env }>();

app.use('*', logger());
app.use('/api/*', cors({ origin: ['https://myapp.pages.dev'], credentials: true }));
app.use('/api/*', authMiddleware);

app.route('/api/users', usersRouter);
app.route('/api/projects', projectsRouter);

app.get('/health', (c) => c.json({ status: 'ok', env: c.env.ENVIRONMENT }));

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;
```

## D1 Query Patterns

### Always Use Parameterized Queries
```typescript
// GOOD — parameterized
const user = await c.env.DB
  .prepare('SELECT * FROM users WHERE id = ?')
  .bind(userId)
  .first();

// BAD — SQL injection risk
const user = await c.env.DB
  .prepare(`SELECT * FROM users WHERE id = '${userId}'`)
  .first();
```

### Batch Operations
```typescript
// Multiple writes in a single round-trip
const results = await c.env.DB.batch([
  c.env.DB.prepare('INSERT INTO audit_log (action, user_id) VALUES (?, ?)').bind('create', userId),
  c.env.DB.prepare('UPDATE users SET updated_at = ? WHERE id = ?').bind(now, userId),
  c.env.DB.prepare('INSERT INTO projects (name, user_id) VALUES (?, ?)').bind(name, userId),
]);
```

### Drizzle ORM Integration
```typescript
// src/lib/server/db.ts
import { drizzle } from 'drizzle-orm/d1';
import * as schema from './schema';

export function getDB(d1: D1Database) {
  return drizzle(d1, { schema });
}

// In a handler:
const db = getDB(c.env.DB);
const projects = await db.select().from(schema.projects)
  .where(eq(schema.projects.userId, userId))
  .orderBy(desc(schema.projects.updatedAt));
```

## R2 Storage Patterns

```typescript
// Upload
app.post('/api/files', async (c) => {
  const file = await c.req.blob();
  const key = `${crypto.randomUUID()}-${Date.now()}`;
  await c.env.ASSETS.put(key, file, {
    httpMetadata: { contentType: file.type },
    customMetadata: { uploadedBy: c.get('userId') },
  });
  return c.json({ key });
});

// Download (stream, don't buffer)
app.get('/api/files/:key', async (c) => {
  const obj = await c.env.ASSETS.get(c.req.param('key'));
  if (!obj) return c.notFound();
  return new Response(obj.body, {
    headers: { 'Content-Type': obj.httpMetadata?.contentType ?? 'application/octet-stream' },
  });
});
```

## Auth Middleware (Clerk)

```typescript
// src/middleware/auth.ts
import { verifyToken } from '@clerk/backend';
import type { Context, Next } from 'hono';

export async function authMiddleware(c: Context, next: Next) {
  const token = c.req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return c.json({ error: 'Unauthorized' }, 401);

  try {
    const payload = await verifyToken(token, {
      secretKey: c.env.CLERK_SECRET_KEY,
    });
    c.set('userId', payload.sub);
    c.set('session', payload);
  } catch {
    return c.json({ error: 'Invalid token' }, 401);
  }

  await next();
}
```

## Error Handling

```typescript
// Structured error responses
class AppError extends Error {
  constructor(public status: number, message: string, public code?: string) {
    super(message);
  }
}

// In handlers
if (!project) throw new AppError(404, 'Project not found', 'PROJECT_NOT_FOUND');

// Global error handler
app.onError((err, c) => {
  if (err instanceof AppError) {
    return c.json({ error: err.message, code: err.code }, err.status);
  }
  console.error(err);
  return c.json({ error: 'Internal server error' }, 500);
});
```

## Request Validation (Zod)

```typescript
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

const createProjectSchema = z.object({
  name: z.string().min(2).max(100),
  description: z.string().max(500).optional(),
});

app.post('/api/projects', zValidator('json', createProjectSchema), async (c) => {
  const { name, description } = c.req.valid('json');
  // Validated and typed
});
```

## Workers-Specific Rules

1. **No `process.env`** — use `c.env` (Hono) or `platform.env` (SvelteKit)
2. **No `fs`, `path`, `crypto` Node imports** — use Web APIs (`crypto.subtle`, etc.)
3. **No dynamic `import()`** — bundle everything statically
4. **No `setTimeout` outside request context** — use `ctx.waitUntil()` for background work
5. **Stream large responses** — don't buffer entire R2 objects in memory
6. **Use `ctx.waitUntil()`** for fire-and-forget work (logging, analytics, webhooks)

## Relationship to Other Skills

- **Pairs with**: `sveltekit-frontend` (frontend calls these APIs)
- **Data layer**: `d1-optimizer` (query performance), `data-remediation` (data quality)
- **Tested by**: `api-tester` (endpoint validation), `test-analyzer` (coverage)
- **Deployed by**: `axiom-cicd` (Workers deployment workflows)
