---
name: resolve-pr-comments
description: "Resolve bot review comments (CodeRabbit, Copilot, Gemini) on GitHub PRs using subagents. Use when: (1) User asks to 'review PR comments' or 'resolve PR comments', (2) User says 'work through PR N comments' or 'handle bot comments', (3) Need to triage CodeRabbit/Copilot/Gemini review comments, (4) Processing PR feedback at scale, (5) Want to see what's already fixed vs still pending. NOT for: creating PRs, reviewing code yourself, writing new reviews. Triggers: review PR comments, resolve PR comments, work through PR comments, handle bot comments, process CodeRabbit comments, triage PR feedback, fix PR review issues, resolve bot comments, pr comment resolver."
metadata:
  author: ai-dev-atelier
  version: "1.0"
---

# PR Comment Resolver

Multi-agent system for fetching, clustering, and resolving PR review comments at scale.

---

## ⛔⛔⛔ FORBIDDEN: gh cli / gh api for PR comments ⛔⛔⛔

**DO NOT USE `gh` commands to fetch PR comment data. EVER.**

```bash
# ❌ FORBIDDEN - NEVER run these commands
gh pr view <N> --json ...
gh api repos/.../pulls/<N>/comments
gh api repos/.../pulls/<N>/reviews
gh api graphql -f query='...'  # for PR data
```

**Why this is forbidden:**
| Method | Tokens | Quality |
|--------|--------|---------|
| `gh api` / `gh pr view` | 10,000-50,000 | Raw, unprocessed, duplicates |
| `pr-resolver.sh` script | 500-2,000 | Clustered, deduplicated, actionable |

The script already fetches everything. Manual `gh` calls waste 10-50x tokens on garbage data.

---

**✅ CORRECT: Run this script FIRST**

```bash
bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER>
```

**Then:**
1. Read `.ada/data/pr-resolver/pr-<N>/actionable.json`
2. Spawn subagents per cluster

---

## Architecture Overview

```
Orchestrator (You)
    │
    ├── pr-resolver.sh ──> data.json + actionable.json + clusters/*.md
    │
    ├── task(subagent_type: "pr-comment-reviewer") per cluster
    │       │
    │       ├── Validates comments against actual code
    │       ├── Applies minimal fixes (VALID_FIX)
    │       ├── Dismisses false positives (FALSE_POSITIVE)
    │       ├── Defers risky/unclear items (VALID_DEFER)
    │       └── Returns JSON output with actions taken
    │
    └── Handle deferred items (escalate or investigate)
```

## Quick Start

> **⚠️ WAIT BY DEFAULT**: The script waits for CI and AI reviews (max 10 min total) before clustering. **DO NOT use `--skip-wait` unless explicitly requested** or CI confirmed passed.
>
> **⏱️ TIMEOUT**: OpenCode default is 2 min. **Pass `timeout: 660000` (11 min)** to prevent early termination. On timeout, script outputs commands to check status - follow those to decide next steps.

```typescript
// 1. Fetch and cluster comments (waits for CI + AI reviews)
bash({
  command: "bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER>",
  timeout: 660000,
  description: "Fetch and cluster PR comments"
})

// Skip wait only when explicitly asked
bash({
  command: "bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER> --skip-wait \"<reason>\"",
  description: "Fetch PR comments (skip wait)"
})
```

**Output**: `.ada/data/pr-resolver/pr-<N>/`
- `data.json` — Full data, all clusters
- `actionable.json` — Token-efficient, actionable clusters only
- `clusters/` — Markdown files for subagent consumption


```typescript
// 2. Fire subagents for each actionable cluster (non-blocking, returns immediately)
background_task({ agent: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/data/pr-resolver/pr-7/clusters/agents-md-suggestion.md", description: "PR #7: agents-md" })
background_task({ agent: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/data/pr-resolver/pr-7/clusters/install-sh-issue.md", description: "PR #7: install-sh" })
// ... spawn all clusters immediately, then collect results as they complete with background_output(task_id)
```


