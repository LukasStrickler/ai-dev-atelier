---
name: git-commit
description: "Write clear git commits with Conventional Commits format. Detects project conventions from history and config. Guides commit granularity. Use when: (1) Completing working code, (2) Code builds and tests pass, (3) Ready to save, (4) Before pushing, (5) After review feedback. Triggers: automatically when finishing commitable work that builds and passes tests."
---

# Git Commit

Write clear, atomic commits. Detect and match project conventions first; use
Conventional Commits as fallback. Every commit = one complete, working change.

## Feature Branch Workflow

**Philosophy: Commit early, commit often.**

```text
Feature branch: Create → [Change → Test → COMMIT]* → PR → Merge
```

Why frequent commits matter:

| Benefit              | Description                                     |
| -------------------- | ----------------------------------------------- |
| Easy rollback        | Revert to last working state in seconds         |
| Safety checkpoints   | Never lose more than one small step             |
| Better debugging     | `git bisect` works with granular history        |
| Collaboration        | Others see incremental progress                 |
| Automation           | Enables auto-changelogs and semantic versioning |

**Anti-pattern**: One giant commit at end of feature (47 files, 2800+ lines).
Split into logical increments instead.

## Quick Start

**Pre-Commit Checklist:**

- [ ] Code builds and tests pass
- [ ] ONE logical change (describable in one sentence)
- [ ] Checked project conventions (Step 1)

## Workflow

### Step 1: Detect Conventions (REQUIRED)

```bash
ls .commitlintrc* commitlint.config.* .czrc .cz.json 2>/dev/null
git log --oneline -15
```

| Finding                      | Action                            |
| ---------------------------- | --------------------------------- |
| Config file exists           | Follow those rules exactly        |
| `feat:`, `fix:` pattern      | Use Conventional Commits          |
| `[JIRA-123]` pattern         | Match ticket prefix format        |
| `Component: message` pattern | Match component prefix format     |
| No clear pattern             | Use Conventional Commits (Step 2) |

### Step 2: Format Message

```text
<type>(<scope>)!: <subject>     ← 50 chars ideal, 72 max
                                ← blank line
<body>                          ← wrap at 72 chars, optional
                                ← blank line
<footer>                        ← optional (Closes #123, BREAKING CHANGE)
```

**Subject rules:** Imperative mood (`add` not `added`), lowercase after colon,
no trailing period, no filler words.

**Types:**

| Type       | Purpose                 | SemVer | Example                      |
| ---------- | ----------------------- | ------ | ---------------------------- |
| `feat`     | New feature             | MINOR  | `feat(auth): add OAuth`      |
| `fix`      | Bug fix                 | PATCH  | `fix(cart): prevent neg qty` |
| `docs`     | Documentation           | -      | `docs(api): add examples`    |
| `style`    | Formatting              | -      | `style: fix indentation`     |
| `refactor` | Code restructure        | -      | `refactor: extract helper`   |
| `perf`     | Performance             | -      | `perf(db): add index`        |
| `test`     | Tests                   | -      | `test(auth): add edge cases` |
| `build`    | Build/deps              | -      | `build: update webpack`      |
| `ci`       | CI config               | -      | `ci: add deploy workflow`    |
| `chore`    | Maintenance             | -      | `chore: update gitignore`    |
| `revert`   | Revert previous commit  | -      | `revert: let us not...`      |

**Breaking changes:** Add `!` after type/scope, explain in body/footer.

```text
feat(api)!: require API key for all endpoints

BREAKING CHANGE: Anonymous access removed. All requests need X-API-Key header.
```

### Step 3: Body (When Needed)

| Required                          | Optional                         |
| --------------------------------- | -------------------------------- |
| Breaking change (impact/migrate)  | Self-explanatory from diff       |
| Non-obvious fix (root cause)      | Simple docs/style/chore          |
| Complex feature (design decision) | Tests with descriptive names     |

**Body content:** WHY (motivation), WHAT problem, HOW users affected.
**Not:** Which files (diff shows), line-by-line explanation (code comments).

### Step 4: Footer

