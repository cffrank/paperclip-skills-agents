# Paperclip Skills & Agents

A complete IT department for [Paperclip AI](https://paperclipai.com) agent orchestration, built for a **Cloudflare-first stack** (Workers, D1, R2, Pages, SvelteKit).

25 skills and 6 agents that cover application development, quality assurance, DevOps, AI/ML, database administration, and technical leadership — all configured for Paperclip's heartbeat protocol and ticket-based delegation.

## What's included

### 6 Agents (4 files each)

| Agent | Model | Budget | Heartbeat | Role |
|-------|-------|--------|-----------|------|
| **CTO** | Sonnet | $50/mo | 10 min | Strategy, delegation, deploy approval, budget governance |
| **App Dev Lead** | Sonnet | $30/mo | 10 min | SvelteKit frontend + Workers API development |
| **QA Lead** | Haiku | $20/mo | Daily + wake | Testing, visual QA, accessibility, quality gates |
| **DevOps Lead** | Sonnet | $30/mo | 10 min | CI/CD, infrastructure, deployments, monitoring |
| **AI/ML Lead** | Sonnet | $30/mo | 10 min | Voice AI, Workers AI, RAG, prompt management |
| **DBA Lead** | Haiku | $15/mo | Daily + wake | D1 schema, query optimization, backups |

Each agent has: `AGENTS.md` (identity + rules), `HEARTBEAT.md` (execution checklist), `SOUL.md` (persona + voice), `TOOLS.md` (available tools + boundaries).

### 25 Skills

**Shared (all agents):** `cloudflare-stack`, `git-workflow`, `automation-governance`

**App Development:** `sveltekit-frontend`, `cf-workers-api`, `software-architect`, `code-reviewer`, `drizzle-schema`

**Quality Assurance:** `reality-checker`, `visual-qa`, `a11y-auditor`, `test-analyzer`, `api-tester`, `perf-benchmarker`, `e2e-playwright`

**DevOps:** `axiom-cicd` (+ 12 reference files), `devops-automator`, `sre-ops`, `security-engineer`

**AI/ML:** `ai-engineer`, `workers-ai`, `voice-ai-stack`, `data-remediation`

**Database:** `d1-optimizer`, `d1-time-travel`

### Deployment Plan

`ceo-issue-list.md` — 24 issues across 7 phases (~4 weeks) that bootstrap the entire IT department from scratch.

## Quick Start

```bash
git clone https://github.com/YOUR_ORG/paperclip-skills-agents.git
cd paperclip-skills-agents

# Replace placeholders with your company info
chmod +x setup.sh
./setup.sh

# Or use environment variables for CI
COMPANY_NAME="Acme Corp" CF_ACCOUNT_ID="your-id-here" ./setup.sh
```

## Stack

This repo is opinionated about the technology stack. The `cloudflare-stack` skill defines what's approved, forbidden, and requires an ADR:

| Layer | Technology |
|-------|-----------|
| Frontend | SvelteKit + Tailwind + shadcn-svelte |
| Runtime | Cloudflare Workers |
| Database | D1 (SQLite) + Drizzle ORM |
| Storage | R2 |
| Cache | KV |
| Auth | Clerk |
| Payments | Stripe |
| Email | Resend |
| Telephony | Telnyx |
| Voice AI | ElevenLabs Conversational AI |
| AI Inference | Workers AI + AI Gateway |
| CI/CD | GitHub Actions + Wrangler |
| Testing | Vitest (workerd pool) + Playwright |

## Repo Structure

```
├── agents/
│   ├── cto/         (AGENTS.md, HEARTBEAT.md, SOUL.md, TOOLS.md)
│   ├── app-dev/
│   ├── qa/
│   ├── devops/
│   ├── ai-ml/
│   └── dba/
├── skills/
│   ├── cloudflare-stack/SKILL.md
│   ├── sveltekit-frontend/SKILL.md
│   ├── axiom-cicd/
│   │   ├── SKILL.md
│   │   └── references/  (12 reference files)
│   └── ... (25 skills total)
├── adapter-configs.md    (Paperclip JSON configs for each agent)
├── ceo-issue-list.md     (24 deployment issues in 7 phases)
├── setup.sh              (replace placeholders with your company info)
└── README.md
```

## Credits

Several skills are adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT license, 64K+ stars) — rewritten from generic React/PostgreSQL/AWS patterns to Cloudflare-first SvelteKit/D1/Workers.

## License

MIT