```bash
# 3. After all subagents complete, verify
bash skills/resolve-pr-comments/scripts/pr-resolver.sh 7
# Success: actionable_clusters should be 0
```


## Output Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `data.json` | Full cluster data including resolved comments | Historical context, debugging |
| `actionable.json` | Token-efficient, only actionable clusters | **Primary orchestration input** |
| `clusters/*.md` | Individual cluster files with full context | Subagent input |

### actionable.json Structure

```json
{
  "pr_number": 7,
  "repository": "owner/repo",
  "generated_at": "2025-01-07T09:00:00Z",
  "statistics": {
    "total_comments": 10,
    "resolved_comments": 3,
    "unresolved_comments": 7,
    "actionable_clusters": 4
  },
  "clusters": [
    {
      "cluster_id": "agents-md-suggestion",
      "file": "AGENTS.md",
      "concern": "suggestion",
      "total_comments": 3,
      "resolved_count": 1,
      "unresolved_count": 2,
      "actionable": true,
      "comments": [...]
    }
  ]
}
```

## Complete Orchestration Workflow

### Phase 1: Fetch and Analyze

```bash
bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER>
```

Read `actionable.json` to understand workload:
- How many actionable clusters?
- What concern types? (security requires special handling)
- Which files are affected?

**Decision Point**: If `actionable_clusters: 0`, you're done.

### Phase 2: Spawn Subagents

⛔ **DO NOT use `task()` in this skill** - it blocks until ALL calls complete, one slow subagent blocks everything.

Use `background_task` for async execution. Fire all, collect as they complete.

**Parallel Execution**: Fire all subagents immediately. They operate on separate files.

**Serial Execution**: If multiple clusters affect the same file, wait for earlier task to complete before spawning next.

**CRITICAL**: The agent name MUST be exactly `"pr-comment-reviewer"`. No variations.

```typescript
// Fire ALL clusters immediately (non-blocking, returns task_id)
background_task({ agent: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/.../cluster-1.md", description: "Cluster 1" })
background_task({ agent: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/.../cluster-2.md", description: "Cluster 2" })
background_task({ agent: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/.../cluster-3.md", description: "Cluster 3" })
// ... all return task_ids immediately

// Collect results as they complete (system notifies on completion)
background_output({ task_id: "..." })  // Get result for specific task
```

**Characteristics:**
- Returns task_id immediately (non-blocking)
- Subagent runs in isolated sub-session
- Collect results with `background_output(task_id)`
- System notifies when each task completes
- Must explicitly tell subagent to read the file (no auto-injection)

**Smart Scheduling**: When a task completes, check if any blocked tasks can now start (e.g., same-file clusters waiting for earlier cluster to finish). Start unblocked tasks immediately rather than waiting for all results.

**Common Errors:**

| Error | Cause | Fix |
|-------|-------|-----|
| Agent not found | Typo in agent name | Use exactly `"pr-comment-reviewer"` |
| Empty result | Subagent didn't read file | Include "Read the cluster file at: {path}" in prompt |

### Phase 3: Collect Results

Each subagent returns output in two formats:

1. **Markdown Summary** (human-readable)
2. **JSON Output** (for orchestrator parsing)

The JSON output includes:

```json
{
  "cluster_id": "agents-md-suggestion",
  "summary": {
    "fixed": 2,
    "dismissed": 1,
    "deferred": 1
  },
  "actions": [
    {
      "comment_id": "123456",
      "classification": "VALID_FIX",
      "confidence": 95,
      "action": "FIXED",
      "reason": "Updated import path",
      "script_executed": "pr-resolver-resolve.sh 7 123456",
      "script_result": "SUCCESS",
      "thread_resolved": true
    }
  ],
  "deferred_items": [
    {
      "comment_id": "345678",
      "reason": "Security concern requires human review",
      "context": "..."
    }
  ]
}
```

**Critical Fields**:
- `script_executed`: Actual command run (null for deferred)
- `script_result`: "SUCCESS" or error message
- `thread_resolved`: Whether GitHub thread is now resolved

### Phase 4: Handle Deferred Items

Subagents defer items they cannot safely resolve. **Before escalating to human, attempt self-investigation.**

