---
name: drizzle-schema
description: >
  Drizzle ORM schema design, migration generation, and query patterns for Cloudflare D1.
  Covers table definitions, relations, indexes, type safety, D1 dialect specifics, and
  migration workflows. Never use Prisma — Drizzle is the mandatory ORM for all __COMPANY_NAME__
  projects. Use when designing database schemas, defining tables, creating relations,
  generating migrations, writing type-safe queries, or troubleshooting Drizzle issues.
  Triggers on: "schema", "table", "Drizzle", "ORM", "migration", "relation", "foreign
  key", "model", "database design", "drizzle-kit", or "type-safe query".
---

# Drizzle Schema Skill

Custom skill — Drizzle ORM patterns specific to the D1 SQLite dialect.
**Never use Prisma** — it fails on D1 due to the internal `_cf_KV` table.

## Setup

```bash
npm install drizzle-orm
npm install -D drizzle-kit
```

### drizzle.config.ts

```typescript
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/lib/server/schema.ts',
  out: './migrations',
  dialect: 'sqlite',
  driver: 'd1-http',
  dbCredentials: {
    accountId: process.env.CLOUDFLARE_ACCOUNT_ID!,
    databaseId: process.env.D1_DATABASE_ID!,
    token: process.env.CLOUDFLARE_API_TOKEN!,
  },
});
```

### Database Instance

```typescript
// src/lib/server/db.ts
import { drizzle } from 'drizzle-orm/d1';
import * as schema from './schema';

export function getDB(d1: D1Database) {
  return drizzle(d1, { schema });
}

// In SvelteKit load function:
const db = getDB(platform.env.DB);

// In Hono handler:
const db = getDB(c.env.DB);
```

## Schema Patterns

### Basic Table

```typescript
// src/lib/server/schema.ts
import { sqliteTable, text, integer, real } from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

export const users = sqliteTable('users', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  clerkId: text('clerk_id').unique().notNull(),
  email: text('email').unique().notNull(),
  name: text('name').notNull(),
  role: text('role', { enum: ['admin', 'member', 'viewer'] }).default('member'),
  createdAt: text('created_at').default(sql`(datetime('now'))`).notNull(),
  updatedAt: text('updated_at').default(sql`(datetime('now'))`).notNull(),
});
```

### Table with Relations

```typescript
export const projects = sqliteTable('projects', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text('name').notNull(),
  description: text('description'),
  status: text('status', { enum: ['active', 'archived', 'draft'] }).default('draft'),
  userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  createdAt: text('created_at').default(sql`(datetime('now'))`).notNull(),
  updatedAt: text('updated_at').default(sql`(datetime('now'))`).notNull(),
});

export const tasks = sqliteTable('tasks', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  title: text('title').notNull(),
  completed: integer('completed', { mode: 'boolean' }).default(false),
  projectId: text('project_id').notNull().references(() => projects.id, { onDelete: 'cascade' }),
  assigneeId: text('assignee_id').references(() => users.id),
  dueDate: text('due_date'),
  createdAt: text('created_at').default(sql`(datetime('now'))`).notNull(),
});
```

### Relation Definitions

```typescript
import { relations } from 'drizzle-orm';

export const usersRelations = relations(users, ({ many }) => ({
  projects: many(projects),
  assignedTasks: many(tasks),
}));

export const projectsRelations = relations(projects, ({ one, many }) => ({
  owner: one(users, { fields: [projects.userId], references: [users.id] }),
  tasks: many(tasks),
}));

export const tasksRelations = relations(tasks, ({ one }) => ({
  project: one(projects, { fields: [tasks.projectId], references: [projects.id] }),
  assignee: one(users, { fields: [tasks.assigneeId], references: [users.id] }),
}));
```

### Indexes

```typescript
import { index, uniqueIndex } from 'drizzle-orm/sqlite-core';

export const projects = sqliteTable('projects', {
  // ... columns
}, (table) => [
  index('idx_projects_user').on(table.userId),
  index('idx_projects_status').on(table.status),
  index('idx_projects_updated').on(table.updatedAt),
  uniqueIndex('idx_projects_name_user').on(table.name, table.userId),
]);
```

## D1/SQLite Type Mapping

