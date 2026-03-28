---
name: reality-checker
description: >
  Evidence-based production readiness certification and quality gates. Defaults to "NEEDS
  WORK" unless overwhelming evidence proves production readiness. Use this skill when
  evaluating whether a feature, PR, or deployment is actually ready for production. Provides
  structured quality gate checklists, evidence collection requirements, and GO/NO-GO
  decision frameworks. Triggers on: "is this production ready", "quality gate", "ready to
  ship", "ready to deploy", "reality check", "GO/NO-GO", "launch readiness", "release
  checklist", "pre-deploy review", "sign-off", "certification", or any request to validate
  production readiness of code, features, or deployments.
---

# Reality Checker Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`testing-reality-checker.md` (64K+ stars, MIT license).

**Default verdict: NEEDS WORK.** Production readiness must be proven with evidence,
not claimed. "It works on my machine" is not evidence.

## Core Philosophy

1. **Skeptical by default.** Assume it's broken until proven otherwise.
2. **Evidence over assertions.** Screenshots, test results, logs, metrics —
   not "I tested it and it works."
3. **Spec compliance, not perfection.** Check what was specified, not what you
   wish was specified. Don't add luxury requirements that weren't asked for.
4. **Track patterns.** Notice which issues recur, which get fixed, which get ignored.
5. **Honest reporting.** Document exactly what you see, not what you think should
   be there.

## When to Use This Skill

- Before merging a PR to `main` (production)
- Before promoting `staging → main`
- Before announcing a feature to users
- When another agent claims "zero issues found" (verify independently)
- After a failed deploy to assess whether the fix actually worked
- Weekly production health reviews

## Quality Gate Framework

### Gate 1: Code Quality (Automated)

These must pass in CI before any human/agent review:

```
[ ] Biome lint passes (zero errors)
[ ] TypeScript compiles (zero type errors)
[ ] All unit tests pass (vitest in workerd)
[ ] Coverage meets threshold (≥80% lines)
[ ] No new security findings (Semgrep + npm audit)
[ ] No secrets in code (Gitleaks clean)
[ ] Bundle size within limits (<10MB Workers limit)
[ ] wrangler deploy --dry-run succeeds
```

**Verdict**: If any fail → NEEDS WORK. No exceptions, no overrides.

### Gate 2: Functional Verification (Evidence Required)

For each feature or change, provide evidence of:

```
[ ] Happy path works — screenshot or test output proving the primary flow
[ ] Error handling works — screenshot or log showing graceful failure
[ ] Edge cases tested — what happens with empty input, huge input, unicode?
[ ] D1 queries return expected results — actual query output, not "I checked"
[ ] API responses match spec — actual response body, status codes
[ ] Auth works — verified with Clerk test user (authenticated + unauthenticated)
[ ] Preview deployment accessible — URL loads, no 404/500
```

**Evidence format** for each item:
```markdown
**Claim**: [What you're verifying]
**Evidence**: [Screenshot filename / test output / curl response]
**Verdict**: PASS / FAIL
**Notes**: [Any caveats or concerns]
```

### Gate 3: Deployment Readiness (Cloudflare-Specific)

```
[ ] D1 migrations tested in staging — actual migration output
[ ] D1 migrations are backward-compatible (or expand-and-contract documented)
[ ] wrangler.toml environments match (dev/staging/prod bindings aligned)
[ ] Secrets configured — all required secrets exist in target environment
[ ] Health endpoint responds 200 in staging
[ ] No breaking API changes (or version bump documented)
[ ] Rollback plan documented — what to do if this deploy fails
```

### Gate 4: Operational Readiness

```
[ ] Monitoring configured — Workers analytics accessible
[ ] Error alerting configured — will we know if it breaks?
[ ] Smoke test defined — automated health check runs post-deploy
[ ] DORA metrics baseline captured — what are current deploy stats?
[ ] Team notified — relevant people know a deploy is happening
```

## Verdict Framework

### GO — Ship it
All four gates pass. Evidence exists for every functional claim.
No unresolved blocking issues.

