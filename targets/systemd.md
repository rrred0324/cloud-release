---
target: systemd
description: "systemd service deployment — detect, deploy, rollback, and verify for Linux VPS deployments."
---

# systemd Deployment Target

## Detection Signals

### Project layer
- `.service` file exists in project (e.g., `{service_name}.service`)
- `supervisord.conf` exists (alternative service manager)
- No Docker/K8s config present → systemd is a candidate

### Cloud environment
- Target is a Linux VPS or bare-metal server
- SSH access available to deployment server

## Applicable Scenarios

- Single-server deployments on Linux VPS
- Projects managed via systemd services
- Simple deployment with rsync + service restart
- When Docker is overkill for the project scale

## Prerequisites

- SSH access to deployment server
- systemd service configured on target server
- Application can run as a foreground process

## Deployment Steps Template

### Step 1: Backup current version
```bash
ssh {server_user}@{server_host} "cp -r {deploy_path} {deploy_path}.backup.$(date +%Y%m%d%H%M%S)"
```

### Step 2: Sync application files
```bash
# Backend
rsync -avz --delete --exclude='venv' --exclude='__pycache__' --exclude='.env' \
  {backend_dir}/ {server_user}@{server_host}:{deploy_path}/{backend_dir}/

# Frontend (if applicable)
rsync -avz --delete {dist_path}/ {server_user}@{server_host}:{deploy_path}/{dist_path}/
```

### Step 3: Install dependencies on server
```bash
ssh {server_user}@{server_host} "cd {deploy_path}/{backend_dir} && {python_path} -m pip install -r requirements.txt"
```

### Step 4: Run database migration
```bash
ssh {server_user}@{server_host} "cd {deploy_path}/{backend_dir} && {python_path} -m alembic upgrade head"
```

### Step 5: Restart service
```bash
ssh {server_user}@{server_host} "sudo systemctl restart {service_name}"
```

### Step 6: Verify service
```bash
ssh {server_user}@{server_host} "sudo systemctl is-active {service_name}"
```

## Configuration Generation

If no `.service` file exists, generate one:

```ini
[Unit]
Description={service_name}
After=network.target

[Service]
Type=simple
User={server_user}
WorkingDirectory={deploy_path}/{backend_dir}
ExecStart={python_path} -m uvicorn {entry_point} --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3
Environment=ENV=production

[Install]
WantedBy=multi-user.target
```

Installation:
```bash
sudo cp {service_name}.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable {service_name}
```

## Rollback Plan

```bash
# 1. Stop service
ssh {server_user}@{server_host} "sudo systemctl stop {service_name}"

# 2. Restore backup
ssh {server_user}@{server_host} "rm -rf {deploy_path} && mv {deploy_path}.backup.YYYYMMDDHHMMSS {deploy_path}"

# 3. Restart service
ssh {server_user}@{server_host} "sudo systemctl start {service_name}"
```

## Post-Deployment Verification

- Service status: `systemctl is-active {service_name}`
- Port listening: `ss -tlnp | grep 8000`
- Health check: `curl -s http://localhost:8000{health_check_url}`
- Log check: `journalctl -u {service_name} -n 20 --no-pager`

## Cost/Complexity

- **Cost**: Low — only VPS hosting cost
- **Complexity**: Low — simple rsync + restart
- **Scalability**: Limited — single server
- **Monitoring**: Manual or basic (journalctl)

## Common Issues

1. **Service fails to start**: Check `journalctl -u {service_name} -n 50` for error logs
2. **Permission denied**: Ensure `{server_user}` owns `{deploy_path}` and has execute permissions
3. **Port conflict**: Check `ss -tlnp | grep <port>` and update service file if needed
4. **Environment variables missing**: Add `Environment=` lines to `.service` file or use `.env` file