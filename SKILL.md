---
name: cloud-release
description: "Systematic release workflow for cloud projects. Auto-detects tech stacks and deployment targets, runs security audits, build verification, and generates deployment plans. Works with Claude Code and Codex."
---

# Cloud Release — Systematic Release Workflow

A zero-config, auto-detecting release workflow for cloud projects. Detects your tech stack, deployment target, and project structure, then guides you through a structured release process with security checks, build verification, and deployment planning.

<HARD-GATE>
Do NOT execute any deployment commands or modify production systems until the user has reviewed and approved the deployment plan at Phase 6. This applies to EVERY release regardless of perceived simplicity.
</HARD-GATE>

## Step 0: Version Check & Upgrade

> **Skip this step if the user invoked the skill with `--upgrade` flag** — jump directly to the upgrade flow below.

### 0.1: Check for updates

Detect the current local version and compare against the latest GitHub release.

**Get local version:**
```bash
# Read from CHANGELOG.md — first version header (e.g. ## [2.0.0])
grep -m1 '## \[' {skill_root}/CHANGELOG.md 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
```

**Get remote version** (GitHub API, no auth required):
```bash
curl -sf "https://api.github.com/repos/rrred0324/cloud-release/releases/latest" \
  2>/dev/null | grep '"tag_name"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
```

Override the default repo with `skill_repo` from `.cloudrelease.yml` if set:
```bash
# If .cloudrelease.yml has: skill_repo: owner/repo
# Use: https://api.github.com/repos/{skill_repo}/releases/latest
```

If the curl fails (no network, rate-limited, private repo), skip silently — do not block the release workflow.

**If remote version > local version**, notify the user once per session:

```
💡 cloud-release {remote_version} is available (you're on {local_version})
   Run: /cloud-release --upgrade   to update
   Or continue with the current version — this won't affect your release.
```

Then continue with the normal release workflow. Do not block or prompt for confirmation.

### 0.2: Upgrade flow (`--upgrade` flag or user confirms upgrade)

**Triggered by:** `/cloud-release --upgrade` (Claude Code) or `codex exec "/cloud-release --upgrade"` (Codex)

**Steps:**

1. Detect `skill_root` — the directory containing this SKILL.md file:
   ```bash
   # Claude Code: skill is in ~/.claude/skills/cloud-release/ or .claude/skills/cloud-release/
   # Codex: skill is in .agents/skills/cloud-release/ or agents/skills/cloud-release/
   # Check both locations; use whichever exists
   ```

2. Confirm the upgrade with the user:

   **[PLATFORM:INTERACT]**
   question: Upgrade cloud-release from {local_version} to {remote_version}?
   options:
     A) Yes, upgrade now (recommended)
     B) No, skip
   recommendation: A
   **[/PLATFORM:INTERACT]**

3. If confirmed, download and apply the update:
   ```bash
   # Download latest release archive
   curl -sfL "https://github.com/rrred0324/cloud-release/archive/refs/heads/main.tar.gz" \
     -o /tmp/cloud-release-latest.tar.gz

   # Backup current version
   cp -r "{skill_root}" "{skill_root}.bak.$(date +%Y%m%d%H%M%S)"

   # Extract and overwrite (preserve .cloudrelease.yml in project — it's not part of the skill)
   tar -xzf /tmp/cloud-release-latest.tar.gz -C /tmp/
   cp -r /tmp/cloud-release-main/. "{skill_root}/"

   # Cleanup
   rm -f /tmp/cloud-release-latest.tar.gz
   rm -rf /tmp/cloud-release-main
   ```

4. Verify the upgrade:
   ```bash
   grep -m1 '## \[' "{skill_root}/CHANGELOG.md" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
   ```

5. Report result:
   - Success: `✅ cloud-release upgraded to {new_version}. Run /cloud-release to start a release.`
   - Failure (download error, extraction error): restore from backup and report:
     `⛔ Upgrade failed — restored previous version {local_version}. Error: {error_message}`

6. **Exit** — do not continue into the release workflow after an upgrade.

---

## Step 0b: Platform Detection

Determine which AI platform is running this skill and load the appropriate adapter.

**Detection logic:**
- If `AskUserQuestion` tool is available → Claude Code → load `platforms/claude-code.md`
- If running in Codex environment → load `platforms/codex.md`
- Otherwise → default to text-based interaction (similar to Codex adapter)

**Action:** Read the detected platform adapter file and follow its interaction patterns for all subsequent steps.

## Step 1: Project Detection

Auto-detect the project structure, tech stacks, and deployment targets.

### 1.1: Load configuration (if exists)

Search for `.cloudrelease.yml` or `.cloudrelease.yaml` in:
1. Current directory
2. Git project root

