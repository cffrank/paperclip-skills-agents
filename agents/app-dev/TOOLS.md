# App Dev Lead Tools

## Paperclip API
Same endpoints as CTO — see CTO TOOLS.md for full reference.
Key operations: inbox, checkout, checkin, comment, update status.

## Skills
| Skill | When to use |
|---|---|
| `paperclip` | Coordination, ticket management |
| `cloudflare-stack` | Verify tech choices against approved list |
| `sveltekit-frontend` | UI components, pages, layouts, load functions, form actions |
| `cf-workers-api` | API endpoints, Hono router, D1/R2/KV bindings, middleware |
| `drizzle-schema` | Schema definitions, relations, migration generation |
| `code-reviewer` | PR review checklists, anti-patterns |
| `git-workflow` | Branching, commits, PR workflow |
| `software-architect` | ADRs, architecture decisions |

## CLI Tools
| Tool | Purpose |
|---|---|
| `npm run dev` | Start SvelteKit dev server (localhost:5173) |
| `npm run build` | Build for production |
| `npx biome check .` | Lint and format |
| `npx vitest run` | Run tests in workerd |
| `npx vitest run --coverage` | Run tests with coverage report |
| `npx drizzle-kit generate` | Generate migration from schema changes |
| `npx drizzle-kit push` | Push schema to dev D1 (dev only, never CI) |
| `wrangler dev` | Local Worker dev with miniflare |
| `wrangler deploy --dry-run` | Validate without deploying |
| `git` | Branching, commits, PRs |

## Tools You Do NOT Use
| Tool | Operated by |
|---|---|
| `wrangler deploy` (production) | DevOps Lead |
| `wrangler d1 migrations apply --remote` | DevOps Lead |
| `npx playwright test` | QA Lead |
| ElevenLabs / Telnyx dashboards | AI/ML Lead |

## Memory (PARA)
Use `para-memory-files` skill. Daily notes: `$AGENT_HOME/memory/YYYY-MM-DD.md`.

## References
- `$AGENT_HOME/HEARTBEAT.md` — execution checklist
- `$AGENT_HOME/SOUL.md` — persona and voice
