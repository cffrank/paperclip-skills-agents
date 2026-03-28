---
name: cloudflare-stack
description: >
  Mandatory Cloudflare-first technology stack rules for all __COMPANY_NAME__ projects. Defines
  approved technologies, forbidden alternatives, binding patterns, environment conventions,
  and cross-cutting concerns. Every agent in the Paperclip org loads this skill. Use as
  the source of truth for technology decisions, stack questions, or when any agent needs
  to verify whether a tool/library/service is approved. Triggers on: "what stack", "which
  framework", "approved tools", "can I use", "technology decision", "stack rules",
  "Cloudflare", "binding", "environment", "wrangler.toml", or any question about what
  technologies to use.
---

# Cloudflare Stack Skill

Shared skill loaded by every agent. This is the single source of truth for
__COMPANY_NAME__'s mandatory technology stack. If it's not listed here, it needs an ADR
(see `software-architect` skill) before adoption.

## The Stack

### Approved (use these, no discussion needed)

| Layer | Technology | Why |
|-------|-----------|-----|
| **Frontend framework** | SvelteKit | SSR on Workers, file-based routing, form actions |
| **UI components** | shadcn-svelte | Accessible, composable, Tailwind-native |
| **Styling** | Tailwind CSS 4 | Utility-first, no custom CSS needed |
| **Language** | TypeScript (strict mode) | Type safety across frontend + Workers |
| **Runtime** | Cloudflare Workers (workerd) | Edge compute, global deployment |
| **Database** | Cloudflare D1 (SQLite) | Edge-local reads, zero connection overhead |
| **ORM** | Drizzle | Type-safe, D1-compatible, generates migrations |
| **Object storage** | Cloudflare R2 | S3-compatible, no egress fees |
| **Cache** | Cloudflare KV | Global key-value, low-latency reads |
| **AI inference** | Cloudflare Workers AI | Edge inference, free tier |
| **AI proxy** | Cloudflare AI Gateway | Cache, rate limit, log AI requests |
| **Vector search** | Cloudflare Vectorize | Native vector DB for RAG |
| **Auth** | Clerk | Managed auth, JWT validation, user management |
| **Payments** | Stripe | Checkout, subscriptions, webhooks |
| **Email** | Resend | Transactional email API |
| **Linting** | Biome | Fast, replaces ESLint + Prettier |
| **Testing** | Vitest + @cloudflare/vitest-pool-workers | Tests in workerd runtime |
| **E2E testing** | Playwright | Cross-browser, screenshot evidence |
| **CI/CD** | GitHub Actions + cloudflare/wrangler-action@v3 | Deploy to CF |
| **Git hosting** | GitHub | Repos, PRs, Actions, Issues |
| **Secrets** | Proton Pass → GitHub Secrets → wrangler secret | Encrypted chain |
| **Telephony** | Telnyx | SIP trunks, SMS, phone numbers |
| **Voice AI** | ElevenLabs Conversational AI | STT-LLM-TTS pipeline |
| **Icons** | Lucide Svelte | Consistent icon set |

### Forbidden (never use, no exceptions)

| Technology | Why forbidden | Use instead |
|-----------|--------------|-------------|
| **Prisma** | `migrate deploy` fails on D1's `_cf_KV` table | Drizzle |
| **Retell AI** | Incompatible with __COMPANY_NAME__ architecture | ElevenLabs |
| **Express.js** | Not Workers-compatible | Hono or SvelteKit API routes |
| **React** | Not the chosen framework | SvelteKit |
| **Next.js** | Not the chosen framework | SvelteKit |
| **MongoDB** | No Cloudflare equivalent | D1 (SQLite) |
| **Redis** | Use Cloudflare-native | KV or Durable Objects |
| **AWS S3** | Use Cloudflare-native | R2 |
| **Vercel** | Use Cloudflare-native | Pages |
| **Netlify** | Use Cloudflare-native | Pages |
| **Docker** | Workers are the runtime | Workers (no containers) |
| **ESLint + Prettier** | Slower, more config | Biome |
| **Jest** | Incompatible with vitest-pool-workers | Vitest |
| **pages-action@v1** | Deprecated | wrangler-action@v3 |

