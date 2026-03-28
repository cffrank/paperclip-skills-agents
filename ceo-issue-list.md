# CEO Issue List — IT Department Deployment

Create these issues in Paperclip in order. The CTO agent will delegate each
to the appropriate department lead. Issues are grouped into phases — complete
each phase before starting the next.

---

## Phase 1: Foundation (Week 1)
*Set up the infrastructure so all other work can proceed.*

### Issue 1: Deploy skills directory to agent workspace
**Priority**: Critical
**Assign to**: CTO → DevOps Lead
**Description**: Create the `axiom-company/skills/` directory structure on the
agent workspace filesystem. Unzip all three skill batches plus axiom-cicd into
the correct directory layout matching `adapter-configs.md`. Verify every
SKILL.md is readable. This must complete before any other agent can be created.
**Acceptance criteria**:
- [ ] 25 SKILL.md files deployed to `skills/` directory
- [ ] 12 axiom-cicd reference files deployed to `skills/axiom-cicd/references/`
- [ ] Directory is readable from the path specified in adapter configs
- [ ] `ls skills/*/SKILL.md | wc -l` returns 25

### Issue 2: Deploy AGENTS.md files for all 6 agents
**Priority**: Critical
**Assign to**: CTO → DevOps Lead
**Description**: Create the `axiom-company/agents/` directory with all 6
AGENTS.md files (cto, app-dev, qa, devops, ai-ml, dba). These define each
agent's identity, KPIs, and rules.
**Acceptance criteria**:
- [ ] 6 AGENTS.md files in `agents/{cto,app-dev,qa,devops,ai-ml,dba}/`
- [ ] Each file is valid markdown with role, responsibilities, KPIs, and rules

### Issue 3: Update existing DevOps Lead agent config
**Priority**: Critical
**Assign to**: CTO (direct — Paperclip dashboard)
**Description**: Update the existing DevOps Lead agent in Paperclip. Change
`instructionsFilePath` to point to the new `agents/devops/AGENTS.md`. Change
`args` to include `--add-dir /path/to/axiom-company/skills`. Do NOT delete
and recreate — update in place to preserve history and ticket assignments.
**Acceptance criteria**:
- [ ] DevOps agent `instructionsFilePath` updated
- [ ] DevOps agent `args` includes skills directory
- [ ] Agent responds correctly on next heartbeat
- [ ] Existing ticket history preserved

### Issue 4: Create CTO agent in Paperclip
**Priority**: Critical
**Assign to**: Board (Carl — manual via Paperclip dashboard)
**Description**: Create the CTO agent using the adapter config from
`adapter-configs.md`. Set as executive role with no reportsTo (reports to
Board). Model: claude-sonnet-4, budget: $50/month, heartbeat: 600s.
**Acceptance criteria**:
- [ ] CTO agent created and active in Paperclip
- [ ] Heartbeat fires successfully
- [ ] Agent loads skills on first run
- [ ] Budget set to 5000 cents

### Issue 5: Create remaining 4 department lead agents
**Priority**: Critical
**Assign to**: CTO → delegates agent creation approval to Board
**Description**: Create App Dev Lead, QA Lead, AI/ML Lead, and DBA Lead agents
in Paperclip using adapter configs from `adapter-configs.md`. Set reporting
lines to CTO. Configure heartbeats and budgets per the config.
**Acceptance criteria**:
- [ ] App Dev Lead: Sonnet, $30/mo, heartbeat 600s
- [ ] QA Lead: Haiku, $20/mo, heartbeat daily + wake-on-demand
- [ ] AI/ML Lead: Sonnet, $30/mo, heartbeat 600s
- [ ] DBA Lead: Haiku, $15/mo, heartbeat daily + wake-on-demand
- [ ] All 4 agents fire heartbeat successfully
- [ ] Org chart shows CTO → 5 leads → Board

---

## Phase 2: CI/CD Pipeline (Week 1-2)
*DevOps Lead sets up the deployment infrastructure.*

