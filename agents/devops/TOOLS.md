# DevOps Lead Tools

## Paperclip API
Same endpoints as CTO — inbox, checkout, checkin, comment, update status.

## Skills
| Skill | When to use |
|---|---|
| `paperclip` | Coordination, ticket management |
| `axiom-cicd` | Deployment workflows, references (12 files covering deploy, rollback, progressive, etc.) |
| `devops-automator` | Wrangler CLI reference, provisioning, wrangler.toml templates |
| `sre-ops` | SLO definitions, golden signals, incident response, error budgets |
| `security-engineer` | Security scanning config, threat model, supply chain hardening |
| `cloudflare-stack` | Verify infrastructure decisions against approved stack |
| `git-workflow` | CI-friendly branching, PR conventions |

## CLI Tools (Primary — you use these directly)
| Tool | Purpose |
|---|---|
| `wrangler deploy` | Deploy Workers to Cloudflare |
| `wrangler deploy --env staging` | Deploy to specific environment |
| `wrangler deploy --dry-run` | Validate without deploying |
| `wrangler pages deploy dist` | Deploy Pages |
| `wrangler d1 create` | Create D1 database |
| `wrangler d1 migrations apply --remote` | Apply D1 migrations |
| `wrangler d1 time-travel info` | Check backup recovery points |
| `wrangler d1 time-travel restore` | Point-in-time recovery |
| `wrangler d1 time-travel bookmark` | Create named recovery point |
| `wrangler r2 bucket create` | Create R2 bucket |
| `wrangler kv namespace create` | Create KV namespace |
| `wrangler secret put` | Set encrypted secrets |
| `wrangler secret list` | List secret names |
| `wrangler versions list` | List deployed versions |
| `wrangler versions upload` | Upload without deploying (for gradual rollout) |
| `wrangler versions deploy --percentage N` | Gradual traffic split |
| `wrangler rollback` | Instant rollback to previous version |
| `wrangler tail` | Stream live Worker logs |
| `git` | Branching, history, diffs |

## Cloudflare API (for monitoring and drift detection)
| Endpoint | Purpose |
|---|---|
| `/workers/analytics/stored` | Query error rates, request counts, latency |
| `/workers/scripts/{name}` | Get deployed Worker details |
| `/workers/scripts/{name}/settings` | Get bindings, routes, compatibility date |

## MCP Servers
| Server | Purpose |
|---|---|
| Cloudflare Developer Platform | `workers_list`, `d1_databases_list`, `r2_buckets_list` |
| GitHub | Workflow status, PR management, issue creation |
| Slack | Deploy notifications, incident alerts |

## Tools You Do NOT Use
| Tool | Operated by |
|---|---|
| Application code (src/) | App Dev Lead |
| `npx playwright test` | QA Lead |
| `npx drizzle-kit generate` | App Dev Lead |
| ElevenLabs / Telnyx | AI/ML Lead |
| Clerk / Stripe dashboards | App Dev Lead |

## Memory (PARA)
Use `para-memory-files` skill. Daily notes: `$AGENT_HOME/memory/YYYY-MM-DD.md`.

## Cloudflare Account
- Account ID: `__CF_ACCOUNT_ID__`
- Secrets: Proton Pass → GitHub Secrets → `wrangler secret put`

## References
- `$AGENT_HOME/HEARTBEAT.md` — execution checklist
- `$AGENT_HOME/SOUL.md` — persona and voice
