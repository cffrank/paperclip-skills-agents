# Preview Deployments

## How Cloudflare Pages Previews Work

Every PR automatically gets a unique preview URL:
- **Unique URL**: `<hash>.<project>.pages.dev`
- **Branch alias**: `<branch>.<project>.pages.dev`

Preview deployments include `X-Robots-Tag: noindex` to prevent SEO impact.

## Standard Implementation

See `references/workflows.md` for the full `deploy-preview.yml` workflow.
The key steps:

1. Build the project
2. Deploy to Pages with `wrangler pages deploy`
3. Capture `deployment-url` and `pages-deployment-alias-url` outputs
4. Post/update a PR comment with the URLs

## Workers Preview (Non-Pages Projects)

For pure Workers (API-only, no frontend), use environment-based previews:

```yaml
- name: Deploy preview Worker
  uses: cloudflare/wrangler-action@v3
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    wranglerVersion: '3.99.0'
    command: deploy --env preview
```

Configure in `wrangler.toml`:
```toml
[env.preview]
name = "myapp-preview-${{ github.event.pull_request.number }}"
routes = []  # No production routes
```

## Fork-Safe Previews

When PRs come from forks, secrets aren't available. Use a two-workflow
pattern:

**Workflow 1**: `build-preview.yml` (runs on fork PR, no secrets):
```yaml
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: preview-build
          path: dist/
```

**Workflow 2**: `deploy-preview.yml` (runs on workflow_run, has secrets):
```yaml
on:
  workflow_run:
    workflows: [Build Preview]
    types: [completed]
jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: preview-build
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy dist --project-name=myapp
```

## Preview with D1 (Isolated Database)

For previews that need database access, create an ephemeral D1 database:

```yaml
- name: Create preview D1
  run: |
    DB_NAME="preview-pr-${{ github.event.pull_request.number }}"
    npx wrangler d1 create $DB_NAME || true
    npx wrangler d1 migrations apply $DB_NAME --remote
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

Clean up on PR close:
```yaml
on:
  pull_request:
    types: [closed]
jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete preview D1
        run: |
          DB_NAME="preview-pr-${{ github.event.pull_request.number }}"
          npx wrangler d1 delete $DB_NAME --force
```

## PR Comment Template

The preview comment (posted by the workflow) should include:

```markdown
## 🚀 Preview Deployment

| | URL |
|---|---|
| **Preview** | https://abc123.myapp.pages.dev |
| **Branch** | feature-xyz.myapp.pages.dev |

**Changes in this PR:**
- Bundle size: 145KB (+2KB from main)
- D1 migrations: 1 new migration applied
- Security: No new findings

<sub>Deployed by __COMPANY_NAME__ CI/CD • 2026-03-27T10:30:00Z</sub>
```
