---
name: test-analyzer
description: >
  Test results analysis, quality metrics, flaky test detection, and coverage trend tracking
  for Vitest suites running in the workerd runtime. Transforms raw test output into
  actionable insights — pass rates, slowest tests, coverage diffs, and sprint quality
  reports. Use when analyzing test failures, identifying flaky tests, generating quality
  reports, tracking coverage trends, or diagnosing slow test suites. Triggers on: "test
  results", "flaky test", "test analysis", "quality report", "coverage trend", "slow tests",
  "test metrics", "sprint quality", "test health", "why did tests fail", "test dashboard",
  or any request to interpret or summarize test output.
---

# Test Results Analyzer Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`testing-test-results-analyzer.md` (64K+ stars, MIT license).

Makes quality visible, measurable, and improvable. Transforms overwhelming test
data into clear stories teams can act on.

## When to Use This Skill

- After a CI run to interpret failures and suggest fixes
- To generate a sprint quality report for the CTO
- To identify and quarantine flaky tests
- To track coverage trends over time
- To find the slowest tests slowing down the pipeline
- To diagnose why a previously passing test now fails

## Vitest JSON Output Setup

All analysis starts with structured test output. Configure Vitest to produce JSON:

```typescript
// vitest.config.ts (add to existing @cloudflare/vitest-pool-workers config)
export default defineWorkersConfig({
  test: {
    reporters: ['verbose', 'json'],
    outputFile: {
      json: 'test-results/results.json',
    },
    coverage: {
      provider: 'istanbul',
      reporter: ['text', 'json', 'json-summary'],
      reportsDirectory: 'test-results/coverage',
    },
  },
});
```

In CI, upload as artifacts:
```yaml
- uses: actions/upload-artifact@v4
  if: always()
  with:
    name: test-results
    path: test-results/
```

## Analysis Playbook

### 1. Parse Results Summary

From `test-results/results.json`:

```typescript
interface VitestResults {
  numTotalTests: number;
  numPassedTests: number;
  numFailedTests: number;
  numPendingTests: number;
  numTodoTests: number;
  startTime: number;
  success: boolean;
  testResults: TestSuite[];
}

interface TestSuite {
  name: string;           // File path
  status: 'passed' | 'failed';
  startTime: number;
  endTime: number;
  testResults: TestCase[];
}

interface TestCase {
  fullName: string;
  status: 'passed' | 'failed' | 'pending' | 'todo';
  duration: number;       // ms
  failureMessages: string[];
  retryReasons?: string[];  // Present if test was retried
}
```

### 2. Generate Summary Metrics

```
Total tests:    87
Passed:         85 (97.7%)
Failed:         2 (2.3%)
Pending/Todo:   0
Duration:       34.2s
Coverage:       87.2% lines (threshold: 80%)
```

### 3. Identify Failed Tests

For each failure, extract:
- Test name and file
- Error message (first line)
- Whether the file was in `changed_files` (regression vs pre-existing)
- Stack trace location (file:line)

```markdown
## Failed Tests

### 1. billing.test.ts > calculates tax correctly
**Error**: Expected 10.50 but received 10.49
**Location**: src/modules/billing/tax.ts:42
**In changed files**: Yes — likely regression
**Suggested fix**: Floating point rounding — use Math.round(amount * 100) / 100

### 2. auth.test.ts > handles expired session
**Error**: Timeout waiting for redirect
**Location**: src/modules/auth/session.ts:78
**In changed files**: No — pre-existing issue
**History**: Failed in 3 of last 10 runs → likely flaky
```

## Flaky Test Detection

A test is flaky if it passes on retry. Vitest tracks this via `retryReasons`.

### Detection Script

```bash
# Parse retried tests from JSON output
node -e "
const r = require('./test-results/results.json');
const flaky = r.testResults
  .flatMap(s => s.testResults)
  .filter(t => t.retryReasons && t.retryReasons.length > 0);
console.log(JSON.stringify(flaky.map(t => ({
  name: t.fullName,
  retries: t.retryReasons.length,
  duration: t.duration,
})), null, 2));
"
```

### Flaky Test Tracking

Maintain a `test-results/flaky-log.json` committed to the repo:

```json
{
  "tests": {
    "auth.test.ts > handles expired session": {
      "first_seen": "2026-03-20",
      "occurrences": 5,
      "last_seen": "2026-03-28",
      "consecutive_flaky": 3,
      "quarantined": false
    }
  }
}
```

