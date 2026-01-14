# Graphite Workflow Examples

Extended examples for common Graphite stacking scenarios.

## Before You Submit

Before any `gt submit`, verify locally by running your project's test, lint, and build commands. Check `package.json`, `Makefile`, `Cargo.toml`, `pyproject.toml`, CI config, or README for the correct commands.

## Basic Stacking Patterns

### Feature with Database Migration

```bash
# Step 1: Database migration (must be reviewed/merged first)
# develop migration, verify locally with your project's test commands
gt create feat-user-preferences-migration
git add . && git commit -m "feat(db): add user_preferences table"

# Step 2: API endpoints (depends on migration)
# develop API, verify locally
gt create feat-user-preferences-api
git add . && git commit -m "feat(api): add user preferences endpoints"

# Step 3: UI (depends on API)
# develop UI, verify locally
gt create feat-user-preferences-ui
git add . && git commit -m "feat(ui): add preferences settings panel"

# Submit entire stack
gt submit --stack
```

### Refactor Before Feature

```bash
# Step 1: Refactor (safe, no behavior change)
# refactor code, verify tests still pass
gt create refactor-auth-utils
git add . && git commit -m "refactor(auth): extract token validation to utils"

# Step 2: Feature (uses refactored code)
# implement feature, verify locally
gt create feat-token-refresh
git add . && git commit -m "feat(auth): add automatic token refresh"

gt submit --stack
```

## Advanced Patterns

### Amending a Commit Mid-Stack

When you need to fix something in an earlier PR:

```bash
# Current stack: step-1 -> step-2 -> step-3 (you're on step-3)

# Go back to the PR that needs fixing
gt checkout step-1

# Make your fix, verify locally
# Amend OR add new commit (both work)
git add . && git commit -m "fix: address review feedback"

# Restack to propagate changes to dependent branches
gt restack

# Submit the entire updated stack
gt submit --stack
```

### Adding a PR in the Middle of a Stack

```bash
# Current: step-1 -> step-3
# Need to add step-2 between them

gt checkout step-1
gt create step-2  # Creates step-2 on top of step-1

# Make changes for step-2, verify locally
git add . && git commit -m "feat: add step 2"

# Rebase step-3 onto step-2
gt checkout step-3
gt restack  # Graphite handles the rebase

gt submit --stack
```

### Splitting a Large PR

If you realize a PR is too big:

```bash
# Current: one big PR with 500+ lines
gt checkout big-feature

# Undo the commit but keep changes
git reset HEAD~1 --soft

# Create smaller, focused PRs
gt create step-1-types
git add src/types/* && git commit -m "feat: add type definitions"

gt create step-2-utils
git add src/utils/* && git commit -m "feat: add utility functions"

gt create step-3-implementation
git add . && git commit -m "feat: implement feature"

gt submit --stack
```

## Team Workflow

### Daily Sync Routine

```bash
# Start of day: sync with remote
gt sync

# If conflicts exist, resolve them
# Then continue work
gt checkout my-feature
```

### When Parent PR is Merged

```bash
# Graphite auto-detects merged parents
gt sync

# Your branch now targets main directly
# Continue working normally
```

### Handling Stale Stacks

```bash
# If your stack is outdated and has conflicts
gt sync              # Fetch latest and attempt auto-rebase
gt restack           # Rebase entire stack
gt submit --stack    # Push updated stack
```

## CI Integration

### Pre-Submit Checklist

Before running `gt submit`, verify locally using your project's test/lint/build commands.

```bash
# Only submit if all checks pass
gt submit --stack
```

### Handling CI Failures

```bash
# If CI fails on step-2 of a 3-PR stack:

# 1. Checkout the failing PR
gt checkout step-2

# 2. Fix the issue locally (reproduce with your test commands)

# 3. Commit the fix
git add . && git commit -m "fix: resolve CI failure"

# 4. Restack to update dependent PRs
gt restack

# 5. Submit the updated stack
gt submit --stack
```

## Command Quick Reference

| Scenario | Command |
|----------|---------|
| Start new stack | `gt create branch-name` |
| Add to stack | `gt create next-branch` (while on current branch) |
| View stack | `gt log short` |
| Switch branches | `gt checkout branch-name` |
| Push single PR | `gt submit` |
| Push entire stack | `gt submit --stack` |
| Sync with remote | `gt sync` |
| Rebase stack | `gt restack` |
| Update commit | `gt modify -c` |
| Track untracked branch | `gt track` |