### Issue 6: Generate CI/CD workflows for first project
**Priority**: High
**Assign to**: CTO → DevOps Lead
**Description**: Using the `axiom-cicd` skill, generate all 6 GitHub Actions
workflow files for [pick one project: Product A, Product B, or Product C].
Workflows: ci.yml, deploy-preview.yml, deploy-staging.yml, deploy-production.yml,
rollback.yml, drift-check.yml.
**Acceptance criteria**:
- [ ] 6 workflow files committed to `.github/workflows/`
- [ ] CI workflow runs on PR and passes (lint + test + security)
- [ ] Preview deployment posts URL as PR comment
- [ ] Staging deploys on merge to `staging` branch
- [ ] Production deploys with gradual rollout on merge to `main`

### Issue 7: Configure GitHub repository secrets
**Priority**: High
**Assign to**: CTO → DevOps Lead
**Description**: Set up required GitHub repository secrets for the target project:
CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_R2_ACCESS_KEY_ID,
CLOUDFLARE_R2_SECRET_ACCESS_KEY. Create scoped API tokens in Cloudflare dashboard.
**Acceptance criteria**:
- [ ] All 4 Cloudflare secrets configured in GitHub
- [ ] Tokens scoped to minimum required permissions
- [ ] `wrangler deploy --dry-run` succeeds in CI
- [ ] R2 upload works with dedicated R2 token

### Issue 8: Set up D1 databases for all environments
**Priority**: High
**Assign to**: CTO → DevOps Lead + DBA Lead
**Description**: Create D1 databases for dev, staging, and production environments.
Update wrangler.toml with database IDs. Apply existing migrations to all environments.
**Acceptance criteria**:
- [ ] 3 D1 databases created (myapp-dev, myapp-staging, myapp-prod)
- [ ] Database IDs in wrangler.toml under correct [env.*] sections
- [ ] Migrations applied successfully to all 3 environments
- [ ] DBA Lead reviews schema and indexes

### Issue 9: Set up daily drift detection
**Priority**: Medium
**Assign to**: CTO → DevOps Lead
**Description**: Deploy the drift-check.yml scheduled workflow. Configure it to
run daily at 6am UTC and create GitHub issues when drift is detected.
**Acceptance criteria**:
- [ ] drift-check.yml committed and scheduled
- [ ] Manual trigger works (workflow_dispatch)
- [ ] Drift detected on intentional test change
- [ ] Issue auto-created when drift found

---

## Phase 3: Quality Gates (Week 2)
*QA Lead establishes testing infrastructure.*

### Issue 10: Set up Vitest with workerd pool
**Priority**: High
**Assign to**: CTO → QA Lead + App Dev Lead
**Description**: Configure Vitest with `@cloudflare/vitest-pool-workers` for the
target project. Write initial test suite covering health endpoint and one
business-critical flow. Ensure tests run in CI.
**Acceptance criteria**:
- [ ] vitest.config.ts configured with Workers pool
- [ ] At least 10 tests passing in workerd runtime
- [ ] Coverage reporting enabled (threshold: 80%)
- [ ] Tests run in CI as part of ci.yml

### Issue 11: Set up Playwright E2E and visual QA
**Priority**: High
**Assign to**: CTO → QA Lead
**Description**: Configure Playwright for E2E testing against preview deployments.
Set up visual QA screenshot capture for desktop, mobile, and dark mode. Write auth
flow E2E test with Clerk test user.
**Acceptance criteria**:
- [ ] playwright.config.ts configured with 3 viewports
- [ ] Auth flow E2E test passes against preview URL
- [ ] Screenshots captured and uploaded as CI artifacts
- [ ] QA evidence report template working

### Issue 12: Set up accessibility auditing
**Priority**: Medium
**Assign to**: CTO → QA Lead
**Description**: Configure @axe-core/playwright for WCAG 2.2 AA auditing. Run
against all user-facing pages in both light and dark mode. Add as CI job.
**Acceptance criteria**:
- [ ] Axe-core scans all pages listed in config
- [ ] Both light and dark mode scanned
- [ ] 0 Critical/Serious violations on production pages
- [ ] Results reported as CI artifact

