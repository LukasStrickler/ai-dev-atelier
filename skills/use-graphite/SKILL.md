---
name: use-graphite
description: "Manage stacked PRs with Graphite CLI. Auto-detects Graphite repos and blocks conflicting git commands. Use when: (1) Creating branches in Graphite repos, (2) Pushing changes, (3) Creating PRs, (4) Working with stacked PRs, (5) Large AI-generated changes that need splitting. Triggers: gt commands, stacked PRs, branch creation, PR submission in Graphite-enabled repos."
---

# Use Graphite - Stacked PRs

Graphite enables stacked PRs - chains of dependent PRs that build on each other.
Essential for large changes that would be overwhelming as single PRs.

## Quick Start

**First, check if Graphite is active:**

```bash
bash skills/use-graphite/scripts/graphite-detect.sh
```

- `enabled: true` → Use `gt` commands for branch/PR operations
- `enabled: false` → Use standard `git`/`gh`, this skill does not apply

## Core Workflow

### Single PR

```bash
gt create my-feature           # Create branch
# make changes, run tests
git add . && git commit -m "feat: add feature"
gt submit                       # Push and create PR (CI runs here)
```

### Stacked PRs (Large Changes)

```bash
gt create step-1-schema
# make schema changes, TEST LOCALLY
git add . && git commit -m "feat(db): add schema"

gt create step-2-api            # Branch ON TOP of step-1
# make API changes, TEST LOCALLY
git add . && git commit -m "feat(api): add endpoints"

gt create step-3-ui             # Branch ON TOP of step-2
# make UI changes, TEST LOCALLY
git add . && git commit -m "feat(ui): add panel"

gt submit --stack               # Submit entire stack
```

## CRITICAL: CI Must Pass

**Before running `gt submit`:**

1. Run tests locally: `npm test` / `pnpm test` / `cargo test`
2. Run type checks: `npm run typecheck` / `tsc --noEmit`
3. Run linting: `npm run lint`
4. Ensure build passes: `npm run build`

```text
WRONG workflow:
1. gt create feature
2. Make changes
3. gt submit → CI fails
4. Fix → gt submit → CI fails again
5. Repeat 5 times...
Result: 5 failed CI runs, wasted time

CORRECT workflow:
1. gt create feature
2. Make changes
3. Run tests/lint/build LOCALLY
4. Fix issues until green
5. gt submit → CI passes
Result: 1 clean submission
```

**Rule:** If local tests fail, you're not ready to submit. Fix first.

## When to Stack

| Scenario | Recommendation |
|----------|----------------|
| Bug fix (< 100 lines) | Single PR |
| Feature (200-500 lines) | 2-3 stacked PRs |
| Large feature (500+ lines) | Always stack |
| Refactor + feature | Stack: refactor first |
| DB migration + code | Stack: migration first |

## DO: Best Practices

| Practice | Why |
|----------|-----|
| **Test before submit** | CI failures waste everyone's time |
| **1 logical change per PR** | Easy to review, easy to revert |
| **Stack by dependency** | schema → API → UI, not random splits |
| **Keep stacks shallow (3-5 PRs)** | Deep stacks are hard to manage |
| **Sync daily** (`gt sync`) | Avoid painful merge conflicts |
| **Use `gt modify -c`** | Not `git commit --amend` in tracked branches |

## DON'T: Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| **Submit without testing** | CI fails, blocks review | Always run tests locally first |
| **Split randomly** | PRs don't make sense alone | Split by logical dependency |
| **10-PR stacks** | Unmergeable, conflicts pile up | Max 3-5 PRs, start new stack |
| **Never sync** | Conflicts grow over time | `gt sync` daily |
| **Use git rebase** | Breaks Graphite tracking | Use `gt restack` instead |
| **Use git push** | Bypasses stack management | Use `gt submit` |
| **Tiny PRs for simple features** | Overhead without benefit | Single PR for <100 lines |

## Command Translation

| Instead of (blocked) | Use (Graphite) |
|---------------------|----------------|
| `git checkout -b feature` | `gt create feature` |
| `git push` | `gt submit` |
| `gh pr create` | `gt submit` |
| `git rebase main` | `gt restack` |
| `git commit --amend` | `gt modify -c` |

## What Graphite Does NOT Replace

Keep using these normally:
- `git add`, `git commit` - staging and committing
- `git status`, `git log`, `git diff` - inspection
- `git stash`, `git checkout <branch>` - switching, stashing

## Updating a Stack

After review feedback on an earlier PR:

```bash
gt checkout step-1-schema
# make changes, TEST LOCALLY
git add . && git commit -m "fix: address review feedback"
gt restack                      # Update dependent branches
gt submit --stack               # Push entire stack
```

## Emergency Fallback

If `gt` commands fail (auth expired, service down), save your work:

```bash
git add .
git commit -m "wip: saving progress"
git push origin HEAD  # BYPASS_GRAPHITE: gt service unavailable
```

The `# BYPASS_GRAPHITE: <reason>` comment is required to bypass the hook.

## Scripts

| Script | Purpose |
|--------|---------|
| `graphite-detect.sh` | Check if Graphite is active |
| `graphite-block-hook.sh` | PreToolUse hook (blocks conflicting commands) |

## Integration

| When | Related Skill | Action |
|------|---------------|--------|
| Before submit | `code-quality` | Run checks, ensure CI will pass |
| After changes | `git-commit` | Commit with proper message |
| Before PR | `code-review` | Review your changes |

## References

- `references/graphite-workflow.md` - Detailed examples
- [Graphite Docs](https://graphite.dev/docs/cli-overview)

## Output

Branches and PRs managed via Graphite CLI. View stack: `gt log short`.
