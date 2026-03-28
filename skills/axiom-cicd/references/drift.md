# Drift Detection

## What is Drift?

Drift occurs when deployed Cloudflare configuration diverges from the
desired state defined in Git. Common causes:

- Manual changes via Cloudflare dashboard
- `wrangler` commands run locally without committing config changes
- API calls from other tools modifying Workers settings
- Secrets added/changed outside CI/CD

## What to Monitor

| Resource | Check method | Drift signal |
|----------|-------------|--------------|
| Worker code | Compare deployed hash vs Git hash | Code mismatch |
| Routes | API vs `wrangler.toml` routes | Route mismatch |
| Bindings | API vs `wrangler.toml` bindings | Missing/extra bindings |
| Environment vars | API vs `wrangler.toml` [vars] | Value mismatch |
| Cron triggers | API vs `wrangler.toml` triggers | Schedule mismatch |
| D1 bindings | API vs `wrangler.toml` d1_databases | DB reference mismatch |
| R2 bindings | API vs `wrangler.toml` r2_buckets | Bucket mismatch |
| Compatibility date | API vs `wrangler.toml` | Date mismatch |

## Implementation

### Scheduled GitHub Action

See `references/workflows.md` for the `drift-check.yml` workflow.
Runs daily at 6am UTC. Can also be triggered manually.

### Using Cloudflare MCP (Preferred)

When the Cloudflare Developer Platform MCP is connected, use it for
read operations instead of raw API calls:

```
- workers_list → Get all deployed Workers
- workers_get_worker → Get specific Worker details
- d1_databases_list → Verify D1 bindings
- r2_buckets_list → Verify R2 bindings
```

Compare MCP results against `wrangler.toml` parsed from Git.

### Drift Check Script

```bash
#!/bin/bash
# scripts/check-drift.sh

set -euo pipefail

WORKER_NAME=$(grep '^name' wrangler.toml | head -1 | cut -d'"' -f2)
API="https://api.cloudflare.com/client/v4"
AUTH="Authorization: Bearer $CLOUDFLARE_API_TOKEN"

echo "Checking drift for Worker: $WORKER_NAME"

# 1. Check if Worker exists
WORKER_INFO=$(curl -s -H "$AUTH" \
  "$API/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/$WORKER_NAME")

if [ "$(echo $WORKER_INFO | jq -r '.success')" != "true" ]; then
  echo "ERROR: Worker $WORKER_NAME not found in account"
  exit 1
fi

# 2. Compare compatibility date
DEPLOYED_COMPAT=$(echo $WORKER_INFO | jq -r '.result.compatibility_date // "none"')
EXPECTED_COMPAT=$(grep 'compatibility_date' wrangler.toml | cut -d'"' -f2)

if [ "$DEPLOYED_COMPAT" != "$EXPECTED_COMPAT" ]; then
  echo "DRIFT: compatibility_date — deployed=$DEPLOYED_COMPAT, expected=$EXPECTED_COMPAT"
  DRIFT_FOUND=true
fi

# 3. Compare bindings
DEPLOYED_BINDINGS=$(curl -s -H "$AUTH" \
  "$API/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/$WORKER_NAME/settings" \
  | jq -r '.result.bindings')

echo "Deployed bindings: $DEPLOYED_BINDINGS"
echo "Expected: (parsed from wrangler.toml)"

# 4. Report
if [ "${DRIFT_FOUND:-false}" == "true" ]; then
  echo "::error::Configuration drift detected"
  exit 1
else
  echo "✅ No drift detected"
fi
```

## Auto-Remediation (Optional)

When drift is detected, the agent can auto-fix by redeploying from Git:

```yaml
- name: Auto-remediate drift
  if: failure()
  uses: cloudflare/wrangler-action@v3
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    wranglerVersion: '3.99.0'
    command: deploy
```

Enable auto-remediation cautiously. Default to alert-only mode and let
the operator decide whether to auto-fix or investigate first.

## Preventing Drift

1. **Lock down dashboard access.** Use API tokens with deploy-only scope.
2. **Never run `wrangler deploy` locally** for production. Always go through CI/CD.
3. **Audit API token usage.** Rotate tokens regularly.
4. **Enforce branch protection.** Require PRs for all changes to `main`.