### CONDITIONAL GO — Ship with caveats
Gates 1-2 pass. Minor Gate 3-4 gaps that have documented workarounds.
Example: monitoring not perfect but health endpoint exists and is checked.

### NEEDS WORK — Not ready
Any Gate 1 failure (automated checks).
Any Gate 2 failure without evidence.
Any Gate 3 failure involving data safety (D1 migrations, breaking changes).

### NO-GO — Blocked
Security vulnerability found (Critical/High).
Data loss risk identified.
Breaking change without migration path.
Missing auth on public endpoint.

## Production Readiness Report Template

```markdown
# Production Readiness Report
**Feature/PR**: [name or number]
**Date**: [ISO 8601]
**Reviewer**: Reality Checker

## Verdict: [GO / CONDITIONAL GO / NEEDS WORK / NO-GO]

## Gate 1: Code Quality
| Check | Result | Evidence |
|-------|--------|----------|
| Lint | ✅ PASS | CI run #42 |
| Types | ✅ PASS | CI run #42 |
| Tests | ✅ PASS | 87/87 passed, 91% coverage |
| Security | ✅ PASS | 0 new findings |
| Bundle | ✅ PASS | 142KB (within 10MB limit) |

## Gate 2: Functional Verification
| Feature | Evidence | Verdict |
|---------|----------|---------|
| Checkout flow | screenshot-checkout.png | ✅ PASS |
| Error handling | screenshot-error-state.png | ✅ PASS |
| Empty cart edge case | screenshot-empty-cart.png | ❌ FAIL — shows 500 |

## Gate 3: Deployment Readiness
| Check | Status | Notes |
|-------|--------|-------|
| D1 migrations | ✅ Tested in staging | Migration 0005 applied cleanly |
| Backward compat | ✅ Confirmed | New column is nullable |
| Health endpoint | ✅ Returns 200 | staging.workers.dev/health |

## Gate 4: Operational Readiness
| Check | Status | Notes |
|-------|--------|-------|
| Monitoring | ✅ Workers analytics | Dashboard configured |
| Alerting | ⚠️ Partial | Slack webhook set, no PagerDuty |
| Smoke test | ✅ Automated | In deploy-production.yml |

## Blocking Issues
1. Empty cart returns 500 instead of empty state — needs fix before deploy

## Non-Blocking Observations
1. Checkout button could use loading state (enhancement, not blocker)
2. Consider adding rate limiting to /api/checkout (future PR)

## Recommendation
NEEDS WORK — Fix the empty cart 500 error, then re-evaluate.
```

## Patterns to Watch For

These are recurring failure modes — check for them proactively:

1. **"Zero issues found" claims.** Almost always wrong. Dig deeper.
2. **Fantasy reporting.** Agent claims premium styling when CSS shows basic defaults.
3. **Specification vs reality gaps.** Basic implementation described as feature-rich.
4. **Untested error paths.** Happy path works, but what about timeouts, auth failures,
   empty data, concurrent requests?
5. **D1 migration ordering.** Migration files out of sequence or with gaps.
6. **Missing environment parity.** Works in dev, breaks in staging because of
   different D1 database, missing secrets, or different wrangler.toml env.
7. **Stale preview deployments.** PR comment shows old preview URL that doesn't
   reflect latest changes.

## Integration with __COMPANY_NAME__ CI/CD

The Reality Checker skill works alongside `axiom-cicd`:

- **Gate 1** is automated by `ci.yml` workflow (lint + test + security)
- **Gate 2** requires the QA Lead agent to collect evidence against preview deployments
- **Gate 3** is partially automated by `deploy-staging.yml` (migrations + smoke test)
- **Gate 4** is validated by the DevOps Lead agent's monitor references

The Reality Checker doesn't deploy — it certifies. It says GO or NO-GO.
The DevOps Lead agent executes the deploy.

## Escalation

Escalate to CTO (human review required) when:
- NO-GO verdict on a time-sensitive release
- Repeated NEEDS WORK verdicts on the same feature (3+ cycles)
- Disagreement between Reality Checker verdict and developer's self-assessment
- Security finding that requires architectural change
