---
name: d1-time-travel
description: >
  D1 database backup, point-in-time recovery via Time Travel, data export, and disaster
  recovery procedures. Covers Time Travel bookmarks, restore operations, data export to
  R2, backup verification, and recovery runbooks. Use when backing up D1, restoring data,
  recovering from bad migrations, exporting data, or planning disaster recovery. Triggers
  on: "backup", "restore", "Time Travel", "point-in-time recovery", "data export", "disaster
  recovery", "rollback data", "D1 recovery", "data loss", or "undo migration".
---

# D1 Time Travel Skill

Custom skill — D1's built-in point-in-time recovery and backup patterns.

## Time Travel Overview

D1 automatically maintains a 30-day history of all changes. You can restore
any database to any point within that window. This is your safety net for
bad migrations, accidental deletes, and data corruption.

**Time Travel does NOT require pre-configuration.** It's always on.

## Core Commands

### Check Available Recovery Points

```bash
# List bookmarks and available time range
wrangler d1 time-travel info MY_DB

# Output shows:
# - Earliest available point (up to 30 days ago)
# - Latest bookmark
# - Current database size
```

### Restore to a Point in Time

```bash
# Restore to specific timestamp
wrangler d1 time-travel restore MY_DB --timestamp "2026-03-27T14:30:00Z"

# Restore to a bookmark
wrangler d1 time-travel restore MY_DB --bookmark "bookmark_abc123"
```

**Restore is destructive** — it replaces the current database state with the
historical version. All changes after the restore point are lost.

### Create a Bookmark

```bash
# Create a named bookmark before risky operations
wrangler d1 time-travel bookmark MY_DB --message "pre-migration-0005"
```

## When to Use Time Travel

| Scenario | Action |
|----------|--------|
| Bad migration applied to production | Restore to timestamp before migration |
| Accidental bulk DELETE/UPDATE | Restore to timestamp before the query |
| Data corruption from bug | Restore to last known good state |
| Need to inspect old data | Restore to temp database at that point |
| Pre-deploy safety | Create bookmark before every production deploy |

## Automated Pre-Deploy Bookmark

Add to your production deploy workflow:

```yaml
# In deploy-production.yml, before migrations
- name: Create pre-deploy bookmark
  uses: cloudflare/wrangler-action@v3
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    wranglerVersion: '3.99.0'
    command: d1 time-travel bookmark MY_DB --message "pre-deploy-${{ github.sha }}"
```

This gives you a named recovery point for every production deploy.

## Data Export Patterns

### Export to JSON (via Worker)

```typescript
// src/routes/api/admin/export/+server.ts
export async function GET({ platform, locals }) {
  // Admin-only endpoint
  if (locals.role !== 'admin') return new Response('Forbidden', { status: 403 });

  const db = platform?.env?.DB;
  const tables = ['users', 'projects', 'tasks', 'appointments'];
  const exportData: Record<string, any[]> = {};

  for (const table of tables) {
    const result = await db.prepare(`SELECT * FROM ${table}`).all();
    exportData[table] = result.results;
  }

  const json = JSON.stringify(exportData, null, 2);
  const filename = `export-${new Date().toISOString().slice(0, 10)}.json`;

  return new Response(json, {
    headers: {
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="${filename}"`,
    },
  });
}
```

### Export to R2 (Scheduled Backup)

```typescript
// src/scheduled.ts — Cron Trigger for nightly backup
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    const tables = ['users', 'projects', 'tasks', 'appointments'];
    const exportData: Record<string, any[]> = {};

    for (const table of tables) {
      const result = await env.DB.prepare(`SELECT * FROM ${table}`).all();
      exportData[table] = result.results;
    }

    const json = JSON.stringify(exportData);
    const date = new Date().toISOString().slice(0, 10);
    const key = `backups/${date}/full-export.json`;

    await env.ASSETS.put(key, json, {
      httpMetadata: { contentType: 'application/json' },
      customMetadata: {
        tables: tables.join(','),
        rowCount: Object.values(exportData).reduce((sum, t) => sum + t.length, 0).toString(),
        exportedAt: new Date().toISOString(),
      },
    });

    console.log(`Backup saved to R2: ${key}`);
  },
};
```

```toml
# wrangler.toml — schedule nightly at 3am UTC
[triggers]
crons = ["0 3 * * *"]
```

### Export to CSV

```typescript
function tableToCSV(rows: Record<string, any>[]): string {
  if (rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  const csv = [
    headers.join(','),
    ...rows.map(row =>
      headers.map(h => {
        const val = row[h];
        if (val === null || val === undefined) return '';
        const str = String(val);
        return str.includes(',') || str.includes('"') || str.includes('\n')
          ? `"${str.replace(/"/g, '""')}"` : str;
      }).join(',')
    ),
  ];
  return csv.join('\n');
}
```

## Disaster Recovery Runbook

### Scenario: Bad Migration in Production

```
1. STOP — Do not deploy any more code
2. Assess — What did the migration change?
   wrangler d1 migrations list MY_DB --remote
3. Check bookmark — Was a pre-deploy bookmark created?
   wrangler d1 time-travel info MY_DB
4. Restore — Roll back to pre-migration state
   wrangler d1 time-travel restore MY_DB --timestamp "BEFORE_MIGRATION_TIME"
5. Rollback code — If Worker code was also deployed
   wrangler rollback
6. Verify — Check data integrity
   wrangler d1 execute MY_DB --command "SELECT count(*) FROM users"
7. Document — Create incident issue with timeline
8. Fix — Correct the migration, test in dev/staging
9. Redeploy — Apply corrected migration through CI/CD
```

### Scenario: Accidental Data Deletion

```
1. Identify — What was deleted and when?
   Check call_log, audit tables, or Workers logs
2. Find timestamp — When was the last good state?
3. Restore — Point-in-time recovery
   wrangler d1 time-travel restore MY_DB --timestamp "SAFE_TIMESTAMP"
4. Verify — Confirm deleted data is back
5. Prevent — Add soft-delete pattern or confirmation gates
```

### Scenario: Need Old Data Without Full Restore

```
1. Create temp database
   wrangler d1 create myapp-recovery-temp
2. Note: D1 Time Travel restores in-place only.
   Export data from the main DB at the desired point:
   - Restore main DB to old timestamp
   - Export the needed data
   - Restore main DB back to latest bookmark
3. This is disruptive — prefer using R2 backups for data retrieval
```

## Backup Verification

Weekly check that backups are running and restorable:

```yaml
# .github/workflows/backup-verify.yml
name: Verify Backups
on:
  schedule:
    - cron: '0 9 * * 1'  # Monday 9am UTC
  workflow_dispatch:

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile

      - name: Check Time Travel availability
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: d1 time-travel info myapp-prod

      - name: Check R2 backup recency
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: r2 object list myapp-assets --prefix backups/ | tail -5
```

## Backup Retention Policy

| Tier | Retention | Storage |
|------|-----------|---------|
| D1 Time Travel | 30 days (automatic) | D1 internal |
| Nightly R2 JSON export | 90 days | R2 bucket |
| Weekly R2 full export | 1 year | R2 bucket (cold) |

Cleanup old R2 backups with a scheduled Worker or lifecycle policy.

## Relationship to Other Skills

- **Loaded by**: DBA Lead agent (primary), DevOps Lead (deploy bookmarks)
- **Pairs with**: `drizzle-schema` (schema design), `d1-optimizer` (query patterns)
- **Integrated into**: `axiom-cicd` (pre-deploy bookmarks in production workflow)
- **Recovery triggers**: `sre-ops` (incident response), `reality-checker` (data verification)