### Issue 13: First Reality Checker production readiness report
**Priority**: High
**Assign to**: CTO → QA Lead
**Description**: Produce the first full production readiness report for the target
project using the `reality-checker` skill. Cover all 4 gates: Code Quality,
Functional Verification, Deployment Readiness, Operational Readiness.
**Acceptance criteria**:
- [ ] Report covers all 4 gates with evidence
- [ ] Every claim has screenshot or test output evidence
- [ ] Clear GO / NEEDS WORK / NO-GO verdict
- [ ] Blocking issues listed with specific fix requirements

---

## Phase 4: Security and Monitoring (Week 2-3)
*DevOps Lead hardens the pipeline.*

### Issue 14: Add security scanning to CI
**Priority**: High
**Assign to**: CTO → DevOps Lead
**Description**: Add Gitleaks (secret detection), Semgrep (SAST), and npm audit
(SCA) to the CI workflow. Configure fail-on-new policy with baseline.
**Acceptance criteria**:
- [ ] Gitleaks runs on every PR
- [ ] Semgrep runs with JS/TS + OWASP Top 10 rules
- [ ] npm audit runs with --audit-level=high
- [ ] Security baseline file committed
- [ ] CI blocks on new Critical/High findings

### Issue 15: Set up SLOs and post-deploy monitoring
**Priority**: Medium
**Assign to**: CTO → DevOps Lead
**Description**: Define SLOs for the target project (availability 99.9%, latency
P99 <200ms). Configure post-deploy health gate observation in the production
deploy workflow. Set up Workers analytics queries.
**Acceptance criteria**:
- [ ] SLO document committed to repo
- [ ] Health gate in deploy-production.yml queries Workers analytics
- [ ] Auto-rollback triggers on error rate >1% sustained 5min
- [ ] Post-deploy observation runs for 5 minutes

### Issue 16: Set up DORA metrics tracking
**Priority**: Low
**Assign to**: CTO → DevOps Lead
**Description**: Add deployment metric recording to the production deploy
workflow. Track deploy frequency, lead time, change failure rate, and MTTR.
Store in D1 using the metrics schema from axiom-cicd.
**Acceptance criteria**:
- [ ] D1 metrics tables created (deployments, incidents)
- [ ] Every production deploy records timestamp, result, lead time
- [ ] DORA metrics queryable via SQL
- [ ] First sprint quality report includes DORA metrics

---

## Phase 5: Data Layer (Week 3)
*DBA Lead establishes data practices.*

### Issue 17: Audit existing D1 schemas and add indexes
**Priority**: Medium
**Assign to**: CTO → DBA Lead
**Description**: Review all existing D1 tables across __COMPANY_NAME__ products. Run
EXPLAIN QUERY PLAN on the top 20 most frequent queries. Add missing indexes.
Document findings.
**Acceptance criteria**:
- [ ] Every table audited with EXPLAIN QUERY PLAN
- [ ] Missing indexes identified and added via migrations
- [ ] No query >50ms after optimization
- [ ] Audit report delivered to CTO

### Issue 18: Set up nightly D1 backups to R2
**Priority**: Medium
**Assign to**: CTO → DBA Lead + DevOps Lead
**Description**: Create a scheduled Worker (Cron Trigger) that exports all D1
tables to JSON in R2 nightly. Configure the backup verification workflow to
run weekly.
**Acceptance criteria**:
- [ ] Cron Trigger runs at 3am UTC daily
- [ ] Full export saved to R2 at `backups/{date}/full-export.json`
- [ ] backup-verify.yml runs weekly and confirms backup recency
- [ ] 90-day retention policy documented

### Issue 19: Set up pre-deploy D1 bookmarks
**Priority**: Medium
**Assign to**: CTO → DevOps Lead
**Description**: Add a D1 Time Travel bookmark step to deploy-production.yml
that creates a named recovery point before every production migration. Use
format: `pre-deploy-{commit-sha}`.
**Acceptance criteria**:
- [ ] Bookmark created before every production D1 migration
- [ ] Bookmark name includes commit SHA for traceability
- [ ] Disaster recovery runbook updated with bookmark restore procedure

