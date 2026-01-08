---
name: use-graphite
description: "Manage stacked PRs with Graphite CLI. Auto-detects Graphite repos and blocks conflicting git commands. Use when: (1) Creating branches in Graphite repos, (2) Pushing changes, (3) Creating PRs, (4) Working with stacked PRs, (5) Large AI-generated changes that need splitting. Triggers: gt commands, stacked PRs, branch creation, PR submission in Graphite-enabled repos."
---

# Use Graphite - Stacked PRs

Graphite enables stacked PRs - chains of dependent PRs that build on each other.
This is essential for large AI-generated changes that would be overwhelming as single PRs.

## CRITICAL: First Check If Graphite Is Active

**Before using ANY gt commands, verify Graphite is enabled:**

```bash
bash skills/use-graphite/scripts/graphite-detect.sh
```

**If `enabled: false` or the script fails**: This is NOT a Graphite repo. Use standard git/gh commands instead. Do not attempt gt commands.

**If `enabled: true`**: Proceed with Graphite workflow below.

## Fallback: When Graphite Fails

**IMPORTANT**: If Graphite commands fail, you MUST save your work using standard git. Never lose uncommitted changes.

### Emergency Fallback Procedure

If `gt` commands fail (auth expired, network issues, Graphite service down):

```bash
git add .
git commit -m "wip: saving progress before troubleshooting gt"  # BYPASS_GRAPHITE: emergency save

git push origin HEAD  # BYPASS_GRAPHITE: gt submit failed, pushing directly
```

### Common Failures and Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| `gt: command not found` | CLI not installed | `npm install -g @withgraphite/graphite-cli` or use git |
| `Not authenticated` | Auth expired | `gt auth login` or use git with BYPASS |
| `gt submit` hangs | Network/service issue | Wait, retry, or use `git push # BYPASS_GRAPHITE: service issue` |
| `Branch not tracked` | Created with git, not gt | `gt track` to add to stack, or continue with git |
| `Repo not initialized` | Missing .graphite_repo_config | `gt init` or use standard git workflow |

### When to Abandon Graphite Temporarily

Use BYPASS and standard git when:
- Graphite service is down
- Auth keeps failing after re-login
- Urgent hotfix that can't wait
- Pushing to a fork (Graphite tracks main repo only)

**Always document why**: `# BYPASS_GRAPHITE: <reason>`

## Quick Start

**Before any branch/PR operation, check if Graphite is active:**

```bash
bash skills/use-graphite/scripts/graphite-detect.sh
```

- If `enabled: true` → use `gt` commands instead of `git`/`gh` for branch and PR operations
- If `enabled: false` → use standard `git`/`gh` commands, this skill does not apply

## What is Stacking?

Traditional GitHub flow: Independent PRs, each based on main.

```text
main ─────┬───────┬───────┐
          │       │       │
          └─ PR1  └─ PR2  └─ PR3  (independent)
```

Graphite stacking: Dependent PRs that build on each other.

```text
main ─── PR1 ─── PR2 ─── PR3  (stacked chain)
          │       │       │
          └───────┴───────┘  (each builds on previous)
```

Why stacking matters for AI-generated code:
- AI tends to produce large diffs
- Large diffs are hard to review
- Stacking breaks changes into reviewable chunks
- Each PR can be reviewed and merged independently

## Command Translation

| Instead of this (Git/GitHub) | Use this (Graphite)      |
|-----------------------------|--------------------------|
| `git checkout -b feature`   | `gt create feature`      |
| `git push`                  | `gt submit`              |
| `git push --force`          | `gt submit`              |
| `gh pr create`              | `gt submit`              |
| `git pull --rebase`         | `gt sync`                |
| `git rebase main`           | `gt restack`             |
| `git commit --amend`        | `gt modify -c`           |

These commands are **blocked** when Graphite is active. The hook will suggest
the correct `gt` equivalent.

## What Graphite Does NOT Replace

