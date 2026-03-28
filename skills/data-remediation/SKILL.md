---
name: data-remediation
description: >
  AI-powered data remediation for cleaning, validating, and fixing anomalous data in D1
  databases. Uses semantic clustering to compress thousands of broken rows into pattern
  families, then generates auditable fix logic via Workers AI or local SLMs. Enforces zero
  PII egress — all inference runs air-gapped (Workers AI on Cloudflare's edge or Ollama
  locally). Use when cleaning imported data, fixing D1 data quality issues, detecting PII
  in voice AI transcripts, building self-healing data pipelines, reconciling data between
  systems, or remediating bulk data anomalies. Triggers on: "data quality", "clean data",
  "fix data", "PII detection", "data remediation", "anomaly", "data validation", "bulk fix",
  "transcript cleaning", "data pipeline", "reconciliation", or any request to find and fix
  bad data in D1.
---

# Data Remediation Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`engineering-ai-data-remediation-engineer.md` (64K+ stars, MIT license).

Self-healing data pipeline that uses AI to detect, classify, and fix data
anomalies at scale — without ever sending PII to external APIs.

## Core Principles

These are architectural invariants. Never violate them.

1. **AI generates logic, not data.** The model outputs transformation functions
   (lambdas), never raw corrected values. Humans can review, version, and
   rollback the logic.
