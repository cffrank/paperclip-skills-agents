---
name: automation-governance
description: >
  Governance framework for AI agent automation in Paperclip. Covers budget enforcement,
  runaway prevention, approval gates, agent safety rails, cost tracking, and autonomous
  operation boundaries. Use when configuring agent budgets, setting up approval workflows,
  defining agent boundaries, preventing runaway costs, or auditing agent behavior. Triggers
  on: "budget", "runaway", "governance", "approval gate", "agent safety", "cost control",
  "autonomous", "guardrails", "circuit breaker", "agent limit", or "spending cap".
---

# Automation Governance Skill

Adapted from agency-agents `specialized-automation-governor.md` — tailored
for Paperclip's budget enforcement and Cloudflare API cost model.

## Core Principle

Autonomy is a privilege, not a default. Every agent operates within explicit
boundaries. When boundaries are exceeded, the agent stops and escalates.

## Budget Framework

### Per-Agent Monthly Budgets

| Role | Budget (cents) | USD | Rationale |
|------|----------------|-----|-----------|
| CTO | 5,000 | $50 | Strategy, delegation, hiring decisions |
| App Dev Lead | 3,000 | $30 | Code generation, refactoring |
| QA Lead | 2,000 | $20 | Testing (mostly Haiku, lower cost) |
| DevOps Lead | 3,000 | $30 | CI/CD operations, deploy monitoring |
| AI/ML Lead | 3,000 | $30 | Model inference, RAG development |
| DBA Lead | 1,500 | $15 | Schema review, query optimization |
| **Company total** | 17,500 | $175 | Ceiling for all agents combined |

### Budget Enforcement Rules

```
80% consumed → Agent focuses on critical tasks only
                No new experiments, explorations, or nice-to-haves
                Log warning to Paperclip audit

95% consumed → Agent completes current task, then pauses
                Notification to board (you)
                No new task checkout until next period

100% consumed → Agent auto-paused by Paperclip
                 Cannot checkout tasks, cannot run heartbeats
                 Board must approve budget increase or wait for reset
```

### Tracking Costs

Paperclip tracks token usage per agent per task. Monitor via:
```bash
pnpm paperclipai agent list          # See budget utilization
pnpm paperclipai cost-report         # Detailed cost breakdown
```

In the Paperclip dashboard: Company → Agents → [agent] → Cost tab.

## Approval Gates

Actions requiring board (human) approval before execution:

### Always Require Approval
- Deploying to production (DevOps Lead proposes, board approves)
- Destructive D1 migrations (DROP/RENAME column)
- Creating new Cloudflare resources (D1 databases, R2 buckets)
- Changing wrangler.toml routes or bindings
- Modifying GitHub Actions workflow files
- Any action costing >$5 in a single execution

### Auto-Approved (Within Budget)
- Deploying to dev/staging
- Running tests
- Code review comments
- Creating branches and PRs
- Non-destructive D1 migrations (ADD column)
- Reading Cloudflare analytics

### Configuring in Paperclip

```json
{
  "runtimeConfig": {
    "governance": {
      "requireApprovalFor": [
        "production_deploy",
        "destructive_migration",
        "resource_creation",
        "workflow_modification"
      ],
      "autoApprove": [
        "dev_deploy",
        "staging_deploy",
        "test_execution",
        "code_review",
        "branch_creation"
      ]
    }
  }
}
```

## Runaway Prevention

### Circuit Breakers

```
Retry limit: 3 attempts per task
  After 3 failures → pause task, create escalation issue

Loop detection: If agent produces >10 commits on same task
  → Pause, notify board, likely stuck in fix-break-fix cycle

Cost spike: If single task burns >20% of monthly budget
  → Pause task, require board review before continuing

Time limit: Tasks open >48 hours without progress
  → Escalate to manager agent, reassign or break down
```

### Heartbeat Governance

```json
{
  "heartbeat": {
    "intervalSec": 600,
    "maxConcurrentRuns": 1,
    "cooldownSec": 10,
    "wakeOnDemand": true
  }
}
```

Rules:
- Never set `intervalSec` below 30 (spam risk, cost risk)
- `maxConcurrentRuns: 1` prevents duplicate work
- `cooldownSec: 10` prevents rapid re-triggering
- IC agents: 600s (10 min) heartbeat
- On-demand agents (QA, DBA): 86400s (daily) + `wakeOnDemand: true`

## Agent Boundaries

What agents CAN do autonomously:
- Read code, read D1, read R2, read KV
- Write code to branches (never directly to main)
- Run tests and linters
- Post PR comments and reviews
- Create issues and update tickets
- Deploy to dev/staging environments

What agents CANNOT do without approval:
- Deploy to production
- Modify production data
- Delete anything (files, databases, buckets)
- Change access controls or permissions
- Hire/fire other agents (CTO proposes, board approves)
- Spend more than allocated budget

What agents MUST NEVER do:
- Expose secrets in logs, comments, or code
- Bypass Paperclip's ticket system
- Modify their own AGENTS.md or skill files
- Disable monitoring or alerting
- Skip quality gates (tests, review, reality check)

## Audit Trail

Every agent action is logged by Paperclip:
- Task checkout/checkin with timestamps
- Token usage per task
- Tool calls with parameters
- Approval requests and responses
- Budget threshold events

Query audit logs:
```bash
pnpm paperclipai audit --agent-id <id> --since 2026-03-01
```

## Cost Optimization Strategies

1. **Use Haiku for routing agents** (QA, DBA) — 3x cheaper than Sonnet
2. **Use Sonnet for creative agents** (App Dev, AI/ML) — quality matters
3. **Batch similar tasks** — one heartbeat processes multiple small tickets
4. **Skip heartbeats when idle** — `wakeOnDemand: true` prevents empty runs
5. **Cache context** — Paperclip's persistent state avoids re-reading repos
6. **Set max_turns low for simple tasks** — 10 turns for review, 30 for coding

## Relationship to Other Skills

- **Loaded by**: CTO agent (primary), all agents (awareness)
- **Enforced by**: Paperclip runtime (budget enforcement is automatic)
- **Complements**: `axiom-cicd` (deploy approval gates)