If found, read it. Configuration values override auto-detection results.

### 1.2: Detect project type

```bash
# Is this a git repo?
git rev-parse --show-toplevel 2>/dev/null || echo "NOT_A_GIT_REPO"

# Current branch
git branch --show-current 2>/dev/null

# Uncommitted changes
git status --porcelain | wc -l
```

### 1.3: Detect tech stacks

For each stack module in `stacks/`, check its detection signals against the project:

```bash
# Check each stack's detection signals
# Python: requirements.txt / pyproject.toml / Pipfile
# Node.js: package.json / tsconfig.json
# Java: pom.xml / build.gradle
# Go: go.mod
# Rust: Cargo.toml
```

Read `stacks/<detected>.md` for each detected stack. Use the configuration file's stack settings to override if needed.

### 1.4: Detect deployment target

Read `targets/recommendation.md` and follow its three-layer detection process:

1. **Layer 1**: Check for deployment config files (Dockerfile, docker-compose.yml, k8s/, vercel.json, etc.)
2. **Layer 2**: Check for cloud environment signals
3. **Layer 3**: Apply recommendation rules

### 1.5: Output project summary

Present the detection results:

```
Project Detection Summary:
  Name: {project_name}
  Type: {frontend-only | fullstack | backend-only}
  Branch: {branch}

  Stacks detected:
    - {stack_1}: {framework_1}
    - {stack_2}: {framework_2}

  Deployment target recommendation:
    Build: {build_method}
    Deploy: {deploy_method}
    Pipeline: {cicd_method}
```

**[PLATFORM:INTERACT]**
question: Are the detected stacks and recommended deployment target correct? If not, specify corrections.
options:
  A) Correct, proceed (recommended)
  B) Different stacks — I'll specify
  C) Different deployment target — I'll specify
recommendation: A
**[/PLATFORM:INTERACT]**

## Step 2: Change Analysis

Analyze all changes since the last deployment.

### 2.1: Git change statistics

```bash
# Find last deploy reference
# Priority: state file commit > git tag > deploy/release commit message > HEAD~5
if [ -f ".cloudrelease-state.json" ]; then
    LAST_DEPLOY=$(python3 -c "import json; print(json.load(open('.cloudrelease-state.json'))['last_commit'])" 2>/dev/null)
fi
if [ -z "$LAST_DEPLOY" ]; then
    LAST_DEPLOY=$(git describe --tags --abbrev=0 2>/dev/null)
fi
if [ -z "$LAST_DEPLOY" ]; then
    LAST_DEPLOY=$(git log --oneline --grep="deploy\|release\|发版" -1 --format="%H" 2>/dev/null || git rev-parse HEAD~5)
fi

# Change stats
git diff $LAST_DEPLOY --stat
git log $LAST_DEPLOY..HEAD --oneline

# Classify changes
echo "=== Database-related changes ==="
git diff $LAST_DEPLOY --name-only | grep -iE "(model|migration|\.db|schema|alembic|prisma|flyway)" || echo "None"

echo "=== Frontend changes ==="
git diff $LAST_DEPLOY --name-only | grep -E "^{frontend_dir}/" | wc -l

echo "=== Backend/API changes ==="
git diff $LAST_DEPLOY --name-only | grep -E "^{backend_dir}/" | wc -l

echo "=== Configuration changes ==="
git diff $LAST_DEPLOY --name-only | grep -iE "(\.env|config|settings|docker|k8s|\.yml|\.yaml)" || echo "None"
```

### 2.2: Database change detection

For each detected stack, follow its `Database Migration` section to:
1. Detect if models/schema files changed
2. Check for corresponding migration scripts
3. Flag missing migrations

### 2.3: Risk assessment

Classify the release risk:
- **Low**: Only frontend changes, no DB/API changes
- **Medium**: Backend changes, no DB schema changes
- **High**: DB schema changes, config changes, or security-sensitive changes

**[PLATFORM:INTERACT]**
question: Risk level for this release is {risk_level}. Key concerns: {concerns}. Proceed with release?
options:
  A) Proceed (recommended for Low/Medium)
  B) Review concerns first
  C) Stop — need more investigation
recommendation: A (if Low/Medium), B (if High)
**[/PLATFORM:INTERACT]**

## Step 3: Security Audit

Scan for common security issues before deployment.

### 3.1: Sensitive information scan

