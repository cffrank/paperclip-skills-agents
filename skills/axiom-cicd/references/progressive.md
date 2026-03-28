# Progressive Delivery

## How Workers Gradual Rollouts Work

Cloudflare Workers supports native traffic splitting between versions.
No external tooling (Argo Rollouts, Flagger) needed.

### The Three-Step Pattern

```bash
# 1. Upload new version WITHOUT deploying
wrangler versions upload

# 2. Split traffic between old and new
wrangler versions deploy --percentage 10   # 10% to new, 90% to old

# 3. After health gate passes, promote
wrangler versions deploy --percentage 100  # 100% to new
```

### Version Affinity

During gradual rollouts, users might get different versions on consecutive
requests, causing asset mismatch (404s for JS/CSS bundles). Cloudflare
handles this with **version affinity** — once a user hits version A, they
stay on version A for that session.

For Workers serving static assets, this is critical. SvelteKit apps should
use content-hashed filenames (`app.abc123.js`) to avoid version conflicts.

## Rollout Progression

For production deploys, follow this logarithmic progression:

```
1%  → observe 2 min  → health gate check
5%  → observe 3 min  → health gate check
10% → observe 5 min  → health gate check
25% → observe 5 min  → health gate check
50% → observe 5 min  → health gate check
100% → deploy complete
```

At any stage, if health gate fails → automatic rollback to previous version.

## Health Gate Criteria

A health gate evaluates three signal categories:

### Application Signals
- **Error rate**: `4xx + 5xx responses / total responses < 1%`
- **Latency P99**: `< 500ms` (Workers are typically <50ms, so this is generous)
- **Success rate**: `200 responses / total responses > 99%`

### Workers Analytics Signals
Query via Cloudflare API:
```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/analytics/stored" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "query": "SELECT sum(requests) as total, sum(errors) as errors FROM workers_analytics WHERE scriptName = \"my-worker\" AND datetime > now() - interval \"5\" minute",
    "format": "json"
  }'
```

### Business Signals (optional)
- Custom metrics from your Worker (e.g., conversion rate, task completion)
- Logged to Workers Analytics Engine or external monitoring

## GitHub Actions Implementation

```yaml
gradual-deploy:
  runs-on: ubuntu-latest
  strategy:
    max-parallel: 1
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with: { node-version: '20', cache: 'npm' }
    - run: npm ci --frozen-lockfile

    - name: Upload version
      uses: cloudflare/wrangler-action@v3
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        wranglerVersion: '3.99.0'
        command: versions upload

    - name: Canary 10%
      uses: cloudflare/wrangler-action@v3
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        wranglerVersion: '3.99.0'
        command: versions deploy --percentage 10

    - name: Health gate (5 min)
      run: |
        sleep 300
        ERROR_RATE=$(curl -s "https://api.cloudflare.com/client/v4/accounts/${{ secrets.CLOUDFLARE_ACCOUNT_ID }}/workers/analytics/stored" \
          -H "Authorization: Bearer ${{ secrets.CLOUDFLARE_API_TOKEN }}" \
          -d '{"query":"SELECT sum(errors)/sum(requests)*100 as error_pct FROM workers_analytics WHERE scriptName = \"my-worker\" AND datetime > now() - interval \"5\" minute"}' \
          | jq -r '.result[0].error_pct // 0')
        echo "Error rate: ${ERROR_RATE}%"
        if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
          echo "::error::Error rate ${ERROR_RATE}% exceeds 1% threshold"
          exit 1
        fi

    - name: Promote to 50%
      uses: cloudflare/wrangler-action@v3
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        wranglerVersion: '3.99.0'
        command: versions deploy --percentage 50

    - name: Health gate (5 min)
      run: sleep 300
      # Repeat health check...

    - name: Promote to 100%
      uses: cloudflare/wrangler-action@v3
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        wranglerVersion: '3.99.0'
        command: versions deploy --percentage 100

    - name: Auto-rollback on failure
      if: failure()
      uses: cloudflare/wrangler-action@v3
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        wranglerVersion: '3.99.0'
        command: rollback

    - name: Alert on rollback
      if: failure()
      run: echo "::error::Gradual deploy failed — auto-rolled back"
```

## Geography-Targeted Canary (Advanced)

For global services, deploy to a single region first:

1. Use Workers routing rules to send traffic from one geo to the canary
2. Monitor that region's error rate for 15–30 minutes
3. If healthy, expand to all regions via full gradual rollout

This requires Cloudflare Enterprise or custom routing logic in a parent Worker.
