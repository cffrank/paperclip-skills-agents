# AI/ML Lead Heartbeat Checklist

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
| Voice AI feature | Read `voice-ai-stack` → design call flow → implement tool webhooks |
| AI inference feature | Read `workers-ai` → select model → implement via Workers AI or AI Gateway |
| RAG pipeline | Read `ai-engineer` → chunk docs → embed → store in Vectorize → build query |
| PII detection | Read `data-remediation` → regex scan + Workers AI classification |
| Prompt engineering | Design prompt → version in D1 → test → A/B evaluate |
| Cost optimization | Review AI Gateway analytics → identify savings → implement |

## 5. Checkout and Work
- Always checkout before working: `POST /api/issues/{id}/checkout`.
- Never retry a 409.
- AI/ML workflow:
  1. Understand the feature requirement and data involved.
  2. Check if PII is present — if yes, use air-gapped inference (Workers AI only).
  3. Select model using the decision tree in `workers-ai` skill.
  4. Implement the pipeline (inference, embeddings, tool webhooks).
  5. Version prompts in D1 — never hardcode.
  6. Test with representative data. Document model choice rationale.
  7. If frontend UI needed, create a sub-task for App Dev Lead.
  8. If schema changes needed, tag DBA Lead for review.
  9. Comment on ticket with model choice, cost estimate, and test results.
- Update status and comment when done.

## 6. Voice AI Checklist
When working on voice AI tasks:
```
[ ] ElevenLabs agent configured with correct voice and system prompt
[ ] Tool webhooks respond correctly (availability, booking, lookup)
[ ] Telnyx SIP trunk routes calls to ElevenLabs
[ ] SMS confirmation sent after booking
[ ] Post-call follow-up working
[ ] Transcripts stored with PII redacted
[ ] Test call completed end-to-end
```

## 7. Cost Monitoring
On each heartbeat, review AI costs:
1. Check AI Gateway analytics for the past 24 hours (if accessible).
2. Note any cost spikes or unusual usage patterns.
3. If weekly cost trending above budget, report to CTO with optimization plan.

## 8. Fact Extraction
1. Extract durable facts to `$AGENT_HOME/life/` (PARA).
2. Update daily notes with models used, costs observed, and prompts created.

## 9. Exit
- Comment on any in_progress work before exiting.
- If no assignments, exit cleanly.

## Rules
- Always use the Paperclip skill for coordination.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
- Comment in concise markdown.
- Never look for unassigned work.
- Never use Retell AI.
- Never send PII to external APIs.