```bash
# Check for tracked sensitive files
git ls-files | grep -iE "\.env|secret|credential|password|\.pem|\.key" && echo "⚠️ Sensitive files tracked in git" || echo "✅ No sensitive files tracked"

# Check .gitignore
grep -iE "\.env|secret|credential|\.pem|\.key" .gitignore || echo "⚠️ .gitignore may be missing sensitive file patterns"

# Scan for hardcoded secrets
grep -riE "(SECRET_KEY|API_KEY|PASSWORD|TOKEN|PRIVATE_KEY)\s*=\s*['\"][^'\"]{16,}" --include="*.py" --include="*.ts" --include="*.js" --include="*.java" --include="*.go" --include="*.rs" . 2>/dev/null && echo "⚠️ Hardcoded secrets detected" || echo "✅ No hardcoded secrets"
```

### 3.2: Authentication check

For API endpoints, check for missing authentication:

- Python (FastAPI): Search for route decorators without `Depends` auth
- Node.js (Express): Search for routes without auth middleware
- Java (Spring): Search for `@RequestMapping` without `@PreAuthorize`
- Go: Search for route registrations without auth middleware

### 3.3: Configuration file security validation

If `.cloudrelease.yml` exists, validate it before any execution:

```python
import re, os

SHELL_METACHAR = re.compile(r'[;&|`$<>()\n]')
UNSAFE_PATH    = re.compile(r'(^\s*/|\.\./)') # absolute or traversal

def validate_config(cfg):
    errors = []
    # Command fields — reject shell metacharacters
    cmd_fields = [
        cfg.get('stack', {}).get('frontend', {}).get('build_command', ''),
        cfg.get('stack', {}).get('backend',  {}).get('test_command',  ''),
        cfg.get('stack', {}).get('backend',  {}).get('entry_point',   ''),
    ]
    for cmd in cmd_fields:
        if cmd and SHELL_METACHAR.search(cmd):
            errors.append(f"BLOCKED: command contains shell metacharacters: {cmd!r}")

    # custom_scripts — relative paths only, no shell metacharacters
    for script in cfg.get('custom_scripts', {}).get('pre_deploy', []) + \
                  cfg.get('custom_scripts', {}).get('post_deploy', []):
        if UNSAFE_PATH.search(script) or SHELL_METACHAR.search(script):
            errors.append(f"BLOCKED: unsafe script path: {script!r}")

    # Path fields — no absolute paths, no traversal
    path_fields = [
        cfg.get('stack', {}).get('frontend', {}).get('path', ''),
        cfg.get('stack', {}).get('frontend', {}).get('dist_path', ''),
        cfg.get('stack', {}).get('backend',  {}).get('path', ''),
        cfg.get('stack', {}).get('database', ).get('path', ''),
        cfg.get('stack', {}).get('database', {}).get('backup_path', ''),
        cfg.get('output', {}).get('deployment_plan_path', ''),
        cfg.get('output', {}).get('release_report_path', ''),
        cfg.get('output', {}).get('scripts_dir', ''),
    ]
    for p in path_fields:
        if p and UNSAFE_PATH.search(p):
            errors.append(f"BLOCKED: unsafe path (absolute or traversal): {p!r}")

    # health_check_url — relative path only, no scheme
    hcu = cfg.get('verification', {}).get('health_check_url', '')
    if hcu and (re.match(r'[a-z]+://', hcu) or not hcu.startswith('/')):
        errors.append(f"BLOCKED: health_check_url must be a relative path starting with '/': {hcu!r}")

    # skip_checks — P0 checks cannot be skipped
    P0 = {'sensitive_files', 'hardcoded_secrets', 'missing_auth'}
    skipped = set(cfg.get('security', {}).get('skip_checks', []))
    blocked = P0 & skipped
    if blocked:
        errors.append(f"BLOCKED: P0 security checks cannot be skipped: {blocked}")

    return errors
```

If any errors are returned: **STOP**, output each error, mark status as `BLOCKED`. Do not proceed to Step 4.

### 3.4: Security gate

If P0 issues found:
- **STOP** the workflow
- Output issue details with fix suggestions
- Mark status as `BLOCKED`

P0 issues:
- Sensitive files tracked in git
- Hardcoded secrets in source code
- Critical endpoints without authentication
- `.cloudrelease.yml` validation errors (from 3.3)

**[PLATFORM:INTERACT]**
question: P0 security issues found: {p0_summary}. Deployment is blocked.
options:
  A) Stop and fix issues first (recommended)
  B) Acknowledge and override (dangerous)
recommendation: A
**[/PLATFORM:INTERACT]**

## Step 4: Build Verification

Verify the project builds and tests pass.

For each detected stack, read and follow `stacks/<stack>.md` → `Build Verification` section.

### 4.1: Run tests

Execute the test command for each detected stack. Collect results.

### 4.2: Run build

Execute the build command for each detected stack. Verify build artifacts exist.

### 4.3: Type checking (optional)

If the stack supports type checking, run it. Non-blocking — report as warning only.

### 4.4: Build summary

Present results:

```
Build Verification:
  {stack_1}: Tests ✅ | Build ✅ | Types ✅
  {stack_2}: Tests ✅ | Build ✅ | Types ⚠️ (optional)
