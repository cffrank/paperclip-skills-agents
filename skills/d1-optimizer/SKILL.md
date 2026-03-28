---
name: d1-optimizer
description: >
  D1 database optimization for Cloudflare's edge SQLite. Covers EXPLAIN QUERY PLAN, index
  strategies, batch operations, read replica patterns, query anti-patterns, and SQLite-
  specific constraints. Use when optimizing slow queries, designing indexes, analyzing
  query plans, tuning D1 performance, or troubleshooting database issues. Triggers on:
  "slow query", "D1 performance", "index", "EXPLAIN", "query optimization", "N+1",
  "database slow", "SQLite", "read replica", or "D1 tuning".
---

# D1 Optimizer Skill

Adapted from agency-agents `engineering-database-optimizer.md` — fully
rewritten from PostgreSQL/MySQL to SQLite/D1.

## D1 Is SQLite (Important Differences)

D1 is SQLite at the edge. Many PostgreSQL patterns don't apply:

| PostgreSQL | SQLite/D1 |
|------------|-----------|
| `EXPLAIN ANALYZE` | `EXPLAIN QUERY PLAN` |
| GIN, GiST, BRIN indexes | B-tree only (+ FTS5 for full-text) |
| Concurrent writers | Single writer (serialized writes) |
| Connection pooling | No connections (binding-based) |
| Stored procedures | Not supported |
| `JSONB` operators | `json_extract()`, `json_each()` |
| `ALTER TABLE ADD CONSTRAINT` | Not supported after creation |
| Materialized views | Not supported (use KV cache instead) |
| `RETURNING` clause | Supported in D1 |

## EXPLAIN QUERY PLAN

Always check before optimizing:

```sql
EXPLAIN QUERY PLAN
SELECT p.*, u.name as author_name
FROM projects p
JOIN users u ON p.user_id = u.id
WHERE p.status = 'active'
ORDER BY p.updated_at DESC
LIMIT 20;
```

Output to look for:
- `SCAN TABLE` = full table scan (bad for large tables)
- `SEARCH TABLE ... USING INDEX` = index used (good)
- `USING COVERING INDEX` = index-only scan (best)
- `USE TEMP B-TREE` = temporary sort (consider index on ORDER BY column)

## Index Strategies

### When to Create Indexes
```sql
-- Columns in WHERE clauses
CREATE INDEX idx_projects_status ON projects(status);

-- Columns in JOIN conditions
CREATE INDEX idx_projects_user_id ON projects(user_id);

-- Columns in ORDER BY (avoid temp B-tree sorts)
CREATE INDEX idx_projects_updated ON projects(updated_at DESC);

-- Composite index for common query patterns
CREATE INDEX idx_projects_user_status ON projects(user_id, status);

-- Partial index (smaller, faster for filtered queries)
CREATE INDEX idx_active_projects ON projects(updated_at DESC) WHERE status = 'active';
```

### Index Rules for D1
1. **Leftmost prefix rule**: Composite index `(a, b, c)` covers queries on `(a)`, `(a, b)`, `(a, b, c)` — but NOT `(b)` or `(c)` alone.
2. **Max 1 index per query**: SQLite uses at most one index per table in a query. Choose wisely.
3. **Don't over-index**: Each index adds write overhead. 3-5 indexes per table is typical.
4. **Cover common queries**: If you always query `WHERE user_id = ? AND status = ?`, make that one composite index.

## N+1 Query Elimination

### The Problem
```typescript
// BAD: N+1 — 1 query for projects + N queries for authors
const projects = await db.prepare('SELECT * FROM projects').all();
for (const p of projects.results) {
  const author = await db.prepare('SELECT name FROM users WHERE id = ?').bind(p.user_id).first();
  p.author = author;
}
```

### The Fix: JOIN
```typescript
// GOOD: Single query with JOIN
const projects = await db.prepare(`
  SELECT p.*, u.name as author_name, u.email as author_email
  FROM projects p
  JOIN users u ON p.user_id = u.id
  ORDER BY p.updated_at DESC
`).all();
```

