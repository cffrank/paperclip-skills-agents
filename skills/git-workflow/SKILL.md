---
name: git-workflow
description: >
  Git branching strategies, conventional commits, history cleanup, and CI-friendly branch
  management for all __COMPANY_NAME__ projects. Shared skill loaded by every agent. Use when
  creating branches, writing commit messages, preparing PRs, resolving merge conflicts,
  cleaning up history, choosing branching strategies, or any git operation. Triggers on:
  "branch", "commit", "merge", "rebase", "PR", "pull request", "git flow", "trunk-based",
  "conventional commit", "squash", "cherry-pick", "worktree", "stash", "git history",
  "changelog", or any git-related task.
---

# Git Workflow Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`engineering-git-workflow-master.md` (64K+ stars, MIT license).

Shared across all __COMPANY_NAME__ agents — every agent uses the same git conventions.

## Branching Strategy: Trunk-Based (__COMPANY_NAME__ Default)

All __COMPANY_NAME__ projects use trunk-based development with short-lived feature branches.

```
main ─────●────●────●────●────●─── (always deployable)
           \  /      \  /
            ●         ●          (short-lived feature branches, <2 days)
```

### Branch Naming Convention

```
feat/short-description       ← New feature
fix/short-description        ← Bug fix
chore/short-description      ← Maintenance, deps, config
refactor/short-description   ← Code restructuring (no behavior change)
docs/short-description       ← Documentation only
test/short-description       ← Adding or fixing tests
```

Rules:
- Lowercase, hyphen-separated, no slashes beyond the prefix
- Keep branch names under 50 characters
- Delete branches after merge (GitHub auto-delete should be enabled)
- Never commit directly to `main` — always PR

### Environment Branches (__COMPANY_NAME__-Specific)

```
main      → production (auto-deploys via GitHub Actions)
staging   → staging environment (auto-deploys)
dev       → development environment (auto-deploys)
```

Promotion: `dev → staging → main` via PR. Never skip environments.

## Conventional Commits (Required)

Every commit message follows the [Conventional Commits](https://www.conventionalcommits.org/)
specification. This enables automated changelogs and semantic versioning.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | When to use | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(billing): add Stripe checkout flow` |
| `fix` | Bug fix | `fix(auth): handle expired Clerk sessions` |
| `chore` | Maintenance | `chore(deps): update wrangler to 3.99.0` |
| `refactor` | Restructure | `refactor(api): extract billing module` |
| `docs` | Documentation | `docs(readme): add D1 migration guide` |
| `test` | Tests | `test(billing): add checkout integration tests` |
| `ci` | CI/CD changes | `ci: add gradual rollout to deploy workflow` |
| `perf` | Performance | `perf(queries): batch D1 reads with db.batch()` |
| `style` | Formatting | `style: run biome format` |

### Scope

Use the module or feature area: `auth`, `billing`, `api`, `ui`, `db`, `ci`, `deps`.

### Breaking Changes

Add `!` after the type or a `BREAKING CHANGE:` footer:

```
feat(api)!: change /users response shape

BREAKING CHANGE: The `users` array is now nested under `data.users`
instead of being the top-level response.
```

### Commit Message Rules

1. **Imperative mood**: "add feature" not "added feature"
2. **No period** at the end of the subject line
3. **Subject line ≤ 72 characters**
4. **Body wraps at 72 characters**
5. **One logical change per commit** — don't mix a feature and a fix

## Pull Request Workflow

### Before Opening a PR

```bash
# 1. Fetch latest main
git fetch origin main

# 2. Rebase your branch onto main (clean linear history)
git rebase origin/main

# 3. Squash fixup commits
git rebase -i origin/main
# Mark fixup commits as 'f' (fixup) or 's' (squash)

# 4. Run local checks
npm run lint        # biome check
npm run test        # vitest
npm run build       # verify it builds

# 5. Force-push the cleaned branch
git push --force-with-lease
```

### PR Title Format

Same as conventional commits:
```
feat(billing): add Stripe checkout flow
fix(auth): handle expired Clerk sessions
```

### PR Description Template

```markdown
## What
[One sentence describing the change]

## Why
[Link to issue or brief explanation of the problem]

## How
[Key technical decisions and approach]

## Testing
- [ ] Unit tests added/updated
- [ ] Tested in preview deployment
- [ ] D1 migrations tested locally

## Checklist
- [ ] Follows conventional commit format
- [ ] No `console.log` left in code
- [ ] No hardcoded secrets
- [ ] wrangler.toml changes reviewed
```

### Merge Strategy

- **Squash merge** for feature branches → keeps main history clean
- **Merge commit** for environment promotions (staging → main) → preserves
  the full history of what was promoted
- **Never rebase** main or staging — only rebase feature branches

## History Cleanup Patterns

### Interactive Rebase (Before PR)

```bash
# Squash the last 5 commits into one
git rebase -i HEAD~5

# In the editor:
pick abc1234 feat(billing): add checkout
fixup def5678 fix typo
fixup ghi9012 wip
fixup jkl3456 more fixes
fixup mno7890 final cleanup
```

### Amend Last Commit

```bash
# Fix the last commit message
git commit --amend -m "feat(billing): add Stripe checkout flow"

# Add forgotten files to last commit
git add forgotten-file.ts
git commit --amend --no-edit
```

### Undo Patterns

```bash
# Undo last commit, keep changes staged
git reset --soft HEAD~1

# Undo last commit, keep changes unstaged
git reset HEAD~1

# Completely discard last commit
git reset --hard HEAD~1

# Revert a specific commit (creates new commit, safe for shared branches)
git revert <commit-sha>
```

## Worktrees (Advanced)

For working on multiple branches simultaneously without stashing:

```bash
# Create a worktree for a hotfix while keeping current work
git worktree add ../myapp-hotfix main
cd ../myapp-hotfix
git checkout -b fix/critical-bug

# When done
cd ../myapp
git worktree remove ../myapp-hotfix
```

Useful for: hotfixes during a long feature branch, reviewing PRs locally,
running tests on a different branch without switching.

## CI-Friendly Practices

1. **Always rebase before merge** — avoids merge commits that make `git bisect` harder
2. **Atomic commits** — each commit should build and pass tests independently
3. **No force-push to shared branches** (main, staging, dev)
4. **Use `--force-with-lease`** instead of `--force` on feature branches
5. **Tag releases** with semantic versions: `git tag v1.2.3`
6. **Signed commits** recommended (GPG or SSH key signing)

## .gitignore Essentials (__COMPANY_NAME__ Projects)

```gitignore
# Dependencies
node_modules/
.pnpm-store/

# Build output
dist/
.svelte-kit/
.wrangler/

# Environment
.env
.env.local
.dev.vars

# IDE
.vscode/settings.json
.idea/

# OS
.DS_Store
Thumbs.db

# Test
coverage/
test-results/

# Cloudflare local state
.mf/
```

## Conflict Resolution

When you hit a merge conflict during rebase:

```bash
# 1. See what's conflicting
git status

# 2. Open conflicting files, resolve manually
# Look for <<<<<<< HEAD ... ======= ... >>>>>>> markers

# 3. Stage resolved files
git add <resolved-file>

# 4. Continue the rebase
git rebase --continue

# 5. If things go sideways, abort and start over
git rebase --abort
```

**Rule of thumb**: If unsure about a conflict, ask the author of the
other change. Don't guess at intent.
