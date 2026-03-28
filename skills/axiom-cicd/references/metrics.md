# DORA Metrics Tracking

## The Four Key Metrics

| Metric | Elite Target | How to Measure |
|--------|-------------|----------------|
| **Deployment Frequency** | Multiple times/day | Count `deploy-production.yml` runs per day |
| **Lead Time for Changes** | < 1 hour | Time from first commit to production deploy |
| **Change Failure Rate** | < 5% | Rollbacks / total deploys |
| **Mean Time to Recovery** | < 1 hour | Time from failure detection to rollback/fix |

Workers' sub-minute global deployment gives __COMPANY_NAME__ a structural advantage
on deployment frequency and lead time.

## Collecting Metrics

### From GitHub Actions

```yaml
# Add to deploy-production.yml as a final job
metrics:
  runs-on: ubuntu-latest
  needs: deploy
  if: always()
  steps:
    - name: Record deployment
      run: |
        DEPLOY_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        RESULT="${{ needs.deploy.result }}"
        COMMIT_SHA="${{ github.sha }}"
        PR_MERGED_AT="${{ github.event.head_commit.timestamp }}"

        # Calculate lead time (commit to deploy)
        COMMIT_EPOCH=$(date -d "$PR_MERGED_AT" +%s 2>/dev/null || echo 0)
        DEPLOY_EPOCH=$(date -d "$DEPLOY_TIME" +%s)
        LEAD_TIME_SEC=$((DEPLOY_EPOCH - COMMIT_EPOCH))
        LEAD_TIME_MIN=$((LEAD_TIME_SEC / 60))

        echo "## Deployment Metrics" >> $GITHUB_STEP_SUMMARY
        echo "- **Time**: $DEPLOY_TIME" >> $GITHUB_STEP_SUMMARY
        echo "- **Result**: $RESULT" >> $GITHUB_STEP_SUMMARY
        echo "- **Lead Time**: ${LEAD_TIME_MIN} minutes" >> $GITHUB_STEP_SUMMARY
        echo "- **Commit**: $COMMIT_SHA" >> $GITHUB_STEP_SUMMARY

        # Store in D1 via Wrangler (or API call to metrics Worker)
        curl -s -X POST "https://metrics.axiom.workers.dev/deployments" \
          -H "Authorization: Bearer ${{ secrets.METRICS_API_KEY }}" \
          -H "Content-Type: application/json" \
          -d "{
            \"timestamp\": \"$DEPLOY_TIME\",
            \"result\": \"$RESULT\",
            \"lead_time_seconds\": $LEAD_TIME_SEC,
            \"commit_sha\": \"$COMMIT_SHA\",
            \"workflow_run_id\": \"${{ github.run_id }}\"
          }"
```

### Metrics Worker (D1 Storage)

A small Worker that stores and queries DORA metrics:

```sql
-- migrations/0001_dora_metrics.sql
CREATE TABLE deployments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  result TEXT NOT NULL,  -- 'success', 'failure', 'rollback'
  lead_time_seconds INTEGER,
  commit_sha TEXT,
  workflow_run_id TEXT,
  project TEXT DEFAULT 'default',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at TEXT NOT NULL,
  resolved_at TEXT,
  deploy_id INTEGER REFERENCES deployments(id),
  resolution_type TEXT,  -- 'rollback', 'hotfix', 'config_change'
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_deployments_timestamp ON deployments(timestamp);
CREATE INDEX idx_deployments_project ON deployments(project);
```

### Query DORA Metrics

```sql
-- Deployment frequency (last 30 days)
SELECT date(timestamp) as day, COUNT(*) as deploys
FROM deployments
WHERE timestamp > datetime('now', '-30 days')
  AND result = 'success'
GROUP BY date(timestamp);

-- Change failure rate (last 30 days)
SELECT
  COUNT(CASE WHEN result IN ('failure', 'rollback') THEN 1 END) * 100.0 / COUNT(*) as failure_rate
FROM deployments
WHERE timestamp > datetime('now', '-30 days');

-- Mean time to recovery (last 30 days)
SELECT AVG(
  (julianday(resolved_at) - julianday(started_at)) * 24 * 60
) as avg_mttr_minutes
FROM incidents
WHERE started_at > datetime('now', '-30 days')
  AND resolved_at IS NOT NULL;

-- Lead time percentiles (last 30 days)
SELECT
  MIN(lead_time_seconds) / 60.0 as min_minutes,
  AVG(lead_time_seconds) / 60.0 as avg_minutes,
  MAX(lead_time_seconds) / 60.0 as max_minutes
FROM deployments
WHERE timestamp > datetime('now', '-30 days')
  AND result = 'success';
```

## Additional Metrics

Beyond DORA, track:

| Metric | Purpose |
|--------|---------|
| Pipeline duration per stage | Identify bottlenecks |
| Flaky test rate | Test reliability |
| Bundle size over time | Performance regression |
| Cost per deployment | Workers request/CPU billing |
| Security findings trend | Supply chain health |
| Preview deploy time | Developer experience |

## Dashboard

Build a simple SvelteKit dashboard on Cloudflare Pages that queries the
metrics Worker. Display:

1. DORA scorecard (4 metrics with elite/high/medium/low rating)
2. Deployment timeline (last 30 days)
3. Lead time trend
4. Failure rate trend
5. Active incidents

This is a future __COMPANY_NAME__ product feature — track in the roadmap.
