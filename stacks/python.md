---
stack: python
description: "Python backend stack — detection, build, test, migration, and deployment for FastAPI/Flask/Django projects."
---

# Python Stack Guide

## Detection Signals

### Primary indicators
- `requirements.txt` or `pyproject.toml` or `Pipfile` or `setup.py` exists
- Directory contains `*.py` files with imports from web frameworks

### Framework detection
| Framework | Detection signal |
|-----------|-----------------|
| FastAPI | `from fastapi` or `import fastapi` in any `.py` file; `uvicorn` in requirements |
| Flask | `from flask` or `Flask(__name__)` in any `.py` file |
| Django | `manage.py` exists; `django` in requirements |
| Starlette | `from starlette` in any `.py` file |

### Project structure patterns
- `backend/` directory with Python files → typical fullstack layout
- `app/` or `src/` with `main.py` → typical standalone layout
- `manage.py` at root → Django project layout

### Detection commands
```bash
# Check for Python project
[ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ] && echo "PYTHON_DETECTED=yes" || echo "PYTHON_DETECTED=no"

# Framework detection
grep -rl "from fastapi" --include="*.py" . 2>/dev/null | head -1 && echo "FRAMEWORK=fastapi"
grep -rl "from flask" --include="*.py" . 2>/dev/null | head -1 && echo "FRAMEWORK=flask"
[ -f "manage.py" ] && echo "FRAMEWORK=django"
```

## Build Verification

### Virtual environment detection
```bash
# Find Python interpreter
if [ -d "venv" ]; then PYTHON="{backend_dir}/venv/bin/python"
elif [ -d ".venv" ]; then PYTHON="{backend_dir}/.venv/bin/python"
elif [ -d "venv_new" ]; then PYTHON="{backend_dir}/venv_new/bin/python"
else PYTHON="python3"
fi
echo "PYTHON_PATH=$PYTHON"
```

### Testing
```bash
cd {backend_dir}
$PYTHON -m pytest {test_command} --tb=short -q 2>&1
```

### Linting (optional)
```bash
cd {backend_dir}
$PYTHON -m ruff check . 2>/dev/null || $PYTHON -m flake8 . 2>/dev/null || echo "NO_LINTER"
```

### Type checking (optional)
```bash
cd {backend_dir}
$PYTHON -m mypy . --ignore-missing-imports 2>/dev/null || echo "NO_MYPY"
```

## Database Migration

### Migration tool detection
| Tool | Detection signal | Command |
|------|-----------------|---------|
| Alembic | `alembic.ini` exists | `$PYTHON -m alembic upgrade head` |
| Django ORM | `manage.py` exists (Django) | `$PYTHON manage.py migrate` |
| Prisma | `prisma/schema.prisma` exists | `npx prisma migrate deploy` |
| None | No migration tool found | Generate manual SQL |

### Ghost column similarity check

After collecting remote schema (Step 5.0), run this locally to identify ghost columns.

**Detection rules (conservative — prefer false positives over false negatives):**
- Similarity ≥ 0.7 against any local column in the same table → DANGER
- Column name ends with a known rename suffix (`_new`, `_old`, `_bak`, `_backup`, `_v2`, `_tmp`, `_copy`, `_orig`) → DANGER regardless of similarity score
- Entire table exists remotely but has no local model definition → GHOST TABLE warning
- Anything else → INFO (legacy, no action)

