---
name: a11y-auditor
description: >
  WCAG accessibility auditing for SvelteKit applications using axe-core and Playwright.
  Automated scanning catches ~57% of WCAG issues; this skill covers both automated and
  manual verification patterns. Use when auditing pages for accessibility compliance,
  checking color contrast, verifying keyboard navigation, testing screen reader compatibility,
  or preparing for ADA/Section 508 compliance. Triggers on: "accessibility", "a11y", "WCAG",
  "screen reader", "keyboard navigation", "color contrast", "alt text", "aria", "focus",
  "ADA compliance", "Section 508", "axe-core", "accessible", or any request to check or
  improve accessibility.
---

# Accessibility Auditor Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`testing-accessibility-auditor.md` (64K+ stars, MIT license).

Automated scans catch ~57% of WCAG issues. This skill covers both automated
scanning and the manual checks needed to reach full compliance.

## Target Standard

**WCAG 2.2 Level AA** — the current industry standard and legal baseline
for ADA compliance. This covers all 50 AA success criteria.

## Automated Testing Setup

### Dependencies

```bash
npm install -D @axe-core/playwright @playwright/test
npx playwright install chromium
```

### Playwright + axe-core Config

```typescript
// a11y-tests/a11y.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility audit', () => {
  const pages = [
    { name: 'homepage', path: '/' },
    { name: 'login', path: '/login' },
    { name: 'dashboard', path: '/dashboard' },
    { name: 'settings', path: '/settings' },
  ];

  for (const pg of pages) {
    test(`${pg.name} has no WCAG 2.2 AA violations`, async ({ page }) => {
      await page.goto(pg.path);
      await page.waitForLoadState('networkidle');

      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
        .analyze();

      // Log violations for debugging
      if (results.violations.length > 0) {
        console.log(`\n❌ ${pg.name}: ${results.violations.length} violations`);
        for (const v of results.violations) {
          console.log(`  [${v.impact}] ${v.id}: ${v.description}`);
          for (const node of v.nodes) {
            console.log(`    → ${node.target.join(' > ')}`);
          }
        }
      }

      expect(results.violations).toEqual([]);
    });

    test(`${pg.name} dark mode has no violations`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: 'dark' });
      await page.goto(pg.path);
      await page.waitForLoadState('networkidle');

      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
        .analyze();

      expect(results.violations).toEqual([]);
    });
  }
});
```

### CI Integration

```yaml
# Add to .github/workflows/ci.yml
a11y:
  runs-on: ubuntu-latest
  needs: lint
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with: { node-version: '20', cache: 'npm' }
    - run: npm ci --frozen-lockfile
    - run: npx playwright install chromium --with-deps
    - name: Start dev server
      run: npm run dev &
    - name: Wait for server
      run: npx wait-on http://localhost:5173 --timeout 30000
    - name: Run a11y audit
      run: npx playwright test a11y-tests/ --reporter=json --output=a11y-results.json
    - uses: actions/upload-artifact@v4
      if: always()
      with:
        name: a11y-results
        path: a11y-results.json
```

For preview deployments, run against the deployed URL:

```yaml
- name: Run a11y audit on preview
  env:
    BASE_URL: ${{ steps.deploy.outputs.deployment-url }}
  run: npx playwright test a11y-tests/ --reporter=json
```

## The 10 Most Common Failures

These account for the majority of WCAG violations in SvelteKit apps:

### 1. Missing alt text on images (WCAG 1.1.1)
```svelte
<!-- BAD -->
<img src="/hero.jpg" />

<!-- GOOD: Descriptive alt -->
<img src="/hero.jpg" alt="Dashboard showing monthly revenue chart" />

<!-- GOOD: Decorative image -->
<img src="/divider.svg" alt="" role="presentation" />
```

### 2. Insufficient color contrast (WCAG 1.4.3)
Minimum ratios: 4.5:1 for normal text, 3:1 for large text (18px+ or 14px bold).
```css
/* FAILS: 2.8:1 ratio */
.muted { color: #999999; }

/* PASSES: 4.6:1 ratio */
.muted { color: #595959; }
```
Tailwind tip: `text-gray-500` often fails on white. Use `text-gray-600` or darker.

### 3. Missing form labels (WCAG 1.3.1)
```svelte
<!-- BAD: No label association -->
<input type="email" placeholder="Email" />

<!-- GOOD: Explicit label -->
<label for="email">Email</label>
<input id="email" type="email" />

<!-- GOOD: Visually hidden label -->
<label for="search" class="sr-only">Search</label>
<input id="search" type="search" placeholder="Search..." />
```

