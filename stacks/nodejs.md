---
stack: nodejs
description: "Node.js stack — detection, build, test, migration, and deployment for Express/NestJS/Next.js projects."
---

# Node.js Stack Guide

## Detection Signals

### Primary indicators
- `package.json` exists in project root or subdirectory
- `node_modules/` directory exists
- `tsconfig.json` exists (TypeScript project)

### Framework detection
| Framework | Detection signal |
|-----------|-----------------|
| Express | `express` in dependencies of package.json |
| NestJS | `@nestjs/core` in dependencies |
| Next.js | `next` in dependencies |
| Nuxt | `nuxt` in dependencies |
| SvelteKit | `@sveltejs/kit` in dependencies |
| Astro | `astro` in dependencies |
| Remix | `@remix-run/node` in dependencies |

### Project type detection
```bash
# Check package.json for framework
[ -f "package.json" ] && echo "NODEJS_DETECTED=yes" || echo "NODEJS_DETECTED=no"

# Framework from dependencies
grep -E '"(express|@nestjs/core|next|nuxt|@sveltejs/kit|astro|@remix-run)"' package.json 2>/dev/null
```

## Build Verification

### Package manager detection
```bash
if [ -f "pnpm-lock.yaml" ]; then PKG="pnpm"
elif [ -f "yarn.lock" ]; then PKG="yarn"
elif [ -f "bun.lockb" ]; then PKG="bun"
else PKG="npm"
fi
echo "PKG_MANAGER=$PKG"
```

### Install dependencies
```bash
cd {frontend_dir}
$PKG install
```

### Testing
```bash
cd {frontend_dir}
$PKG test 2>&1
```

### Linting
```bash
cd {frontend_dir}
$PKG run lint 2>/dev/null || echo "NO_LINT_SCRIPT"
```

### Type checking (TypeScript)
```bash
cd {frontend_dir}
npx tsc --noEmit 2>/dev/null || echo "NO_TYPESCRIPT"
```

### Build
```bash
cd {frontend_dir}
$PKG run build 2>&1

# Verify output
[ -d "{dist_path}" ] && echo "BUILD_SUCCESS=yes" || echo "BUILD_SUCCESS=no"
```

## Database Migration

### Migration tool detection
| Tool | Detection signal | Command |
|------|-----------------|---------|
| Prisma | `prisma/schema.prisma` exists | `npx prisma migrate deploy` |
| Drizzle | `drizzle.config.ts` exists | `npx drizzle-kit push` |
| TypeORM | `typeorm` in dependencies | `npx typeorm migration:run` |
| Sequelize | `sequelize` in dependencies | `npx sequelize-cli db:migrate` |
| None | No migration tool found | Generate manual SQL |

### Remote schema collection (Prisma + PostgreSQL)

When the target is a remote server, collect DB state before generating migration plan:

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}

# 1. Prisma migration status
echo "=== PRISMA_MIGRATION_STATUS ==="
npx prisma migrate status 2>&1 || echo "PRISMA_NOT_CONFIGURED"

# 2. Existing tables (PostgreSQL)
echo "=== EXISTING_TABLES ==="
psql $DATABASE_URL -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" -t -A | sort | tr '\n' ',' | sed 's/,$//'

# 3. Column details (PostgreSQL)
echo "=== TABLE_COLUMNS ==="
psql $DATABASE_URL -t -A -c "
SELECT json_object(
  table_name,
  json_agg(column_name ORDER BY column_name)
)
FROM information_schema.columns
WHERE table_schema='public'
GROUP BY table_name
"
REMOTE
```

### Remote schema collection (Prisma + SQLite)

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}

# 1. Prisma migration status
echo "=== PRISMA_MIGRATION_STATUS ==="
npx prisma migrate status 2>&1 || echo "PRISMA_NOT_CONFIGURED"

# 2. Existing tables (SQLite)
echo "=== EXISTING_TABLES ==="
node -e "
const Database = require('better-sqlite3');
const db = new Database('{db_path}');
const tables = db.prepare(\"SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence'\").all().map(r => r.name).sort();
console.log(tables.join(','));
db.close();
" 2>/dev/null || echo "NEEDS_BETTER_SQLITE3"
REMOTE
```

### Remote schema collection (Drizzle + PostgreSQL)

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}

# Drizzle doesn't have a "status" command — use pg_dump schema
echo "=== DRIZZLE_SCHEMA ==="
pg_dump $DATABASE_URL --schema-only --no-owner --no-privileges 2>&1 | head -100 || echo "PG_DUMP_FAILED"

# Existing tables
echo "=== EXISTING_TABLES ==="
psql $DATABASE_URL -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" -t -A | sort | tr '\n' ',' | sed 's/,$//'
REMOTE
```

### Pre-migration safety check

Before deploying migrations, verify local schema diffs match remote reality:

```bash
# Generate a local migration diff
npx prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --script

# Or for Drizzle:
npx drizzle-kit generate
```

Compare the generated SQL against remote schema tables collected above. Skip migrations for tables/columns that already exist on the target.

### Prisma workflow
```bash
cd {frontend_dir}

# Check migration status
npx prisma migrate status

# Apply pending migrations
npx prisma migrate deploy

# Rollback: Prisma doesn't support rollback natively
# Use database backup to restore
```

## Dependency Management

```bash
cd {frontend_dir}
$PKG install --frozen-lockfile 2>/dev/null || $PKG install
```

## Service Start

### Express / NestJS
```bash
NODE_ENV=production node dist/main.js
# or with PM2
pm2 start dist/main.js --name {service_name}
```

### Next.js
```bash
cd {frontend_dir}
$PKG start
# or
node .next/standalone/server.js
```

### Using PM2 (production)
```bash
pm2 start ecosystem.config.js --env production
pm2 save
```

## Common Issues

1. **node_modules out of sync**: Delete and reinstall — `rm -rf node_modules && $PKG install`
2. **Build fails with TypeScript errors**: Run `npx tsc --noEmit` first to see type errors
3. **Memory issues during build**: Set `NODE_OPTIONS=--max-old-space-size=4096`
4. **Next.js standalone mode**: Ensure `output: 'standalone'` in `next.config.js` for containerized deployment
5. **Lock file mismatch**: Use the same package manager consistently; don't mix npm and yarn