---
name: security-engineer
description: >
  Security engineering for Cloudflare Workers applications. Covers supply chain security,
  edge CORS, rate limiting, Clerk JWT validation, R2 access control, threat modeling, and
  vulnerability remediation. Use when reviewing security, hardening endpoints, configuring
  auth, threat modeling, or responding to security findings. Triggers on: "security",
  "vulnerability", "CORS", "auth", "JWT", "rate limit", "injection", "XSS", "CSRF",
  "threat model", "penetration test", "hardening", "secrets", or "supply chain".
---

# Security Engineer Skill

Adapted from agency-agents `engineering-security-engineer.md` — rewritten for
Cloudflare Workers edge security model.

## Workers Security Model

Workers run in V8 isolates (not containers). This changes the threat model:

| Concern | Traditional | Workers |
|---------|-------------|---------|
| OS-level exploits | High risk | Not applicable (no OS) |
| Container escapes | Medium risk | Not applicable (isolates) |
| Supply chain | Medium | **High** — every dep runs at global edge |
| Secrets exposure | Environment vars | `wrangler secret put` (encrypted at rest) |
| CORS | Server config | **Manual in code** — Workers handle it |
| Rate limiting | Nginx/WAF | Workers rate limiting binding or custom |

## Security Checklist (Every PR)

### Authentication (Clerk)
```
[ ] JWT validated on every protected route via middleware
[ ] Token expiry checked (not just signature)
[ ] User ID extracted from token, not from request body
[ ] Unauthenticated routes explicitly marked (health, public API)
[ ] No secrets in client-accessible code (load functions in +page.server.ts only)
```

### Input Validation
```
[ ] All user input validated with Zod schemas
[ ] File uploads checked for type and size before R2 storage
[ ] URL parameters sanitized (no path traversal)
[ ] JSON body size limited (Workers: 100MB max, but set lower)
[ ] Query strings validated (SQL injection via query params)
```

### D1 Security
```
[ ] All queries parameterized (.prepare().bind())
[ ] No raw SQL from user input
[ ] Row-level access control (WHERE user_id = ?)
[ ] Sensitive columns excluded from SELECT (password hashes, tokens)
```

### CORS
```typescript
// Correct: Explicit origin allowlist
app.use('/api/*', cors({
  origin: ['https://myapp.pages.dev', 'https://myapp.com'],
  credentials: true,
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// WRONG: Wildcard with credentials
app.use('/api/*', cors({ origin: '*', credentials: true }));
```

### Rate Limiting
```typescript
// Using Workers rate limiting binding
export default {
  async fetch(req: Request, env: Env) {
    const { success } = await env.RATE_LIMITER.limit({ key: getClientIP(req) });
    if (!success) {
      return new Response('Too Many Requests', {
        status: 429,
        headers: { 'Retry-After': '60' },
      });
    }
    return app.fetch(req, env);
  },
};
```

### Headers
```typescript
// Security headers for Workers API responses
// Note: Cloudflare Pages adds some headers automatically for static assets,
// but Workers API responses need them set explicitly in code.
// You can also configure these via Cloudflare dashboard (Transform Rules)
// for site-wide coverage without code changes.
app.use('*', async (c, next) => {
  await next();
  c.header('X-Content-Type-Options', 'nosniff');
  c.header('X-Frame-Options', 'DENY');
  c.header('Referrer-Policy', 'strict-origin-when-cross-origin');
  c.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
});
```

## Threat Model Template

```markdown
# Threat Model: [Service Name]
**Stack**: SvelteKit + Workers + D1 + R2 + Clerk + Stripe

## Assets
- User PII (email, name) — stored in D1 + Clerk
- Payment data — Stripe only, never in D1
- File uploads — R2, authenticated access only
- Session tokens — Clerk JWTs, short-lived

## Trust Boundaries
| Boundary | From → To | Controls |
|----------|-----------|----------|
| Internet → Workers | User → API | TLS (automatic), rate limiting |
| Workers → D1 | API → database | Parameterized queries, binding auth |
| Workers → R2 | API → storage | Binding auth, key validation |
| Workers → Clerk | API → auth | HTTPS, API key |
| Workers → Stripe | API → payments | HTTPS, webhook signature verification |

## Top Threats
1. SQL injection via D1 — mitigated by parameterized queries
2. Broken auth — mitigated by Clerk JWT middleware on all /api/* routes
3. Supply chain attack via npm — mitigated by npm audit + Semgrep in CI
4. SSRF via user-provided URLs — mitigated by URL validation + allowlist
5. Data exposure via error messages — mitigated by generic error handler
```

## Supply Chain Hardening

Workers bundle all dependencies — every npm package runs at the global edge.

```
[ ] npm audit --audit-level=high passes in CI
[ ] Lock file committed and frozen installs used
[ ] No unnecessary dependencies (check bundle analyzer)
[ ] Semgrep SAST runs on every PR
[ ] SBOM generated on production deploys
[ ] Dependabot or Renovate configured for automated updates
```

## Secrets Management

```bash
# Set secrets (never in wrangler.toml [vars])
wrangler secret put CLERK_SECRET_KEY
wrangler secret put STRIPE_SECRET_KEY
wrangler secret put STRIPE_WEBHOOK_SECRET

# Rotate procedure:
# 1. Generate new secret in provider (Clerk/Stripe dashboard)
# 2. wrangler secret put KEY_NAME (new value)
# 3. Verify with health check
# 4. Revoke old secret in provider
```

Never store secrets in: `wrangler.toml`, `.env` files committed to git,
client-side code, PR comments, or D1 tables.

## Relationship to Other Skills

- **Loaded by**: DevOps Lead (primary), App Dev Lead (threat modeling)
- **Feeds into**: `axiom-cicd` (security scanning in CI), `reality-checker` (Gate 3)
- **References**: `cf-workers-api` (auth middleware patterns)
