---
name: perf-benchmarker
description: >
  Performance benchmarking for Cloudflare Workers. Covers CPU time measurement, cold start
  analysis, request duration profiling, D1 query latency, edge cache hit rates, and bundle
  size tracking. Use when performance testing, profiling slow endpoints, analyzing cold
  starts, benchmarking D1 queries, or tracking Core Web Vitals. Triggers on: "performance",
  "benchmark", "slow", "latency", "cold start", "CPU time", "profiling", "Core Web Vitals",
  "bundle size", "cache hit rate", or "optimization".
---

# Performance Benchmarker Skill

Adapted from agency-agents `testing-performance-benchmarker.md` — rewritten
for Cloudflare Workers serverless performance model.

## What's Different About Workers Performance

Workers don't have traditional server metrics (CPU load, memory, thread pools).
Performance is measured differently:

| Metric | Traditional | Workers |
|--------|-------------|---------|
| Response time | Time to first byte | Request duration (wall time) |
| CPU usage | % of cores | CPU time per request (ms) |
| Memory | RSS/heap | Isolate memory (128MB limit) |
| Scaling | Instances/pods | Automatic (global edge) |
| Cold starts | Container boot | V8 isolate creation (~5ms) |

## Key Metrics to Track

### Per-Request Metrics
```typescript
// Instrument in middleware
app.use('*', async (c, next) => {
  const start = performance.now();
  await next();
  const duration = performance.now() - start;

  // Log for analytics
  c.executionCtx.waitUntil(
    logMetric(c.env, {
      path: new URL(c.req.url).pathname,
      method: c.req.method,
      status: c.res.status,
      duration_ms: Math.round(duration * 100) / 100,
      d1_queries: c.get('d1QueryCount') ?? 0,
    })
  );
});
```

### D1 Query Profiling
```typescript
// Wrapper that tracks query count and duration
async function trackedQuery(db: D1Database, sql: string, params: any[]) {
  const start = performance.now();
  const result = await db.prepare(sql).bind(...params).all();
  const duration = performance.now() - start;

  if (duration > 50) {
    console.warn(`Slow D1 query (${duration.toFixed(1)}ms): ${sql.slice(0, 100)}`);
  }

  return { result, duration };
}
```

## Performance Budgets

| Metric | Budget | Alert |
|--------|--------|-------|
| Request P50 | < 50ms | > 100ms |
| Request P99 | < 200ms | > 500ms |
| CPU time per request | < 10ms | > 30ms |
| D1 query | < 20ms | > 50ms |
| Cold start | < 10ms | > 50ms |
| First load JS bundle | < 200KB | > 300KB |
| LCP (pages) | < 2.5s | > 4s |
| CLS (pages) | < 0.1 | > 0.25 |

## Bundle Size Tracking

```bash
# In CI — track bundle size per PR
npx wrangler deploy --dry-run --outdir=dist
BUNDLE_SIZE=$(du -sb dist/ | cut -f1)
BUNDLE_KB=$((BUNDLE_SIZE / 1024))

echo "Bundle: ${BUNDLE_KB}KB"

# Compare against baseline
BASELINE=$(cat .bundle-baseline 2>/dev/null || echo 0)
DIFF=$((BUNDLE_KB - BASELINE))

if [ $DIFF -gt 50 ]; then
  echo "::warning::Bundle grew by ${DIFF}KB — review dependencies"
fi
```

## Load Testing Pattern

```typescript
// scripts/load-test.ts — run against staging
async function loadTest(url: string, rps: number, duration: number) {
  const results: number[] = [];
  const interval = 1000 / rps;
  const end = Date.now() + duration * 1000;

  while (Date.now() < end) {
    const start = performance.now();
    const res = await fetch(url);
    results.push(performance.now() - start);
    await new Promise(r => setTimeout(r, interval));
  }

  const sorted = results.sort((a, b) => a - b);
  return {
    count: results.length,
    p50: sorted[Math.floor(sorted.length * 0.5)],
    p95: sorted[Math.floor(sorted.length * 0.95)],
    p99: sorted[Math.floor(sorted.length * 0.99)],
    min: sorted[0],
    max: sorted[sorted.length - 1],
    errors: results.filter(r => r < 0).length,
  };
}
```

## Common Performance Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| N+1 D1 queries | High subrequest count, slow response | Use `db.batch()` or JOIN |
| Unbuffered R2 reads | High memory, timeout | Stream with `obj.body` |
| Large bundle | Slow cold starts | Tree-shake, lazy load |
| Missing KV cache | Repeated D1 reads for static data | Cache in KV with TTL |
| Sync crypto operations | High CPU time | Use `crypto.subtle` (async) |
| JSON.stringify on large objects | CPU spike | Stream or paginate |

## Benchmark Report Template

```markdown
# Performance Benchmark Report
**Service**: myapp-api
**Environment**: staging
**Date**: [ISO 8601]

## Summary
| Metric | Value | Budget | Status |
|--------|-------|--------|--------|
| P50 latency | 23ms | <50ms | PASS |
| P99 latency | 142ms | <200ms | PASS |
| CPU time avg | 8ms | <10ms | PASS |
| Bundle size | 156KB | <200KB | PASS |
| D1 avg query | 14ms | <20ms | PASS |

## Slowest Endpoints
| Endpoint | P99 | D1 queries | Fix |
|----------|-----|------------|-----|
| GET /api/projects | 180ms | 3 | Consider KV cache |
| POST /api/billing | 320ms | 5 | Batch D1 writes |

## Recommendations
1. Cache project list in KV (TTL: 60s) — saves 3 D1 queries/request
2. Batch billing writes — 5 sequential → 1 batch call
```

## Relationship to Other Skills

- **Loaded by**: QA Lead agent
- **Feeds into**: `reality-checker` (Gate 2 performance evidence), `sre-ops` (SLO data)
- **Complements**: `test-analyzer` (functional metrics), `d1-optimizer` (query tuning)
