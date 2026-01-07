---
name: pr-comment-resolver
description: "Batch-resolve bot review comments (CodeRabbit, Copilot, Gemini) on PRs using AI subagents. Fetches all comments, clusters by file+concern, spawns subagent per cluster to validate/fix/dismiss. Use when: (1) PR has many bot comments to process at once, (2) Want AI to auto-fix valid issues and dismiss false positives, (3) Need to triage CodeRabbit/Copilot/Gemini review comments, (4) Processing PR feedback at scale, (5) Want to see what's already fixed vs still pending. Triggers: resolve bot comments, triage bot review, process CodeRabbit comments, handle Copilot suggestions, batch resolve PR comments, auto-fix review comments, pr comment resolver, resolve all PR comments."
---

# PR Comment Resolver

Multi-agent system for fetching, clustering, and resolving PR review comments at scale.

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

```bash
# 1. Fetch and cluster all comments
bash skills/pr-comment-resolver/scripts/pr-resolver.sh 7

# Output: .ada/data/pr-resolver/pr-7/
#   ├── data.json       (full data, all clusters)
#   ├── actionable.json (token-efficient, actionable clusters only)
#   └── clusters/       (markdown files for subagent consumption)
```

```typescript
// 2. Spawn subagents for each actionable cluster (parallel)
task({ subagent_type: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/data/pr-resolver/pr-7/clusters/agents-md-suggestion.md", description: "PR #7: agents-md" })
task({ subagent_type: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/data/pr-resolver/pr-7/clusters/install-sh-issue.md", description: "PR #7: install-sh" })
```

```bash
# 3. After all subagents complete, verify
bash skills/pr-comment-resolver/scripts/pr-resolver.sh 7
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
bash skills/pr-comment-resolver/scripts/pr-resolver.sh <PR_NUMBER>
```

Read `actionable.json` to understand workload:
- How many actionable clusters?
- What concern types? (security requires special handling)
- Which files are affected?

**Decision Point**: If `actionable_clusters: 0`, you're done.

### Phase 2: Spawn Subagents

For each cluster in `actionable.json`, spawn a subagent using the task tool.

**Parallel Execution**: Spawn multiple subagents concurrently for different clusters. They operate on separate files.

**Serial Execution**: If multiple clusters affect the same file, process them sequentially to avoid conflicts.

**CRITICAL**: The `subagent_type` MUST be exactly `"pr-comment-reviewer"`. No variations.

```typescript
// Single cluster
task({
  subagent_type: "pr-comment-reviewer",
  prompt: "Process PR comment cluster. Read the cluster file at: .ada/data/pr-resolver/pr-7/clusters/agents-md-suggestion.md",
  description: "PR #7: agents-md-suggestion"
})

// Multiple clusters - parallel execution (call multiple task() in same response)
task({ subagent_type: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/.../cluster-1.md", description: "Cluster 1" })
task({ subagent_type: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/.../cluster-2.md", description: "Cluster 2" })
task({ subagent_type: "pr-comment-reviewer", prompt: "Process cluster. Read: .ada/.../cluster-3.md", description: "Cluster 3" })
```

**Characteristics:**
- Runs in background, returns result when complete
- Subagent runs in isolated sub-session
- Enables parallel execution (multiple task() calls in one response)
- Must explicitly tell subagent to read the file (no auto-injection)

**Common Errors:**

| Error | Cause | Fix |
|-------|-------|-----|
| Agent not found | Typo in subagent_type | Use exactly `"pr-comment-reviewer"` |
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
| **Unclear requirement** | NO | Escalate to human |
| **Security concern** | **NEVER** | Escalate immediately |

**Security Rule (ABSOLUTE)**: Never self-investigate security concerns. Always escalate.

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
bash skills/pr-comment-resolver/scripts/pr-resolver-resolve.sh <PR> <COMMENT_ID>

# After dismissing with evidence
bash skills/pr-comment-resolver/scripts/pr-resolver-dismiss.sh <PR> <COMMENT_ID> "reason with evidence"
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
bash skills/pr-comment-resolver/scripts/pr-resolver.sh <PR_NUMBER>
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
| `pr-resolver.sh <PR>` | Fetch + cluster + generate outputs | Main entry point |
| `pr-resolver-resolve.sh <PR> <ID> [ID2...]` | Resolve thread(s) after fixing | Post-fix cleanup |
| `pr-resolver-dismiss.sh <PR> <ID> "reason"` | Dismiss with reply | False positive handling |

## Concern Categories

Comments are auto-categorized by content:

| Category | Trigger Keywords | Auto-Fix Risk |
|----------|------------------|---------------|
| `security` | security, vulnerability, injection, xss, csrf | **NEVER** - Always defer |
| `issue` | bug, error, fail, incorrect, broken | Careful |
| `import-fix` | import, export, require, module | Safe |
| `markdown-lint` | markdown, md0XX, fenced, code block | Safe |
| `doc-fix` | doc link, documentation, readme | Careful |
| `suggestion` | consider, should, might, could, suggest | Careful |
| `uncategorized` | Everything else | **DEFER** |

## When to Escalate to Human

| Scenario | Escalation Required |
|----------|---------------------|
| Any security-related comment | YES - Always |
| Breaking API changes | YES |
| Performance implications unclear | YES |
| Multiple valid interpretations | YES (ask for preference) |
| Subagent failed 2+ times on same item | YES |

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Process clusters without reading actionable.json first | Start with actionable.json to understand scope |
| Skip deferred items | Handle each deferred item explicitly |
| Resolve security comments automatically | Always escalate security to human |
| Ignore subagent verification failures | Investigate why verification failed |
| Run multiple subagents on same file simultaneously | Serialize per-file to avoid conflicts |
| Mark complete without refreshing | Always run pr-resolver.sh again to verify |

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
