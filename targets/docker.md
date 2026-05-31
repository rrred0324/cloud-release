---
target: docker
description: "Docker/Docker Compose deployment — detect, build, deploy, rollback, and verify for containerized deployments."
---

# Docker Deployment Target

## Detection Signals

### Project layer
- `Dockerfile` exists in project root or subdirectory
- `docker-compose.yml` or `docker-compose.yaml` exists
- `docker-compose.override.yml` exists (dev overrides)
- `.dockerignore` exists

### Cloud environment
- Docker installed on target server
- Docker Hub or private registry accessible
- Docker Compose v2 available (`docker compose`)

## Applicable Scenarios

- Containerized application deployments
- Multi-service deployments via Docker Compose
- Environments where reproducibility matters
- When systemd is too low-level for the project

## Prerequisites

- Docker installed on deployment target
- Docker Compose v2 (or v1 with `docker-compose`)
- Registry access (Docker Hub or private)
- SSH access to deployment server (for remote Docker)

## Deployment Steps Template

### Step 1: Build images
```bash
# Build all services
docker compose build

# Or build specific service
docker compose build {service_name}
```

### Step 2: Tag and push images (if using registry)
```bash
docker tag {service_name}:latest {registry}/{service_name}:{version}
docker push {registry}/{service_name}:{version}
```

### Step 3: Deploy on target server
```bash
# SSH to server
ssh {server_user}@{server_host}

# Pull latest images
cd {deploy_path}
docker compose pull

# Restart services with zero downtime
docker compose up -d --remove-orphans
```

### Step 4: Verify
```bash
docker compose ps
docker compose logs --tail=20 {service_name}
```

## Configuration Generation

### Minimal Dockerfile (Python example)
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "{entry_point}", "--host", "0.0.0.0", "--port", "8000"]
```

### Minimal docker-compose.yml
```yaml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "8000:8000"
    env_file:
      - .env
    restart: unless-stopped
```

### Multi-stage Dockerfile (optimized)
```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY . .
EXPOSE 8000
CMD ["uvicorn", "{entry_point}", "--host", "0.0.0.0", "--port", "8000"]
```

## Rollback Plan

```bash
# 1. Rollback to previous image version
docker compose down
docker tag {registry}/{service_name}:{previous_version} {service_name}:latest
docker compose up -d

# 2. Or restore from backup compose config
cp docker-compose.yml.backup docker-compose.yml
docker compose up -d
```

## Post-Deployment Verification

- Container status: `docker compose ps`
- Health check: `curl -s http://localhost:8000{health_check_url}`
- Logs: `docker compose logs --tail=50 {service_name}`
- Resource usage: `docker stats --no-stream`

## Cost/Complexity

- **Cost**: Low-Medium — VPS + optional registry
- **Complexity**: Medium — Docker knowledge required
- **Scalability**: Medium — limited to single host with Compose
- **Monitoring**: Docker logs + optional Prometheus/Grafana

## Common Issues

1. **Build fails with dependency errors**: Ensure `requirements.txt`/`package.json` is up to date
2. **Container exits immediately**: Check `docker compose logs {service_name}` for crash logs
3. **Volume permission issues**: Ensure UID/GID matches between host and container
4. **Network connectivity between containers**: Use Docker Compose network aliases
5. **Out of disk space**: Run `docker system prune -f` to clean unused images/containers