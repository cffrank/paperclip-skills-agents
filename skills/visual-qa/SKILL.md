---
name: visual-qa
description: >
  Screenshot-based visual QA and evidence collection using Playwright. Captures visual proof
  of feature implementation against specifications. Use this skill when collecting evidence
  for quality gates, verifying UI implementations match specs, running visual regression
  tests, capturing screenshots of preview deployments, or building evidence reports for the
  Reality Checker. Triggers on: "screenshot", "visual QA", "visual test", "capture evidence",
  "does it match the spec", "visual regression", "screenshot comparison", "evidence report",
  "Playwright capture", "UI verification", or "take screenshots of the preview".
---

# Visual QA Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`testing-evidence-collector.md` (64K+ stars, MIT license).

Captures visual proof that what's built matches what was specified. Trust your
eyes, demand evidence, don't let fantasy reporting slip through.

## Core Principle

**Compare what's built vs what was specified.** Don't add luxury requirements
that weren't in the original spec. Don't claim features exist if screenshots
show otherwise. Document exactly what you see.

## When to Use This Skill

- Before submitting a Reality Checker report (collecting Gate 2 evidence)
- After a PR preview deployment is live — capture screenshots for the PR comment
- When verifying a bug fix — before/after screenshots
- When a developer claims "it works" — independent visual verification
- Visual regression testing between releases

## Playwright Capture Setup

### Installation

```bash
npm install -D @playwright/test
npx playwright install chromium
```

### Capture Script

Create `scripts/qa-capture.sh` in the project root:

```bash
#!/bin/bash
# Usage: ./scripts/qa-capture.sh <URL> <OUTPUT_DIR>
URL="${1:-http://localhost:5173}"
OUTPUT_DIR="${2:-qa-screenshots}"

mkdir -p "$OUTPUT_DIR"

npx playwright test --config=playwright-qa.config.ts \
  --output="$OUTPUT_DIR" \
  --reporter=list

echo "Screenshots saved to $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/"
```

### Playwright QA Config

```typescript
// playwright-qa.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './qa-tests',
  outputDir: './qa-screenshots',
  use: {
    baseURL: process.env.QA_URL || 'http://localhost:5173',
    screenshot: 'on',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      name: 'tablet',
      use: { ...devices['iPad Pro 11'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'] },
    },
  ],
});
```

### Standard Capture Test

```typescript
// qa-tests/visual-evidence.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Visual evidence collection', () => {
  test('homepage renders correctly', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.screenshot({
      path: `qa-screenshots/homepage-${test.info().project.name}.png`,
      fullPage: true,
    });
    await expect(page.locator('h1')).toBeVisible();
  });

  test('login flow works', async ({ page }) => {
    await page.goto('/login');
    await page.screenshot({ path: 'qa-screenshots/login-page.png' });

    // Attempt login with test credentials
    await page.fill('[name="email"]', 'test@axiom.ai');
    await page.fill('[name="password"]', 'test-password');
    await page.click('button[type="submit"]');

    await page.waitForURL('/dashboard', { timeout: 10000 });
    await page.screenshot({ path: 'qa-screenshots/dashboard-after-login.png' });
  });

  test('error state renders gracefully', async ({ page }) => {
    await page.goto('/api/nonexistent-route');
    await page.screenshot({ path: 'qa-screenshots/404-error-page.png' });
    // Verify it's a styled error page, not a raw Workers error
    await expect(page.locator('body')).not.toContainText('Worker threw exception');
  });

  test('dark mode renders correctly', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'qa-screenshots/homepage-dark-mode.png', fullPage: true });
  });

  test('responsive layout', async ({ page }) => {
    const viewports = [
      { width: 1440, height: 900, name: 'desktop' },
      { width: 768, height: 1024, name: 'tablet' },
      { width: 375, height: 812, name: 'mobile' },
    ];
    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await page.goto('/');
      await page.waitForLoadState('networkidle');
      await page.screenshot({
        path: `qa-screenshots/responsive-${vp.name}.png`,
        fullPage: true,
      });
    }
  });
});
```

## Running Against Preview Deployments