#### Triage Deferred Items

Parse each deferred item's reason and classify investigability:

| Defer Reason | Self-Investigable? | Action |
|--------------|-------------------|--------|
| **Low confidence (50-69)** | YES | Investigate with more context |
| **Conflicting evidence** | YES | Gather more evidence, break tie |
| **Complex refactor** | MAYBE | Assess scope first |
| **Security concern** | **YES - Research First** | Research vulnerability type, check if it applies, look up mitigations. Only escalate if fix is unclear after thorough research |
| **Unclear requirement** | YES | Search codebase for patterns, check docs, understand intent |

**Autonomy Principle**: Exhaust all research options before escalating. You have tools - use them.

#### Self-Investigation Workflow

For each investigable deferred item:

1. **READ** the deferred_item context from subagent output
   - What did the subagent check?
   - Why was confidence low?

2. **READ** the file at the mentioned location (±30 lines context)
   - Understand the full function/component, not just the line

3. **GATHER** additional evidence
   - `grep`: Search for patterns the subagent might have missed
   - `lsp_find_references`: Check how the code is used
   - `lsp_hover`: Understand types and signatures
   - `read`: Check related files (imports, callers)

4. **CHECK** resolved comments in same cluster
   - What patterns were already validated/dismissed?

5. **SEARCH** codebase for similar patterns
   - How is this pattern handled elsewhere?

See [Investigation Guide](references/investigation-guide.md) for detailed examples and decision trees.

#### Post-Investigation Decision

| New Confidence | Action |
|----------------|--------|
| **≥70** | Apply fix or dismiss with evidence |
| **50-69** | Document findings, escalate with notes |
| **<50** | Escalate immediately |

**If you resolved it yourself, execute the scripts:**

```bash
# After fixing
bash skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh <PR> <COMMENT_ID>

# After dismissing with evidence
bash skills/resolve-pr-comments/scripts/pr-resolver-dismiss.sh <PR> <COMMENT_ID> "reason with evidence"
```

#### Escalation Format

When escalating to human, provide full context:

```markdown
## Deferred Items Requiring Human Review

### 1. Comment {ID} - {file}:{line}

**Original Comment**: {bot's comment}
**Subagent Reason**: {why deferred}
**Subagent Confidence**: {N}%

**My Investigation**:
{what you checked and found}

**Why I'm Escalating**:
{specific uncertainty}

**Options I See**:
1. {option A} - {implications}
2. {option B} - {implications}

**My Recommendation**: {if you have one}
```

### Phase 5: Verification

After all subagents complete and deferred items are handled:

```bash
bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER>
```

**Success Criteria**: `actionable_clusters: 0`

If actionable clusters remain:
- Check which threads weren't resolved
- Investigate why (subagent errors, script failures)
- Retry or handle manually

## Subagent Output Contract

The `@pr-comment-reviewer` subagent (defined in `agents/pr-comment-reviewer.md`) returns:

### Classification Types

| Classification | Meaning | Thread Status |
|----------------|---------|---------------|
| `VALID_FIX` | Issue was real, fix applied | RESOLVED |
| `FALSE_POSITIVE` | Bot was wrong | DISMISSED |
| `ALREADY_FIXED` | Fixed elsewhere | DISMISSED |
| `STYLE_CHOICE` | Preference, not bug | DISMISSED |
| `VALID_DEFER` | Real issue, too risky | OPEN |
| `UNCLEAR` | Cannot determine | OPEN |

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `pr-resolver.sh <PR>` | Fetch + cluster + generate outputs | Main entry point (waits for CI by default) |
| `pr-resolver.sh <PR> --skip-wait "reason"` | Skip CI/review wait | When CI already passed |
| `pr-resolver-resolve.sh <PR> <ID> [ID2...]` | Resolve thread(s) after fixing | Post-fix cleanup |
| `pr-resolver-dismiss.sh <PR> <ID> "reason"` | Dismiss with reply | False positive handling |

### Fork/Upstream Support

When working with PRs from forks to upstream repos, use `--repo` to specify the upstream:

