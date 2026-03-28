---
name: devops-automator
description: >
  Cloudflare infrastructure automation via Wrangler CLI. Covers Workers provisioning, D1
  database management, R2 bucket operations, KV namespace setup, Pages configuration,
  secret management, and wrangler.toml authoring. Use when provisioning infrastructure,
  configuring Wrangler, managing Cloudflare resources, or automating infrastructure tasks.
  Triggers on: "wrangler", "provision", "create database", "create bucket", "KV namespace",
  "wrangler.toml", "infrastructure", "secret", "environment variable", "binding", or
  "Cloudflare setup".
---

# DevOps Automator Skill

Adapted from agency-agents `engineering-devops-automator.md` — rewritten from
Docker/Kubernetes/Terraform to Wrangler CLI + Cloudflare infrastructure.

## Wrangler CLI Quick Reference

### Workers
```bash
wrangler init myapp                    # Scaffold new Worker
wrangler dev                           # Local dev (miniflare)
wrangler deploy                        # Deploy to production
wrangler deploy --env staging          # Deploy to environment
wrangler deploy --dry-run --outdir=dist # Validate without deploying
wrangler tail                          # Stream live logs
wrangler versions list                 # List deployed versions
wrangler versions upload               # Upload without deploying
wrangler versions deploy --percentage 10 # Gradual rollout
wrangler rollback                      # Roll back to previous
```

### D1
```bash
wrangler d1 create myapp-db             # Create database
wrangler d1 list                        # List databases
wrangler d1 execute myapp-db --command "SELECT 1" # Ad-hoc query
wrangler d1 execute myapp-db --file seed.sql       # Run SQL file
wrangler d1 migrations create myapp-db "add users" # New migration
wrangler d1 migrations apply myapp-db --remote     # Apply migrations
wrangler d1 migrations list myapp-db --remote      # Check status
wrangler d1 time-travel info myapp-db              # Backup info
wrangler d1 time-travel restore myapp-db --timestamp "2026-03-28T10:00:00Z"
```

### R2
```bash
wrangler r2 bucket create myapp-assets   # Create bucket
wrangler r2 bucket list                  # List buckets
wrangler r2 object put myapp-assets/key --file ./local-file  # Upload
wrangler r2 object get myapp-assets/key --file ./output       # Download
wrangler r2 object delete myapp-assets/key                    # Delete
```

### KV
```bash
wrangler kv namespace create CACHE         # Create namespace
wrangler kv namespace list                 # List namespaces
wrangler kv key put --namespace-id=ID key value  # Set key
wrangler kv key get --namespace-id=ID key        # Get key
wrangler kv key list --namespace-id=ID           # List keys
wrangler kv bulk put --namespace-id=ID data.json # Bulk import
```

### Secrets
```bash
wrangler secret put SECRET_NAME          # Set secret (prompts for value)
wrangler secret list                     # List secret names (not values)
wrangler secret delete SECRET_NAME       # Remove secret
echo "value" | wrangler secret put NAME  # Set from pipe (CI-friendly)
```

### Pages
```bash
wrangler pages project create myapp     # Create Pages project
wrangler pages deploy dist              # Deploy directory
wrangler pages deploy dist --branch staging  # Deploy to branch
wrangler pages deployment list          # List deployments
```

## wrangler.toml Template

```toml
name = "myapp"
main = "src/index.ts"
compatibility_date = "2026-03-01"
compatibility_flags = ["nodejs_compat"]

# Production bindings
[[d1_databases]]
binding = "DB"
database_name = "myapp-prod"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
migrations_dir = "migrations"

[[r2_buckets]]
binding = "ASSETS"
bucket_name = "myapp-assets"

[[kv_namespaces]]
binding = "CACHE"
id = "xxxxxxxx"

[ai]
binding = "AI"

[vars]
ENVIRONMENT = "production"
APP_NAME = "myapp"

# Staging
[env.staging]
name = "myapp-staging"
[env.staging.vars]
ENVIRONMENT = "staging"
[[env.staging.d1_databases]]
binding = "DB"
database_name = "myapp-staging"
database_id = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
migrations_dir = "migrations"
[[env.staging.r2_buckets]]
binding = "ASSETS"
bucket_name = "myapp-staging-assets"
[[env.staging.kv_namespaces]]
binding = "CACHE"
id = "yyyyyyyy"

# Dev
[env.dev]
name = "myapp-dev"
[env.dev.vars]
ENVIRONMENT = "dev"
[[env.dev.d1_databases]]
binding = "DB"
database_name = "myapp-dev"
database_id = "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"
migrations_dir = "migrations"
```

## New Project Setup Checklist

```bash
# 1. Create D1 databases
wrangler d1 create myapp-prod
wrangler d1 create myapp-staging
wrangler d1 create myapp-dev

# 2. Create R2 buckets
wrangler r2 bucket create myapp-assets
wrangler r2 bucket create myapp-staging-assets

# 3. Create KV namespaces
wrangler kv namespace create CACHE
wrangler kv namespace create CACHE --env staging

# 4. Set secrets
wrangler secret put CLERK_SECRET_KEY
wrangler secret put STRIPE_SECRET_KEY
wrangler secret put RESEND_API_KEY

# 5. Apply migrations
wrangler d1 migrations apply myapp-dev --remote
wrangler d1 migrations apply myapp-staging --remote --env staging
wrangler d1 migrations apply myapp-prod --remote

# 6. Deploy
wrangler deploy --env dev
wrangler deploy --env staging
wrangler deploy
```

## Environment Parity Rules

1. All environments share the same `wrangler.toml` file (different `[env.*]` sections)
2. All environments use the same `migrations_dir`
3. Never copy production secrets to dev/staging
4. Never share D1 database IDs across environments
5. Always test migrations in dev → staging before production

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| "No account id found" | Missing env var | Set `CLOUDFLARE_ACCOUNT_ID` |
| "Authentication error" | Bad/expired token | Regenerate API token with correct permissions |
| "Script too large" | Bundle > 10MB | Tree-shake, remove unused deps |
| "Too many subrequests" | >50 binding calls/request | Batch D1, cache in KV |
| "D1_ERROR: UNIQUE constraint" | Duplicate key | Handle with try/catch, return 409 |
| "wrangler.toml not found" | Wrong directory | Run from project root |

## Relationship to Other Skills

- **Loaded by**: DevOps Lead agent
- **Foundation for**: `axiom-cicd` (workflows call these commands)
- **Creates resources for**: `cf-workers-api`, `sveltekit-frontend`, `d1-optimizer`
