---
name: ai-engineer
description: >
  AI/ML engineering on Cloudflare Workers AI, AI Gateway, and Vectorize. Covers model
  selection, RAG pipelines on D1, embedding generation, prompt management, AI Gateway
  routing, cost optimization, and production ML patterns. Use when integrating AI models,
  building RAG systems, managing prompts, routing between providers, or optimizing AI
  costs. Triggers on: "AI", "ML", "model", "Workers AI", "AI Gateway", "embedding",
  "RAG", "vector", "prompt", "LLM", "inference", "Vectorize", or "AI cost".
---

# AI Engineer Skill

Adapted from agency-agents `engineering-ai-engineer.md` — rewritten for
Cloudflare Workers AI + AI Gateway + Vectorize stack.

## Platform Components

| Component | Purpose | Binding |
|-----------|---------|---------|
| Workers AI | Run models at the edge (text, embeddings, image) | `env.AI` |
| AI Gateway | Proxy, cache, rate limit, log AI requests | Gateway URL |
| Vectorize | Vector database for embeddings | `env.VECTORIZE` |
| D1 | Store prompts, results, metadata | `env.DB` |
| R2 | Store documents for RAG ingestion | `env.ASSETS` |

## Workers AI Inference

```typescript
// Text generation
const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages: [
    { role: 'system', content: 'You are a helpful assistant.' },
    { role: 'user', content: userMessage },
  ],
  max_tokens: 500,
  temperature: 0.7,
});
const text = response.response;

// Embeddings
const embeddings = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
  text: ['Document chunk 1', 'Document chunk 2'],
});
// embeddings.data = [[0.1, 0.2, ...], [0.3, 0.4, ...]]

// Text classification
const result = await env.AI.run('@cf/huggingface/distilbert-sst-2-int8', {
  text: 'This product is amazing!',
});
// result = [{ label: 'POSITIVE', score: 0.98 }]
```

## AI Gateway (Provider Routing)

```typescript
// Route through AI Gateway for caching, logging, rate limiting
const GATEWAY_URL = 'https://gateway.ai.cloudflare.com/v1/ACCOUNT_ID/GATEWAY_NAME';

// Anthropic via Gateway
const response = await fetch(`${GATEWAY_URL}/anthropic/v1/messages`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${env.ANTHROPIC_API_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1000,
    messages: [{ role: 'user', content: prompt }],
  }),
});

// OpenAI via Gateway
const response = await fetch(`${GATEWAY_URL}/openai/chat/completions`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: prompt }],
  }),
});
```

### Gateway Benefits
- **Caching**: Identical prompts return cached responses (saves cost)
- **Rate limiting**: Prevent runaway API costs
- **Logging**: Full request/response audit trail
- **Fallback**: Route to backup provider if primary fails
- **Analytics**: Token usage, latency, error rates per provider

## RAG Pipeline on D1 + Vectorize

### Document Ingestion

```typescript
// 1. Chunk document
function chunkText(text: string, chunkSize = 500, overlap = 50): string[] {
  const chunks: string[] = [];
  for (let i = 0; i < text.length; i += chunkSize - overlap) {
    chunks.push(text.slice(i, i + chunkSize));
  }
  return chunks;
}

// 2. Generate embeddings and store
async function ingestDocument(doc: { id: string; text: string }, env: Env) {
  const chunks = chunkText(doc.text);
  const embeddings = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
    text: chunks,
  });

  // Store chunks in D1
  const batch = chunks.map((chunk, i) =>
    env.DB.prepare('INSERT INTO chunks (doc_id, chunk_index, text) VALUES (?, ?, ?)')
      .bind(doc.id, i, chunk)
  );
  await env.DB.batch(batch);

  // Store vectors in Vectorize
  const vectors = embeddings.data.map((values, i) => ({
    id: `${doc.id}-${i}`,
    values,
    metadata: { docId: doc.id, chunkIndex: i },
  }));
  await env.VECTORIZE.upsert(vectors);
}

// 3. Query
async function ragQuery(query: string, env: Env): Promise<string> {
  // Embed the query
  const queryEmb = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
    text: [query],
  });

  // Find similar chunks
  const matches = await env.VECTORIZE.query(queryEmb.data[0], {
    topK: 5,
    returnMetadata: true,
  });

  // Retrieve chunk text from D1
  const chunkIds = matches.matches.map(m => m.metadata?.chunkIndex);
  const docId = matches.matches[0]?.metadata?.docId;
  const chunks = await env.DB
    .prepare('SELECT text FROM chunks WHERE doc_id = ? AND chunk_index IN (?)')
    .bind(docId, chunkIds.join(','))
    .all();

  const context = chunks.results.map(c => c.text).join('\n\n');

  // Generate answer with context
  const answer = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
    messages: [
      { role: 'system', content: `Answer based on this context:\n${context}` },
      { role: 'user', content: query },
    ],
  });

  return answer.response;
}
```

## Model Selection Guide

| Use case | Model | Binding |
|----------|-------|---------|
| General text generation | `@cf/meta/llama-3.1-8b-instruct` | `env.AI` |
| Embeddings | `@cf/baai/bge-base-en-v1.5` | `env.AI` |
| Summarization | `@cf/meta/llama-3.1-8b-instruct` | `env.AI` |
| Classification | `@cf/huggingface/distilbert-sst-2-int8` | `env.AI` |
| Code generation | Route to Claude via AI Gateway | Gateway |
| Complex reasoning | Route to Claude Opus via AI Gateway | Gateway |
| High-volume, low-cost | Workers AI (free tier: 10K requests/day) | `env.AI` |

**Rule**: Use Workers AI for high-volume commodity tasks (embeddings,
classification, simple generation). Route to Claude/GPT via AI Gateway
for complex reasoning, code generation, and tasks requiring high accuracy.

## Prompt Management

Store prompts in D1, version them, A/B test:

```sql
CREATE TABLE prompts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  system_prompt TEXT NOT NULL,
  model TEXT NOT NULL,
  temperature REAL DEFAULT 0.7,
  max_tokens INTEGER DEFAULT 500,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX idx_prompt_name_version ON prompts(name, version);
```

```typescript
async function getPrompt(name: string, env: Env) {
  return env.DB
    .prepare('SELECT * FROM prompts WHERE name = ? AND is_active = TRUE ORDER BY version DESC LIMIT 1')
    .bind(name)
    .first();
}
```

## Cost Optimization

1. **Cache via AI Gateway** — identical prompts return cached responses
2. **Use Workers AI for embeddings** — free tier covers most use cases
3. **Batch embedding calls** — one call with N texts, not N calls with 1 text
4. **Set max_tokens conservatively** — don't request 4096 when 200 suffices
5. **Route by complexity** — simple tasks → Workers AI, complex → Claude via Gateway
6. **Monitor via Gateway analytics** — track cost per endpoint per day

## Relationship to Other Skills

- **Loaded by**: AI/ML Lead agent
- **Depends on**: `cf-workers-api` (handler patterns), `d1-optimizer` (query performance)
- **Data quality**: `data-remediation` (clean data before embedding)
- **Deployed by**: `axiom-cicd`
