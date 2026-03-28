---
name: workers-ai
description: >
  Cloudflare Workers AI runtime patterns — model catalog, AI Gateway configuration,
  binding usage, streaming responses, model routing, cost tracking, and production
  deployment patterns. Complements the ai-engineer skill with Cloudflare-specific runtime
  details. Use when selecting Workers AI models, configuring AI Gateway, debugging inference
  issues, optimizing AI costs on Cloudflare, or understanding Workers AI limits. Triggers
  on: "Workers AI", "@cf/", "AI binding", "AI Gateway", "model catalog", "inference",
  "AI cost", "AI rate limit", "streaming AI", or "which model".
---

# Workers AI Skill

Custom skill — covers Cloudflare-specific AI runtime details that the
generic `ai-engineer` skill doesn't address.

## Workers AI Binding

```toml
# wrangler.toml
[ai]
binding = "AI"
```

```typescript
// Access in handler
const result = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages: [{ role: 'user', content: 'Hello' }],
});
```

## Model Catalog (Key Models)

### Text Generation
| Model | Speed | Quality | Free tier | Use case |
|-------|-------|---------|-----------|----------|
| `@cf/meta/llama-3.1-8b-instruct` | Fast | Good | 10K req/day | General chat, summaries |
| `@cf/meta/llama-3.1-70b-instruct` | Slow | Great | Limited | Complex reasoning |
| `@cf/mistral/mistral-7b-instruct-v0.2` | Fast | Good | 10K req/day | Structured output |
| `@cf/qwen/qwen1.5-14b-chat-awq` | Medium | Good | 10K req/day | Multilingual |

### Embeddings
| Model | Dimensions | Use case |
|-------|------------|----------|
| `@cf/baai/bge-base-en-v1.5` | 768 | English text similarity, RAG |
| `@cf/baai/bge-large-en-v1.5` | 1024 | Higher quality, slower |
| `@cf/baai/bge-small-en-v1.5` | 384 | Fastest, lower quality |

### Classification / NLP
| Model | Use case |
|-------|----------|
| `@cf/huggingface/distilbert-sst-2-int8` | Sentiment analysis |
| `@cf/meta/llama-guard-3-8b` | Content moderation |

### Image
| Model | Use case |
|-------|----------|
| `@cf/stabilityai/stable-diffusion-xl-base-1.0` | Image generation |
| `@cf/microsoft/resnet-50` | Image classification |

## Streaming Responses

```typescript
// Stream text generation to client
app.get('/api/chat/stream', async (c) => {
  const stream = await c.env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
    messages: [{ role: 'user', content: c.req.query('q') ?? '' }],
    stream: true,
  });

  return new Response(stream, {
    headers: { 'Content-Type': 'text/event-stream' },
  });
});

// Client-side consumption
const response = await fetch('/api/chat/stream?q=Hello');
const reader = response.body.getReader();
const decoder = new TextDecoder();

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  const chunk = decoder.decode(value);
  // Parse SSE: data: {"response":"token"}\n\n
}
```

## AI Gateway Setup

AI Gateway proxies requests to any provider with caching, logging, and rate limiting.

### Create Gateway
1. Cloudflare dashboard → AI → AI Gateway → Create
2. Note the gateway URL: `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_name}`

### Route Workers AI Through Gateway
```typescript
// Instead of env.AI.run(), use fetch to gateway
const GATEWAY = `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/my-gateway`;

const result = await fetch(`${GATEWAY}/workers-ai/@cf/meta/llama-3.1-8b-instruct`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    messages: [{ role: 'user', content: prompt }],
  }),
});
```

### Route External Providers Through Gateway
```typescript
// Anthropic via Gateway (caching + logging + rate limiting)
const result = await fetch(`${GATEWAY}/anthropic/v1/messages`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${env.ANTHROPIC_API_KEY}`,
    'Content-Type': 'application/json',
    'anthropic-version': '2023-06-01',
  },
  body: JSON.stringify({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1000,
    messages: [{ role: 'user', content: prompt }],
  }),
});

// OpenAI via Gateway
const result = await fetch(`${GATEWAY}/openai/chat/completions`, {
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

### Gateway Features
- **Caching**: Identical requests return cached responses (TTL configurable)
- **Rate limiting**: Per-user or per-endpoint limits prevent runaway costs
- **Logging**: Full request/response audit trail in dashboard
- **Fallback**: If primary provider fails, route to backup
- **Analytics**: Tokens used, latency, error rates, cost per provider
- **Retry**: Automatic retries on transient failures

## Limits and Quotas

| Limit | Free | Paid (Workers Paid) |
|-------|------|---------------------|
| Requests/day | 10,000 | Unlimited (pay per use) |
| Max input tokens | Model-dependent | Model-dependent |
| Max output tokens | Model-dependent | Model-dependent |
| Concurrent requests | 6 | Higher (account-dependent) |
| Request timeout | 30s | 30s |

### Cost Model
- Workers AI: Free tier covers 10K requests/day per model
- Beyond free tier: billed per neuron (varies by model)
- AI Gateway: Free (no additional cost for proxying)
- External providers: Standard API pricing applies

## Error Handling

```typescript
async function safeInference(env: Env, model: string, input: any) {
  try {
    const result = await env.AI.run(model, input);
    return { success: true, data: result };
  } catch (err: any) {
    if (err.message?.includes('rate limit')) {
      // Retry after delay or fall back to cheaper model
      return safeInference(env, '@cf/mistral/mistral-7b-instruct-v0.2', input);
    }
    if (err.message?.includes('timeout')) {
      // Model overloaded — try smaller model
      return safeInference(env, '@cf/meta/llama-3.1-8b-instruct', input);
    }
    console.error('AI inference failed:', err);
    return { success: false, error: err.message };
  }
}
```

## Model Selection Decision Tree

```
Is accuracy critical? (legal, medical, financial)
  YES → Route to Claude via AI Gateway
  NO  ↓

Is it high-volume? (>1000 req/day)
  YES ↓
    Is it embeddings?
      YES → @cf/baai/bge-base-en-v1.5 (free tier)
      NO  → @cf/meta/llama-3.1-8b-instruct (free tier)
  NO  ↓

Is complex reasoning needed?
  YES → Route to Claude Sonnet via AI Gateway
  NO  → @cf/meta/llama-3.1-8b-instruct
```

## Vectorize Integration

```typescript
// wrangler.toml
[[vectorize]]
binding = "VECTORIZE"
index_name = "my-embeddings"

// Store vectors
const vectors = embeddings.map((values, i) => ({
  id: `doc-${i}`,
  values,
  metadata: { source: 'knowledge-base', docId: ids[i] },
}));
await env.VECTORIZE.upsert(vectors);

// Query
const matches = await env.VECTORIZE.query(queryEmbedding, {
  topK: 5,
  returnMetadata: true,
  filter: { source: 'knowledge-base' },
});
```

## Relationship to Other Skills

- **Loaded by**: AI/ML Lead agent
- **Complements**: `ai-engineer` (higher-level patterns), `voice-ai-stack` (inference for voice)
- **Data source**: `data-remediation` (clean data before embedding)
- **Provisioned by**: `devops-automator` (AI binding + Vectorize setup)
