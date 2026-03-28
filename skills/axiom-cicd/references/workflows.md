# GitHub Actions Workflow Templates

Complete workflow files for Cloudflare-first CI/CD. Generate all six when setting up a
new project. Customize environment names and database bindings per project.

## 1. CI Workflow (`.github/workflows/ci.yml`)

Runs on every PR. Covers lint, test, security scan, and bundle size check.

```yaml
name: CI
on:
  pull_request:
    branches: [main, staging, dev]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci --frozen-lockfile
      - run: npx biome check .

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci --frozen-lockfile
      - run: npx vitest run --reporter=verbose --coverage
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/

  security:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci --frozen-lockfile

      # Dependency audit
      - run: npm audit --audit-level=high

      # Secret scanning
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # SAST with Semgrep
      - uses: semgrep/semgrep-action@v1
        with:
          config: >-
            p/javascript
            p/typescript
            p/owasp-top-ten

      # Wrangler config validation
      - run: npx wrangler deploy --dry-run --outdir=dist
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}

  bundle-size:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci --frozen-lockfile
      - run: npx wrangler deploy --dry-run --outdir=dist
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
      - name: Report bundle size
        run: |
          SIZE=$(du -sb dist/ | cut -f1)
          SIZE_KB=$((SIZE / 1024))
          echo "### Bundle Size: ${SIZE_KB}KB" >> $GITHUB_STEP_SUMMARY
          # Workers limit: 10MB compressed for paid, 1MB for free
          if [ $SIZE -gt 10485760 ]; then
            echo "::error::Bundle exceeds 10MB Workers limit"
            exit 1
          fi
```

## 2. Preview Deployment (`.github/workflows/deploy-preview.yml`)

Posts preview URL as PR comment. Uses fork-safe two-step pattern.

```yaml
name: Deploy Preview
on:
  pull_request:
    branches: [main, staging, dev]
    types: [opened, synchronize, reopened]

concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  deploy-preview:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      deployments: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci --frozen-lockfile
      - run: npm run build

      - name: Deploy to Cloudflare Pages
        id: deploy
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: pages deploy dist --project-name=${{ github.event.repository.name }}
          # For Workers (not Pages):
          # command: deploy --env preview

      - name: Comment preview URL
        uses: actions/github-script@v7
        with:
          script: |
            const url = '${{ steps.deploy.outputs.deployment-url }}';
            const alias = '${{ steps.deploy.outputs.pages-deployment-alias-url }}';
            const body = `## 🚀 Preview Deployment

            | | URL |
            |---|---|
            | **Preview** | ${url} |
            | **Branch alias** | ${alias || 'N/A'} |

            <sub>Deployed by __COMPANY_NAME__ CI/CD • ${new Date().toISOString()}</sub>`;

            // Find and update existing comment or create new
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            });
            const botComment = comments.find(c =>
              c.body.includes('Preview Deployment') && c.user.type === 'Bot'
            );
            if (botComment) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: botComment.id,
                body,
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body,
              });
            }
```

## 3. Deploy Staging (`.github/workflows/deploy-staging.yml`)

Triggered on merge to `staging`. Runs D1 migrations before deploy.

```yaml
name: Deploy Staging
on:
  push:
    branches: [staging]

concurrency:
  group: deploy-staging
  cancel-in-progress: false  # Never cancel in-progress deploys

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile
      - run: npx vitest run

  migrate:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile
      - name: Apply D1 migrations
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: d1 migrations apply MY_DB --remote --env staging

  deploy:
    runs-on: ubuntu-latest
    needs: migrate
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile
      - name: Deploy Worker
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: deploy --env staging

      - name: Post-deploy smoke test
        run: |
          WORKER_URL="https://myapp-staging.your-subdomain.workers.dev"
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$WORKER_URL/health")
          if [ "$STATUS" != "200" ]; then
            echo "::error::Smoke test failed with status $STATUS"
            exit 1
          fi
```

## 4. Deploy Production (`.github/workflows/deploy-production.yml`)

Gradual rollout with health gates. See `references/progressive.md` for details.

