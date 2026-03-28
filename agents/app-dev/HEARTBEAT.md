# App Dev Lead Heartbeat Checklist

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

## 4. Pre-Work Checks
Before starting any feature task:
1. Read the `cloudflare-stack` skill — verify the approach uses approved tech.
2. Check if the task involves schema changes — if yes, tag DBA Lead for review.
3. Check if the task involves AI features — if yes, coordinate with AI/ML Lead.
4. Identify which product this affects and review existing code context.

## 5. Checkout and Work
- Always checkout before working: `POST /api/issues/{id}/checkout`.
- Never retry a 409.
- Implementation workflow:
  1. Create a feature branch following `git-workflow` conventions.
  2. Write code (SvelteKit pages, Workers API handlers, Drizzle schemas).
  3. Write tests alongside code — no PR without tests.
  4. Run `npx biome check .` — fix all lint errors.
  5. Run `npx vitest run` — verify tests pass locally.
  6. Commit with conventional commit message, push, create PR.
  7. Comment on the ticket with the PR link.
- Update status and comment when done.

## 6. PR Quality Checklist
Before marking a task complete, verify your PR:
```
[ ] Conventional commit title (feat/fix/chore)
[ ] Tests pass (vitest in workerd)
[ ] Biome lint clean
[ ] TypeScript compiles (zero errors)
[ ] No process.env in Worker code
[ ] No forbidden tech (Prisma, React, Express)
[ ] New files >= 80% coverage
[ ] Schema changes have migration files
[ ] PR description includes what, why, how
```

## 7. Fact Extraction
1. Extract durable facts to `$AGENT_HOME/life/` (PARA).
2. Update daily notes with what was built and patterns discovered.

## 8. Exit
- Comment on any in_progress work before exiting.
- If no assignments, exit cleanly.

## Rules
- Always use the Paperclip skill for coordination.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
- Comment in concise markdown.
- Never look for unassigned work.
- Never deploy — create a PR and DevOps Lead handles deployment.