```

If any tests fail or build fails:
- Report the failure
- Ask whether to proceed (not recommended) or stop to fix

## Step 5: Data Sync Plan

Plan database schema and data synchronization — accurately, by comparing against the **remote database's actual state** rather than just local file changes.

For each detected stack, follow `stacks/<stack>.md` → `Database Migration` section.

### 5.0: Remote database schema collection

Before generating a migration plan, collect the **actual** schema state from the target database via SSH. This prevents false positives where already-synced changes are re-reported.

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}/{backend_dir}
source venv/bin/activate 2>/dev/null || true

# 1. Collect migration version
echo "=== ALEMBIC_VERSION ==="
{python_path} -m alembic current 2>/dev/null || echo "ALEMBIC_NOT_CONFIGURED"

# 2. Collect existing tables (SQLite)
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

# 2b. Collect existing tables (PostgreSQL — uncomment if applicable)
# echo "=== EXISTING_TABLES ==="
# psql $DATABASE_URL -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" -t -A | sort | tr '\n' ','

# 3. Collect column details for all tables
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

**Fallback**: If SSH is unreachable, fall back to `.cloudrelease-state.json` (if ≤7 days old). If neither is available, mark all detected changes as "unverified" with a confidence warning.

### 5.1: Read release state file

If `.cloudrelease-state.json` exists in the project root, read it. This file records what was synced in the last successful release:

```json
{
  "last_release": "2026-05-30",
  "last_commit": "24553ac",
  "remote_alembic_version": "dc4501920f21",
  "remote_tables": ["companies", "shareholders", "..."],
  "remote_columns": {
    "agency_market_data": ["company_name", "dividend_scale_premium", "..."]
  },
  "synced_migrations": ["dc4501920f21"]
}
```

### 5.2: Three-way diff (local models vs remote DB vs state file)

Compare local model definitions against the remote schema collected in 5.0:

| Local model has | Remote DB has | State file records | Action |
|----------------|---------------|-------------------|--------|
| ✅ | ✅ | ✅ | Already synced → output in "Already synced" section |
| ✅ | ✅ | ❌ | Previously synced manually → output in "Already synced", update state |
| ✅ | ❌ | ❌ | **New change** → output in "Changes to sync" section |
| ❌ | ✅ | any | Name similarity ≥ 0.7 with an existing column, OR name ends with `_new`/`_old`/`_bak`/`_backup`/`_v2`/`_tmp`/`_copy`/`_orig` → **⚠️ DANGER ghost column** — collect data stats, run impact check, require user confirmation before generating DROP migration |
| ❌ | ✅ | any | Name similarity < 0.7 with all existing columns AND no rename suffix → **ℹ️ INFO legacy column** — output in "Manual review needed" section, no action required |

**Ghost column detection rules (conservative — prefer false positives over false negatives):**
- Similarity ≥ 0.7 against any local column in the same table → DANGER
- Column name ends with a known rename suffix (`_new`, `_old`, `_bak`, `_backup`, `_v2`, `_tmp`, `_copy`, `_orig`) → DANGER regardless of similarity score
- Entire table exists remotely but has no local model definition → GHOST TABLE — run full impact assessment below before any action
- Anything else → INFO (legacy, no action)

**Ghost table impact assessment** (run for every GHOST TABLE before presenting to user):

```bash
# 1. Local codebase scan
grep -r "{ghost_table}" {project_root} \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.sql" \
  --include="*.go" --include="*.java" --include="*.rs" \
  -l 2>/dev/null

# 2. Production codebase scan (catches hot-patches not in local repo)
ssh {server_user}@{server_host} "grep -r '{ghost_table}' {deploy_path} \
  --include='*.py' --include='*.ts' --include='*.js' --include='*.sql' \
  -l 2>/dev/null" 2>/dev/null || echo "SSH_UNAVAILABLE"

# 3. Row count — is there data worth keeping?
ssh {server_user}@{server_host} << 'REMOTE'
{python_path} -c "
import sqlite3
conn = sqlite3.connect('{db_path}')
count = conn.execute('SELECT COUNT(*) FROM \"{ghost_table}\"').fetchone()[0]
print(f'ROW_COUNT={count}')
conn.close()
"
REMOTE
```

Present findings before any user decision:

```
⚠️  GHOST TABLE DETECTED — Impact Assessment

Table: {ghost_table}
Rows in production: {row_count}
Local code references:      {local_refs_count} file(s) — {local_refs_files}
Production code references: {prod_refs_count} file(s) — {prod_refs_files}
  (SSH unavailable — production scan skipped, treat as unknown)