### The Fix: Batch (when JOIN is awkward)
```typescript
// GOOD: Two queries instead of N+1
const projects = await db.prepare('SELECT * FROM projects WHERE status = ?').bind('active').all();
const userIds = [...new Set(projects.results.map(p => p.user_id))];
const placeholders = userIds.map(() => '?').join(',');
const users = await db.prepare(`SELECT * FROM users WHERE id IN (${placeholders})`).bind(...userIds).all();
const userMap = new Map(users.results.map(u => [u.id, u]));
projects.results.forEach(p => p.author = userMap.get(p.user_id));
```

## Batch Write Optimization

```typescript
// BAD: 10 sequential writes = 10 round-trips
for (const item of items) {
  await db.prepare('INSERT INTO items (name) VALUES (?)').bind(item.name).run();
}

// GOOD: 1 batch = 1 round-trip
await db.batch(
  items.map(item =>
    db.prepare('INSERT INTO items (name) VALUES (?)').bind(item.name)
  )
);
```

D1 batch is atomic — all statements succeed or all fail.

## JSON Operations in D1

SQLite supports JSON via built-in functions:

```sql
-- Store JSON
INSERT INTO settings (user_id, preferences) VALUES (?, json(?));

-- Extract value
SELECT json_extract(preferences, '$.theme') as theme FROM settings WHERE user_id = ?;

-- Query inside JSON
SELECT * FROM settings WHERE json_extract(preferences, '$.notifications') = 'true';

-- Iterate JSON array
SELECT value FROM settings, json_each(json_extract(preferences, '$.tags'));
```

## Read Replica Patterns

D1 supports read replicas for lower latency reads:

```typescript
// Read from replica (lower latency, eventual consistency)
const projects = await db
  .prepare('SELECT * FROM projects WHERE user_id = ?')
  .bind(userId)
  .all({ location: 'nearest' });  // Routes to nearest replica

// Write always goes to primary
await db
  .prepare('INSERT INTO projects (name, user_id) VALUES (?, ?)')
  .bind(name, userId)
  .run();  // Routes to primary
```

Use replicas for: dashboards, lists, search results.
Use primary for: writes, reads-after-writes, financial data.

## Common Anti-Patterns

| Anti-pattern | Why it's bad | Fix |
|-------------|-------------|-----|
| `SELECT *` | Returns unused columns, wastes bandwidth | Select specific columns |
| Missing pagination | Returns entire table | Use `LIMIT ? OFFSET ?` |
| String concatenation in SQL | SQL injection | `.prepare().bind()` |
| LIKE '%search%' | Full table scan, can't use index | Use FTS5 for full-text search |
| Storing booleans as text | Wastes space, slower comparisons | Use `INTEGER` (0/1) |
| Missing `created_at` default | Requires app-side timestamp | `DEFAULT (datetime('now'))` |

## Full-Text Search (FTS5)

For search features, use FTS5 instead of LIKE:

```sql
-- Create FTS virtual table
CREATE VIRTUAL TABLE projects_fts USING fts5(name, description, content=projects, content_rowid=rowid);

-- Populate
INSERT INTO projects_fts(projects_fts) VALUES('rebuild');

-- Search (much faster than LIKE '%term%')
SELECT p.* FROM projects p
JOIN projects_fts fts ON p.rowid = fts.rowid
WHERE projects_fts MATCH 'search terms'
ORDER BY rank;
```

## Query Performance Report Template

```markdown
## D1 Query Performance Audit
**Database**: myapp-prod
**Tables audited**: [count]
**Date**: [ISO 8601]

### Slow Queries (>50ms)
| Query | Avg ms | Calls/hr | Fix |
|-------|--------|----------|-----|
| SELECT * FROM projects WHERE status=? | 62ms | 500 | Add index on status |
| SELECT ... JOIN ... WHERE ... | 85ms | 200 | Composite index (user_id, status) |

### Missing Indexes
| Table | Column(s) | Query pattern | Impact |
|-------|-----------|---------------|--------|
| projects | status | WHERE status = ? | 500 queries/hr |
| invoices | user_id, created_at | WHERE + ORDER BY | 200 queries/hr |

### Recommendations
1. Add `idx_projects_status` — estimated 80% query time reduction
2. Batch the 5 sequential invoice writes — saves 4 round-trips
```

## Relationship to Other Skills

- **Loaded by**: DBA Lead agent (primary), App Dev Lead (query patterns)
- **Feeds into**: `perf-benchmarker` (D1 latency metrics), `data-remediation` (data quality)
- **Depends on**: D1 migrations from `axiom-cicd` references