| Concept | Drizzle type | SQLite storage | Notes |
|---------|-------------|----------------|-------|
| UUID | `text('id')` | TEXT | Use `crypto.randomUUID()` |
| Boolean | `integer('col', { mode: 'boolean' })` | INTEGER (0/1) | SQLite has no BOOLEAN |
| Timestamp | `text('col')` | TEXT (ISO 8601) | `datetime('now')` default |
| JSON | `text('col', { mode: 'json' })` | TEXT | Stored as JSON string |
| Enum | `text('col', { enum: [...] })` | TEXT | TypeScript-only validation |
| Money | `integer('cents')` | INTEGER | Store as cents, not float |
| Auto-increment | `integer('id').primaryKey({ autoIncrement: true })` | INTEGER | For numeric PKs |

### Important: No DECIMAL/NUMERIC

SQLite stores all numbers as INTEGER or REAL. For money, always store as
integer cents to avoid floating point issues:

```typescript
export const invoices = sqliteTable('invoices', {
  amountCents: integer('amount_cents').notNull(), // $10.50 = 1050
  taxCents: integer('tax_cents').default(0),
});
```

## Query Patterns

### Select with Relations
```typescript
const projectsWithTasks = await db.query.projects.findMany({
  where: eq(projects.userId, userId),
  with: {
    tasks: true,
    owner: { columns: { name: true, email: true } },
  },
  orderBy: [desc(projects.updatedAt)],
  limit: 20,
});
```

### Insert
```typescript
const [newProject] = await db.insert(projects).values({
  name: 'My Project',
  userId: currentUser.id,
}).returning();
```

### Update
```typescript
await db.update(projects)
  .set({ status: 'active', updatedAt: sql`(datetime('now'))` })
  .where(and(
    eq(projects.id, projectId),
    eq(projects.userId, userId),  // Row-level access control
  ));
```

### Delete
```typescript
await db.delete(projects)
  .where(and(
    eq(projects.id, projectId),
    eq(projects.userId, userId),
  ));
```

### Aggregate
```typescript
const stats = await db.select({
  total: count(),
  active: count(sql`CASE WHEN ${projects.status} = 'active' THEN 1 END`),
}).from(projects).where(eq(projects.userId, userId));
```

### Transaction (via D1 batch)
```typescript
// Drizzle doesn't support D1 transactions natively — use D1 batch
const d1 = platform.env.DB;
await d1.batch([
  d1.prepare('UPDATE accounts SET balance = balance - ? WHERE id = ?').bind(amount, fromId),
  d1.prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?').bind(amount, toId),
  d1.prepare('INSERT INTO transfers (from_id, to_id, amount) VALUES (?, ?, ?)').bind(fromId, toId, amount),
]);
```

## Migration Workflow

```bash
# 1. Modify schema.ts

# 2. Generate migration SQL
npx drizzle-kit generate

# 3. Review generated SQL in migrations/NNNN_*.sql

# 4. Apply to dev
wrangler d1 migrations apply myapp-dev --remote

# 5. Test, then apply to staging
wrangler d1 migrations apply myapp-staging --remote --env staging

# 6. Apply to production (via CI/CD, never manually)
# axiom-cicd handles this in deploy-production.yml
```

### Migration Rules
1. **Never use `drizzle-kit push` in CI** — it bypasses migration tracking
2. **Review generated SQL** — Drizzle sometimes generates suboptimal migrations
3. **Additive only** for zero-downtime — use expand-and-contract for breaking changes
4. **Test migrations** with `readD1Migrations()` + `applyD1Migrations()` in Vitest

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| `$defaultFn` not running in D1 | Use SQL defaults: `default(sql\`...\`)` |
| Missing `notNull()` on required fields | Always explicit — SQLite allows NULL by default |
| Using `real()` for money | Use `integer()` storing cents |
| Forgetting `onDelete: 'cascade'` | Orphaned rows after parent deletion |
| Schema changes without migration | Always `drizzle-kit generate` then apply |
| Using Prisma syntax | Drizzle syntax is different — check docs |

## Relationship to Other Skills

- **Loaded by**: DBA Lead (primary), App Dev Lead (query patterns)
- **Pairs with**: `d1-optimizer` (query tuning), `d1-time-travel` (backup)
- **Migrations via**: `axiom-cicd` (D1 migration reference)
- **Tested by**: `api-tester` (D1 integration tests)
