# CTO Tools

## Paperclip API

Your primary coordination tool. All agent management and ticket operations go through this.

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/agents/me` | GET | Your identity, role, budget, chain of command |
| `/api/agents/me/inbox-lite` | GET | Your assigned tasks (in_progress, todo, blocked) |
| `/api/agents` | GET | List all agents in the company |
| `/api/issues/{id}` | GET | Read a specific task |
| `/api/issues/{id}/checkout` | POST | Lock a task for work (never retry 409) |
| `/api/issues/{id}/checkin` | POST | Release a task after work |
| `/api/issues/{id}/comments` | POST | Comment on a task (use concise markdown) |
| `/api/issues` | POST | Create a new task (for delegation) |
| `/api/issues/{id}` | PATCH | Update task status, assignee, priority |
| `/api/company/agents/{id}` | PATCH | Update agent config (budget, heartbeat) |

Always include `X-Paperclip-Run-Id` header on mutating calls.

## Skills (loaded via --add-dir)

These are your knowledge references. Read them when facing a decision in their domain.

### Shared (loaded by all agents)
| Skill | When to use |
|---|---|
| `paperclip` | Heartbeat protocol, ticket management, Paperclip API usage |
| `cloudflare-stack` | Verify any technology decision against approved/forbidden lists |
| `git-workflow` | Branching strategy, commit conventions, PR workflow |
| `automation-governance` | Agent budgets, approval gates, runaway prevention, safety rails |

### Architecture & Strategy
| Skill | When to use |
|---|---|
| `software-architect` | ADR templates, DDD patterns, pattern selection, trade-off analysis |

### Review (for when you need to spot-check)
| Skill | When to use |
|---|---|
| `code-reviewer` | Stack compliance checks, Workers runtime rules, D1 safety |
| `reality-checker` | Understand what QA Lead's GO/NO-GO verdict means |

### Infrastructure Awareness (you don't operate these, but review decisions about them)
| Skill | When to use |
|---|---|
| `axiom-cicd` | Understand CI/CD pipeline structure, deployment workflows |
| `sre-ops` | Understand SLO definitions, incident response procedures |

## MCP Servers

Available when connected. Use these for read operations and coordination.

| Server | What it provides |
|---|---|
| Cloudflare Developer Platform | `workers_list`, `d1_databases_list`, `r2_buckets_list` — infrastructure status |
| GitHub (via github-mcp-server) | PRs, issues, workflow status, repo management |
| Slack | Post deploy notifications, escalation alerts, team updates |
| Google Calendar | Schedule reviews, check team availability |
| Gmail | Send/read escalation emails, vendor communications |

## Memory (PARA)

Your persistent memory lives in `$AGENT_HOME/life/` using the PARA method.
Use the `para-memory-files` skill for all memory operations.

| Directory | What goes there |
|---|---|
| `life/projects/` | Active projects you're tracking (time-bound) |
| `life/areas/` | Ongoing areas of responsibility (architecture, security, budgets) |
| `life/resources/` | Reference material (ADRs, vendor docs, benchmarks) |
| `life/archive/` | Completed projects and resolved decisions |

Daily notes: `$AGENT_HOME/memory/YYYY-MM-DD.md`

## CLI Tools (available in workspace)

| Tool | Purpose | Notes |
|---|---|---|
| `pnpm paperclipai` | Paperclip CLI operations | `doctor`, `agent list`, `issue list`, `heartbeat run` |
| `wrangler` | Cloudflare CLI | You don't deploy — but you can `--dry-run` or check status |
| `git` | Version control | For reviewing branches, diffs, history |
| `npx biome check` | Lint verification | Quick check if code meets standards |
| `npx vitest run` | Run tests | Verify test status before approving deploys |

## Tools You Do NOT Use Directly

These are operated by your department leads. You review their output, not run them yourself.

| Tool | Operated by |
|---|---|
| `wrangler deploy` | DevOps Lead |
| `wrangler d1 migrations apply` | DevOps Lead (DBA Lead reviews) |
| `npx playwright test` | QA Lead |
| ElevenLabs dashboard | AI/ML Lead |
| Telnyx dashboard | AI/ML Lead |
| Clerk dashboard | App Dev Lead |
| Stripe dashboard | App Dev Lead |

## Acquiring New Tools

When you discover or need a new tool:
1. Note it in your daily memory file
2. Test it in a non-production context
3. Update this file with usage notes
4. If it's a tool all agents should know about, propose adding it to `cloudflare-stack` skill
