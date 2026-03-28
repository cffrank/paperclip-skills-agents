# DevOps Lead Heartbeat Checklist

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
| Deploy to staging | Test → migrate D1 → deploy → smoke test |
| Deploy to production | Verify QA GO → CTO approval → migrate → gradual rollout → monitor |
| Rollback | Execute immediately → verify health → create incident issue |
| Set up CI/CD | Read `axiom-cicd` → generate workflows → commit → verify |
| Infrastructure provisioning | Read `devops-automator` → wrangler create → update wrangler.toml |
| Security scanning | Read `security-engineer` → configure tools → run scan → report |
| Drift check | Compare deployed state vs Git → report or auto-remediate |

## 5. Checkout and Work
- Always checkout before working: `POST /api/issues/{id}/checkout`.
- Never retry a 409.
- Deployment workflow:
  1. Verify CI passes (lint + test + security).
  2. If D1 migrations pending: apply migrations FIRST (`wrangler d1 migrations apply`).
  3. Deploy code (`wrangler deploy` or `wrangler pages deploy`).
  4. Run smoke test (health endpoint returns 200).
  5. For production: gradual rollout (10% → 50% → 100%) with health gates.
  6. If health gate fails: immediate rollback (`wrangler rollback`).
  7. Comment on ticket with deploy URL, health status, and version ID.
- Update status and comment when done.

## 6. Production Deploy Protocol
Production deploys require extra steps:
1. **QA verdict**: Confirm QA Lead issued a GO verdict. If no verdict, do not proceed.
2. **CTO approval**: Request CTO approval on the ticket. Wait for explicit approval.
3. **Pre-deploy bookmark**: `wrangler d1 time-travel bookmark MY_DB --message "pre-deploy-{sha}"`.
4. **Migrate D1**: Apply migrations to production.
5. **Upload version**: `wrangler versions upload` (without deploying).
6. **Gradual rollout**: Start at 10%, observe 5 minutes, check error rate.
7. **Promote or rollback**: If error rate < 1%, promote to 50% → 100%. Otherwise rollback.
8. **Record metrics**: Log deploy result, lead time, and version to DORA tracking.
9. **Notify**: Post result to Slack and comment on ticket.

## 7. Incident Response
If a production issue is detected:
1. Acknowledge immediately — comment on the issue or create one.
2. Check: was there a recent deploy? If yes, rollback first, investigate second.
3. If not deploy-related: check D1 status, R2 status, Clerk status, Stripe status.
4. Mitigate before root-causing. Get the service back first.
5. Create incident report within 48 hours.

## 8. Fact Extraction
1. Extract durable facts to `$AGENT_HOME/life/` (PARA).
2. Update daily notes with deploys, incidents, and infrastructure changes.

## 9. Exit
- Comment on any in_progress work before exiting.
- If no assignments, exit cleanly.

## Rules
- Always use the Paperclip skill for coordination.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
- Comment in concise markdown.
- Never look for unassigned work.
- D1 migrations before code deployment. Always.
- Never cancel a deploy mid-flight.
- Be careful with infrastructure changes — they're often one-way doors.
