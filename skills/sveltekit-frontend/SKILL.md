---
name: sveltekit-frontend
description: >
  SvelteKit frontend development on Cloudflare Pages with Tailwind CSS and shadcn-svelte.
  Covers component architecture, load functions, form actions, SSR on Workers, routing,
  layout patterns, state management, and performance optimization. Use when building UI
  components, pages, layouts, or any frontend feature in a __COMPANY_NAME__ project. Triggers on:
  "component", "page", "layout", "form", "UI", "frontend", "SvelteKit", "Svelte",
  "Tailwind", "shadcn", "responsive", "dark mode", "load function", "form action",
  "+page", "+layout", "+server", "store", "client-side", "SSR", or any request to build
  or modify user interface code.
---

# SvelteKit Frontend Skill

Adapted from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
`engineering-frontend-developer.md` — rewritten from React/Vue/Angular to SvelteKit +
Tailwind + shadcn-svelte on Cloudflare Pages.

## Mandatory Stack

Never deviate from this without an ADR:
- **Framework**: SvelteKit (latest, adapter-cloudflare)
- **Styling**: Tailwind CSS 4 (no custom CSS unless Tailwind can't do it)
- **Components**: shadcn-svelte (not shadcn/ui for React)
- **Hosting**: Cloudflare Pages (SSR via Workers)
- **Auth**: Clerk (frontend SDK: @clerk/svelte or REST API)
- **Icons**: Lucide Svelte
- **Forms**: SvelteKit form actions (progressive enhancement)
- **State**: Svelte stores ($state rune in Svelte 5, writable/derived in Svelte 4)

## Project Structure

```
src/
├── routes/
│   ├── +layout.svelte          ← Root layout (nav, footer, theme)
│   ├── +layout.server.ts       ← Root load (auth session)
│   ├── +page.svelte            ← Homepage
│   ├── +page.server.ts         ← Homepage data loading
│   ├── (auth)/                 ← Route group for auth pages
│   │   ├── login/+page.svelte
│   │   └── signup/+page.svelte
│   ├── (app)/                  ← Route group for authenticated pages
│   │   ├── +layout.svelte      ← App shell (sidebar, header)
│   │   ├── +layout.server.ts   ← Auth guard
│   │   ├── dashboard/
│   │   │   ├── +page.svelte
│   │   │   └── +page.server.ts
│   │   └── settings/
│   │       ├── +page.svelte
│   │       └── +page.server.ts
│   └── api/                    ← API routes (Workers handlers)
│       └── [...path]/+server.ts
├── lib/
│   ├── components/
│   │   ├── ui/                 ← shadcn-svelte components
│   │   └── custom/             ← Project-specific components
│   ├── stores/                 ← Svelte stores
│   ├── utils/                  ← Helpers, formatters
│   └── server/                 ← Server-only code (D1 queries, etc.)
├── app.html                    ← HTML shell
├── app.css                     ← Tailwind imports
└── hooks.server.ts             ← Server hooks (auth, error handling)
```

## Load Functions

Load functions run on the server (Workers) and pass data to pages.

### Server Load (+page.server.ts)

```typescript
// src/routes/(app)/dashboard/+page.server.ts
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ platform, locals }) => {
  // Access D1 via platform.env
  const db = platform?.env?.DB;
  if (!db) throw error(500, 'Database not available');

  const projects = await db
    .prepare('SELECT * FROM projects WHERE user_id = ? ORDER BY updated_at DESC')
    .bind(locals.userId)
    .all();

  return {
    projects: projects.results,
  };
};
```

### Rules for Load Functions

1. **Always use `+page.server.ts`** for data that touches D1, R2, or secrets.
   Never expose bindings to the client via `+page.ts`.
2. **Access Cloudflare bindings via `platform.env`**, not `process.env`.
3. **Type your bindings** in `app.d.ts`:
   ```typescript
   declare global {
     namespace App {
       interface Platform {
         env: {
           DB: D1Database;
           ASSETS: R2Bucket;
           CACHE: KVNamespace;
           AI: Ai;
         };
       }
       interface Locals {
         userId: string;
         session: Session | null;
       }
     }
   }
   ```
4. **Return serializable data only.** No D1 statement objects, no functions.
5. **Handle errors gracefully** — use SvelteKit's `error()` helper.

## Form Actions

Progressive enhancement — forms work without JavaScript.

```typescript
// src/routes/(app)/projects/+page.server.ts
import type { Actions } from './$types';
import { fail, redirect } from '@sveltejs/kit';

export const actions: Actions = {
  create: async ({ request, platform, locals }) => {
    const data = await request.formData();
    const name = data.get('name')?.toString().trim();

    if (!name || name.length < 2) {
      return fail(400, { name, error: 'Name must be at least 2 characters' });
    }

    const db = platform?.env?.DB;
    await db
      .prepare('INSERT INTO projects (name, user_id) VALUES (?, ?)')
      .bind(name, locals.userId)
      .run();

    throw redirect(303, '/projects');
  },

  delete: async ({ request, platform, locals }) => {
    const data = await request.formData();
    const id = data.get('id');

    await platform?.env?.DB
      .prepare('DELETE FROM projects WHERE id = ? AND user_id = ?')
      .bind(id, locals.userId)
      .run();

    return { success: true };
  },
};
```

```svelte
<!-- src/routes/(app)/projects/+page.svelte -->
<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ActionData, PageData } from './$types';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';

  export let data: PageData;
  export let form: ActionData;
</script>

<form method="POST" action="?/create" use:enhance>
  <Input name="name" value={form?.name ?? ''} placeholder="Project name" />
  {#if form?.error}
    <p class="text-sm text-red-500">{form.error}</p>
  {/if}
  <Button type="submit">Create project</Button>
</form>
```

### Form Action Rules

1. **Always use `use:enhance`** for progressive enhancement with client-side UX.
2. **Return `fail()` for validation errors** — preserves form state.
3. **Use `redirect()` for success** — prevents double-submit on refresh.
4. **Never trust client data** — validate and sanitize on the server.

## Component Patterns

### shadcn-svelte Setup

```bash
npx shadcn-svelte@latest init
npx shadcn-svelte@latest add button input card dialog table
```

Components install to `src/lib/components/ui/`. Import from there:

```svelte
<script>
  import { Button } from '$lib/components/ui/button';
  import { Card, CardHeader, CardTitle, CardContent } from '$lib/components/ui/card';
</script>
```

### Custom Component Pattern

```svelte
<!-- src/lib/components/custom/ProjectCard.svelte -->
<script lang="ts">
  import { Card, CardHeader, CardTitle, CardContent } from '$lib/components/ui/card';
  import { Badge } from '$lib/components/ui/badge';

  export let project: {
    id: string;
    name: string;
    status: 'active' | 'archived';
    updatedAt: string;
  };
</script>

<Card class="hover:border-primary/50 transition-colors">
  <CardHeader>
    <div class="flex items-center justify-between">
      <CardTitle class="text-lg">{project.name}</CardTitle>
      <Badge variant={project.status === 'active' ? 'default' : 'secondary'}>
        {project.status}
      </Badge>
    </div>
  </CardHeader>
  <CardContent>
    <p class="text-sm text-muted-foreground">
      Updated {new Date(project.updatedAt).toLocaleDateString()}
    </p>
  </CardContent>
</Card>
```

### Component Rules

1. **Props over context** for component data. Use context only for deeply nested state.
2. **Type all props** with TypeScript interfaces.
3. **Use Tailwind classes exclusively** — no inline styles, no `<style>` blocks.
4. **Compose from shadcn-svelte primitives** — don't rebuild buttons, inputs, dialogs.
5. **Forward `class` prop** using `$$restProps` or explicit `class` prop for customization.

## SSR on Workers

SvelteKit runs SSR inside Cloudflare Workers via `adapter-cloudflare`.

```typescript
// svelte.config.js
import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      routes: {
        include: ['/*'],
        exclude: ['<all>'], // Let Pages handle static assets
      },
    }),
  },
};
```

### SSR Gotchas on Workers

1. **No `fs`, `path`, or Node built-ins** unless `nodejs_compat` is enabled.
2. **No `window`, `document`** on the server — guard with `import { browser } from '$app/environment'`.
3. **Bundle size matters** — Workers has a 10MB limit. Check with `wrangler deploy --dry-run`.
4. **No long-running processes** — Workers have a 30s CPU time limit (paid plan).
5. **Streaming SSR works** — SvelteKit streams HTML by default on Workers.

### Client-Only Components

For components that use browser APIs:

```svelte
<script>
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';

  let MapComponent: any;

  onMount(async () => {
    if (browser) {
      const module = await import('$lib/components/custom/Map.svelte');
      MapComponent = module.default;
    }
  });
</script>

{#if MapComponent}
  <svelte:component this={MapComponent} />
{:else}
  <div class="h-64 animate-pulse bg-muted rounded-lg" />
{/if}
```

## Dark Mode

Use Tailwind's `dark:` variant with class-based toggling:

```svelte
<!-- src/routes/+layout.svelte -->
<script>
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';

  let theme = 'light';

  onMount(() => {
    theme = localStorage.getItem('theme') ??
      (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.classList.toggle('dark', theme === 'dark');
  });

  function toggleTheme() {
    theme = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.classList.toggle('dark', theme === 'dark');
    localStorage.setItem('theme', theme);
  }
</script>
```

shadcn-svelte components handle dark mode automatically via CSS variables.

## Performance Checklist

```
[ ] Images use next-gen formats (WebP/AVIF) — Pages serves them from edge CDN
[ ] Lazy load below-fold images and heavy components
[ ] Preload critical fonts and above-fold data
[ ] Use SvelteKit preloading: data-sveltekit-preload-data="hover"
[ ] Bundle size < 200KB JS (first load)
[ ] Core Web Vitals: LCP < 2.5s, FID < 100ms, CLS < 0.1
[ ] No layout shift from async content (use skeleton loaders)
[ ] Static assets cached automatically by Cloudflare edge (no R2 needed for this)
```

## Relationship to Other Skills

- **Depends on**: `cf-workers-api` (backend patterns), `git-workflow` (branching)
- **Tested by**: `visual-qa` (screenshot evidence), `a11y-auditor` (WCAG compliance)
- **Deployed by**: `axiom-cicd` (Pages preview + production workflows)
- **Reviewed by**: `code-reviewer` (Workers runtime compatibility checks)
