---
name: e2e-playwright
description: >
  End-to-end testing for SvelteKit applications on Cloudflare Pages using Playwright.
  Covers auth flows with Clerk, form action testing, SSR vs CSR verification, preview
  deployment testing, and cross-browser validation. Use when writing E2E tests, testing
  user flows, verifying auth integration, testing against preview URLs, or validating
  full-stack behavior. Triggers on: "e2e", "end to end", "Playwright", "user flow",
  "integration test", "auth flow", "form test", "full-stack test", "browser test",
  or "cross-browser".
---

# E2E Playwright Skill

Adapted from agency-agents evidence-collector patterns — dedicated E2E skill
for SvelteKit + Cloudflare Pages with Clerk auth.

## Setup

```bash
npm install -D @playwright/test
npx playwright install chromium firefox webkit
```

### Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? 'json' : 'html',
  outputDir: 'e2e-results',

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'mobile', use: { ...devices['iPhone 14'] } },
  ],

  webServer: process.env.BASE_URL ? undefined : {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
});
```

## Auth Flow Testing (Clerk)

### Auth Helper

```typescript
// e2e/helpers/auth.ts
import { Page } from '@playwright/test';

export async function loginAsTestUser(page: Page) {
  await page.goto('/login');

  // Clerk's sign-in component
  await page.getByLabel('Email address').fill(process.env.TEST_USER_EMAIL!);
  await page.getByRole('button', { name: 'Continue' }).click();
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!);
  await page.getByRole('button', { name: 'Continue' }).click();

  // Wait for redirect to dashboard
  await page.waitForURL('/dashboard', { timeout: 15000 });
}

export async function logout(page: Page) {
  await page.getByRole('button', { name: 'User menu' }).click();
  await page.getByRole('menuitem', { name: 'Sign out' }).click();
  await page.waitForURL('/');
}
```

### Auth Tests

```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';
import { loginAsTestUser, logout } from './helpers/auth';

test.describe('Authentication', () => {
  test('redirects unauthenticated users to login', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
  });

  test('login with valid credentials', async ({ page }) => {
    await loginAsTestUser(page);
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('logout returns to homepage', async ({ page }) => {
    await loginAsTestUser(page);
    await logout(page);
    await expect(page).toHaveURL('/');
  });

  test('expired session redirects to login', async ({ page }) => {
    await loginAsTestUser(page);
    // Clear auth cookies to simulate expiry
    await page.context().clearCookies();
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
  });
});
```

## Form Action Testing

```typescript
// e2e/projects.spec.ts
import { test, expect } from '@playwright/test';
import { loginAsTestUser } from './helpers/auth';

test.describe('Project management', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsTestUser(page);
  });

  test('creates a new project', async ({ page }) => {
    await page.goto('/projects');
    await page.getByPlaceholder('Project name').fill('E2E Test Project');
    await page.getByRole('button', { name: 'Create project' }).click();

    // SvelteKit form action redirects — verify the new project appears
    await expect(page.getByText('E2E Test Project')).toBeVisible();
  });

  test('validates empty project name', async ({ page }) => {
    await page.goto('/projects');
    await page.getByRole('button', { name: 'Create project' }).click();

    // Form action returns fail() — error message appears without page reload
    await expect(page.getByText('Name must be at least 2 characters')).toBeVisible();
  });

  test('deletes a project', async ({ page }) => {
    await page.goto('/projects');
    const project = page.getByText('E2E Test Project').locator('..');
    await project.getByRole('button', { name: 'Delete' }).click();

    // Confirm dialog
    await page.getByRole('button', { name: 'Confirm' }).click();
    await expect(page.getByText('E2E Test Project')).not.toBeVisible();
  });
});
```

## Progressive Enhancement Verification

SvelteKit form actions should work WITHOUT JavaScript:

```typescript
test('form works without JavaScript', async ({ page }) => {
  // Disable JS
  await page.route('**/*.js', route => route.abort());

  await page.goto('/projects');
  await page.getByPlaceholder('Project name').fill('No-JS Project');
  await page.getByRole('button', { name: 'Create project' }).click();

  // Should still work via standard form POST
  await expect(page.getByText('No-JS Project')).toBeVisible();
});
```

## Testing Against Preview Deployments

```yaml
# In CI — run E2E against the preview URL
- name: Run E2E tests on preview
  env:
    BASE_URL: ${{ steps.deploy.outputs.deployment-url }}
    TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
    TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
  run: npx playwright test --reporter=json
```

## SSR Verification

Ensure pages render server-side (not blank HTML waiting for JS):

```typescript
test('page renders server-side', async ({ page }) => {
  // Intercept and block all JS
  await page.route('**/*.js', route => route.abort());
  await page.goto('/');

  // Content should be visible even without JS (SSR)
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await expect(page.getByRole('navigation')).toBeVisible();
});
```

## Test Data Management

```typescript
// e2e/helpers/seed.ts
import { test as setup } from '@playwright/test';

setup('seed test data', async ({ request }) => {
  // Call a test-only API endpoint to seed data
  await request.post('/api/test/seed', {
    headers: { 'X-Test-Secret': process.env.TEST_SECRET! },
    data: {
      users: [{ email: 'test@axiom.ai', name: 'Test User' }],
      projects: [{ name: 'Seed Project', status: 'active' }],
    },
  });
});

setup('cleanup test data', async ({ request }) => {
  await request.post('/api/test/cleanup', {
    headers: { 'X-Test-Secret': process.env.TEST_SECRET! },
  });
});
```

Only expose `/api/test/*` routes when `ENVIRONMENT !== 'production'`.

## Common Patterns

### Wait for SvelteKit navigation
```typescript
// SvelteKit client-side nav doesn't trigger full page load
await page.getByRole('link', { name: 'Settings' }).click();
await page.waitForURL('/settings');
```

### Test loading states
```typescript
await page.goto('/dashboard');
// Skeleton should appear briefly
await expect(page.getByTestId('loading-skeleton')).toBeVisible();
// Then real content replaces it
await expect(page.getByTestId('loading-skeleton')).not.toBeVisible();
await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
```

### Test responsive behavior
```typescript
test('sidebar collapses on mobile', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await loginAsTestUser(page);
  await expect(page.getByTestId('sidebar')).not.toBeVisible();
  await page.getByRole('button', { name: 'Menu' }).click();
  await expect(page.getByTestId('sidebar')).toBeVisible();
});
```

## Relationship to Other Skills

- **Loaded by**: QA Lead agent
- **Complements**: `visual-qa` (screenshots), `a11y-auditor` (accessibility), `api-tester` (API-level)
- **Runs against**: `axiom-cicd` preview deployments
- **Feeds into**: `reality-checker` (Gate 2 evidence)