Keep using these git commands normally:
- `git add`, `git commit` - staging and committing
- `git status`, `git log`, `git diff` - inspection
- `git stash`, `git cherry-pick` - advanced operations
- `git checkout <existing-branch>` - switching branches (without -b)

## Core Workflow

### Single PR (Simple Case)

```bash
gt create my-feature      # Create branch
# make changes
git add . && git commit -m "feat: add feature"
gt submit                  # Push and create PR
```

### Stacked PRs (Large Changes)

```bash
gt create step-1-schema
# make schema changes
git add . && git commit -m "feat(db): add user preferences schema"

gt create step-2-api       # Creates branch ON TOP of step-1
# make API changes
git add . && git commit -m "feat(api): add preferences endpoints"

gt create step-3-ui        # Creates branch ON TOP of step-2
# make UI changes
git add . && git commit -m "feat(ui): add preferences panel"

gt submit --stack          # Submit entire stack as linked PRs
```

Result: 3 linked PRs, each reviewable independently.

### Updating a Stack

After making changes to an earlier PR in the stack:

```bash
gt checkout step-1-schema
# make changes, commit
gt submit                  # Push changes
gt restack                 # Update all dependent branches
gt submit --stack          # Push entire stack
```

### Syncing with Main

```bash
gt sync                    # Fetch and rebase onto latest main
gt restack                 # Update stack if needed
```

## When to Stack

| Scenario                        | Recommendation          |
|---------------------------------|-------------------------|
| Small bug fix (< 100 lines)     | Single PR               |
| Feature 200-500 lines           | Consider 2-3 stacked    |
| Large feature (500+ lines)      | Always stack            |
| AI-generated code               | Always stack            |
| Refactor + feature              | Stack: refactor first   |
| DB migration + code             | Stack: migration first  |

## Stack Best Practices

1. **Each PR independently reviewable** - don't split mid-function
2. **Stack by logical dependency** - schema → API → UI, not by file count
3. **Keep stacks shallow** - 3-5 PRs max, split into separate features if larger
4. **Sync frequently** - `gt sync` daily to avoid conflicts
5. **Use gt modify** - not `git commit --amend` in tracked branches

## Detection Details

Graphite is active when ALL conditions are true:
1. `gt` CLI installed (`command -v gt`)
2. User authenticated (`~/.config/graphite/user_config` has authToken)
3. Repo initialized (`.graphite_repo_config` in git directory)

The detection script handles worktrees correctly.

## Bypass (Emergency Only)

If you must use git directly (e.g., pushing to a fork):

```bash
git push origin fork-remote  # BYPASS_GRAPHITE: pushing to personal fork
```

The `# BYPASS_GRAPHITE: <reason>` comment is required. Without it, the command
is blocked.

## MCP Tools

When the Graphite MCP is available, prefer MCP tools over CLI:

```javascript
// MCP (preferred)
mcp.graphite.create({ branch: 'feature', message: 'Add feature' })
mcp.graphite.submit({ stack: true })

// CLI (fallback)
bash('gt create feature -m "Add feature"')
bash('gt submit --stack')
```

## Integration

| When                    | Related Skill    | Action                        |
|-------------------------|------------------|-------------------------------|
| Before branching        | use-graphite     | Check detection, use gt       |
| After committing        | git-commit       | Use gt modify if amending     |
| Before PR creation      | use-graphite     | Use gt submit, not gh pr      |
| Large code generation   | use-graphite     | Plan stack structure first    |

## Scripts

| Script                   | Purpose                              |
|--------------------------|--------------------------------------|
| `graphite-detect.sh`     | Check if Graphite is active          |
| `graphite-block-hook.sh` | PreToolUse hook (internal)           |

## References

- `references/graphite-workflow.md` - Detailed workflow examples
- [Graphite Documentation](https://graphite.dev/docs/cli-overview)
- [GT MCP Documentation](https://graphite.dev/docs/gt-mcp)

## Output

Branches and PRs managed via Graphite CLI. Stack state visible via `gt log short`.
