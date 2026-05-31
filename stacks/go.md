---
stack: go
description: "Go backend stack — detection, build, test, and deployment for Gin/Fiber/Echo projects."
---

# Go Stack Guide

## Detection Signals

### Primary indicators
- `go.mod` exists
- `go.sum` exists
- `*.go` files in project

### Framework detection
| Framework | Detection signal |
|-----------|-----------------|
| Gin | `gin-gonic/gin` in go.mod |
| Fiber | `gofiber/fiber` in go.mod |
| Echo | `labstack/echo` in go.mod |
| Chi | `go-chi/chi` in go.mod |
| Standard net/http | No framework in go.mod |

### Detection commands
```bash
[ -f "go.mod" ] && echo "GO_DETECTED=yes" || echo "GO_DETECTED=no"
grep -E "gin-gonic|gofiber|labstack/echo|go-chi" go.mod 2>/dev/null
```

## Build Verification

### Testing
```bash
cd {backend_dir}
go test ./... -v 2>&1
```

### Race detection (recommended)
```bash
cd {backend_dir}
go test -race ./... 2>&1
```

### Build binary
```bash
cd {backend_dir}
CGO_ENABLED=0 GOOS=linux go build -o {service_name} .
```

### Vet (static analysis)
```bash
cd {backend_dir}
go vet ./... 2>&1
```

## Database Migration

### Migration tool detection
| Tool | Detection signal | Command |
|------|-----------------|---------|
| golang-migrate | `golang-migrate` in go.mod or `migrations/` dir | `migrate -path migrations/ -database $DB_URL up` |
| Goose | `goose` in go.mod | `goose $DB_URL up` |
| Atlas | `atlas` in go.mod or `atlas.hcl` | `atlas migrate apply` |
| GORM AutoMigrate | `gorm.io/gorm` in go.mod | Handled in application code |
| None | No migration tool found | Generate manual SQL |

## Dependency Management

```bash
cd {backend_dir}
go mod download
go mod tidy
```

## Service Start

### Direct binary
```bash
./{service_name} --port 8080
```

### With environment
```bash
ENV=production ./{service_name}
```

### Using systemd
```bash
/opt/{service_name}/{service_name} --port 8080
```

## Common Issues

1. **CGO dependency in container**: Use `CGO_ENABLED=0` for static binary, or install `gcc` in container
2. **Module proxy issues**: Set `GOPROXY=https://proxy.golang.org,direct` if behind firewall
3. **Binary too large**: Use `go build -ldflags="-s -w"` to strip debug info
4. **Hot reload in dev**: Use `air` or `realize` — not for production
5. **Graceful shutdown**: Implement `signal.NotifyContext` for clean shutdown