Risk assessment:
  {if local_refs_count > 0 or prod_refs_count > 0}
  ⛔ CODE REFERENCE RISK: table is still referenced in code. Dropping will cause runtime errors.
     Files to update: {all_refs_files}
  {elif row_count > 0}
  ⚠️  DATA RISK: table has {row_count} rows. Confirm data has no retention value before dropping.
  {else}
  ✅ Safe to drop: no code references found, table is empty.
  {endif}

Recommendation: {if any ⛔} Do NOT drop — fix code references first.
                {elif row_count > 0} Confirm data value, then drop manually.
                {else} Safe to drop — no references, no data.
```

**[PLATFORM:INTERACT]**
question: Ghost table {ghost_table} found in production DB (no local model). How should it be handled?
options:
  A) Mark for manual cleanup — add to release notes, I'll drop it after confirming data value
  B) Skip — keep the table, it may be used by an external system
  C) Abort release — I need to investigate further
recommendation: A if no ⛔ risk; C if ⛔ CODE REFERENCE RISK exists
**[/PLATFORM:INTERACT]**

### 5.3: Detect migration tool

Check which migration tool the project uses (Alembic, Django ORM, Prisma, Flyway, etc.)

### 5.4: Check migration status

```bash
# Alembic example
cd {backend_dir} && {python_path} -m alembic current

# Prisma example
npx prisma migrate status

# Django example
{python_path} manage.py showmigrations --list
```

Also compare local alembic version with remote version from Step 5.0. If they diverge, flag a version mismatch warning and recommend `alembic stamp head` to align.

### 5.5: Decision point D1

**[PLATFORM:INTERACT]**
question: Database changes detected. How should schema changes be applied to the target environment?
options:
  A) Use migration tool (recommended) — versioned, trackable, rollbackable
  B) Manual SQL — flexible but no version record
  C) Backup and rebuild — only for non-production or disposable data
recommendation: A
**[/PLATFORM:INTERACT]**

### 5.6: Generate migration plan

Based on the three-way diff (Step 5.2) and chosen strategy, generate a structured migration plan:

```markdown
## Data Sync Plan

### Remote Database Current State
- Alembic version: {remote_alembic_version}
- Existing tables: {count} ({table_list})
- Last sync: {last_release} (commit {last_commit})

### Changes to Sync (New)
| Change type | Object | Details | SQL |
|-------------|--------|---------|-----|
| New table | {table} | {column_count} columns | CREATE TABLE ... |
| New column | {table}.{col} | {type} | ALTER TABLE ... |

### Already Synced (No Action Needed)
| Change type | Object | Synced on |
|-------------|--------|-----------|
| New table | {table} etc. | {date} |
| New column | {table}.{col} | {date} |

### Manual Review Needed
- Local alembic version ({local_ver}) does not match remote ({remote_ver}). Run `alembic stamp head` before migrating.

### ⚠️ Ghost Column Cleanup Plan (requires confirmation)

> Only present this section if DANGER ghost columns were detected in Step 5.2.

For each DANGER ghost column, collect the following via SSH **before** asking the user:

```bash
ssh {server_user}@{server_host} << 'REMOTE'
cd {deploy_path}/{backend_dir}
source venv/bin/activate 2>/dev/null || true
{python_path} -c "
import sqlite3, json, os
conn = sqlite3.connect('{db_path}')

# Check SQLite version — DROP COLUMN requires >= 3.35.0
import sqlite3 as _sq
ver = tuple(int(x) for x in _sq.sqlite_version.split('.'))
print(f'SQLITE_VERSION={_sq.sqlite_version}')
print(f'SUPPORTS_DROP_COLUMN={ver >= (3, 35, 0)}')

result = {}
for table, ghost_col, similar_col in {ghost_columns_list}:
    total = conn.execute(f'SELECT COUNT(*) FROM \"{table}\"').fetchone()[0]
    ghost_nonnull = conn.execute(f'SELECT COUNT(*) FROM \"{table}\" WHERE \"{ghost_col}\" IS NOT NULL').fetchone()[0]
    similar_nonnull = conn.execute(f'SELECT COUNT(*) FROM \"{table}\" WHERE \"{similar_col}\" IS NOT NULL').fetchone()[0]
    # Collect actual column type for accurate downgrade template
    col_info = conn.execute(f'PRAGMA table_info(\"{table}\")').fetchall()
    ghost_type = next((r[2] for r in col_info if r[1] == ghost_col), 'TEXT')
    result[ghost_col] = {
        'table': table,
        'similar_col': similar_col,
        'total_rows': total,
        'ghost_nonnull': ghost_nonnull,
        'similar_nonnull': similar_nonnull,
        'ghost_type': ghost_type,
        'data_migrated': ghost_nonnull == 0 or similar_nonnull >= ghost_nonnull,
        'data_loss_risk': ghost_nonnull > 0 and similar_nonnull < ghost_nonnull
    }
print(json.dumps(result, indent=2))
conn.close()
"
REMOTE
```