```bash
# Fetch PR comments from upstream repo (when in a fork)
bash skills/resolve-pr-comments/scripts/pr-resolver.sh 123 --repo upstream-owner/repo

# Resolve/dismiss also support --repo
bash skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh 123 456789 --repo upstream-owner/repo
```

Auto-detection: If you're in a fork, the scripts automatically detect the upstream and use it. The `--repo` flag overrides this for explicit control.

## Concern Categories

Comments are auto-categorized by content:

| Category | Trigger Keywords | Auto-Fix Risk |
|----------|------------------|---------------|
| `security` | security, vulnerability, injection, xss, csrf | **Research deeply** - understand the vulnerability, verify it applies, fix if confident |
| `issue` | bug, error, fail, incorrect, broken | Careful |
| `import-fix` | import, export, require, module | Safe |
| `markdown-lint` | markdown, md0XX, fenced, code block | Safe |
| `doc-fix` | doc link, documentation, readme | Careful |
| `suggestion` | consider, should, might, could, suggest | Careful |
| `uncategorized` | Everything else | Research first, then decide |

## When to Escalate to Human

| Scenario | Escalation Required |
|----------|---------------------|
| Security concern **after thorough research** still unclear | YES |
| Breaking API changes | YES |
| Performance implications unclear after benchmarking/analysis | YES |
| Multiple valid interpretations | YES (ask for preference) |
| Subagent failed 2+ times on same item | YES |

**Key Principle**: Research first, escalate only when truly uncertain after exhausting your tools.

## Anti-Patterns

### ⛔ FORBIDDEN (Blocking Subagents)

```typescript
// ❌ FORBIDDEN - task() blocks until ALL complete, one slow subagent blocks everything
task({ subagent_type: "pr-comment-reviewer", ... })

// ✅ CORRECT - background_task returns immediately, collect results as they complete
background_task({ agent: "pr-comment-reviewer", ... })
```

### ⛔ FORBIDDEN (Context Bloat)

These commands are **NEVER** allowed when using this skill:

```bash
# ❌ FORBIDDEN - bloats context with raw unprocessed data
gh pr view <N> --json ...
gh api repos/.../pulls/<N>/comments
gh api repos/.../pulls/<N>/reviews
gh api graphql -f query='...' # for PR comments

# ✅ CORRECT - run this instead
bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER>
```

### Other Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Use `task()` to spawn subagents | Use `background_task()` for non-blocking execution |
| Process clusters without reading actionable.json first | Start with actionable.json to understand scope |
| Skip deferred items | Handle each deferred item explicitly |
| Defer without researching first | Research thoroughly (docs, codebase, web), then decide |
| Ignore subagent verification failures | Investigate why verification failed |
| Run multiple subagents on same file simultaneously | Serialize per-file to avoid conflicts |
| Mark complete without refreshing | Always run pr-resolver.sh again to verify |
| Ask humans for things you can look up | Use your tools - search, read, grep before escalating |

**Context Efficiency Rule**: The script produces `actionable.json` specifically to minimize token usage. Raw `gh api` output is ~10-50x larger than the processed output. Never fetch what the script already fetches.

## Integration with Other Skills

| Skill | Integration |
|-------|-------------|
| `docs-check` | Run after code fixes to check doc impact |
| `docs-write` | Use when docs need updating |
| `git-commit` | Commit resolved changes with proper format |
| `code-review` | Run before pushing to catch regressions |

## References

- [Investigation Guide](references/investigation-guide.md) - Detailed workflow for investigating deferred items
- [Documentation Guide](references/documentation-guide.md) - Documentation standards

## Workflow Checklist

Before marking PR comment resolution complete:

- [ ] Ran `pr-resolver.sh` to fetch current state
- [ ] Read `actionable.json` to understand workload
- [ ] Spawned subagent for each actionable cluster
- [ ] Collected and verified subagent results
- [ ] Handled all deferred items (investigate or escalate)
- [ ] Re-ran `pr-resolver.sh` - confirmed `actionable_clusters: 0`
- [ ] Reported any items escalated to human