After a PR triggers a preview deploy, capture evidence from the live preview URL:

```bash
QA_URL="https://abc123.myapp.pages.dev" ./scripts/qa-capture.sh
```

In GitHub Actions:

```yaml
- name: Capture visual evidence
  env:
    QA_URL: ${{ steps.deploy.outputs.deployment-url }}
  run: |
    npx playwright install chromium --with-deps
    npx playwright test --config=playwright-qa.config.ts
- uses: actions/upload-artifact@v4
  with:
    name: qa-screenshots
    path: qa-screenshots/
```

## Evidence Report Format

After capturing screenshots, produce a structured evidence report that feeds
into the Reality Checker's Gate 2:

```markdown
# Visual QA Evidence Report
**PR**: #42 — Add billing checkout flow
**Preview URL**: https://abc123.myapp.pages.dev
**Captured**: 2026-03-28T10:30:00Z
**Viewports**: Desktop (1440x900), Tablet (768x1024), Mobile (375x812)

## Evidence Collected

### 1. Checkout page renders
**Spec says**: "Checkout page shows order summary, payment form, and submit button"
**Screenshot**: `checkout-desktop.png`
**What I see**: Order summary on left, Stripe Elements form on right, "Pay now"
button below. Layout matches spec.
**Verdict**: ✅ PASS

### 2. Empty cart handling
**Spec says**: "Empty cart shows message and link to products"
**Screenshot**: `empty-cart-desktop.png`
**What I see**: Blank white page with no message. Console shows 500 error.
**Verdict**: ❌ FAIL — No empty state handling

### 3. Mobile responsiveness
**Spec says**: "Checkout stacks vertically on mobile"
**Screenshot**: `checkout-mobile.png`
**What I see**: Summary stacks above form correctly. Button is full-width.
**Verdict**: ✅ PASS

### 4. Dark mode
**Screenshot**: `checkout-dark-mode.png`
**What I see**: Background switches correctly. Form inputs have dark background.
Stripe Elements use dark theme. Text is readable.
**Verdict**: ✅ PASS

## Summary
- **Passed**: 3/4 checks
- **Failed**: 1 (empty cart 500 error)
- **Blocking**: Yes — empty cart must be handled before production
```

## Spec-vs-Reality Verification Checklist

For every feature claim, verify:

```
[ ] Does the screenshot show what the spec describes?
[ ] Are all specified interactive elements visible?
[ ] Does the layout match the spec at all three breakpoints?
[ ] Are error states handled (not raw stack traces)?
[ ] Does dark mode work (if the app supports it)?
[ ] Are loading states present (not instant render with no skeleton)?
[ ] Do forms validate input (try submitting empty)?
[ ] Does navigation work (click through to verify, not just look)?
```

## Visual Regression Testing

For ongoing visual regression detection between releases:

```typescript
// qa-tests/visual-regression.spec.ts
import { test, expect } from '@playwright/test';

test('homepage matches baseline', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveScreenshot('homepage-baseline.png', {
    maxDiffPixelRatio: 0.01,  // Allow 1% pixel difference
    threshold: 0.2,           // Per-pixel color threshold
  });
});
```

Update baselines intentionally:
```bash
npx playwright test --update-snapshots
```

Store baselines in `qa-screenshots/baselines/` committed to the repo.

## Failure Patterns to Watch

1. **"Zero issues found" with no screenshots.** Reject — no evidence means no verdict.
2. **Screenshots of dev tools, not the actual page.** Reject — show the UI.
3. **Only happy-path screenshots.** Incomplete — require error states and edge cases.
4. **Screenshots from localhost, not preview URL.** Unreliable — local may differ.
5. **Single viewport only.** Incomplete — require desktop + mobile minimum.
6. **Claims of "premium styling" when CSS shows defaults.** Verify with computed styles.

## Relationship to Other Skills

- **Feeds into**: `reality-checker` (Gate 2 evidence)
- **Triggered by**: `axiom-cicd` preview deploy workflow (capture after deploy)
- **Complemented by**: `a11y-auditor` (accessibility testing on same preview URLs)
