# R2 Asset Deployment

## Three Approaches

### 1. Wrangler with R2 Bindings (Preferred for Workers)

Workers access R2 via `env.MY_BUCKET` binding. Assets are uploaded as part
of the Worker deployment or separately.

```toml
# wrangler.toml
[[r2_buckets]]
binding = "ASSETS"
bucket_name = "myapp-assets"
```

### 2. Community Action (Standalone Uploads)

`ryand56/r2-upload-action` uses R2's S3-compatible API:

```yaml
- uses: ryand56/r2-upload-action@latest
  with:
    r2-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    r2-access-key-id: ${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}
    r2-secret-access-key: ${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}
    r2-bucket: myapp-assets
    source-dir: dist/assets
    destination-dir: v${{ github.run_number }}
```

### 3. Custom Script (Maximum Control)

```javascript
// scripts/upload-r2.mjs
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { readdir, readFile } from 'fs/promises';
import { join } from 'path';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.CF_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

const VERSION = process.env.GITHUB_SHA?.slice(0, 8) || 'local';

async function uploadDir(dir, prefix = '') {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    const key = `${VERSION}/${prefix}${entry.name}`;
    if (entry.isDirectory()) {
      await uploadDir(fullPath, `${prefix}${entry.name}/`);
    } else {
      const body = await readFile(fullPath);
      await s3.send(new PutObjectCommand({
        Bucket: 'myapp-assets',
        Key: key,
        Body: body,
        ContentType: getContentType(entry.name),
      }));
      console.log(`Uploaded: ${key}`);
    }
  }
}

await uploadDir('dist/assets');
```

## Best Practices

### Versioned Paths

Always upload to versioned directories. Two strategies:

**Commit SHA** (preferred for cache busting):
```
myapp-assets/
├── abc123de/
│   ├── app.js
│   ├── styles.css
│   └── images/logo.png
├── f0e1d2c3/
│   └── ...
```

**Semantic version** (for API assets):
```
myapp-assets/
├── v42/
│   └── ...
├── v43/
│   └── ...
```

### Content-Hashed Filenames

SvelteKit and Vite generate hashed filenames by default (`app.abc123.js`).
Cloudflare Pages serves these with edge caching automatically — no manual
Cache-Control needed for build output.

For R2-served user uploads (images, documents), set Cache-Control when storing:

```typescript
await env.ASSETS.put(key, file, {
  httpMetadata: {
    contentType: file.type,
    cacheControl: 'public, max-age=31536000, immutable',
  },
});
```

### Separate API Tokens

Create dedicated R2 API tokens separate from Workers deploy tokens:
- Workers token: "Edit Cloudflare Workers" permission
- R2 token: "Admin Read & Write" on specific bucket only

### Cleanup Old Versions

Keep the last N versions and prune old ones:

```yaml
- name: Cleanup old R2 versions
  run: |
    # List all version prefixes, keep last 10
    VERSIONS=$(aws s3 ls s3://myapp-assets/ \
      --endpoint-url https://${{ secrets.CLOUDFLARE_ACCOUNT_ID }}.r2.cloudflarestorage.com \
      | awk '{print $2}' | sort -r | tail -n +11)
    for V in $VERSIONS; do
      aws s3 rm s3://myapp-assets/$V --recursive \
        --endpoint-url https://${{ secrets.CLOUDFLARE_ACCOUNT_ID }}.r2.cloudflarestorage.com
    done
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: auto
```