2. **Zero PII egress.** All inference runs via Workers AI (Cloudflare's edge)
   or Ollama (localhost). Never send data containing PII to external cloud APIs.
3. **Validate before execute.** Every generated fix function is checked against
   a safety whitelist before execution — no `eval`, `import`, `exec`, or `os`.
4. **Mathematical reconciliation.** Every batch enforces:
   `Source_Rows == Success_Rows + Quarantine_Rows`. Zero data loss, guaranteed.

## When to Use This Skill

- Cleaning imported CSV/JSON data before loading into D1
- Fixing data quality issues discovered in production D1 tables
- Detecting and redacting PII in voice AI transcripts (ElevenLabs/Telnyx)
- Reconciling data between Clerk (auth), Stripe (payments), and D1 (app data)
- Bulk-fixing formatting issues (phone numbers, addresses, dates)
- Post-migration data validation after D1 schema changes

## Architecture

```
Data source (D1 / CSV / API)
        │
        ▼
┌──────────────────┐
│ Deterministic     │ ← regex, type checks, constraint validation
│ Validation        │ ← Rows pass → staging
└────────┬─────────┘
         │ Rows tagged NEEDS_AI
         ▼
┌──────────────────┐
│ Semantic          │ ← Cluster 50K broken rows into 8-15 pattern families
│ Compression       │ ← Reduces inference calls from thousands to dozens
└────────┬─────────┘
         ▼
┌──────────────────┐
│ AI Fix            │ ← Workers AI generates fix lambdas per pattern
│ Generation        │ ← Safety gate validates before execution
└────────┬─────────┘
         ▼
┌──────────────────┐
│ Reconciliation    │ ← Source == Success + Quarantine
│ & Audit           │ ← Full audit trail in D1
└──────────────────┘
```

## Step 1: Deterministic Validation

Before involving AI, catch everything rules can catch:

```typescript
// src/modules/data/validator.ts
interface ValidationResult {
  valid: Row[];
  needsAI: Row[];
  invalid: Row[];  // Structurally broken, can't be fixed
}

function validateBatch(rows: Row[], rules: ValidationRule[]): ValidationResult {
  const result: ValidationResult = { valid: [], needsAI: [], invalid: [] };

  for (const row of rows) {
    const failures = rules.filter(rule => !rule.check(row));

    if (failures.length === 0) {
      result.valid.push(row);
    } else if (failures.some(f => f.severity === 'structural')) {
      result.invalid.push({ ...row, _failures: failures });
    } else {
      result.needsAI.push({ ...row, _failures: failures });
    }
  }

  return result;
}

// Common validation rules for __COMPANY_NAME__ data
const RULES: ValidationRule[] = [
  { name: 'email_format', check: (r) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(r.email), severity: 'fixable' },
  { name: 'phone_format', check: (r) => /^\+?[\d\s()-]{10,}$/.test(r.phone), severity: 'fixable' },
  { name: 'date_valid', check: (r) => !isNaN(Date.parse(r.date)), severity: 'fixable' },
  { name: 'id_present', check: (r) => r.id != null, severity: 'structural' },
  { name: 'amount_numeric', check: (r) => typeof r.amount === 'number', severity: 'fixable' },
];
```

## Step 2: Semantic Anomaly Compression

**50,000 broken rows are never 50,000 unique problems.** They are 8-15 pattern
families. Cluster by meaning, not by string matching.

### Using Workers AI for Embeddings

```typescript
// src/modules/data/cluster.ts
async function clusterAnomalies(
  rows: Row[],
  env: Env
): Promise<PatternFamily[]> {
  // Generate embeddings via Workers AI (zero egress)
  const descriptions = rows.map(r =>
    `${r._failures.map(f => f.name).join(', ')}: ${JSON.stringify(r).slice(0, 200)}`
  );

  const embeddings = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
    text: descriptions,
  });

  // Simple clustering: group by cosine similarity > 0.85
  const families = groupBySimilarity(embeddings.data, descriptions, 0.85);

  // Each family gets 3-5 representative samples
  return families.map(f => ({
    pattern: f.centroidDescription,
    count: f.members.length,
    samples: f.members.slice(0, 5),
    failures: f.commonFailures,
  }));
}
```

### Using Ollama Locally (Alternative)

```typescript
// For local development or air-gapped environments
import { SentenceTransformer } from 'sentence-transformers';

const model = new SentenceTransformer('all-MiniLM-L6-v2');
const embeddings = model.encode(descriptions);
// Then cluster with HDBSCAN or simple cosine similarity grouping
```

## Step 3: AI Fix Generation

For each pattern family, generate a fix function — not a fixed value.

### Workers AI Approach

```typescript
async function generateFix(
  pattern: PatternFamily,
  env: Env
): Promise<FixFunction> {
  const prompt = `You are a data remediation engine. Given these anomalous data samples,
generate a JavaScript arrow function that fixes the issue.

RULES:
- Output ONLY a JSON object: {"fix": "row => ({ ...row, field: correctedValue })", "confidence": 0.95}
- No markdown, no explanation, no preamble
- The function must be a pure transformation (no side effects)
- Never use eval, import, require, fetch, or process

PATTERN: ${pattern.pattern}
FAILURE TYPE: ${pattern.failures.join(', ')}
SAMPLES:
${pattern.samples.map(s => JSON.stringify(s)).join('\n')}`;

  const result = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
    messages: [{ role: 'user', content: prompt }],
    max_tokens: 200,
  });

  const parsed = JSON.parse(result.response);
  return {
    fix: parsed.fix,
    confidence: parsed.confidence,
    pattern: pattern.pattern,
    affectedRows: pattern.count,
  };
}
```

### Safety Gate

**Every generated function must pass this whitelist before execution:**

```typescript
function validateFixFunction(fixStr: string): boolean {
  // Must be an arrow function or lambda
  if (!fixStr.includes('=>')) return false;

  // Blocklist: dangerous operations
  const BLOCKED = ['import', 'require', 'eval', 'exec', 'fetch',
                   'process', 'fs.', 'child_process', 'os.', 'Function('];
  if (BLOCKED.some(b => fixStr.includes(b))) return false;

  // Must reference 'row' parameter
  if (!fixStr.includes('row')) return false;

  return true;
}

function applyFix(rows: Row[], fixStr: string): Row[] {
  if (!validateFixFunction(fixStr)) {
    throw new Error(`Fix function failed safety check: ${fixStr}`);
  }

  // Execute in sandboxed scope
  const fixFn = new Function('row', `return (${fixStr})(row)`);
  return rows.map(row => {
    try {
      return fixFn(row);
    } catch {
      return { ...row, _quarantined: true, _reason: 'Fix function threw' };
    }
  });
}
```

## Step 4: Reconciliation

After every batch, enforce the math:

```typescript
function reconcile(source: Row[], success: Row[], quarantine: Row[]): void {
  const total = success.length + quarantine.length;
  if (total !== source.length) {
    throw new Error(
      `Reconciliation failed: source=${source.length}, ` +
      `success=${success.length}, quarantine=${quarantine.length}, ` +
      `missing=${source.length - total}`
    );
  }

  // Log audit record to D1
  // INSERT INTO remediation_audit (batch_id, source_count, success_count, quarantine_count, ...)
}
```

## PII Detection for Voice AI Transcripts

When processing transcripts from ElevenLabs/Telnyx voice AI, detect and
redact PII before storing in D1:

```typescript
const PII_PATTERNS = [
  { type: 'SSN', regex: /\b\d{3}-\d{2}-\d{4}\b/g, replacement: '[SSN REDACTED]' },
  { type: 'PHONE', regex: /\b\+?1?[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/g, replacement: '[PHONE REDACTED]' },
  { type: 'EMAIL', regex: /\b[^\s@]+@[^\s@]+\.[^\s@]+\b/g, replacement: '[EMAIL REDACTED]' },
  { type: 'CC', regex: /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/g, replacement: '[CC REDACTED]' },
  { type: 'DOB', regex: /\b(0[1-9]|1[0-2])\/(0[1-9]|[12]\d|3[01])\/\d{4}\b/g, replacement: '[DOB REDACTED]' },
];

function redactPII(transcript: string): { cleaned: string; findings: PIIFinding[] } {
  const findings: PIIFinding[] = [];
  let cleaned = transcript;

  for (const pattern of PII_PATTERNS) {
    const matches = cleaned.match(pattern.regex);
    if (matches) {
      findings.push({ type: pattern.type, count: matches.length });
      cleaned = cleaned.replace(pattern.regex, pattern.replacement);
    }
  }

  return { cleaned, findings };
}
```

For semantic PII detection (names, addresses mentioned conversationally),
use Workers AI classification:

```typescript
async function detectSemanticPII(text: string, env: Env): Promise<PIIFinding[]> {
  const result = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
    messages: [{
      role: 'user',
      content: `Identify any PII in this transcript. Return JSON array of findings.
Each finding: {"type": "name|address|medical|financial", "text": "the PII", "start": 0, "end": 10}
Return [] if none found. No explanation, JSON only.

TRANSCRIPT: ${text}`
    }],
    max_tokens: 500,
  });

  return JSON.parse(result.response);
}
```

## D1 Audit Schema

```sql
-- migrations/NNNN_remediation_audit.sql
CREATE TABLE remediation_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_id TEXT UNIQUE NOT NULL,
  source_table TEXT NOT NULL,
  source_count INTEGER NOT NULL,
  success_count INTEGER NOT NULL,
  quarantine_count INTEGER NOT NULL,
  patterns_found INTEGER,
  duration_ms INTEGER,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE remediation_fixes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_id TEXT NOT NULL REFERENCES remediation_batches(batch_id),
  pattern TEXT NOT NULL,
  fix_function TEXT NOT NULL,
  confidence REAL NOT NULL,
  rows_affected INTEGER NOT NULL,
  applied BOOLEAN DEFAULT FALSE,
  reviewed_by TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE quarantine (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_id TEXT NOT NULL REFERENCES remediation_batches(batch_id),
  original_row TEXT NOT NULL,  -- JSON
  failure_reasons TEXT NOT NULL,  -- JSON array
  resolution TEXT,  -- 'fixed' | 'discarded' | 'manual'
  resolved_at TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);
```

## Confidence Routing

| Confidence | Action |
|------------|--------|
| ≥ 0.95 | Auto-apply fix, log to audit |
| 0.80–0.94 | Apply fix, flag for human review |
| 0.50–0.79 | Quarantine, request human decision |
| < 0.50 | Quarantine, escalate to DBA Lead |

## Relationship to Other Skills

- **Used by**: AI/ML Lead agent (transcript PII), DBA Lead agent (D1 data quality)
- **Feeds into**: `reality-checker` (data quality is part of operational readiness)
- **Depends on**: Workers AI (embeddings + inference) or Ollama (local alternative)
- **Stores results in**: D1 audit tables (remediation_batches, remediation_fixes, quarantine)
