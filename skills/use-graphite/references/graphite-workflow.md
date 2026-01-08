# Graphite Workflow Examples

Detailed examples for common Graphite scenarios.

## Setting Up a New Repository

```bash
npm install -g @withgraphite/graphite-cli
gt auth login
gt repo init --trunk main
```

## Example 1: Simple Feature (No Stacking)

Adding a single small feature.

```bash
gt create add-dark-mode-toggle
git add src/components/Settings.tsx
git commit -m "feat(ui): add dark mode toggle"
gt submit
```

## Example 2: Feature with Refactor (2-Stack)

Refactoring before adding feature ensures clean separation.

```bash
gt create refactor-theme-system
git add src/theme/*
git commit -m "refactor(theme): extract theme provider"
# Don't submit yet - build the stack first

gt create add-dark-mode
git add src/components/Settings.tsx src/hooks/useDarkMode.ts
git commit -m "feat(ui): add dark mode with system preference detection"

gt submit --stack
```

Reviewers see:
- PR 1: Pure refactor, easy to verify nothing broke
- PR 2: New feature, builds on clean foundation

## Example 3: Full-Stack Feature (3-Stack)

Backend → API → Frontend pattern.

```bash
gt create user-preferences-schema
git add prisma/schema.prisma prisma/migrations/*
git commit -m "feat(db): add user preferences table"

gt create user-preferences-api
git add src/api/preferences/*
git commit -m "feat(api): add preferences CRUD endpoints"

gt create user-preferences-ui
git add src/components/Preferences/* src/pages/settings/*
git commit -m "feat(ui): add preferences settings panel"

gt submit --stack
```

Merge order is enforced: schema → API → UI.

## Example 4: Updating Mid-Stack

You get review feedback on PR 2 of a 3-stack.

```bash
gt log short
# Output:
#   main
#   └── user-preferences-schema (PR #123)
#       └── user-preferences-api (PR #124) ← YOU ARE HERE
#           └── user-preferences-ui (PR #125)

gt checkout user-preferences-api
git add src/api/preferences/validation.ts
git commit -m "fix(api): add input validation per review feedback"
gt submit

gt restack
gt submit --stack
```

All PRs are updated, maintaining the dependency chain.

## Example 5: Syncing with Main

Teammate merged changes to main. Update your stack.

```bash
gt sync
# If conflicts:
# 1. Resolve conflicts
# 2. git add <resolved-files>
# 3. git rebase --continue
# 4. gt sync (again if needed)

gt restack
gt submit --stack
```

## Example 6: Splitting a Large Commit

You realize a single commit should have been stacked.

```bash
git reset HEAD~1 --soft
gt create step-1-types
git add src/types/*
git commit -m "feat(types): add new API types"

gt create step-2-implementation
git add src/api/*
git commit -m "feat(api): implement new endpoints"

gt create step-3-tests
git add src/__tests__/*
git commit -m "test(api): add endpoint tests"

gt submit --stack
```

## Example 7: Abandoning Part of a Stack

PR 2 needs major rework, but PR 1 is approved.

```bash
gt log short
#   main
#   └── feature-part-1 (PR #101, approved)
#       └── feature-part-2 (PR #102, needs rework)
#           └── feature-part-3 (PR #103)

gt checkout feature-part-1
gt submit
# Wait for PR #101 to merge

gt sync
gt checkout feature-part-2
gt track --force main
# Now feature-part-2 is based on main, not the merged PR
```

## Example 8: AI-Generated Code Workflow

When AI generates a large changeset:

```bash
gt create ai-refactor-step-1
# AI generates changes to shared utilities
git add src/utils/*
git commit -m "refactor(utils): extract common helpers"

gt create ai-refactor-step-2
# AI generates changes that use the utilities
git add src/services/*
git commit -m "refactor(services): use new helpers"

gt create ai-refactor-step-3
# AI generates updated tests
git add src/__tests__/*
git commit -m "test: update tests for refactored code"

gt submit --stack
```

## Viewing Stack Status

```bash
gt log short
```

Output:
```
  main
  └── feat-schema (merged)
      └── feat-api (#234, approved)
          └── feat-ui (#235, changes requested)
              └── feat-tests (#236, pending review)
```

## Common Issues

### "Branch not tracked by Graphite"

```bash
gt track
gt submit
```

### "Stack is out of sync"

```bash
gt restack
gt submit --stack
```

### "Merge conflict during sync"

```bash
gt sync
# Resolve conflicts manually
git add <resolved-files>
git rebase --continue
gt sync  # Complete the sync
```

### "Need to force push"

Graphite handles force pushes safely:

```bash
gt submit  # Automatically force pushes if needed
```

Never use `git push --force` - it bypasses Graphite's tracking.