### Requires ADR (case-by-case)

| Technology | When it might be OK |
|-----------|-------------------|
| Hono | For standalone API Workers (no UI) |
| Durable Objects | For stateful coordination, WebSocket servers |
| Queues | For async job processing |
| Cron Triggers | For scheduled tasks |
| Service Bindings | For Worker-to-Worker RPC |
| Workers for Platforms | For multi-tenant isolation |

## Cloudflare Account

```
Account ID: __CF_ACCOUNT_ID__
```

All resources (Workers, D1, R2, KV, Pages) live in this account.

## Environment Conventions

Every project has three environments with matching branches:

| Branch | Environment | D1 suffix | R2 suffix | Purpose |
|--------|-------------|-----------|-----------|---------|
| `dev` | dev | `-dev` | `-dev` | Daily development |
| `staging` | staging | `-staging` | `-staging` | QA validation |
| `main` | production | `-prod` | (no suffix) | Live users |

Promotion: `dev → staging → main` via PR. Never skip environments.
Never deploy to production manually — always through CI/CD.

## Binding Naming Conventions

```toml
# wrangler.toml — consistent across all projects
[[d1_databases]]
binding = "DB"           # Always "DB", never "DATABASE" or "D1"

[[r2_buckets]]
binding = "ASSETS"       # Always "ASSETS" for primary bucket

[[kv_namespaces]]
binding = "CACHE"        # Always "CACHE" for primary KV

[ai]
binding = "AI"           # Always "AI"

[[vectorize]]
binding = "VECTORIZE"    # Always "VECTORIZE"
```

## TypeScript Conventions

### Strict Mode
```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### Import Aliases
```json
// svelte.config.js (via vite.resolve.alias)
{
  "$lib": "src/lib",
  "$components": "src/lib/components"
}
```

### File Naming
- Components: `PascalCase.svelte` (`ProjectCard.svelte`)
- Everything else: `kebab-case.ts` (`auth-middleware.ts`)
- Schema files: `schema.ts` (single file for small projects, split by domain for large)
- Test files: `*.test.ts` co-located with source

## Cross-Cutting Rules

### Error Handling
- Workers: Return structured JSON errors, never raw stack traces
- SvelteKit: Use `error()` helper, custom error pages
- D1: Catch constraint violations, return 409 Conflict

### Logging
- Use `console.log/warn/error` in Workers (captured by `wrangler tail`)
- Structured JSON for machine-parseable logs
- Never log secrets, PII, or full request bodies

### Security
- Auth on every `/api/*` route via Clerk middleware
- CORS allowlist (never `*` with credentials)
- Rate limiting on public endpoints
- Secrets via `wrangler secret put`, never in code or config

### Performance
- D1 queries: parameterized, batched, indexed
- R2: stream large objects, never buffer
- KV: cache hot reads with TTL
- Static assets: served by Cloudflare edge automatically
- Bundle: < 10MB (Workers limit)

### Data
- Money stored as integer cents (never floats)
- Dates as ISO 8601 TEXT in D1 (never Unix timestamps)
- IDs as UUID TEXT (never auto-increment for distributed systems)
- Soft delete preferred over hard delete for auditable data

## When an Agent Is Unsure

If any agent encounters a technology choice not covered here:

1. Check this skill first — if it's listed as forbidden, stop
2. If not listed at all, propose an ADR using the `software-architect` skill
3. Never adopt a new dependency without explicit approval
4. When in doubt, use the Cloudflare-native option

## Relationship to Other Skills

- **Loaded by**: Every agent in the Paperclip org (shared)
- **Overrides**: Any agent-specific technology preferences
- **Extended by**: `software-architect` (ADRs for new tech decisions)
- **Enforced by**: `code-reviewer` (stack compliance checks)
