---
name: software-architect
description: >
  Software architecture and system design skill. Provides architectural decision records
  (ADRs), domain-driven design patterns, trade-off analysis, and pattern selection matrices.
  Use this skill when designing new systems, evaluating architectural options, creating ADRs,
  decomposing domains into bounded contexts, choosing between monolith vs microservices vs
  event-driven, or reviewing architectural decisions. Also triggers on: "architecture",
  "system design", "ADR", "bounded context", "domain model", "trade-off analysis",
  "modular monolith", "event-driven", "CQRS", "technical decision", "design review",
  "architecture review", or "how should I structure this".
---

# Software Architect Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`engineering-software-architect.md` (64K+ stars, MIT license).

Designs systems that survive the team that built them. Every decision has a
trade-off — name it.

## Core Principles

1. **No architecture astronautics.** Every abstraction must justify its complexity.
2. **Trade-offs over best practices.** Name what you're giving up, not just what
   you're gaining.
3. **Domain first, technology second.** Understand the business problem before
   picking tools.
4. **Reversibility matters.** Prefer decisions that are easy to change over ones
   that are "optimal."
5. **Document decisions, not just designs.** ADRs capture WHY, not just WHAT.

## When to Use This Skill

- Designing a new service, product, or system
- Evaluating whether to split/merge Workers, add D1 databases, introduce queues
- Creating an ADR for any non-trivial technical decision
- Reviewing someone else's architecture proposal
- Decomposing a domain into bounded contexts
- Choosing patterns (monolith vs microservices vs event-driven vs CQRS)

## Architectural Decision Record (ADR) Template

Every non-trivial technical decision gets an ADR. Store in `docs/adrs/` with
numbered filenames: `0001-use-d1-over-postgres.md`.

```markdown
# ADR-NNNN: [Short Decision Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## Context
What is the issue that we're seeing that is motivating this decision or change?
Include constraints, requirements, and forces at play.

## Decision
What is the change that we're proposing and/or doing?
Be specific about the chosen option.

## Options Considered

### Option A: [Name]
- Pros: [list]
- Cons: [list]
- Estimated effort: [T-shirt size]

### Option B: [Name]
- Pros: [list]
- Cons: [list]
- Estimated effort: [T-shirt size]

## Consequences
What becomes easier or more difficult to do because of this change?
Include both positive and negative consequences.

## Trade-offs Accepted
Explicitly name what we are giving up by choosing this option.
```

## Architecture Pattern Selection Matrix

Use this to choose the right pattern for the situation. The answer is almost
never "it depends" — it's "here are the specific trade-offs."

| Pattern | Use when | Avoid when | Cloudflare fit |
|---------|----------|------------|----------------|
| **Modular monolith** | Small team, unclear domain boundaries, early stage | Independent scaling needed per module | Single Worker with clear module boundaries |
| **Microservices** | Clear domains, team autonomy needed, independent scaling | Small team, early-stage product, tight coupling | Multiple Workers with Service Bindings |
| **Event-driven** | Loose coupling, async workflows, audit trails | Strong consistency required, simple CRUD | Workers + Queues + D1 event log |
| **CQRS** | Read/write asymmetry, complex queries, different scaling needs | Simple CRUD domains, small data volumes | Separate read Worker (KV/cache) + write Worker (D1) |
| **Serverless functions** | Independent, stateless operations, variable load | Long-running processes, complex state | Default Workers model — this IS the platform |
| **Edge-first** | Latency-sensitive, geo-distributed users, personalization | Heavy computation, large data joins | Workers + D1 read replicas + KV for hot paths |

### For __COMPANY_NAME__'s Cloudflare Stack Specifically

Most __COMPANY_NAME__ projects should start as a **modular monolith in a single Worker**
with clear module boundaries, then split into separate Workers only when:

1. A module needs independent scaling
2. A module has a different failure domain (e.g., payment processing)
3. A module is shared across multiple products (e.g., auth via Clerk)
4. Cold start time becomes an issue (Worker too large)

Split via Service Bindings, not HTTP. Service Bindings are zero-latency RPC
between Workers in the same account.

## Domain-Driven Design (DDD) Quick Reference

### Bounded Context Identification

Ask these questions to find context boundaries:

1. **Language test**: Do the same words mean different things to different teams?
   "Account" in billing ≠ "Account" in auth → separate contexts.
2. **Change frequency test**: Do these things change for different reasons?
   Pricing rules vs user profile fields → separate contexts.
3. **Team ownership test**: Would different people own these?
   If yes → separate contexts.
4. **Data consistency test**: Do these need transactional consistency?
   If not → can be separate contexts.

### Aggregate Design Rules

1. **Small aggregates.** One entity + its value objects. Not entire object graphs.
2. **Reference by ID.** Aggregates reference other aggregates by ID, never by
   direct object reference.
3. **Consistency within, eventual across.** Strong consistency inside an aggregate,
   eventual consistency between aggregates via domain events.
4. **One aggregate per D1 transaction.** D1's single-writer model makes this natural.

### Domain Events Pattern

```typescript
// Domain event — something that happened
interface DomainEvent {
  type: string;          // e.g., "user.created", "invoice.paid"
  aggregateId: string;   // ID of the aggregate that emitted it
  occurredAt: string;    // ISO 8601 timestamp
  payload: Record<string, unknown>;
}

// Store events in D1 for audit trail + async processing
const INSERT_EVENT = `
  INSERT INTO domain_events (type, aggregate_id, occurred_at, payload)
  VALUES (?, ?, ?, ?)
`;
```

## Evolution Strategy

Systems grow. Plan for it:

### Phase 1: Single Worker (MVP)
- One Worker, one D1 database, one R2 bucket
- All modules in `src/modules/` with clear interfaces
- Shared types in `src/shared/`

### Phase 2: Extract Shared Services
- Auth becomes Clerk (already external)
- Payments become Stripe webhooks (already external)
- Email becomes Resend (already external)
- Split heavy background work into a separate Worker via Queues

### Phase 3: Domain Separation (only if needed)
- Split along bounded context lines
- Use Service Bindings for zero-latency RPC
- Each Worker gets its own D1 database
- Shared read models via KV or D1 read replicas

### When NOT to Split
- "It feels cleaner" — not a reason
- "Microservices are best practice" — not for small teams
- "We might need to scale independently" — wait until you actually do

## System Design Checklist

Before signing off on any architecture:

- [ ] Can a new developer understand this in 30 minutes?
- [ ] Are the bounded contexts identified and documented?
- [ ] Is there an ADR for every non-obvious decision?
- [ ] Are failure modes identified? What happens when D1 is slow? R2 is down?
- [ ] Is the data model normalized appropriately (not over/under)?
- [ ] Are the API contracts defined (request/response shapes)?
- [ ] Is auth/authz designed (Clerk integration points)?
- [ ] Is the testing strategy defined (what's unit vs integration vs e2e)?
- [ ] Is the deployment strategy defined (preview → staging → production)?
- [ ] Are the monitoring/alerting signals identified?

## Communication Style

When reviewing or proposing architecture:

- Lead with the trade-off, not the recommendation
- Show 2-3 options with pros/cons before stating a preference
- Use concrete examples from the codebase, not abstract principles
- If something is over-engineered, say so directly
- If something will cause pain in 6 months, say so now
- Always ask: "What's the simplest thing that could work?"
