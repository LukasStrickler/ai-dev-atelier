#!/bin/bash
# PreCompact hook: Ensures skill reminder persists through compaction
# Applies to main agent AND subagents
#
# Input: JSON via stdin (Claude Code / oh-my-opencode format)
# Output: Plain stdout added to compaction context (exit 0)
#
# This hook re-injects the skill reminder before context is compacted,
# ensuring the agent remembers to check skills even after summarization.

set -euo pipefail

cat <<'EOF'
<skill-reminder>
## MANDATORY: Skill Check Protocol

**BEFORE STARTING ANY WORK**, verify if a skill applies to your task.

### The 1% Rule
If there is even a 1% chance a skill might be relevant, you MUST:
1. Load the skill using the skill tool.
2. Read the instructions completely.
3. Follow the mandated workflow exactly.

### Anti-Rationalization
Do NOT skip this check. The following thoughts are RED FLAGS:
- "This is a simple task" → Simple tasks are where errors hide.
- "I already know how to do this" → Skills contain project-specific requirements you do not know.
- "I will check skills later" → Check BEFORE starting, not after.

**CRITICAL**: Proceeding without loading a relevant skill is a violation of operational protocol.
</skill-reminder>
EOF

exit 0
