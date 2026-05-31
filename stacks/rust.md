---
stack: rust
description: "Rust backend stack — detection, build, test, and deployment for Actix/Axum/Rocket projects."
---

# Rust Stack Guide

## Detection Signals

### Primary indicators
- `Cargo.toml` exists
- `Cargo.lock` exists
- `src/` directory with `*.rs` files

### Framework detection
| Framework | Detection signal |
|-----------|-----------------|
| Actix Web | `actix-web` in Cargo.toml |
| Axum | `axum` in Cargo.toml |
| Rocket | `rocket` in Cargo.toml |
| Warp | `warp` in Cargo.toml |

### Detection commands
```bash
[ -f "Cargo.toml" ] && echo "RUST_DETECTED=yes" || echo "RUST_DETECTED=no"
grep -E "actix-web|axum|rocket|warp" Cargo.toml 2>/dev/null
```

## Build Verification

### Testing
```bash
cd {backend_dir}
cargo test 2>&1
```

### Clippy (linting)
```bash
cd {backend_dir}
cargo clippy -- -D warnings 2>&1
```

### Build release binary
```bash
cd {backend_dir}
cargo build --release 2>&1
```

### Verify binary
```bash
ls -lh {backend_dir}/target/release/{service_name}
```

## Database Migration

### Migration tool detection
| Tool | Detection signal | Command |
|------|-----------------|---------|
| SQLx | `sqlx` in Cargo.toml | `sqlx migrate run` |
| Diesel | `diesel` in Cargo.toml | `diesel migration run` |
| SeaORM | `sea-orm` in Cargo.toml | `sea-orm-cli migrate` |
| None | No migration tool found | Generate manual SQL |

## Dependency Management

```bash
cd {backend_dir}
cargo build --release
```

Cargo fetches and compiles dependencies automatically.

## Service Start

### Direct binary
```bash
ROCKET_ENV=production ./{service_name}
# or
./{service_name} --port 8080
```

### With environment variables
```bash
APP_ENV=production DATABASE_URL=$DB_URL ./{service_name}
```

## Common Issues

1. **Long build times**: Use `sccache` or split workspace into multiple crates
2. **Cross-compilation**: Use `cross` tool or appropriate target — `cargo build --target x86_64-unknown-linux-musl`
3. **OpenSSL dependency**: Use `rustls` instead of `native-tls` to avoid system OpenSSL
4. **Memory usage during build**: Rust compilation can use 2-4GB RAM; use `CARGO_BUILD_JOBS=2` to limit parallelism
5. **Binary size**: Use `strip = true` in Cargo.toml `[profile.release]` and `opt-level = "z"` for size