Then search both local and production codebases for any references to the ghost column name:

```bash
# Local codebase scan
grep -r "{ghost_col}" {project_root} \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.sql" \
  --include="*.go" --include="*.java" --include="*.rs" \
  -l 2>/dev/null

# Production codebase scan (catches hot-patches not committed to local repo)
ssh {server_user}@{server_host} "grep -r '{ghost_col}' {deploy_path} \
  --include='*.py' --include='*.ts' --include='*.js' --include='*.sql' \
  -l 2>/dev/null" 2>/dev/null || echo "SSH_UNAVAILABLE"
```

Present the findings to the user in this format before generating any DROP migration:

```
⚠️  GHOST COLUMN DETECTED — Confirmation Required

Table: {table}
Ghost column:   {ghost_col}  ({ghost_nonnull}/{total_rows} rows have data)
Similar column: {similar_col} ({similar_nonnull}/{total_rows} rows have data)
Detection reason: {reason}  (similarity score: {score})

Data status:
  {ghost_col}:   {ghost_nonnull} non-null rows  ← data is HERE
  {similar_col}: {similar_nonnull} non-null rows ← code reads HERE

Code references to ghost column:
  Local:      {local_refs_count} file(s) — {local_refs_files}
  Production: {prod_refs_count} file(s) — {prod_refs_files}
              (SSH unavailable — production scan skipped, treat as unknown)

Impact assessment:
  {if data_loss_risk}
  ⛔ DATA LOSS RISK: ghost column has {ghost_nonnull} rows NOT yet in {similar_col}.
     Run data migration first: UPDATE {table} SET {similar_col} = {ghost_col} WHERE {similar_col} IS NULL
     Then re-run cloud-release to verify before dropping.
  {elif local_refs_count > 0 or prod_refs_count > 0}
  ⛔ CODE REFERENCE RISK: {total_refs_count} file(s) still reference this column.
     Update all references to use {similar_col} before dropping.
     Files: {all_refs_files}
  {else}
  ✅ Safe to drop: data is fully in {similar_col}, no code references found (local + production).
  ⚠️  IMPORTANT: Ensure all code writing to {ghost_col} is already offline before running DROP.
  {endif}
```

**[PLATFORM:INTERACT]**
question: Ghost column {ghost_col} detected in {table}. How should it be handled?
options:
  A) Generate DROP migration — I confirm: (1) data is fully in {similar_col}, (2) no code writes to {ghost_col}, (3) new code is already deployed (recommended ONLY if impact assessment shows ✅)
  B) Skip — keep the ghost column for now, I'll handle it manually
  C) Abort release — I need to investigate further before proceeding
recommendation: B if any ⛔ risk exists; A only if impact assessment shows ✅
**[/PLATFORM:INTERACT]**

If user selects A, first verify data is complete, then generate the cleanup migration:

```bash
# Final data verification before DROP — run this immediately before the migration
ssh {server_user}@{server_host} << 'VERIFY'
cd {deploy_path}/{backend_dir}
source venv/bin/activate 2>/dev/null || true
{python_path} -c "
import sqlite3
conn = sqlite3.connect('{db_path}')
ghost_remaining = conn.execute('SELECT COUNT(*) FROM \"{table}\" WHERE \"{ghost_col}\" IS NOT NULL AND \"{similar_col}\" IS NULL').fetchone()[0]
print(f'Rows with data only in ghost column (should be 0): {ghost_remaining}')
if ghost_remaining > 0:
    print('ABORT: data not fully migrated — do NOT run DROP')
else:
    print('OK: safe to drop')
conn.close()
"
VERIFY
```

Only generate the migration if the verification above prints `OK: safe to drop`:

```python
# alembic migration: cleanup ghost column {ghost_col}
# Generated by cloud-release on {date}
# PRE-CONDITION: {similar_col} must contain all data from {ghost_col}
# PRE-CONDITION: all code writing to {ghost_col} must already be offline

def upgrade() -> None:
    # Use batch_alter_table for SQLite compatibility (works on all SQLite versions)
    with op.batch_alter_table('{table}') as batch_op:
        batch_op.drop_column('{ghost_col}')

def downgrade() -> None:
    # Re-add column if rollback needed (data will be empty after rollback)
    with op.batch_alter_table('{table}') as batch_op:
        batch_op.add_column(sa.Column('{ghost_col}', {ghost_col_sa_type}, nullable=True))
    # After rollback, manually restore data if needed:
    # UPDATE {table} SET {ghost_col} = {similar_col}
```

