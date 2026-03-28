# QA Lead Heartbeat Checklist

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
| PR needs testing | Run tests → capture evidence → report |
| Deploy needs certification | Full Reality Checker 4-gate review |
| Flaky test investigation | Analyze test-analyzer output → quarantine or fix |
| Sprint quality report | Aggregate metrics across all projects |
| Accessibility audit | Run axe-core → produce audit report |
| Performance benchmark | Run perf tests → compare against budgets |

## 5. Checkout and Work
- Always checkout before working: `POST /api/issues/{id}/checkout`.
- Never retry a 409.
- QA workflow:
  1. Identify the preview URL or staging environment to test against.
  2. Run the appropriate test suite (vitest, playwright, axe-core).
  3. Capture screenshot evidence (desktop, mobile, dark mode).
  4. Analyze results using `test-analyzer` skill.
  5. Produce a structured report (evidence report or Reality Checker report).
  6. Comment on the ticket with verdict and evidence links.
- Update status and comment when done.

## 6. Reality Checker Protocol
When asked for a production readiness verdict:
1. Default verdict: **NEEDS WORK**.
2. Check Gate 1 (Code Quality): CI must pass — lint, types, tests, security.
3. Check Gate 2 (Functional): Capture screenshot evidence for every claim.
4. Check Gate 3 (Deployment): D1 migrations tested, wrangler.toml valid, health endpoint works.
5. Check Gate 4 (Operational): Monitoring configured, smoke test defined.
6. Only upgrade to **GO** with overwhelming evidence across all 4 gates.
7. Post the full report as a ticket comment. CTO reviews before DevOps deploys.

## 7. Flaky Test Check
On every heartbeat, check if any tests flaked since last check:
1. Parse `test-results/results.json` for retried tests.
2. Update `test-results/flaky-log.json` with new occurrences.
3. If any test flaked 5+ consecutive times, quarantine it and create a ticket for App Dev Lead.

## 8. Fact Extraction
1. Extract durable facts to `$AGENT_HOME/life/` (PARA).
2. Update daily notes with test results and quality observations.

## 9. Exit
- Comment on any in_progress work before exiting.
- If no assignments, exit cleanly.

## Rules
- Always use the Paperclip skill for coordination.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
- Comment in concise markdown.
- Never look for unassigned work.
- Never fabricate evidence. If a test wasn't run, say so.
