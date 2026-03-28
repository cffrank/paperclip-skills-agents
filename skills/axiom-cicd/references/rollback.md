# Rollback Strategy

## How Workers Rollback Works

Workers maintain the **100 most recent versions**. Rollback creates a new
deployment pointing to old code — it's instant and atomic.

```bash
# Roll back to previous version
wrangler rollback

# Roll back to specific version
wrangler rollback <version-id>

# List available versions
wrangler versions list
```

## What Rollback Does NOT Revert

This is critical. Rollback only reverts Worker code. These are NOT reverted:

| Resource | Reverted? | Mitigation |
|----------|-----------|------------|
| Worker code | ✅ Yes | Instant |
| D1 schema changes | ❌ No | Expand-and-contract pattern |
| D1 data changes | ❌ No | D1 Time Travel (30-day window) |
| KV data | ❌ No | Manual revert or versioned keys |
| R2 objects | ❌ No | Versioned paths (`v{n}/file.ext`) |
| Durable Object migrations | ❌ No | DO migrations are forward-only |
| Secrets / env vars | ❌ No | Manual revert via `wrangler secret` |
| Routes | ❌ No | Manual revert via dashboard/API |
| Cron triggers | ❌ No | Stored in `wrangler.toml`, auto-revert with code |

## Rollback Decision Matrix

| Signal | Threshold | Action |
|--------|-----------|--------|
| Error rate > 1% | Within 5 min of deploy | Auto-rollback |
| Error rate > 5% | Any time | Immediate rollback |
| P99 latency > 500ms | Sustained 3+ min | Auto-rollback |
| Health endpoint down | 2 consecutive checks | Immediate rollback |
| Manual trigger | Operator decision | Manual rollback |

## Data Layer Compatibility

Before rolling back, check whether the old code version is compatible with
the current data layer state:

1. **Were D1 migrations applied in this deploy?**
   - If migrations only ADDED columns/tables → safe to rollback (old code
     ignores new columns)
   - If migrations RENAMED or DROPPED columns → rollback will break
   - If expand-and-contract was used → safe (old code reads old columns)

2. **Were KV schemas changed?**
   - If KV values have a new format → old code must handle both formats
   - Use versioned KV keys (`user:v2:123`) to avoid conflicts

3. **Were R2 paths changed?**
   - If old code references different R2 paths → 404s on rollback
   - Use content-hashed or versioned paths to avoid this

## Post-Rollback Checklist

1. Verify health endpoint returns 200
2. Check Workers analytics for error rate normalization
3. Create incident issue documenting the rollback reason
4. Notify team via Slack
5. Investigate root cause before re-deploying
6. If D1 migrations need reversal, use Time Travel:
   ```bash
   wrangler d1 time-travel restore MY_DB --timestamp "2026-03-26T10:00:00Z"
   ```

## Automated Rollback Workflow

See `references/workflows.md` for the full `rollback.yml` workflow.
The workflow can be triggered:
- Manually via `workflow_dispatch`
- Automatically from a failed health gate in `deploy-production.yml`
- Via GitHub API from an external monitoring system
