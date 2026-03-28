---
name: axiom-cicd
description: >
  Cloudflare-first CI/CD skill for __COMPANY_NAME__ projects. Provides deployment knowledge,
  workflow templates, and reference material for a DevOps agent operating on Cloudflare
  Workers, D1, R2, and Pages via GitHub Actions. Load this skill whenever deploying code,
  setting up CI/CD pipelines, creating GitHub Actions workflows, running Wrangler commands,
  managing D1 migrations, uploading R2 assets, configuring preview deployments, performing
  rollbacks, setting up progressive delivery (canary/gradual rollouts), drift detection,
  security scanning, DORA metrics tracking, or any deployment-related task targeting
  Cloudflare infrastructure. Also triggers on: "deploy", "rollback", "wrangler", "pipeline",
  "CI/CD", "GitHub Actions", "preview URL", "canary deploy", "gradual rollout", "D1
  migration", "R2 upload", "bundle size", "deploy to staging", "deploy to production",
  "health check", "drift detection", or "DORA metrics".
---

# __COMPANY_NAME__ CI/CD Skill

Deployment knowledge and workflow templates for a single DevOps agent running
Cloudflare-first CI/CD. Every deployment is a hypothesis validated against
production metrics — not a binary pass/fail.

## Pipeline Flow

```
PR opened / push to branch
        │
        ▼
┌──────────────────┐
│  1. Review       │ ← Check Workers runtime compat + Cloudflare-specific rules
└────────┬─────────┘
         ▼
┌──────────────────┐
│  2. Secure       │ ← Semgrep + Gitleaks + npm audit + wrangler.toml validation
└────────┬─────────┘
         ▼
┌──────────────────┐
│  3. Test         │ ← Vitest + @cloudflare/vitest-pool-workers (workerd runtime)
└────────┬─────────┘
         ▼
┌──────────────────┐
│  4. Build+Deploy │ ← D1 migrations → Wrangler deploy → R2 assets → Pages preview
└────────┬─────────┘
         ▼
┌──────────────────┐
│  5. Ship         │ ← Gradual rollout (1%→10%→50%→100%) with health gates
└────────┬─────────┘
         ▼
┌──────────────────┐
│  6. Guard        │ ← Rollback on SLO breach, drift detection, DORA tracking
└──────────────────┘
```

## Reference Lookup Table

When a task comes in, read the relevant reference file(s) before acting.

| Task | Reference file to read |
|---|---|
| Set up CI/CD for a project | `references/workflows.md` |
| Deploy to staging or production | `references/deploy.md` |
| Review a PR for Cloudflare issues | `references/review.md` |
| Run tests in CI | `references/testing.md` |
| Roll back a deploy | `references/rollback.md` |
| Set up canary / gradual rollout | `references/progressive.md` |
| Check for config drift | `references/drift.md` |
| Add security scanning | `references/security.md` |
| Show or track DORA metrics | `references/metrics.md` |
| Set up D1 migrations in CI | `references/d1-migrations.md` |
| Upload assets to R2 in CI | `references/r2-assets.md` |
| Create preview deployments | `references/previews.md` |

Multiple references often compose — a full production deploy needs
`d1-migrations.md` → `deploy.md` → `progressive.md` → `rollback.md`.

## Core Rules (always follow)

1. **D1 migrations run BEFORE code deployment.** Always. No exceptions.
2. **Pin Wrangler version** in every workflow. Never use `latest` or wildcards.
3. **Scope API tokens narrowly** — "Edit Cloudflare Workers" template, restricted
   to specific account/zone. Separate tokens for R2 operations.
4. **Tests run in workerd**, not Node.js. Use `@cloudflare/vitest-pool-workers`.
5. **Every PR gets a preview URL** posted as a comment.
6. **Rollback is instant but data is not reverted.** D1 schema, KV data, R2 objects
   survive rollback. Design for backward compatibility.
7. **Expand-and-contract for breaking schema changes.** Add nullable → deploy
   dual-write → migrate data → deploy read-from-new → drop old.
8. **Secrets never appear in logs.** Use `--var` for non-sensitive config, GitHub
   encrypted secrets for everything else.
9. **Never cancel a deploy mid-flight.** `cancel-in-progress: false` for deploy jobs.
10. **Never use Prisma with D1.** Drizzle + Wrangler native migrations only.

## Environment Matrix

| Branch | Workers env | D1 database | R2 bucket | Pages | Purpose |
|--------|-------------|-------------|-----------|-------|---------|
| `dev` | `dev` | `myapp-dev` | `myapp-dev` | Preview | Development |
| `staging` | `staging` | `myapp-staging` | `myapp-staging` | Preview | QA |
| `main` | `production` | `myapp-prod` | `myapp-prod` | Production | Live |

Promotion flow: `dev → staging → main` via PR.

## Quick Start: Generate a Full Pipeline

When asked to "set up CI/CD", read `references/workflows.md` and generate:

1. `.github/workflows/ci.yml` — lint + test + security scan on every PR
2. `.github/workflows/deploy-preview.yml` — preview deployment on PR
3. `.github/workflows/deploy-staging.yml` — deploy on merge to `staging`
4. `.github/workflows/deploy-production.yml` — deploy on merge to `main`
5. `.github/workflows/rollback.yml` — manual rollback trigger
6. `.github/workflows/drift-check.yml` — scheduled drift detection (daily)

## Deploy Sequence (always follow this order)

```
1. Lint + Type Check          ─┐
2. Security Scan               ├── Parallel
3. Bundle Size Check          ─┘
4. Run Tests (Vitest in workerd)   ── Sequential from here
5. D1 Migrations (if pending)
6. Build
7. Deploy Worker/Pages
8. Smoke Test
9. (Production) Gradual Rollout with Health Gates
```

## Rollback Decision Matrix

| Signal | Threshold | Action |
|--------|-----------|--------|
| Error rate > 1% | Sustained 5 min post-deploy | Auto-rollback |
| Error rate > 5% | Any time | Immediate rollback |
| P99 latency > 500ms | Sustained 3+ min | Auto-rollback |
| Health endpoint down | 2 consecutive checks | Immediate rollback |
| Manual trigger | Operator decision | Manual rollback |

**Rollback does NOT revert:** D1 schema, KV data, R2 objects, Durable Object
migrations, secrets, or routes. Only Worker code is reverted.

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `CLOUDFLARE_API_TOKEN` | Wrangler deploy (Workers + Pages) |
| `CLOUDFLARE_ACCOUNT_ID` | Account identifier |
| `CLOUDFLARE_R2_ACCESS_KEY_ID` | R2 uploads (separate token) |
| `CLOUDFLARE_R2_SECRET_ACCESS_KEY` | R2 uploads (separate token) |
| `ANTHROPIC_API_KEY` | Claude Code Action (AI review, optional) |

App runtime secrets (Clerk, Stripe, Resend) are set via `wrangler secret put`,
not in workflow files.

## Escalation Rules

Escalate to CTO (or human operator) when:

- Destructive D1 migration detected (DROP/RENAME column)
- 3+ consecutive deploy failures
- Drift detected that can't be auto-remediated
- New Worker bindings or route changes in a PR
- Budget approaching 95% utilization