> `{ghost_col_sa_type}` is derived from the actual remote column type collected above (e.g., `sa.Numeric(precision=8, scale=4)` for `NUMERIC(8,4)`, `sa.String(100)` for `VARCHAR(100)`, `sa.Integer()` for `INTEGER`).

**Post-DROP verification** — run after migration to confirm API data is intact:

```bash
ssh {server_user}@{server_host} << 'POSTCHECK'
cd {deploy_path}/{backend_dir}
source venv/bin/activate 2>/dev/null || true
{python_path} -c "
import sqlite3
conn = sqlite3.connect('{db_path}')
# Confirm the column the API reads ({similar_col}) still has data
nonnull = conn.execute('SELECT COUNT(*) FROM \"{table}\" WHERE \"{similar_col}\" IS NOT NULL').fetchone()[0]
total = conn.execute('SELECT COUNT(*) FROM \"{table}\"').fetchone()[0]
print(f'{similar_col}: {nonnull}/{total} rows non-null')
# Confirm ghost column is gone
cols = [r[1] for r in conn.execute('PRAGMA table_info(\"{table}\")').fetchall()]
print(f'Ghost column removed: {ghost_col not in cols}')
conn.close()
"
POSTCHECK
```

If user selects B or C, output a warning block in the deployment plan:

```
⚠️  Ghost column {ghost_col} NOT cleaned up.
    Required before next release:
    1. Verify data: SELECT COUNT(*) FROM {table} WHERE {ghost_col} IS NOT NULL AND {similar_col} IS NULL
    2. Migrate if needed: UPDATE {table} SET {similar_col} = {ghost_col} WHERE {similar_col} IS NULL
    3. Confirm no code writes to {ghost_col}
    4. Run cloud-release again to generate and apply DROP migration
```
```

If no new changes exist, output: **"No new schema changes to sync. Remote database is up to date."**

## Step 6: Deployment Execution Plan

Generate the deployment plan document.

For the detected deployment target, read and follow `targets/<target>.md`.

### 6.1: Decision point D2

If the target recommendation from Step 1 was not confirmed, present options:

**[PLATFORM:INTERACT]**
question: Which deployment method should be used?
options:
  A) {recommended_method} (recommended)
  B) {alternative_1}
  C) {alternative_2}
recommendation: A
**[/PLATFORM:INTERACT]**

### 6.2: Generate deployment plan

Use `templates/deployment-plan.md` as the base template. Fill in:
- Project info from detection results
- Deployment steps from `targets/<detected>.md`
- Migration steps from Step 5
- Verification steps from `targets/<detected>.md` and config

### 6.3: Output deployment plan

Write the deployment plan to the configured output path (default: `releases/<date>/DEPLOYMENT_PLAN.md`).

## Step 7: Execute Deployment (Optional)

Before asking, summarize the deployment plan in one line (e.g., "3 steps: rsync backend, restart service, verify API").

Then present the three options with their trade-offs clearly stated:

**[PLATFORM:INTERACT]**
question: 部署计划已生成。你想如何执行？
context: |
  说明每个选项的优势与风险，让用户做出知情选择：

  **选项 1 — 生成命令，我手动执行**
  ✅ 优势：你完全掌控每一步，可以随时暂停或跳过
  ⚠️ 风险：需要你熟悉命令行；执行顺序出错可能导致部署失败
  适合：熟悉服务器操作、希望逐行审查命令的用户

  **选项 2 — 工具自动执行，每步确认后继续（推荐）**
  ✅ 优势：工具处理执行细节，你只需在每步前确认；出错立即停止并报告
  ⚠️ 风险：需要 SSH 已配置；每步仍需你点确认，不能完全离开
  适合：大多数用户，尤其是不熟悉代码但希望保持掌控感的用户

  **选项 3 — 全自动执行，无需逐步确认**
  ✅ 优势：最快，适合已验证过多次的标准部署流程
  ⚠️ 风险：中途出错不会暂停等待确认；需要你信任整个部署脚本
  适合：已多次成功部署、对流程非常熟悉的用户

options:
  A) 生成命令，我手动执行
  B) 工具自动执行，每步确认（推荐）
  C) 全自动执行，无需逐步确认
recommendation: B
**[/PLATFORM:INTERACT]**

If A: Output the deployment script path and each command in a copyable block. Stop and wait for user to report results.
If B: Follow `targets/<detected>.md` → `Deployment Steps Template` section. Before each step, show what will be executed and wait for explicit confirmation. On any failure, stop immediately and report the error with rollback instructions.
If C: Follow `targets/<detected>.md` → `Deployment Steps Template` section. Execute all steps sequentially. On any failure, stop and report with rollback instructions.

## Step 8: Post-Deployment Verification

### 8.1: Run verification checklist

For the detected target, follow `targets/<detected>.md` → `Post-Deployment Verification` section.

### 8.2: Write release state file

After successful deployment, write `.cloudrelease-state.json` to the project root to persist what was synced. This enables accurate incremental detection in future releases:

```bash
python3 -c "
import json, os