```yaml
name: Deploy Production
on:
  push:
    branches: [main]

concurrency:
  group: deploy-production
  cancel-in-progress: false

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile
      - run: npx vitest run

  migrate:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile
      - name: Apply D1 migrations
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: d1 migrations apply MY_DB --remote

  deploy:
    runs-on: ubuntu-latest
    needs: migrate
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile

      # Upload version without deploying
      - name: Upload new version
        id: upload
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: versions upload

      # Start gradual rollout at 10%
      - name: Canary deploy (10%)
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: versions deploy --percentage 10

      # Health gate: wait and check error rates
      - name: Health gate (5 min observation)
        run: |
          echo "Observing canary for 5 minutes..."
          sleep 300
          # Query Workers analytics for error rate
          # If error rate > threshold, the rollback job handles it

      # Promote to 100%
      - name: Promote to 100%
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: versions deploy --percentage 100

  notify:
    runs-on: ubuntu-latest
    needs: deploy
    if: always()
    steps:
      - name: Notify deploy result
        run: |
          if [ "${{ needs.deploy.result }}" == "success" ]; then
            echo "✅ Production deploy succeeded"
          else
            echo "❌ Production deploy failed — check rollback"
          fi
          # Integrate with Slack MCP or webhook here
```

## 5. Rollback (`.github/workflows/rollback.yml`)

Manual trigger with version selection. Auto-trigger from health gate failure.

```yaml
name: Rollback
on:
  workflow_dispatch:
    inputs:
      version_id:
        description: 'Version ID to roll back to (leave empty for previous)'
        required: false
      reason:
        description: 'Reason for rollback'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile

      - name: Execute rollback
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: '3.99.0'
          command: rollback ${{ github.event.inputs.version_id }}

      - name: Verify rollback
        run: |
          WORKER_URL="https://myapp.your-subdomain.workers.dev"
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$WORKER_URL/health")
          echo "Post-rollback health check: $STATUS"
          if [ "$STATUS" != "200" ]; then
            echo "::error::Rollback health check failed"
            exit 1
          fi

      - name: Create rollback issue
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `🔄 Rollback executed: ${{ github.event.inputs.reason }}`,
              body: `## Rollback Details\n\n- **Version**: ${{ github.event.inputs.version_id || 'previous' }}\n- **Reason**: ${{ github.event.inputs.reason }}\n- **Triggered by**: @${{ github.actor }}\n- **Time**: ${new Date().toISOString()}\n\n⚠️ D1 schema changes, KV data, and R2 objects were NOT reverted.\nReview data layer compatibility.`,
              labels: ['rollback', 'incident']
            });
```

## 6. Drift Detection (`.github/workflows/drift-check.yml`)

Scheduled daily. Compares deployed Worker config against Git.

```yaml
name: Drift Detection
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6am UTC
  workflow_dispatch:

jobs:
  check-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --frozen-lockfile

      - name: Check deployed vs Git state
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        run: |
          # Get deployed Worker details via API
          WORKER_NAME=$(grep 'name' wrangler.toml | head -1 | cut -d'"' -f2)

          # Compare routes
          DEPLOYED_ROUTES=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/$WORKER_NAME/routes" \
            | jq -r '.result')

          # Compare environment variables (non-secret)
          DEPLOYED_VARS=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/$WORKER_NAME/settings" \
            | jq -r '.result.bindings')

          # Parse wrangler.toml for expected state
          EXPECTED_ROUTES=$(npx wrangler deploy --dry-run 2>&1 | grep -i route || true)

          echo "## Drift Report" >> $GITHUB_STEP_SUMMARY
          echo "Deployed routes: $DEPLOYED_ROUTES" >> $GITHUB_STEP_SUMMARY
          echo "Expected routes: $EXPECTED_ROUTES" >> $GITHUB_STEP_SUMMARY

          # Alert if drift detected
          # Customize comparison logic per project

      - name: Alert on drift
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '⚠️ Configuration drift detected',
              body: 'Deployed Worker configuration differs from Git state. Review the drift check workflow run for details.',
              labels: ['drift', 'ops']
            });
```

## Monorepo Variant

For projects with multiple Workers (e.g., Product D FSM, Product E), use
path filters and Turborepo:

```yaml
# In ci.yml, add path filters:
on:
  pull_request:
    paths:
      - 'apps/api/**'
      - 'packages/shared/**'

# In deploy jobs, use Turborepo:
- run: npx turbo run build --filter=@myapp/api
- run: npx turbo run deploy --filter=@myapp/api
```

Each Worker has its own `wrangler.toml` in its directory. Shared packages are in
`packages/`. Use `pnpm workspaces` for dependency management.