### Auto-Quarantine Rules

| Condition | Action |
|-----------|--------|
| Flaky 3+ times in 10 runs | Flag as unstable, warn in PR comment |
| Flaky 5+ consecutive runs | Auto-quarantine: skip + create issue |
| Quarantined > 2 weeks with no fix | Escalate to App Dev Lead |

Quarantine implementation:
```typescript
// In the test file, wrap with skip condition
const QUARANTINED = ['handles expired session'];

test.skipIf(QUARANTINED.includes(test.name))('handles expired session', async () => {
  // ...
});
```

## Coverage Analysis

### Coverage Diff (PR-level)

Compare current coverage against the base branch:

```bash
# In CI, after tests run:
CURRENT=$(jq '.total.lines.pct' test-results/coverage/coverage-summary.json)
echo "Current coverage: ${CURRENT}%"

# Compare against stored baseline
BASELINE=$(cat test-results/coverage-baseline.txt 2>/dev/null || echo "0")
DIFF=$(echo "$CURRENT - $BASELINE" | bc)
echo "Coverage diff: ${DIFF}%"

if (( $(echo "$DIFF < -2" | bc -l) )); then
  echo "::error::Coverage dropped by ${DIFF}% (threshold: -2%)"
  exit 1
fi
```

### Per-File Coverage for Changed Files

When a PR changes `src/modules/billing/checkout.ts`, check that file specifically:

```bash
jq '.["src/modules/billing/checkout.ts"].lines.pct' \
  test-results/coverage/coverage-final.json
```

Rules:
- New files should have ≥80% coverage
- Modified files should not decrease coverage
- Deleted files don't count

### Coverage Trend (Sprint-level)

Track weekly in `test-results/coverage-history.json`:

```json
[
  { "date": "2026-03-21", "lines": 85.2, "functions": 82.1, "branches": 71.3 },
  { "date": "2026-03-28", "lines": 87.2, "functions": 84.5, "branches": 73.8 }
]
```

## Slowest Tests

Find tests that slow down the pipeline:

```bash
node -e "
const r = require('./test-results/results.json');
const tests = r.testResults
  .flatMap(s => s.testResults)
  .sort((a, b) => b.duration - a.duration)
  .slice(0, 10);
tests.forEach((t, i) => console.log(
  \`\${i+1}. \${t.duration}ms — \${t.fullName}\`
));
"
```

Performance budget: total test suite should complete in <120 seconds.
Individual tests over 5 seconds need investigation.

Common causes of slow tests:
- Missing `await` causing test to wait for timeout
- Real network calls instead of mocked bindings
- Large D1 seed data when a few rows would suffice
- No test isolation (shared state causes sequential execution)

## Sprint Quality Report Template

```markdown
# Sprint Quality Report
**Sprint**: [name/number]
**Period**: [start] — [end]
**Overall health**: [green/yellow/red]

## Summary
| Metric | This sprint | Last sprint | Trend |
|--------|------------|-------------|-------|
| Test pass rate | 97.7% | 96.1% | ↑ |
| Code coverage | 87.2% | 85.2% | ↑ |
| Avg test duration | 34s | 38s | ↑ (faster) |
| Flaky tests | 2 | 4 | ↑ (fewer) |
| Failed deploys | 0 | 1 | ↑ |

## Key Findings
1. Coverage increased 2% — new billing module has 92% coverage
2. Two flaky tests quarantined — both in auth module (Clerk session timing)
3. Test suite 10% faster after removing unnecessary D1 seed data

## Areas of Concern
1. **Auth module**: 3 flaky tests in 2 sprints — investigate Clerk mock stability
2. **Coverage gaps**: `src/modules/voice-ai/` at 62% — below 80% threshold

## Recommendations
1. Fix auth mock timing — use deterministic token expiry in tests
2. Add integration tests for voice-ai booking flow
3. Consider splitting billing tests into unit + integration suites
```

## Relationship to Other Skills

- **Feeds into**: `reality-checker` (Gate 1 evidence — pass rate, coverage)
- **Triggered by**: `axiom-cicd` CI workflow (runs after every test job)
- **Informs**: `software-architect` (test patterns reveal architectural issues)
- **Consumes**: Vitest JSON output from `@cloudflare/vitest-pool-workers`
