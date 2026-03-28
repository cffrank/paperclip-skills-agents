# Deployment Guide

## Deployment Sequence (Always Follow This Order)

```
1. Lint + Type Check
2. Run Tests (Vitest in workerd)
3. Security Scan
4. D1 Migrations (if any pending)
5. Build
6. Deploy Worker/Pages
7. Smoke Test
8. (Production only) Gradual Rollout with Health Gates
```

Steps 1–3 run in parallel. Steps 4–8 run sequentially.

## Wrangler Deploy Commands

### Workers

```bash
# Deploy to production (default environment)
wrangler deploy

# Deploy to specific environment
wrangler deploy --env staging

# Dry run (validate without deploying)
wrangler deploy --dry-run --outdir=dist

# Deploy specific version (gradual rollout)
wrangler versions upload        # Upload without deploying
wrangler versions deploy --percentage 10  # Split traffic
```

### Pages

```bash
# Deploy to Pages
wrangler pages deploy dist --project-name=myapp

# Deploy specific branch
wrangler pages deploy dist --project-name=myapp --branch=staging
```

## wrangler.toml Template

```toml
name = "myapp"
main = "src/index.ts"
compatibility_date = "2026-03-01"
compatibility_flags = ["nodejs_compat"]

# Bindings
[[d1_databases]]
binding = "DB"
database_name = "myapp-prod"
database_id = "xxx"
migrations_dir = "migrations"

[[r2_buckets]]
binding = "ASSETS"
bucket_name = "myapp-assets"

[[kv_namespaces]]
binding = "CACHE"
id = "xxx"

[vars]
ENVIRONMENT = "production"
APP_NAME = "myapp"

# Staging environment
[env.staging]
name = "myapp-staging"
[env.staging.vars]
ENVIRONMENT = "staging"

[env.staging.d1_databases]
binding = "DB"
database_name = "myapp-staging"
database_id = "yyy"

# Dev environment
[env.dev]
name = "myapp-dev"
[env.dev.vars]
ENVIRONMENT = "dev"

[env.dev.d1_databases]
binding = "DB"
database_name = "myapp-dev"
database_id = "zzz"
```

## GitHub Actions Best Practices

### Cache node_modules

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
- run: npm ci --frozen-lockfile
```

### Pin Wrangler Version

```yaml
- uses: cloudflare/wrangler-action@v3
  with:
    wranglerVersion: '3.99.0'  # Always pin, never use 'latest'
```

### Concurrency Control

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false  # NEVER cancel deploys mid-flight
```

For CI (lint/test), `cancel-in-progress: true` is fine.
For deploys, always `false` — canceling mid-deploy can leave state inconsistent.

### Smoke Tests

After every deploy, verify the health endpoint:

```yaml
- name: Smoke test
  run: |
    URL="${{ steps.deploy.outputs.deployment-url || 'https://myapp.workers.dev' }}"
    for i in 1 2 3; do
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL/health")
      if [ "$STATUS" == "200" ]; then
        echo "✅ Health check passed"
        exit 0
      fi
      echo "Attempt $i: status=$STATUS, retrying..."
      sleep 5
    done
    echo "::error::Health check failed after 3 attempts"
    exit 1
```

### Secret Injection

```yaml
# Non-sensitive config: use [vars] in wrangler.toml
# Sensitive config: use GitHub secrets + wrangler secret

- name: Set secrets
  run: |
    echo "${{ secrets.CLERK_SECRET_KEY }}" | wrangler secret put CLERK_SECRET_KEY
    echo "${{ secrets.STRIPE_SECRET_KEY }}" | wrangler secret put STRIPE_SECRET_KEY
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

## Monorepo Deploys

For projects with multiple Workers:

```yaml
strategy:
  matrix:
    worker:
      - { name: 'api', dir: 'apps/api' }
      - { name: 'webhook', dir: 'apps/webhook' }
      - { name: 'cron', dir: 'apps/cron' }

steps:
  - uses: cloudflare/wrangler-action@v3
    with:
      apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
      wranglerVersion: '3.99.0'
      workingDirectory: ${{ matrix.worker.dir }}
      command: deploy
```

Use path filters to deploy only changed Workers:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'apps/api/**'
      - 'packages/shared/**'
```