state_file = '{state_file}'  # default: .cloudrelease-state.json

state = {
    'last_release': '$(date +%Y-%m-%d)',
    'last_commit': '$(git rev-parse --short HEAD)',
    'remote_alembic_version': '{remote_alembic_version}',
    'remote_tables': {remote_tables_json},
    'remote_columns': {remote_columns_json},
    'synced_migrations': {synced_migrations_json}
}

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
"
```

Add `.cloudrelease-state.json` to `.gitignore` if it contains environment-specific data.

### 8.3: Generate release report

Use `templates/release-report.md` as the base template. Fill in:
- All results from previous phases
- Known issues
- Improvement suggestions

Write to the configured output path (default: `releases/<date>/RELEASE_REPORT.md`).

### 8.4: Frontend page review (automatic)

> Only run this step if the project has a frontend component (detected in Step 1) and a `frontend_url` is available.

**Get the frontend URL:**
1. Check `.cloudrelease.yml` for `frontend_url` field
2. If not configured, check `targets/<target>.md` for a derived URL pattern (e.g., `https://{project_name}.pages.dev`)
3. If still unavailable, output: "⚠️ Frontend review skipped — set `frontend_url` in `.cloudrelease.yml` to enable automatic post-deploy page checks." and skip this step.

**Run the review using `/browse`:**

Use `/browse` to visit the frontend URL and check for visual or functional issues. Check the following pages (use `frontend_review_pages` from config if set, otherwise check the root URL and any top-level nav links visible on the homepage):

For each page checked:
1. Take a screenshot and inspect the rendered output
2. Check browser console for JavaScript errors
3. Check for: broken layouts, missing data, loading spinners that never resolve, 404 errors, blank sections where content is expected, and any visible error messages

**If no issues found:**

```
✅ Frontend review passed
   Pages checked: {pages_checked}
   No visual errors, console errors, or broken layouts detected.
```

**If issues found — self-review and fix loop:**

For each issue detected:

1. Identify the root cause: is it a frontend code bug, a missing asset, a failed API call, or a data issue?
2. If it is a **frontend code bug** (JS error, broken component, CSS layout issue, missing import):
   - Locate the relevant source file
   - Apply the fix
   - Re-run the frontend build step from Step 4
   - Re-deploy the frontend only (follow `targets/<target>.md` → frontend-only redeploy path)
   - Re-check the affected page with `/browse` to confirm the fix
3. If it is a **backend/API issue** (API returning errors, wrong data format, missing endpoint):
   - Do NOT auto-fix. Output:
     ```
     ⛔ Backend issue detected — requires manual investigation
     Symptom: {what the user sees}
     Likely cause: {API endpoint or data issue}
     Suggested fix: {specific next step}
     ```
4. If the fix attempt fails after one retry, stop and report:
   ```
   ⛔ Frontend review found issues that could not be auto-fixed
   Issue: {description}
   Attempted fix: {what was tried}
   Next step: {manual action required}
   ```

**Maximum fix iterations: 2** — if the page still has issues after 2 fix-and-redeploy cycles, stop and report `DONE_WITH_CONCERNS` with the outstanding issues listed.

## Completion Status

Output one of:

| Status | Meaning |
|--------|---------|
| **DONE** | Deployment succeeded, all verifications passed |
| **DONE_WITH_CONCERNS** | Deployment succeeded but with non-critical issues |
| **BLOCKED** | P0 security issues prevent deployment |
| **NEEDS_CONTEXT** | Missing required information (server address, credentials, etc.) |

## Module Reference

The following module files are loaded on demand based on detection results:

| Module | When loaded |
|--------|------------|
| `platforms/<platform>.md` | Step 0: Platform detection |
| `stacks/<stack>.md` | Step 1: Stack detection → Steps 4-5: Build/Migration |
| `targets/recommendation.md` | Step 1: Target recommendation |
| `targets/<target>.md` | Steps 6-7: Deployment planning and execution |
| `templates/deployment-plan.md` | Step 6: Deployment plan generation |
| `templates/release-report.md` | Step 8: Release report generation |

## Key Principles

- **Zero config by default** — auto-detect everything possible
- **Security first** — P0 issues block deployment
- **Incremental validation** — verify after each phase
- **Rollback ready** — always have a rollback plan before deploying
- **No hardcoded values** — all project-specific info from detection or config
- **Platform agnostic** — core logic works on Claude Code and Codex