```python
# Run locally: python3 ghost_check.py
import json, difflib, sys

# Load remote columns from Step 5.0 output
remote_columns = json.loads('{table_columns_json}')  # from SSH output

# Load local model columns (adapt import path to project)
try:
    from app.models import Base
    local_columns = {
        table: [c.name for c in mapper.columns]
        for table, mapper in Base.metadata.tables.items()
    }
except Exception as e:
    print(f"Could not load models: {e}"); sys.exit(1)

DANGER_THRESHOLD = 0.7
# Suffix patterns that always indicate a renamed/migrated column — DANGER regardless of score
GHOST_SUFFIXES = ('_new', '_old', '_bak', '_backup', '_v2', '_tmp', '_copy', '_orig')

ghost_columns = []  # [(table, ghost_col, similar_col, score, reason)]

for table, remote_cols in remote_columns.items():
    local_cols = local_columns.get(table, [])

    # Entire table is unknown to local models — warn but don't auto-drop
    if not local_cols:
        print(f"⚠️  GHOST TABLE  {table} (exists remotely, no local model — manual review required)")
        continue

    for remote_col in remote_cols:
        if remote_col in local_cols:
            continue  # exists in model, not a ghost

        best_match = max(
            local_cols,
            key=lambda c: difflib.SequenceMatcher(None, remote_col, c).ratio(),
            default=None
        )
        score = difflib.SequenceMatcher(None, remote_col, best_match).ratio() if best_match else 0.0

        suffix_hit = remote_col.endswith(GHOST_SUFFIXES)
        is_danger = score >= DANGER_THRESHOLD or suffix_hit
        reason = []
        if score >= DANGER_THRESHOLD:
            reason.append(f"similarity {score:.2f}")
        if suffix_hit:
            reason.append("rename suffix")

        if is_danger:
            ghost_columns.append((table, remote_col, best_match, round(score, 2), ', '.join(reason)))
            print(f"⚠️  DANGER  {table}.{remote_col} → {best_match} ({', '.join(reason)})")
        else:
            print(f"ℹ️  INFO    {table}.{remote_col} (score {score:.2f}, no suffix match — legacy column)")

if ghost_columns:
    print(f"\n{len(ghost_columns)} DANGER ghost column(s) found — proceed to ghost column cleanup plan")
    print(json.dumps([
        {"table": t, "ghost": g, "similar": s, "score": sc, "reason": r}
        for t, g, s, sc, r in ghost_columns
    ]))
else:
    print("No DANGER ghost columns detected.")
```

### SQLite version check (before generating DROP COLUMN migration)

`ALTER TABLE ... DROP COLUMN` requires SQLite ≥ 3.35.0. Check before generating the migration:

```bash
ssh {server_user}@{server_host} 'sqlite3 --version'
# Output example: 3.39.5 2022-10-14 ...
# If version < 3.35.0, use the table-rebuild approach instead of DROP COLUMN
```

If SQLite < 3.35.0, generate this migration instead of `op.drop_column`:

```python
def upgrade() -> None:
    # SQLite < 3.35.0: rebuild table to drop column
    with op.batch_alter_table('{table}') as batch_op:
        batch_op.drop_column('{ghost_col}')
```

`op.batch_alter_table` (Alembic's SQLite compatibility mode) handles the rebuild automatically.

### Pre-migration safety check

Before running migrations remotely, verify the local alembic version is consistent with the actual DB state. If the DB was modified manually (e.g., tables created outside alembic), the version number will lag behind:

```bash
cd {backend_dir}

# Check if alembic version matches actual DB tables
$PYTHON -c "
from sqlalchemy import inspect, create_engine
import os, sys

# Get engine from app config or direct path
db_path = '{db_path}'
if os.path.exists(db_path):
    engine = create_engine(f'sqlite:///{db_path}')
    insp = inspect(engine)
    actual_tables = set(insp.get_table_names()) - {'sqlite_sequence'}
    print(f'DB has {len(actual_tables)} tables: {sorted(actual_tables)}')
else:
    print('DB file not found at {db_path}')
    sys.exit(0)

# Compare with model definitions
try:
    from app.models import Base
    model_tables = set(Base.metadata.tables.keys())
    missing_in_db = model_tables - actual_tables
    extra_in_db = actual_tables - model_tables
    if missing_in_db:
        print(f'Tables in models but missing from DB: {sorted(missing_in_db)}')
    if extra_in_db:
        print(f'Tables in DB but not in models: {sorted(extra_in_db)}')
    if not missing_in_db and not extra_in_db:
        print('DB tables match model definitions')
except Exception as e:
    print(f'Could not load models for comparison: {e}')
"

# If DB has tables from migrations that alembic doesn't know about:
if [ "$NEEDS_STAMP" = "true" ]; then
    echo "⚠️  Alembic version does not reflect actual DB state. Run:"
    echo "   $PYTHON -m alembic stamp head"
fi
```

### Remote schema collection (SQLite)

When the target is a remote server, collect the actual DB schema via SSH before generating the migration plan:

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}/{backend_dir}
source venv/bin/activate 2>/dev/null || true

# 1. Alembic version
echo "=== ALEMBIC_VERSION ==="
{python_path} -m alembic current 2>/dev/null || echo "ALEMBIC_NOT_CONFIGURED"

