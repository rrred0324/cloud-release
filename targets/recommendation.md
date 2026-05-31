---
target: recommendation
description: "Three-layer deployment target detection and recommendation engine. Loaded first to determine which other target modules to load."
---

# Deployment Target Recommendation Engine

## Purpose

This module runs during Phase 0 to detect and recommend deployment targets. It uses three detection layers and produces a recommendation that the user confirms at decision point D2.

## Layer 1: Project Feature Detection (Local)

### Signals to check
```bash
# Deployment config files
[ -f "Dockerfile" ] && echo "HAS_DOCKERFILE=yes"
[ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] && echo "HAS_COMPOSE=yes"
[ -d "k8s" ] || [ -d "kubernetes" ] || [ -d "manifests" ] && echo "HAS_K8S_MANIFESTS=yes"
[ -d "helm" ] || [ -f "Chart.yaml" ] && echo "HAS_HELM=yes"
[ -f ".service" ] && echo "HAS_SYSTEMD_SERVICE=yes"
[ -f "vercel.json" ] && echo "HAS_VERCEL=yes"
[ -f "netlify.toml" ] && echo "HAS_NETLIFY=yes"
[ -f "wrangler.toml" ] && echo "HAS_CF_WORKERS=yes"
[ -f "serverless.yml" ] || [ -f "serverless.yaml" ] && echo "HAS_SERVERLESS_FW=yes"
[ -d ".github/workflows" ] && echo "HAS_GITHUB_ACTIONS=yes"
[ -f ".gitlab-ci.yml" ] && echo "HAS_GITLAB_CI=yes"
[ -f ".circleci/config.yml" ] && echo "HAS_CIRCLECI=yes"
[ -f "Jenkinsfile" ] && echo "HAS_JENKINS=yes"
[ -f "terraform" ] || [ -d "terraform" ] && echo "HAS_TERRAFORM=yes"
```

### Project type detection
```bash
# Frontend-only?
HAS_BACKEND="no"
HAS_FRONTEND="no"
[ -d "backend" ] || [ -f "requirements.txt" ] || [ -f "go.mod" ] || [ -f "Cargo.toml" ] || [ -f "pom.xml" ] && HAS_BACKEND="yes"
[ -d "frontend" ] || [ -f "package.json" ] || [ -f "next.config.js" ] || [ -f "nuxt.config.ts" ] && HAS_FRONTEND="yes"

if [ "$HAS_FRONTEND" = "yes" ] && [ "$HAS_BACKEND" = "no" ]; then echo "PROJECT_TYPE=frontend-only"
elif [ "$HAS_FRONTEND" = "yes" ] && [ "$HAS_BACKEND" = "yes" ]; then echo "PROJECT_TYPE=fullstack"
elif [ "$HAS_FRONTEND" = "no" ] && [ "$HAS_BACKEND" = "yes" ]; then echo "PROJECT_TYPE=backend-only"
fi
```

### Scale signals
```bash
# Microservices?
SERVICE_COUNT=$(find . -maxdepth 2 -name "Dockerfile" | wc -l | tr -d ' ')
[ "$SERVICE_COUNT" -gt 2 ] && echo "SCALE=microservices" || echo "SCALE=single-service"
```

## Layer 2: Cloud Environment Detection

### Environment variable signals
```bash
# AWS
[ -n "${AWS_REGION:-}" ] || [ -n "${AWS_DEFAULT_REGION:-}" ] && echo "CLOUD_PROVIDER=aws"

# GCP
[ -n "${GOOGLE_CLOUD_PROJECT:-}" ] || [ -n "${GCP_PROJECT:-}" ] && echo "CLOUD_PROVIDER=gcp"

# Azure
[ -n "${AZURE_SUBSCRIPTION_ID:-}" ] && echo "CLOUD_PROVIDER=azure"

# Cloudflare
[ -n "${CF_ACCOUNT_ID:-}" ] && echo "CLOUD_PROVIDER=cloudflare"
```

### Infrastructure as Code
```bash
[ -d "terraform" ] && echo "IAC_TOOL=terraform"
[ -d "pulumi" ] && echo "IAC_TOOL=pulumi"
[ -f "cdk.json" ] && echo "IAC_TOOL=cdk"
```

### From .cloudrelease.yml (if exists)
Read `target.method`, `target.server`, `target.docker`, `target.kubernetes`, `target.serverless`, `target.cicd` sections.

## Layer 3: Recommendation Rules

### Pure frontend projects
| Detected | Recommendation |
|----------|---------------|
| `vercel.json` | Serverless (Vercel) |
| `netlify.toml` | Serverless (Netlify) |
| `wrangler.toml` | Serverless (CF Workers) |
| No deploy config | Serverless (Vercel or Netlify — simplest path) |

### Fullstack / Backend-only projects
| Detected | Recommendation |
|----------|---------------|
| `docker-compose.yml` | Docker Compose |
| `Dockerfile` (no compose) | Docker |
| `.service` file | systemd |
| `k8s/` + `Dockerfile` | Docker build + Kubernetes deploy |
| `Chart.yaml` | Helm |
| No deploy config + VPS | systemd (simplest) |
| No deploy config + cloud | Docker + cloud container service |

### CI/CD integration (additive)
| Detected | Recommendation |
|----------|---------------|
| `.github/workflows/` | GitHub Actions (enhance existing) |
| `.gitlab-ci.yml` | GitLab CI (enhance existing) |
| `.circleci/` | CircleCI (enhance existing) |
| No CI/CD | Generate basic GitHub Actions or GitLab CI pipeline |

### Combination recommendations
Real-world deployments combine targets. Common patterns:
- **Small VPS**: rsync + systemd restart + manual trigger
- **Docker host**: Docker Compose + manual or CI/CD trigger
- **Cloud native**: Docker build + K8s deploy + CI/CD pipeline
- **Serverless frontend**: Vercel/Netlify + git push auto-deploy

## Output Format

After detection, produce a structured summary:

```
Detection Results:
  Project type: {frontend-only|fullstack|backend-only}
  Scale: {single-service|microservices}
  Cloud: {aws|gcp|azure|cloudflare|none-detected}
  
  Detected stacks: [python, nodejs, ...]
  Detected targets: [docker, kubernetes, ...]
  Detected CI/CD: [github-actions, ...]
  
  Recommended deployment:
    Build: {docker|native|none}
    Deploy: {systemd|docker|kubernetes|serverless}
    Pipeline: {github-actions|gitlab-ci|manual}
```

This summary is presented to the user at decision point D2 for confirmation or override.