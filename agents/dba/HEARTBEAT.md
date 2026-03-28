# DBA Lead Heartbeat Checklist

Run this checklist on every heartbeat.

## 1. Identity and Context
- `GET /api/agents/me` — confirm your id, role, budget, chainOfCommand.
- Check wake context: `PAPERCLIP_TASK_ID`, `PAPERCLIP_WAKE_REASON`, `PAPERCLIP_WAKE_COMMENT_ID`.

## 2. Local Planning Check
1. Read today's plan from `$AGENT_HOME/memory/YYYY-MM-DD.md`.
2. Review planned items: completed, blocked, next.
3. Escalate blockers to CTO.

## 3. Get Assignments
- `GET /api/agents/me/inbox-lite`
- Prioritize: `in_progress` first, then `todo`. Skip `blocked` unless you can unblock it.
- If `PAPERCLIP_TASK_ID` is set and assigned to you, prioritize that task.

## 4. Determine Task Type
| Task type | Workflow |
|---|---|
| Migration review | Check for destructive changes → verify expand-and-contract → approve or reject |
| Query optimization | Run EXPLAIN QUERY PLAN → identify missing indexes → recommend fix |
| Schema design | Review table structure → check types, constraints, indexes → approve |
| Backup verification | Check D1 Time Travel availability → verify R2 backup recency |
| Data quality | Run validation queries → identify anomalies → use `data-remediation` if needed |
| Disaster recovery | Follow runbook in `d1-time-travel` skill |

## 5. Checkout and Work
- Always checkout before working: `POST /api/issues/{id}/checkout`.
- Never retry a 409.
- DBA workflow:
  1. Read the migration PR or schema change request.
  2. Check for destructive operations (DROP, RENAME) — require expand-and-contract.
  3. Run EXPLAIN QUERY PLAN on new queries against representative data.
  4. Verify indexes cover the query patterns.
  5. Check data type conventions (cents for money, ISO 8601 for dates, UUID for IDs).
  6. Comment with approval or required changes, citing specific issues.
- Update status and comment when done.

## 6. Migration Review Checklist
```
[ ] No DROP COLUMN or RENAME COLUMN without expand-and-contract plan
[ ] File numbering is sequential (zero-padded: 0001, 0002, not 1, 2)
[ ] New tables have created_at with DEFAULT (datetime('now'))
[ ] Foreign keys have ON DELETE CASCADE where appropriate
[ ] Indexes exist for WHERE clause columns
[ ] No more than 5 indexes per table
[ ] No SELECT * in associated application code
[ ] Money stored as INTEGER (cents), not REAL
[ ] Dates stored as TEXT (ISO 8601), not INTEGER (Unix)
[ ] IDs stored as TEXT (UUID), not auto-increment (for distributed systems)
```

## 7. Weekly Backup Check (if on weekly heartbeat)
1. Run `wrangler d1 time-travel info` for each production database.
2. Verify R2 backup exists for the past 7 days.
3. If any backup is missing, create a ticket for DevOps Lead.
4. Log results in daily notes.

## 8. Fact Extraction
1. Extract durable facts to `$AGENT_HOME/life/` (PARA).
2. Update daily notes with schema changes reviewed and optimization findings.

## 9. Exit
- Comment on any in_progress work before exiting.
- If no assignments, exit cleanly.

## Rules
- Always use the Paperclip skill for coordination.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
- Comment in concise markdown.
- Never look for unassigned work.
- Never approve destructive migrations without an expand-and-contract plan.
- Never run `wrangler d1 migrations apply` yourself — DevOps Lead executes, you review.
