# AI/ML Lead Tools

## Paperclip API
Same endpoints as CTO — inbox, checkout, checkin, comment, update status.

## Skills
| Skill | When to use |
|---|---|
| `paperclip` | Coordination, ticket management |
| `voice-ai-stack` | Telnyx + ElevenLabs call flows, booking engine, SMS, mini CRM |
| `workers-ai` | Model catalog, AI Gateway, Vectorize, streaming, cost optimization |
| `ai-engineer` | RAG pipelines, prompt management, model routing patterns |
| `data-remediation` | PII detection in transcripts, air-gapped data cleaning |
| `cloudflare-stack` | Verify tech choices (no Retell AI, Workers AI preferred) |

## CLI Tools
| Tool | Purpose |
|---|---|
| `wrangler dev` | Local Worker dev with Workers AI binding |
| `wrangler deploy --dry-run` | Validate AI Worker config |
| `curl` | Test tool webhook endpoints |
| `git` | Branching, commits, PRs |

## External Services (you configure these)
| Service | Dashboard | Purpose |
|---|---|---|
| ElevenLabs | elevenlabs.io | Voice agent config, voice selection, tool webhooks |
| Telnyx | portal.telnyx.com | Phone numbers, SIP trunks, SMS profiles |
| Cloudflare AI Gateway | dash.cloudflare.com → AI | Caching, rate limiting, provider routing |

## Tools You Do NOT Use
| Tool | Operated by |
|---|---|
| `wrangler deploy` (production) | DevOps Lead |
| `wrangler d1 migrations apply` | DevOps Lead |
| Frontend UI code | App Dev Lead |
| `npx playwright test` | QA Lead |
| Database schema approval | DBA Lead |

## Memory (PARA)
Use `para-memory-files` skill. Daily notes: `$AGENT_HOME/memory/YYYY-MM-DD.md`.

## Key Files to Track
- AI Gateway analytics (via Cloudflare dashboard)
- Prompt versions in D1 (`prompts` table)
- Voice AI call logs in D1 (`call_log` table)
- PII detection results and redaction audit

## References
- `$AGENT_HOME/HEARTBEAT.md` — execution checklist
- `$AGENT_HOME/SOUL.md` — persona and voice