# 2. Existing tables
echo "=== EXISTING_TABLES ==="
{python_path} -c "
import sqlite3, os
db_path = '{db_path}'
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    tables = [r[0] for r in conn.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence'\").fetchall()]
    print(','.join(sorted(tables)))
    conn.close()
else:
    print('DB_NOT_FOUND')
"

# 3. Column details for all tables
echo "=== TABLE_COLUMNS ==="
{python_path} -c "
import sqlite3, os, json
db_path = '{db_path}'
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    result = {}
    for table in conn.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence'\").fetchall():
        cols = [r[1] for r in conn.execute(f'PRAGMA table_info({table[0]})').fetchall()]
        result[table[0]] = sorted(cols)
    print(json.dumps(result))
    conn.close()
"
REMOTE
```

### Remote schema collection (PostgreSQL)

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}/{backend_dir}

# 1. Alembic version
echo "=== ALEMBIC_VERSION ==="
{python_path} -m alembic current 2>/dev/null || echo "ALEMBIC_NOT_CONFIGURED"

# 2. Existing tables
echo "=== EXISTING_TABLES ==="
psql $DATABASE_URL -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" -t -A | sort | tr '\n' ',' | sed 's/,$//'

# 3. Column details for all tables
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

### Remote schema collection (MySQL)

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}/{backend_dir}

# 1. Alembic version
echo "=== ALEMBIC_VERSION ==="
{python_path} -m alembic current 2>/dev/null || echo "ALEMBIC_NOT_CONFIGURED"

# 2. Existing tables
echo "=== EXISTING_TABLES ==="
mysql $DATABASE_URL -e "SHOW TABLES" -s | sort | tr '\n' ',' | sed 's/,$//'

# 3. Column details
echo "=== TABLE_COLUMNS ==="
mysql $DATABASE_URL -e "
SELECT TABLE_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY COLUMN_NAME) as columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE()
GROUP BY TABLE_NAME
" -s
REMOTE
```

### Alembic workflow
```bash
cd {backend_dir}

# Check current migration state
$PYTHON -m alembic current

# List pending migrations
$PYTHON -m alembic history --verbose

# Execute migration (on server)
$PYTHON -m alembic upgrade head

# Rollback one migration
$PYTHON -m alembic downgrade -1
```

### Django migration workflow
```bash
cd {backend_dir}

# Check pending migrations
$PYTHON manage.py showmigrations --list

# Execute migration
$PYTHON manage.py migrate

# Rollback
$PYTHON manage.py migrate <app_name> <migration_number>
```

### Manual SQL generation
When no migration tool is detected, analyze model diffs and generate:
```sql
-- Generated migration script — review before executing
-- Source: {db_path}

-- Add new columns
-- ALTER TABLE <table_name> ADD COLUMN <column_name> <column_type>;

-- Verify
SELECT COUNT(*) FROM sqlite_master WHERE type='table';
```

## Dependency Management

### pip (requirements.txt)
```bash
cd {backend_dir}
$PYTHON -m pip install -r requirements.txt
```

### pip (pyproject.toml)
```bash
cd {backend_dir}
$PYTHON -m pip install -e .
```

### pipenv
```bash
cd {backend_dir}
pipenv install --deploy
```

## Service Start

### FastAPI / Uvicorn
```bash
$PYTHON -m uvicorn {entry_point} --host 0.0.0.0 --port 8000
```

### Flask
```bash
$PYTHON -m flask run --host 0.0.0.0 --port 5000
```

### Django
```bash
$PYTHON manage.py runserver 0.0.0.0:8000
```

### Gunicorn (production)
```bash
$PYTHON -m gunicorn {entry_point} --bind 0.0.0.0:8000 --workers 4
```

## Common Issues

1. **Virtual environment not found**: Check for `venv/`, `.venv/`, or create one with `$PYTHON -m venv venv`
2. **Alembic stamp mismatch**: Run `$PYTHON -m alembic stamp head` to sync, then re-run migration
3. **Import errors after deploy**: Ensure `$PYTHON -m pip install -r requirements.txt` ran on the server with correct Python version
4. **Port already in use**: Check with `lsof -i :8000` or `ss -tlnp | grep 8000`
5. **Environment variables missing**: Ensure `.env` file or environment is configured on the server