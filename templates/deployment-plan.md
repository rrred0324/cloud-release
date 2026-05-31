# Deployment Plan — {project_name}

**Generated**: {timestamp}
**Branch**: {branch}
**Commit**: {commit_hash}
**Stacks detected**: {detected_stacks}
**Deploy target**: {deploy_method}

---

## Pre-Deployment Checklist

- [ ] All tests passed
- [ ] Build successful
- [ ] No P0 security issues
- [ ] Code committed and pushed
- [ ] Database backed up
- [ ] Deployment target accessible
- [ ] Rollback plan reviewed

## Deployment Steps

<!-- Steps are generated dynamically based on detected stacks and target -->
<!-- Each step follows: command → expected output → verification -->

### Step 1: Backup

```bash
# Backup current deployment
```

_Verification_: Backup file exists and has expected size.

### Step 2: Build

```bash
# Build commands from detected stack(s)
```

_Verification_: Build artifacts exist in expected paths.

### Step 3: Database Migration

<!-- Generated from the three-way diff in Step 5 -->
<!-- Only contains changes that actually need to be applied to the remote DB -->

#### Remote Database Current State
- Migration tool version: {remote_migration_version}
- Existing tables: {remote_table_count} ({remote_table_list})
- Last sync: {last_sync_date} (commit {last_sync_commit})

#### Changes to Sync (New)
| Change type | Object | Details | SQL |
|-------------|--------|---------|-----|
| New table | {table} | {column_count} columns | CREATE TABLE ... |
| New column | {table}.{col} | {type} | ALTER TABLE ... |

#### Already Synced (No Action Needed)
| Change type | Object | Synced on |
|-------------|--------|-----------|
| New table | {table} etc. | {date} |
| New column | {table}.{col} | {date} |

#### Manual Review Needed
<!-- e.g., local alembic version mismatch with remote -->

```bash
# Migration commands from detected stack
```

_Verification_: Migration completed without errors; data integrity checks pass.

### Step 4: Deploy

```bash
# Deployment commands from detected target
```

_Verification_: Service/container is running; health check passes.

### Step 5: Post-Deploy Verification

```bash
# Verification commands from detected target
```

_Verification_: All checks pass.

## Rollback Plan

<!-- Generated from targets/<detected>.md rollback section -->

1. Stop current deployment
2. Restore backup
3. Restart previous version
4. Verify rollback

## Post-Deployment Verification Checklist

- [ ] Service/container is running
- [ ] Health check endpoint responds
- [ ] Frontend page loads correctly
- [ ] API endpoints respond
- [ ] Database queries return expected data
- [ ] No errors in logs
- [ ] New features working as expected

## Notes

<!-- Any additional notes specific to this deployment -->