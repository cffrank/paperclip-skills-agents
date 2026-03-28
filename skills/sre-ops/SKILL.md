---
name: sre-ops
description: >
  Site reliability engineering for Cloudflare Workers. Covers SLOs, error budgets, golden
  signals, incident response, toil reduction, and capacity planning — all adapted for
  serverless edge compute. Use when defining SLOs, setting up monitoring, responding to
  incidents, analyzing reliability, or planning capacity. Triggers on: "SLO", "SLA",
  "error budget", "reliability", "incident", "outage", "latency", "uptime", "monitoring",
  "observability", "golden signals", "chaos engineering", "toil", or "on-call".
---

# SRE Operations Skill

Adapted from agency-agents `engineering-sre.md` — rewritten from
Kubernetes/Prometheus to Cloudflare Workers analytics and edge observability.

## Golden Signals for Workers

| Signal | What to measure | Source | Alert threshold |
|--------|----------------|--------|-----------------|
| Latency | Request duration (P50, P95, P99) | Workers analytics | P99 > 500ms |
| Traffic | Requests/second | Workers analytics | Sudden 5x spike or drop to 0 |
| Errors | 4xx + 5xx rate | Workers analytics | Error rate > 1% sustained 3min |
| Saturation | CPU time per request | Workers analytics | >50ms avg CPU time |

Workers-specific signals:
- **Cold start frequency**: How often new isolates spin up
- **Subrequest count**: D1/R2/KV calls per request (Workers limit: 50)
- **Wall time**: Total duration including I/O waits (limit: 30s paid)

## SLO Framework

```yaml
service: myapp-api
slos:
  availability:
    target: 99.9%
    window: 30d
    calculation: (1 - error_requests / total_requests) * 100
    error_budget_minutes: 43.2  # per 30 days

  latency:
    target: 99%
    window: 30d
    threshold: 200ms
    calculation: requests_under_200ms / total_requests * 100

  freshness:
    target: 99.5%
    window: 30d
    description: D1 read replicas within 30s of primary
```

### Error Budget Calculation

```
Monthly error budget = (1 - SLO) × total_minutes
99.9% SLO = 0.1% budget = 43.2 minutes/month
99.5% SLO = 0.5% budget = 216 minutes/month

Current burn rate = errors_this_period / error_budget
Burn rate > 1.0 = consuming budget faster than allowed
Burn rate > 3.0 = alert immediately
```

## Workers Analytics Queries

```bash
# Error rate over last hour
curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/analytics/stored" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{
    "query": "SELECT sum(requests) as total, sum(errors) as errors,
              (sum(errors) * 100.0 / sum(requests)) as error_pct
              FROM workers_analytics
              WHERE scriptName = \"myapp\"
              AND datetime > now() - interval \"1\" hour"
  }'

# P99 latency
# Use Workers Analytics Engine for custom latency histograms

# Subrequest breakdown
# Log in Worker: console.log(JSON.stringify({ d1_calls: N, kv_calls: M }))
# Query via Logpush or Workers Trace Events
```

## Incident Response Runbook

### Severity Levels

| Level | Criteria | Response time | Example |
|-------|----------|--------------|---------|
| SEV1 | Service down, data loss risk | 15 min | Workers returning 500 globally |
| SEV2 | Degraded, users affected | 30 min | P99 latency >2s, error rate >5% |
| SEV3 | Minor impact, workaround exists | 4 hours | One endpoint slow, non-critical |
| SEV4 | No user impact | Next business day | Monitoring gap, tech debt |

### SEV1/SEV2 Response Flow

```
1. Acknowledge alert (Slack/PagerDuty)
2. Check Workers analytics dashboard — is it global or regional?
3. Check recent deployments — was something just deployed?
4. If recent deploy: rollback immediately (wrangler rollback)
5. If not deploy-related: check D1 status, R2 status, Clerk status
6. Mitigate (rollback, disable feature flag, scale down traffic)
7. Communicate status to stakeholders
8. Root cause analysis after mitigation
9. Write incident report within 48 hours
```

### Post-Incident Report Template

```markdown
# Incident Report: [Title]
**Severity**: SEV[1-4]
**Duration**: [start] — [end] ([X] minutes)
**Impact**: [users affected, error rate, revenue impact]

## Timeline
- HH:MM — Alert fired: [description]
- HH:MM — Acknowledged by: [person/agent]
- HH:MM — Root cause identified: [cause]
- HH:MM — Mitigation applied: [action]
- HH:MM — Resolved

## Root Cause
[Technical explanation]

## What Went Well
- [e.g., Alert fired within 2 minutes]

## What Went Wrong
- [e.g., Rollback took 10 minutes because version wasn't pinned]

## Action Items
- [ ] [Preventive action] — Owner: [agent] — Due: [date]
```

## Toil Reduction

Toil = manual, repetitive, automatable, no lasting value. Track and eliminate:

| Toil | Frequency | Fix |
|------|-----------|-----|
| Manual deployments | Weekly | axiom-cicd automates via GitHub Actions |
| Checking deployment health | Every deploy | Automated smoke tests + health gates |
| D1 migration verification | Every deploy | Migration tests in CI |
| Secret rotation | Monthly | Scheduled workflow + Proton Pass |
| Drift checking | Ad-hoc | Daily scheduled drift-check.yml |

## Capacity Planning (Workers-Specific)

Workers auto-scale — no capacity planning for compute. Focus on:

- **D1 row limits**: Monitor table sizes, plan for sharding if >10GB
- **R2 storage costs**: Track growth rate, set lifecycle policies
- **KV key count**: Monitor namespace size
- **Workers request limits**: Free plan: 100K/day. Paid: unlimited.
- **Subrequest limits**: 50 per request (D1 + R2 + KV + fetch combined)

## Relationship to Other Skills

- **Loaded by**: DevOps Lead agent
- **Feeds into**: `axiom-cicd` (health gates use SLO thresholds), `reality-checker` (Gate 4)
- **Monitors output of**: all deployed Workers
