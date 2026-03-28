# D1 Migrations in CI/CD

## Critical Rule

**D1 migrations MUST run before Worker code deployment.** The `migrate` job must
complete successfully before the `deploy` job starts. Use `needs: migrate` in
GitHub Actions to enforce this ordering.

## Migration File Structure

```
migrations/
├── 0001_initial_schema.sql
├── 0002_add_users_table.sql
├── 0003_add_index_on_email.sql
└── 0004_add_billing_columns.sql
```

Each file is a numbered SQL script. D1 tracks applied migrations in the
`d1_migrations` table. In CI, the confirmation prompt is automatically skipped
and a backup is captured before applying.

## Wrangler Commands

```bash
# Apply all pending migrations to remote D1
wrangler d1 migrations apply MY_DB --remote

# Apply to specific environment
wrangler d1 migrations apply MY_DB --remote --env staging

# Create a new migration file
wrangler d1 migrations create MY_DB "add_users_table"

# List migrations and their status
wrangler d1 migrations list MY_DB --remote
```

## wrangler.toml Configuration

```toml
[[d1_databases]]
binding = "DB"
database_name = "myapp-prod"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
migrations_dir = "migrations"

[env.staging.d1_databases]
binding = "DB"
database_name = "myapp-staging"
database_id = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
migrations_dir = "migrations"
```

## Breaking Schema Changes: Expand-and-Contract

Never drop or rename columns directly. Follow this pattern:

**Phase 1 — Expand** (Migration N):
```sql
-- 0005_add_new_email_column.sql
ALTER TABLE users ADD COLUMN email_v2 TEXT;
```

**Phase 2 — Deploy dual-write code**:
Worker writes to both `email` and `email_v2`. Reads from `email`.

**Phase 3 — Backfill** (Migration N+1):
```sql
-- 0006_backfill_email_v2.sql
UPDATE users SET email_v2 = email WHERE email_v2 IS NULL;
```

**Phase 4 — Deploy read-from-new code**:
Worker reads from `email_v2`, writes to both.

**Phase 5 — Contract** (Migration N+2):
```sql
-- 0007_drop_old_email.sql
ALTER TABLE users DROP COLUMN email;
ALTER TABLE users RENAME COLUMN email_v2 TO email;
```

Each phase is a separate deploy cycle. This ensures zero-downtime migrations
even if a rollback occurs between phases.

## Testing Migrations in CI

Use `@cloudflare/vitest-pool-workers` to test migrations:

```typescript
import { env } from 'cloudflare:test';
import { readD1Migrations, applyD1Migrations } from '@cloudflare/vitest-pool-workers/d1';

describe('D1 migrations', () => {
  beforeAll(async () => {
    const migrations = readD1Migrations('migrations');
    await applyD1Migrations(env.DB, migrations);
  });

  it('creates expected tables', async () => {
    const result = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type='table'"
    ).all();
    const tables = result.results.map(r => r.name);
    expect(tables).toContain('users');
  });
});
```

## D1 Time Travel (Safety Net)

D1 supports 30-day point-in-time recovery. If a migration goes wrong:

```bash
# List available bookmarks
wrangler d1 time-travel info MY_DB

# Restore to a specific point
wrangler d1 time-travel restore MY_DB --timestamp "2026-03-26T10:00:00Z"
```

Time Travel is the last resort. The expand-and-contract pattern should prevent
needing it.

## Drizzle ORM Integration

Drizzle generates migration SQL from schema changes:

```bash
# Generate migration from schema diff
npx drizzle-kit generate

# Push schema directly (dev only, never in CI)
npx drizzle-kit push
```

In CI, always use `wrangler d1 migrations apply` with the generated SQL files.
Never use `drizzle-kit push` in CI/CD pipelines — it bypasses migration tracking.

## Common Pitfalls

1. **Never use Prisma with D1.** `prisma migrate deploy` fails due to the internal
   `_cf_KV` table. Use Drizzle + Wrangler migrations.
2. **SQLite limitations apply.** No concurrent writes, no `ALTER TABLE ... ADD CONSTRAINT`,
   limited `ALTER TABLE` support.
3. **Migration order matters.** Files are applied in lexicographic order. Use zero-padded
   numbers (`0001`, `0002`, not `1`, `2`).
4. **Test with the same migrations dir.** Point `migrations_dir` in `wrangler.toml` to
   the same directory used in vitest config.