```text
Closes #123                              # Issue reference
Fixes #456                               # Also closes issue
Refs: #789                               # Reference without closing
BREAKING CHANGE: <description>           # If not in body
Co-authored-by: Name <email@example.com> # Co-authorship
Reviewed-by: Name                        # Use hyphens in tokens
```

## Commit Granularity

### Atomic Commit = Smallest Complete Change

1. **ONE purpose** - single feature/fix/refactor
2. **Self-contained** - doesn't depend on uncommitted work
3. **Leaves code working** - builds pass, tests pass
4. **Revertable alone** - without breaking other features

### What Goes Together vs Separate

| Together (same commit)       | Separate (different commits)   |
| ---------------------------- | ------------------------------ |
| Feature + its unit tests     | Feature + unrelated formatting |
| Bug fix + regression test    | Bug fix + dependency update    |
| API change + docs update     | Refactor + new feature         |
| Refactor + affected tests    | Multiple unrelated fixes       |

### When to Commit (Triggers)

| Trigger                          | Action                             |
| -------------------------------- | ---------------------------------- |
| Function works and tested        | COMMIT now                         |
| Test passes (red → green)        | COMMIT now                         |
| Bug fixed and verified           | COMMIT before next task            |
| About to refactor                | COMMIT working state first         |
| Starting new sub-task            | COMMIT current progress            |
| End of session / before pull     | COMMIT if working                  |

**Key:** Before starting new task, commit all current task changes.

### When NOT to Commit

| Situation                        | Why                                |
| -------------------------------- | ---------------------------------- |
| Code doesn't build               | Breaks bisect, blocks others       |
| Tests failing*                   | Not a valid checkpoint             |
| "I think this works" (untested)  | Verify first, commit second        |
| Mid-debugging / mid-fix          | Wait until fix is complete         |
| Uncertain about approach         | Prototype first, commit when solid |
| CI still running / red           | Wait for green, then commit fix    |

*_Exception: TDD RED commits (test-only commits that intentionally fail) are valid._

**"Commit often" means verified working increments, not untested guesses.**

```text
❌ BAD: Commit-and-pray workflow
───────────────────────────────
1. Write fix
2. "Looks right to me" → commit
3. Push → CI fails
4. "Oops, forgot X" → commit again
5. Push → CI fails again
6. Repeat 3 more times...
Result: 5 broken commits in history

✓ GOOD: Verify-then-commit workflow
───────────────────────────────
1. Write fix
2. Run tests locally → fails
3. Fix the issue
4. Run tests locally → passes
5. Commit
6. Push → CI passes
Result: 1 clean commit
```

**Rule:** If CI or local tests are red, you're not done. Fix first, verify, then commit.

### TDD Pattern

```bash
test(auth): add failing test for validation  # RED
feat(auth): implement validation             # GREEN
refactor(auth): extract to helper            # REFACTOR
```

## Examples

See `references/examples.md` for comprehensive examples. Quick reference:

```text
# Feature with context
feat(auth): add password strength indicator

Users lacked feedback on password quality during signup.
Add real-time strength meter, requirements checklist, submission block.

Closes #234
```

```text
# Bug fix with root cause
fix(api): handle null response from payment gateway

Gateway returns null on timeout. Add null check with retry logic.

Fixes #567
```

```text
# Simple changes (no body needed)
docs(readme): add Docker installation steps
test(utils): add edge case tests for date parser
chore(deps): update lodash to 4.17.21
```

| Bad           | Problem          | Good                                 |
| ------------- | ---------------- | ------------------------------------ |
| `fix bug`     | No context       | `fix(cart): prevent duplicate items` |
| `update code` | Meaningless      | `refactor(api): simplify errors`     |
| `WIP`         | Incomplete       | Finish work, then commit             |
| `misc fixes`  | Multiple changes | Split into separate commits          |

## Integration

| When              | Skill                      | Why                       |
| ----------------- | -------------------------- | ------------------------- |
| Before committing | `code-quality`             | Ensure checks pass        |
| After committing  | `docs-check`               | Check if docs need update |
| After PR review   | `pr-review` → `git-commit` | Resolve then commit       |

## References

- `references/examples.md` - Extended examples by scenario

## Output

Git commits created via standard git commands. No files saved. Commit history visible via `git log`.
