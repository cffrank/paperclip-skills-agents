# AI Code Review

## Claude Code Action Integration

Use Anthropic's official `claude-code-action` for AI-powered PR review.
This runs the full Claude Code runtime inside GitHub Actions.

### Setup

```yaml
name: AI Review
on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]

jobs:
  claude-review:
    if: |
      (github.event_name == 'pull_request') ||
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude'))
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          model: claude-sonnet-4-20250514
          # Optional: add custom instructions
          custom_instructions: |
            You are reviewing code for a Cloudflare Workers project.
            Pay special attention to:
            - Workers API usage patterns and edge runtime compatibility
            - D1 query patterns (parameterized queries, batch operations)
            - R2 access patterns (streaming, multipart uploads)
            - Missing error handling for binding operations
            - CORS configuration completeness
            - Rate limiting implementation
            - wrangler.toml configuration correctness
            - Drizzle ORM usage (never suggest Prisma)
            - SvelteKit SSR compatibility with Workers
```

### Cloudflare-Specific Review Rules

When reviewing PRs, the AI agent checks for:

**Workers Runtime Compatibility:**
- No Node.js built-in imports (`fs`, `path`, `crypto` → use Web APIs)
- No `process.env` → use `env` parameter from Worker handler
- No dynamic `import()` → bundle all dependencies
- No `__dirname` or `__filename`
- Avoid `setTimeout`/`setInterval` outside of request context

**D1 Query Safety:**
- Always use parameterized queries (`prepare().bind()`)
- Never concatenate user input into SQL strings
- Batch operations for multiple writes (`db.batch([...])`)
- Check for missing `await` on D1 operations

**R2 Best Practices:**
- Stream large objects instead of loading into memory
- Use `onlyIf` for conditional operations
- Set appropriate `Content-Type` headers
- Use `httpMetadata` for cache control

**wrangler.toml Validation:**
- `compatibility_date` is set and recent
- All bindings have matching environment overrides
- Routes don't conflict across environments
- `node_compat` or `nodejs_compat` flags are set if needed

**Security:**
- No hardcoded secrets or API keys
- CORS `Access-Control-Allow-Origin` is not `*` in production
- Rate limiting is configured for public endpoints
- Input validation on all user-facing endpoints

## Review Comment Format

The AI review posts inline comments on specific lines plus a summary:

```markdown
## 🤖 AI Review Summary

### Issues Found
- 🔴 **Critical**: SQL injection risk in `src/routes/users.ts:42`
- 🟡 **Warning**: Missing error handling for D1 batch operation
- 🔵 **Info**: Consider using `env.DB.batch()` for these 3 sequential writes

### Cloudflare-Specific Notes
- ✅ Workers runtime compatible
- ✅ wrangler.toml configuration valid
- ⚠️ No rate limiting on `/api/public/*` routes

### Bundle Impact
- Size change: +2.1KB (145KB → 147.1KB)
- Well within 10MB Workers limit
```

## When NOT to Use AI Review

- On PRs from untrusted forks (prompt injection risk)
- On automated dependency update PRs (use npm audit instead)
- On documentation-only changes (waste of API credits)

Filter in the workflow:
```yaml
if: |
  github.event.pull_request.head.repo.full_name == github.repository &&
  !contains(github.event.pull_request.title, '[skip-review]') &&
  !startsWith(github.head_ref, 'dependabot/')
```
