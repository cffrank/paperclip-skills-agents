# Security Scanning in CI/CD

## Layered Security Model

Security runs progressively through the pipeline. Earlier stages are fast and
non-blocking; later stages are thorough and blocking.

```
Pre-commit (local)     → Gitleaks, Biome lint       → Non-blocking
PR (CI)                → Semgrep SAST, npm audit     → Warn on High, Block on Critical
Merge to main          → Full SCA, SBOM generation   → Block on Critical
Deploy                 → wrangler.toml validation     → Block on any error
Nightly (scheduled)    → Full dependency audit        → Alert
```

## Tool Configuration

### Gitleaks (Secret Detection)

Catches accidentally committed secrets, API keys, tokens.

```yaml
- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Custom rules for Cloudflare tokens (`.gitleaks.toml`):
```toml
[[rules]]
id = "cloudflare-api-token"
description = "Cloudflare API Token"
regex = '''(?i)cloudflare[_\-]?api[_\-]?token\s*[:=]\s*['"]?([a-zA-Z0-9_\-]{40})'''
tags = ["key", "cloudflare"]

[[rules]]
id = "cloudflare-api-key"
description = "Cloudflare Global API Key"
regex = '''(?i)cloudflare[_\-]?api[_\-]?key\s*[:=]\s*['"]?([a-f0-9]{37})'''
tags = ["key", "cloudflare"]
```

### Semgrep (SAST)

Static analysis for code vulnerabilities.

```yaml
- uses: semgrep/semgrep-action@v1
  with:
    config: >-
      p/javascript
      p/typescript
      p/owasp-top-ten
      p/nodejs
```

Cloudflare-specific rules to add:
- Detect unvalidated `request.url` usage in Workers
- Flag missing rate limiting on public endpoints
- Warn on `eval()` or `Function()` in Worker code
- Check for missing CORS origin validation

### npm audit (SCA)

Dependency vulnerability scanning.

```yaml
- run: npm audit --audit-level=high --omit=dev
```

For stricter enforcement:
```yaml
- run: npm audit --audit-level=moderate --omit=dev
  continue-on-error: false
```

### SBOM Generation

Generate Software Bill of Materials on every production deploy:

```yaml
- name: Generate SBOM
  run: npx @cyclonedx/cyclonedx-npm --output-file sbom.json
- uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: sbom.json
```

### wrangler.toml Validation

Check for misconfigurations before deploy:

```bash
# Dry run catches config errors without deploying
npx wrangler deploy --dry-run --outdir=dist

# Check for common issues:
# - Missing compatibility_date
# - Incorrect binding names
# - Missing environment overrides
# - Route conflicts
```

### Claude Code Security Review

For AI-powered security review (optional, requires Anthropic API key):

```yaml
- uses: anthropics/claude-code-security-review@v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    model: claude-sonnet-4-20250514
```

Note: This action is NOT hardened against prompt injection. Only use it on
trusted PRs (not from forks).

## Workers-Specific Security Concerns

1. **Supply chain risk is elevated.** Every bundled dependency runs at the
   global edge. Audit dependencies aggressively.
2. **No filesystem isolation.** Workers share the V8 isolate model. Avoid
   dynamic imports or code generation.
3. **Secrets in environment variables.** Use `wrangler secret put` for
   sensitive values, never `[vars]` in `wrangler.toml`.
4. **CORS must be explicit.** Workers handle CORS manually. Validate
   `Origin` headers against an allowlist.
5. **Rate limiting via Cloudflare.** Use Workers rate limiting bindings
   rather than in-code counters.

## Fail-Only-On-New Policy

To avoid blocking deploys on pre-existing vulnerabilities:

```yaml
- name: Security scan (new findings only)
  run: |
    # Compare against baseline
    npx semgrep --config auto --json --output current.json .
    if [ -f .semgrep-baseline.json ]; then
      NEW_FINDINGS=$(jq '.results | length' current.json)
      BASELINE=$(jq '.results | length' .semgrep-baseline.json)
      if [ $NEW_FINDINGS -gt $BASELINE ]; then
        echo "::error::New security findings detected"
        exit 1
      fi
    fi
```
