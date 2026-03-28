---
name: code-reviewer
description: >
  Code review skill with Cloudflare Workers runtime checks, D1 query safety, Drizzle ORM
  patterns, wrangler.toml validation, and SvelteKit conventions. Provides three-tier
  feedback (blocker/suggestion/nit) with copy-paste-ready fixes. Use when reviewing PRs,
  auditing code quality, checking Workers compatibility, or mentoring through code review.
  Triggers on: "review", "PR", "code review", "check this code", "is this safe", "review
  my changes", "code quality", or any request to evaluate code.
---

# Code Reviewer Skill

Adapted from agency-agents `engineering-code-reviewer.md` — enhanced with
Cloudflare Workers runtime checks, D1 safety, and SvelteKit conventions.

## Review Priority System

### Blockers (must fix before merge)
- Security vulnerabilities (SQL injection, XSS, auth bypass)
- Workers runtime incompatibility (Node built-ins, `process.env`)
- Data loss risk (missing `await` on D1, destructive migrations)
- Stack violations (Prisma usage, wrong framework)

### Suggestions (should fix, non-blocking)
- Missing input validation, error handling
- Performance issues (N+1 queries, unbatched D1 writes)
- Missing TypeScript types
- Accessibility gaps in UI components

### Nits (style, optional improvements)
- Naming conventions, code organization
- Documentation gaps
- Tailwind class ordering

## Review Comment Format

```
[BLOCKER] Security: SQL injection risk
Line 42: User input interpolated directly into query.
Why: Attacker could inject `'; DROP TABLE users; --`
Fix:
  const user = await db
    .prepare('SELECT * FROM users WHERE email = ?')
    .bind(email)
    .first();
```

## Cloudflare-Specific Checks

### Workers Runtime
```
[ ] No require() or __dirname/__filename
[ ] No process.env — uses env parameter or platform.env
[ ] No dynamic import() — all imports static
[ ] No fs, path, child_process, or Node built-ins
[ ] No setTimeout/setInterval outside request context
[ ] Uses ctx.waitUntil() for background work, not dangling promises
[ ] Bundle stays under 10MB (check with --dry-run)
```

### D1 Safety
```
[ ] All queries use .prepare().bind() — never string interpolation
[ ] Every D1 operation has await
[ ] Multiple writes use db.batch([...])
[ ] No SELECT * in production code — specify columns
[ ] Transactions are single-aggregate (D1 single-writer model)
[ ] Migrations are additive or use expand-and-contract
```

### SvelteKit Conventions
```
[ ] Server data in +page.server.ts, not +page.ts
[ ] Form actions use fail() for errors, redirect() for success
[ ] No secrets in client-accessible load functions
[ ] Platform bindings accessed via platform.env, not global
[ ] Components use shadcn-svelte, not custom implementations
[ ] Tailwind classes only — no <style> blocks
```

### wrangler.toml
```
[ ] compatibility_date is set and recent (within 6 months)
[ ] All environments have matching bindings
[ ] No secrets in [vars] — uses wrangler secret put
[ ] Routes don't conflict across environments
[ ] Migrations dir matches vitest config
```

### Drizzle ORM
```
[ ] Schema changes have corresponding migration files
[ ] No Prisma imports anywhere in codebase
[ ] Relations defined correctly
[ ] Indexes on frequently queried columns
```

## Anti-Patterns to Flag

| Pattern | Severity | Fix |
|---------|----------|-----|
| `process.env.X` | Blocker | Use `env.X` from handler |
| `import fs from 'fs'` | Blocker | Use R2 or KV |
| `db.exec(userInput)` | Blocker | Use `.prepare().bind()` |
| `await Promise.all(items.map(i => db.prepare(...).run()))` | Suggestion | Use `db.batch([...])` |
| `fetch('http://...')` | Suggestion | Use HTTPS only |
| `JSON.parse(body)` without try/catch | Suggestion | Wrap in try/catch or use Zod |
| `console.log` in production code | Nit | Remove or use structured logging |
| Inline styles in Svelte components | Nit | Use Tailwind classes |

## Review Workflow

1. Read the PR description and linked issue
2. Check changed files list — flag wrangler.toml, migration, and workflow changes
3. Review each file against the checklists above
4. Post inline comments with severity + fix
5. Write summary: X blockers, Y suggestions, Z nits
6. Verdict: Approve / Request Changes / Comment

## Relationship to Other Skills

- **Loaded by**: App Dev Lead (primary), QA Lead (secondary)
- **Feeds into**: `reality-checker` (code quality is part of Gate 1)
- **References**: `cf-workers-api` (backend patterns), `sveltekit-frontend` (UI patterns)
