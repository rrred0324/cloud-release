---
target: serverless
description: "Serverless deployment — Vercel, Netlify, Cloudflare Workers. Detect, deploy, rollback, and verify."
---

# Serverless Deployment Target

## Detection Signals

### Project layer
- `vercel.json` → Vercel
- `netlify.toml` → Netlify
- `wrangler.toml` → Cloudflare Workers
- `serverless.yml` / `serverless.yaml` → Serverless Framework (AWS Lambda)
- `samconfig.toml` → AWS SAM

### Cloud environment
- Vercel: `VERCEL_TOKEN` env var
- Netlify: `NETLIFY_AUTH_TOKEN` env var
- Cloudflare: `CF_API_TOKEN` env var
- AWS Lambda: `AWS_ACCESS_KEY_ID` env var

## Applicable Scenarios

- Frontend-only projects (SPA, SSG)
- API functions / edge functions
- Low-traffic services with burst patterns
- Projects wanting zero-ops deployment

## Prerequisites

- CLI tool installed: `vercel`, `netlify`, `wrangler`, or `serverless`
- Authentication configured (API token or OAuth)
- Project linked to platform (via CLI or config)

## Deployment Steps Template

### Vercel
```bash
# Deploy (auto-detects framework)
vercel --prod

# Or with specific config
vercel --prod --yes
```

### Netlify
```bash
# Deploy
netlify deploy --prod

# Or with build
netlify build && netlify deploy --prod --dir=dist
```

### Cloudflare Workers
```bash
# Deploy
npx wrangler deploy

# Or with secrets
npx wrangler secret put API_KEY
```

### AWS Lambda (Serverless Framework)
```bash
# Deploy
npx serverless deploy --stage production

# Update function only (faster)
npx serverless deploy function -f {function_name}
```

## Configuration Generation

### vercel.json (minimal)
```json
{
  "framework": null,
  "buildCommand": "{build_command}",
  "outputDirectory": "{dist_path}",
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

### netlify.toml (minimal)
```toml
[build]
  command = "{build_command}"
  publish = "{dist_path}"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### wrangler.toml (minimal)
```toml
name = "{service_name}"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[site]
  bucket = "{dist_path}"
```

## Rollback Plan

### Vercel
```bash
# List deployments
vercel ls

# Rollback to previous deployment
vercel rollback <deployment-url>
```

### Netlify
```bash
# Rollback via Netlify UI or redeploy previous commit
netlify deploy --prod --dir=dist
```

### Cloudflare Workers
```bash
# Rollback via dashboard or re-deploy previous version
npx wrangler rollback
```

## Post-Deployment Verification

- **Vercel**: `curl -s https://{project}.vercel.app{health_check_url}`
- **Netlify**: `curl -s https://{project}.netlify.app{health_check_url}`
- **CF Workers**: `curl -s https://{service_name}.{subdomain}.workers.dev{health_check_url}`

## Cost/Complexity

- **Cost**: Very Low (free tier generous) to Low
- **Complexity**: Very Low — git push to deploy
- **Scalability**: Automatic (platform handles scaling)
- **Monitoring**: Platform dashboard + optional integrations

## Common Issues

1. **Build fails on platform**: Check build command and output directory in config
2. **Environment variables missing**: Set via CLI (`vercel env add`, `netlify env:set`) or dashboard
3. **Routing issues**: Ensure `rewrites`/`redirects` config is correct for SPA
4. **Cold start latency**: Optimize function size; use edge functions for lower latency
5. **CORS errors**: Configure allowed origins in serverless function headers