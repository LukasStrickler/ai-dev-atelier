# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-14
**Context:** Multi-Agent PR Comment Resolver Skill

## OVERVIEW
Multi-agent system for clustering and resolving bot review comments (CodeRabbit, Copilot) via parallel subagents.

## WHERE TO LOOK
| Component | File/Path | Purpose |
|-----------|-----------|---------|
| **Entry Point** | `scripts/pr-resolver.sh` | Fetches, clusters, and deduplicates comments |
| **Fix Logic** | `scripts/pr-resolver-resolve.sh` | Applies fixes and marks threads resolved |
| **Dismiss Logic** | `scripts/pr-resolver-dismiss.sh` | Handles false positives with explanation |
| **Investigation** | `references/investigation-guide.md` | Decision trees for deferred items |
| **Orchestration** | `SKILL.md` | Defines the `background_task` workflow |

## CONVENTIONS
- **Actionable First**: Agents MUST read `.ada/data/pr-resolver/pr-{N}/actionable.json` (optimized) instead of `data.json` or raw API.
- **Parallelism**: Use `background_task` to fire subagents per cluster. NEVER use blocking `task()`.
- **Agent Identity**: Subagents must be spawned with `agent: "pr-comment-reviewer"` exactly.
- **State Management**: Always re-run `pr-resolver.sh` to verify state before marking task complete.

## ANTI-PATTERNS
- **Raw GH Calls**: NEVER run `gh api` or `gh pr view` for comments. It wastes 10-50x tokens. Use `pr-resolver.sh`.
- **Blocking Loops**: NEVER loop with `task()`; it serializes execution. Fire all clusters with `background_task`.
- **Blind Escalation**: NEVER escalate "low confidence" items without running investigation steps (grep, lsp) first.
- **Context Bloat**: NEVER read the full `data.json` into context; it contains history you don't need.