---

## Phase 6: Rollout to Remaining Projects (Week 3-4)
*Replicate the pipeline across all __COMPANY_NAME__ products.*

### Issue 20: Replicate CI/CD to remaining projects
**Priority**: Medium
**Assign to**: CTO → DevOps Lead
**Description**: Copy and adapt the CI/CD workflows from the first project to
all remaining __COMPANY_NAME__ projects (Product A, Product B, Product C, Product D,
Product E). Adjust wrangler.toml, D1 database IDs, and R2 bucket names
per project.
**Acceptance criteria**:
- [ ] All 5 projects have full CI/CD workflows
- [ ] Each project has dev/staging/prod D1 databases
- [ ] Preview deployments work on all projects
- [ ] All projects pass CI (lint + test + security)

### Issue 21: First full sprint quality report
**Priority**: High
**Assign to**: CTO → QA Lead
**Description**: Produce the first comprehensive sprint quality report covering
all __COMPANY_NAME__ projects. Include test pass rates, coverage trends, flaky tests,
DORA metrics, and accessibility status.
**Acceptance criteria**:
- [ ] Report covers all active projects
- [ ] DORA metrics included (deploy frequency, lead time, CFR, MTTR)
- [ ] Flaky test log initialized
- [ ] Recommendations for next sprint included
- [ ] CTO reviews and approves

---

## Phase 7: Voice AI (Week 4+)
*AI/ML Lead builds the voice AI infrastructure.*

### Issue 22: Set up Telnyx SIP trunk and phone number
**Priority**: Medium
**Assign to**: CTO → AI/ML Lead
**Description**: Purchase a phone number on Telnyx, create a SIP trunk or TeXML
application, and configure inbound call webhooks pointing to the Product B
Workers endpoint.
**Acceptance criteria**:
- [ ] Phone number purchased and active
- [ ] SIP trunk configured
- [ ] Inbound calls reach the Workers webhook handler
- [ ] Telnyx secrets configured via `wrangler secret put`

### Issue 23: Configure ElevenLabs Conversational AI agent
**Priority**: Medium
**Assign to**: CTO → AI/ML Lead
**Description**: Create an ElevenLabs Conversational AI agent for the Product B
receptionist. Configure voice, system prompt, and tool webhooks (check_availability,
book_appointment, lookup_customer). Connect to Telnyx SIP.
**Acceptance criteria**:
- [ ] ElevenLabs agent created with appropriate voice
- [ ] System prompt follows dental receptionist persona
- [ ] 3 tool webhooks configured and responding
- [ ] Test call completes successfully end-to-end

### Issue 24: Build booking engine and mini CRM
**Priority**: Medium
**Assign to**: CTO → AI/ML Lead + App Dev Lead
**Description**: Implement the D1 schema for customers, appointments, availability,
call_log, and sms_log tables. Build the Workers API endpoints that ElevenLabs
tool webhooks call. Implement SMS follow-up via Telnyx.
**Acceptance criteria**:
- [ ] D1 schema migrated with all 5 tables
- [ ] Tool webhooks handle availability check, booking, and customer lookup
- [ ] SMS confirmation sent after booking
- [ ] Post-call SMS follow-up working
- [ ] PII redaction applied to stored transcripts

---

## Summary: 24 Issues, 7 Phases

| Phase | Issues | Duration | Key agents |
|-------|--------|----------|------------|
| 1. Foundation | #1-5 | Week 1 | Board, CTO, DevOps |
| 2. CI/CD Pipeline | #6-9 | Week 1-2 | DevOps, DBA |
| 3. Quality Gates | #10-13 | Week 2 | QA, App Dev |
| 4. Security & Monitoring | #14-16 | Week 2-3 | DevOps |
| 5. Data Layer | #17-19 | Week 3 | DBA, DevOps |
| 6. Rollout | #20-21 | Week 3-4 | DevOps, QA |
| 7. Voice AI | #22-24 | Week 4+ | AI/ML, App Dev |

Total estimated budget for deployment: ~$175/month across all 6 agents.
