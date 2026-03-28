# QA Lead Tools

## Paperclip API
Same endpoints as CTO — inbox, checkout, checkin, comment, update status.

## Skills
| Skill | When to use |
|---|---|
| `paperclip` | Coordination, ticket management |
| `reality-checker` | Production readiness verdicts (4-gate framework) |
| `visual-qa` | Playwright screenshot evidence capture |
| `a11y-auditor` | WCAG 2.2 AA accessibility auditing with axe-core |
| `test-analyzer` | Test result interpretation, flaky detection, coverage trends |
| `api-tester` | Workers API endpoint validation |
| `perf-benchmarker` | Performance measurement (CPU time, latency, bundle size) |
| `e2e-playwright` | End-to-end tests for auth flows, forms, SSR verification |
| `cloudflare-stack` | Verify what standards to test against |

## CLI Tools
| Tool | Purpose |
|---|---|
| `npx vitest run --reporter=json` | Run tests, output structured results |
| `npx vitest run --coverage` | Run tests with coverage report |
| `npx playwright test` | Run E2E tests |
| `npx playwright test --update-snapshots` | Update visual baselines |
| `npx playwright install chromium` | Install browser for CI |

## Tools You Do NOT Use
| Tool | Operated by |
|---|---|
| `wrangler deploy` | DevOps Lead |
| `npx biome check` (fixing code) | App Dev Lead |
| `npx drizzle-kit generate` | App Dev Lead |
| ElevenLabs / Telnyx | AI/ML Lead |

## Memory (PARA)
Use `para-memory-files` skill. Daily notes: `$AGENT_HOME/memory/YYYY-MM-DD.md`.

## Key Files to Track
- `test-results/results.json` — latest vitest output
- `test-results/coverage/coverage-summary.json` — coverage percentages
- `test-results/flaky-log.json` — flaky test history
- `qa-screenshots/` — visual evidence directory
- `a11y-results.json` — latest accessibility scan

## References
- `$AGENT_HOME/HEARTBEAT.md` — execution checklist
- `$AGENT_HOME/SOUL.md` — persona and voice
