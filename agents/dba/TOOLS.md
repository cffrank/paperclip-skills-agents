# DBA Lead Tools

## Paperclip API
Same endpoints as CTO — inbox, checkout, checkin, comment, update status.

## Skills
| Skill | When to use |
|---|---|
| `paperclip` | Coordination, ticket management |
| `d1-optimizer` | EXPLAIN QUERY PLAN, indexing strategies, N+1 elimination, batch ops |
| `drizzle-schema` | Schema definitions, relations, type mapping, migration generation |
| `d1-time-travel` | Backups, point-in-time recovery, disaster recovery runbooks |
| `data-remediation` | Data quality validation, anomaly detection, bulk fixes |
| `cloudflare-stack` | Database conventions (cents, ISO dates, UUIDs) |

## CLI Tools
| Tool | Purpose |
|---|---|
| `wrangler d1 execute MY_DB --command "..."` | Run ad-hoc queries for analysis |
| `wrangler d1 execute MY_DB --file seed.sql` | Run SQL files |
| `wrangler d1 migrations list MY_DB --remote` | Check migration status |
| `wrangler d1 time-travel info MY_DB` | Check backup recovery points |
| `wrangler d1 time-travel bookmark MY_DB` | Create named recovery point |
| `npx drizzle-kit generate` | Generate migration from schema diff (review only) |
| `git diff migrations/` | Review migration file changes in PRs |

## Tools You Do NOT Use
| Tool | Operated by |
|---|---|
| `wrangler d1 migrations apply --remote` | DevOps Lead executes |
| `wrangler d1 time-travel restore` | DevOps Lead executes (you advise) |
| `wrangler deploy` | DevOps Lead |
| Application code (src/) | App Dev Lead |
| `npx drizzle-kit push` | App Dev Lead (dev only) |

## Useful Queries for Auditing
```sql
-- List all tables and row counts
SELECT name, (SELECT count(*) FROM pragma_table_info(name)) as columns
FROM sqlite_master WHERE type='table'
AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name != 'd1_migrations';

-- List all indexes
SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index';

-- Check for tables missing created_at
SELECT name FROM sqlite_master WHERE type='table'
AND name NOT IN (SELECT DISTINCT tbl_name FROM pragma_table_info(name) WHERE name='created_at')
AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%';

-- Find largest tables
SELECT name, (SELECT count(*) FROM [name]) as rows FROM sqlite_master WHERE type='table';
```

## Memory (PARA)
Use `para-memory-files` skill. Daily notes: `$AGENT_HOME/memory/YYYY-MM-DD.md`.

## Key Files to Track
- `migrations/*.sql` — all migration files
- `src/lib/server/schema.ts` — Drizzle schema definitions
- `drizzle.config.ts` — Drizzle configuration
- `wrangler.toml` — D1 database bindings per environment

## References
- `$AGENT_HOME/HEARTBEAT.md` — execution checklist
- `$AGENT_HOME/SOUL.md` — persona and voice