### 4. Missing focus indicators (WCAG 2.4.7)
```css
/* BAD: Removes focus entirely */
*:focus { outline: none; }

/* GOOD: Visible focus ring */
*:focus-visible {
  outline: 3px solid #0066CC;
  outline-offset: 2px;
}
```
Tailwind: Use `focus-visible:ring-2 focus-visible:ring-offset-2`.

### 5. Non-semantic interactive elements (WCAG 4.1.2)
```svelte
<!-- BAD: Div as button (not keyboard accessible) -->
<div on:click={submit}>Submit</div>

<!-- GOOD: Semantic button -->
<button type="submit" on:click={submit}>Submit</button>
```

### 6. Missing page title (WCAG 2.4.2)
```svelte
<!-- In +page.svelte or +layout.svelte -->
<svelte:head>
  <title>Dashboard — __COMPANY_NAME__</title>
</svelte:head>
```

### 7. Missing language attribute (WCAG 3.1.1)
```html
<!-- app.html -->
<html lang="en">
```

### 8. Missing heading hierarchy (WCAG 1.3.1)
```svelte
<!-- BAD: Skips h2 -->
<h1>Dashboard</h1>
<h3>Revenue</h3>

<!-- GOOD: Sequential -->
<h1>Dashboard</h1>
<h2>Revenue</h2>
```

### 9. Links without discernible text (WCAG 2.4.4)
```svelte
<!-- BAD: No text -->
<a href="/settings"><Icon name="gear" /></a>

<!-- GOOD: Screen reader text -->
<a href="/settings" aria-label="Settings">
  <Icon name="gear" />
</a>
```

### 10. Missing error identification (WCAG 3.3.1)
```svelte
<!-- BAD: No error feedback -->
{#if error}
  <p class="text-red-500">{error}</p>
{/if}

<!-- GOOD: Associated error with aria -->
<input id="email" type="email" aria-describedby="email-error" aria-invalid={!!error} />
{#if error}
  <p id="email-error" role="alert" class="text-red-500">{error}</p>
{/if}
```

## Manual Checks (Not Catchable by Automation)

These require human verification — axe-core marks them as "incomplete":

### Keyboard Navigation
```
[ ] All interactive elements reachable via Tab
[ ] Tab order matches visual order
[ ] Focus never gets trapped (can always Tab/Escape out)
[ ] Modals trap focus correctly (Tab cycles within modal)
[ ] Escape closes modals and returns focus to trigger
[ ] Skip-to-content link present and works
```

### Screen Reader Testing
```
[ ] Page structure makes sense when read linearly
[ ] Dynamic content updates announced (aria-live regions)
[ ] Form errors announced when they appear
[ ] Loading states communicated (aria-busy, status messages)
[ ] Custom components have correct ARIA roles
```

### Motion and Animation
```
[ ] Animations respect prefers-reduced-motion
[ ] No content flashes more than 3 times per second
[ ] Auto-playing content can be paused
```

SvelteKit pattern for reduced motion:
```svelte
<script>
  import { browser } from '$app/environment';
  const prefersReducedMotion = browser
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
</script>

{#if !prefersReducedMotion}
  <div class="animate-fade-in">...</div>
{:else}
  <div>...</div>
{/if}
```

## Audit Report Template

```markdown
# Accessibility Audit Report
**URL**: [preview or production URL]
**Standard**: WCAG 2.2 Level AA
**Date**: [ISO 8601]
**Tools**: axe-core 4.x + manual testing

## Automated Scan Results
- **Violations**: [count]
- **Passes**: [count]
- **Incomplete (needs review)**: [count]

## Violations by Impact

### Critical
| Rule | Count | Pages affected | Fix |
|------|-------|---------------|-----|
| image-alt | 3 | /products, /about | Add alt attributes |

### Serious
| Rule | Count | Pages affected | Fix |
|------|-------|---------------|-----|
| color-contrast | 5 | Site-wide | Darken muted text |

### Moderate
(table)

### Minor
(table)

## Manual Testing Results

### Keyboard Navigation
- ✅ All interactive elements reachable
- ❌ Focus trapped in date picker — needs Escape handler

### Screen Reader (VoiceOver)
- ✅ Page structure reads correctly
- ❌ Toast notifications not announced

## Summary
- **Automated**: [X] violations across [Y] pages
- **Manual**: [X] issues found
- **Verdict**: [PASS / NEEDS WORK]
- **Estimated fix effort**: [hours]
```

## Relationship to Other Skills

- **Feeds into**: `reality-checker` (accessibility is part of Gate 2 evidence)
- **Runs alongside**: `visual-qa` (both test against preview URLs)
- **Runs in**: `ci.yml` workflow as a parallel job
