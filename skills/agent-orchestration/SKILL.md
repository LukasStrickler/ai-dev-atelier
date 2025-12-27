---
name: agent-orchestration
description: Spawn and manage multiple local AI sub-agents (Cursor, Codex, Gemini) in isolated git worktrees. Supports work mode (code changes) and research mode (experiments + answer.md), with fire-and-forget or await execution patterns. Hierarchical agents up to 3 levels deep. Use when: (1) Need to delegate tasks to AI agents, (2) Parallel work on different features, (3) Research tasks requiring web search, (4) Code refactoring or implementation, (5) Documentation updates, (6) Testing agent orchestration systems. Triggers: "spawn agent", "delegate to agent", "agent orchestration", "multi-agent", "sub-agent", "agent work", "agent research".
---

# Agent Orchestration

Spawn and manage multiple local AI sub-agents in isolated git worktrees. Each agent operates independently with its own branch, supporting work mode (code changes) and research mode (experiments + answer.md output), with fire-and-forget or await execution patterns.

## Quick Start

**Purpose:** Delegate tasks to AI agents that operate in isolated environments, enabling parallel work, research, and code modifications without conflicts.

**Core Concepts:**
- **Work Mode**: Agent makes code changes, produces diffs for review/merge
- **Research Mode**: Agent performs research/experiments, writes final answer to `answer.md`
- **Await Runtime**: Block until agent completes, then collect results
- **Fire-and-Forget Runtime**: Spawn agent in background, collect later
- **Isolated Worktrees**: Each agent gets its own git worktree and branch
- **Hierarchical Agents**: Agents can spawn sub-agents (up to 3 levels deep)

## Execution Modes Matrix

| Mode | Runtime | Use Case | Output |
|------|---------|----------|--------|
| **Research** | **Await** | Research questions, analysis, web search | `answer.md` + patch |
| **Work** | **Fire-and-Forget** | Documentation updates, quick fixes | Patch (auto-merge with `--quick-merge`) |
| **Work** | **Await** | Code implementation, refactoring | Patch (manual review/merge) |

## Core Commands

### 1. `agent-spawn.sh` - Spawn a New Agent

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider <cursor|codex|gemini> \
  --mode <work|research> \
  --runtime <await|ff> \
  --prompt "<task description>" \
  [--base <branch>] \
  [--model <model>] \
  [--parent-run-id <id>] \
  [--max-depth <n>] \
  [--quick-merge]
```

**Returns:** `runId` (e.g., `20251224-012840-c4381a`)

**Examples:**

**Example 1: Research Agent (Await)**
```bash
# Spawn a research agent to answer a question using web search
PROMPT="Research information retrieval systems. Use Tavily search tools to gather current information, then write a comprehensive answer covering: what they are, key components, modern approaches, and real-world applications. Write your final answer to answer.md."

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

echo "Agent completed with runId: $RUN_ID"
```

**Example 2: Work Agent (Await) - Code Implementation**
```bash
# Spawn a work agent to implement a feature
PROMPT="Create a new API endpoint at /api/users that returns a list of users. Add the route to routes/api.ts, create a controller function, and add basic error handling."

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode work \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

echo "Agent completed with runId: $RUN_ID"
# Review changes, then merge if approved
bash skills/agent-orchestration/scripts/agent-merge.sh "$RUN_ID"
```

**Example 3: Work Agent (Fire-and-Forget) - Documentation Update**
```bash
# Spawn a work agent to update documentation (fire-and-forget)
PROMPT="Update the README.md to document the new /api/users endpoint. Include request/response examples and error codes."

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode work \
  --runtime ff \
  --prompt "$PROMPT" \
  --model auto \
  --quick-merge)

echo "Agent running in background with runId: $RUN_ID"
# Agent will auto-merge when complete (due to --quick-merge)
```

**Example 4: Hierarchical Agent (Sub-Agent)**
```bash
# Spawn a sub-agent from within another agent's worktree
# This is typically done programmatically from within an agent
# The parent agent would call:
PROMPT="Research microservices patterns and write findings to microservices-research.md"

SUB_RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --parent-run-id "$PARENT_RUN_ID" \
  --max-depth 2 \
  --model auto)

echo "Sub-agent completed with runId: $SUB_RUN_ID"
```

**Arguments:**
- `--provider`: AI provider (`cursor`, `codex`, `gemini`) - **Required**
- `--mode`: Execution mode (`work` or `research`) - **Required**
- `--runtime`: Runtime pattern (`await` or `ff`) - **Required**
- `--prompt`: Task description for the agent - **Required**
- `--base`: Base git branch (default: `main`)
- `--model`: Model to use (default: `auto` for cursor)
- `--parent-run-id`: Parent agent's runId (for hierarchical agents)
- `--max-depth`: Maximum agent depth (default: `2`, max: `3`)
- `--quick-merge`: Auto-merge work mode changes on completion (fire-and-forget only)

### 2. `agent-wait.sh` - Wait for Agent Completion

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-wait.sh <runId> [timeout]
```

**Examples:**

```bash
# Wait for agent to complete (default timeout: 3600s = 1 hour)
bash skills/agent-orchestration/scripts/agent-wait.sh 20251224-012840-c4381a

# Wait with custom timeout (5 minutes)
bash skills/agent-orchestration/scripts/agent-wait.sh 20251224-012840-c4381a 300
```

**What it does:**
- Monitors the agent process (PID) in real-time
- Updates `meta.json` with status every 5 seconds
- Checks for `cursor-agent` processes (for cursor provider)
- Returns when agent completes, times out, or fails
- Updates final status in `meta.json`

### 3. `agent-collect.sh` - Collect Results from Agent

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-collect.sh <runId>
```

**Examples:**

```bash
# Collect results from a completed agent
RESULT_JSON=$(bash skills/agent-orchestration/scripts/agent-collect.sh 20251224-012840-c4381a)

# Parse result.json
echo "$RESULT_JSON" | jq '.artifacts.answer'  # For research mode
echo "$RESULT_JSON" | jq '.artifacts.patch'   # For work mode
```

**What it does:**
- **Patch-First Approach**: Generates `patch.diff` FIRST (before checking results)
- Analyzes patch to detect work (even if output files are missing/misplaced)
- Extracts primary outputs:
  - **Research mode**: `answer.md` (searches patch for location)
  - **Work mode**: `patch.diff`, `changed_files.txt`, `diffstat.txt`
- Performs rescue logic if no results found (max 2 attempts)
- Generates `result.json` with structured findings
- Auto-cleanup based on mode and status

**Output Files:**
- `.ada/data/agents/runs/<runId>/result.json` - Structured result data
- `.ada/data/agents/runs/<runId>/patch.diff` - Git diff of all changes
- `.ada/data/agents/runs/<runId>/changed_files.txt` - List of modified files
- `.ada/data/agents/runs/<runId>/answer.md` - Research mode answer (if found)
- `.ada/data/agents/runs/<runId>/diffstat.txt` - Diff statistics (work mode)

**Result JSON Structure:**
```json
{
  "runId": "20251224-012840-c4381a",
  "provider": "cursor",
  "mode": "research",
  "status": "success",
  "report": "Answer written to answer.md",
  "patchAnalysis": {
    "hasChanges": true,
    "answerLocation": "answer.md",
    "changedFiles": ["answer.md", "research-notes.md"],
    "patchSize": 1523,
    "workDetected": true
  },
  "artifacts": {
    "answer": ".ada/data/agents/runs/<id>/answer.md",
    "patch": ".ada/data/agents/runs/<id>/patch.diff",
    "changedFiles": ".ada/data/agents/runs/<id>/changed_files.txt"
  }
}
```

### 4. `agent-merge.sh` - Merge Work Mode Changes

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-merge.sh <runId> [targetBranch] [--auto-resolve]
```

**Examples:**

```bash
# Merge agent's changes to main branch
bash skills/agent-orchestration/scripts/agent-merge.sh 20251224-012840-c4381a main

# Merge to feature branch with auto-resolve
bash skills/agent-orchestration/scripts/agent-merge.sh 20251224-012840-c4381a feature/api --auto-resolve
```

**What it does:**
- Validates agent is in work mode
- Performs quality review of changes
- Merges agent branch into target branch
- Handles merge conflicts (with optional auto-resolve)
- Cleans up worktree after successful merge

**Note:** Only works for work-mode agents. Research mode agents don't merge (only `answer.md` matters).

### 5. `agent-discard.sh` - Discard an Agent Run

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-discard.sh <runId>
```

**Examples:**

```bash
# Discard a failed or unwanted agent run
bash skills/agent-orchestration/scripts/agent-discard.sh 20251224-012840-c4381a
```

**What it does:**
- Kills agent process if still running
- Removes git worktree and branch
- Updates `meta.json` with "discarded" status
- Keeps run directory for audit (configurable)

### 6. `agent-status.sh` - Quick Status Check

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-status.sh <runId>
```

**Examples:**

```bash
# Check agent status
bash skills/agent-orchestration/scripts/agent-status.sh 20251224-012840-c4381a
```

**Output:**
```
==========================================
Agent Status: 20251224-012840-c4381a
==========================================

Status:        running
Process:       running
Provider:      cursor
Mode:          research

PID:           12345 (alive)
Cursor Procs:  2

Started:       2025-12-24T01:28:40Z
Last Check:    2025-12-24T01:30:15Z
Elapsed:       95s

Artifacts:
  ✓ patch.diff (1523 bytes)
  ✓ changed_files.txt (2 files)
  ✗ answer.md (missing)

==========================================
```

### 7. `agent-orchestrate.sh` - Batch Orchestration

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-orchestrate.sh <plan.json>
```

**Examples:**

```bash
# Orchestrate multiple agents from a plan file
bash skills/agent-orchestration/scripts/agent-orchestrate.sh plan.json
```

**Plan JSON Format:**
```json
{
  "jobs": [
    {
      "id": "research-1",
      "provider": "cursor",
      "mode": "research",
      "runtime": "await",
      "prompt": "Research topic X",
      "model": "auto"
    },
    {
      "id": "work-1",
      "provider": "cursor",
      "mode": "work",
      "runtime": "ff",
      "prompt": "Implement feature Y",
      "model": "auto",
      "quickMerge": true
    }
  ],
  "parallel": true,
  "mergeOrder": ["work-1"]
}
```

**Note:** Batch orchestration is a placeholder - full implementation coming soon.

### 8. `agent-cleanup.sh` - Clean Up Old Runs

**Usage:**
```bash
bash skills/agent-orchestration/scripts/agent-cleanup.sh [retentionDays]
```

**Examples:**

```bash
# Clean up runs older than 7 days (default)
bash skills/agent-orchestration/scripts/agent-cleanup.sh

# Clean up runs older than 30 days
bash skills/agent-orchestration/scripts/agent-cleanup.sh 30
```

## Complete Workflow Examples

### Example 1: Research Task with Web Search

```bash
# Step 1: Spawn research agent
PROMPT="Research microservices architecture patterns. Use Tavily search tools to find:
1. Best practices for microservices communication
2. Service mesh vs API gateway approaches
3. Modern deployment patterns
Write a comprehensive answer to answer.md covering these topics with examples."

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

# Step 2: Agent automatically waits (await mode), so we can collect immediately
RESULT=$(bash skills/agent-orchestration/scripts/agent-collect.sh "$RUN_ID")

# Step 3: Extract answer
ANSWER_FILE=$(echo "$RESULT" | jq -r '.artifacts.answer')
cat "$ANSWER_FILE"
```

### Example 2: Code Implementation with Review

```bash
# Step 1: Spawn work agent
PROMPT="Add user authentication to the API:
1. Create /api/auth/login endpoint
2. Create /api/auth/register endpoint
3. Add JWT token generation
4. Add password hashing with bcrypt
5. Update API documentation"

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode work \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

# Step 2: Collect results
RESULT=$(bash skills/agent-orchestration/scripts/agent-collect.sh "$RUN_ID")

# Step 3: Review patch
PATCH_FILE=$(echo "$RESULT" | jq -r '.artifacts.patch')
cat "$PATCH_FILE"

# Step 4: If approved, merge
read -p "Merge changes? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash skills/agent-orchestration/scripts/agent-merge.sh "$RUN_ID" main
fi
```

### Example 3: Fire-and-Forget Documentation Update

```bash
# Spawn agent in background with auto-merge
PROMPT="Update API documentation in docs/api.md to include the new authentication endpoints."

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode work \
  --runtime ff \
  --prompt "$PROMPT" \
  --model auto \
  --quick-merge)

echo "Agent running in background: $RUN_ID"
echo "Check status with: bash skills/agent-orchestration/scripts/agent-status.sh $RUN_ID"

# Later, collect results
RESULT=$(bash skills/agent-orchestration/scripts/agent-collect.sh "$RUN_ID")
```

### Example 4: Hierarchical Agents (Sub-Agent)

```bash
# Main agent spawns a sub-agent for research
MAIN_RUN_ID="20251224-010000-abc123"  # Parent agent's runId

PROMPT="Research database migration strategies. Write findings to db-migration-research.md"

SUB_RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --parent-run-id "$MAIN_RUN_ID" \
  --max-depth 2 \
  --model auto)

# Sub-agent completes, results bubble up to parent
RESULT=$(bash skills/agent-orchestration/scripts/agent-collect.sh "$SUB_RUN_ID")
```

## Key Features

### 1. Patch-First Result Detection

**Problem Solved:** Agents sometimes create output files in wrong locations or formats.

**Solution:** System always generates `patch.diff` FIRST, then analyzes it to detect work, even if expected output files are missing or misplaced.

**How it works:**
1. `agent-collect.sh` generates `patch.diff` immediately
2. Analyzes patch for work detection:
   - **Research mode**: Looks for `answer.md` in ANY location in patch
   - **Work mode**: Looks for actual code changes (excludes metadata files)
3. Falls back to file-based checks only if patch is empty
4. Always returns patch in `result.json`, even if no expected output found

**Example:**
```bash
# Agent creates answer.md in subdirectory/research/answer.md instead of root
# System still detects it via patch analysis:
RESULT=$(bash skills/agent-orchestration/scripts/agent-collect.sh "$RUN_ID")
echo "$RESULT" | jq '.patchAnalysis.answerLocation'
# Output: "subdirectory/research/answer.md"
```

### 2. Real-Time Process Monitoring

**Features:**
- Updates `meta.json` with process status every 5 seconds
- Tracks elapsed time, process status, cursor-agent process count
- Provides real-time status via `agent-status.sh`
- Handles process timeouts and orphaned processes

**Example:**
```bash
# Monitor agent in real-time
bash skills/agent-orchestration/scripts/agent-status.sh "$RUN_ID"
# Shows: status, PID, elapsed time, cursor processes, artifacts
```

### 3. Isolated Git Worktrees

**Benefits:**
- Each agent gets its own git worktree and branch
- No file conflicts between agents
- Can work on same codebase areas in parallel
- Easy to review/merge/discard individual agent work

**Structure:**
```
.ada/temp/agents/worktrees/<runId>/  # Agent's worktree
.ada/data/agents/runs/<runId>/       # Agent's metadata and artifacts
```

### 4. Rescue Logic

**Problem Solved:** Agents sometimes finish without producing expected results.

**Solution:** Progressive rescue escalation:
1. **Basic Rescue** (max 2 attempts): Re-prompt agent to complete task
2. **Enhanced Rescue**: Orchestrator-guided rescue with enhanced instructions
3. **Orchestrator Intervention**: Parent agent reviews and guides
4. **Human Escalation**: Last resort (saves partial results)

**How it works:**
- `agent-collect.sh` checks for results using patch-first approach
- If no work detected, spawns rescue agent in same worktree
- Max 2 rescue attempts with exponential backoff
- Always saves partial results, never gives up without exhausting options

### 5. Hierarchical Agents

**Features:**
- Agents can spawn sub-agents (up to 3 levels deep, default: 2)
- Level enforcement via `.agent-level` file (immutable)
- Strict up/down communication only (no sideways communication)
- Context scoping: Sub-agents receive minimal context to prevent token explosion

**Example:**
```
Level 1 (Orchestrator): Main task
  └─ Level 2 (Sub-Agent): Research subtask
      └─ Level 3 (Sub-Sub-Agent): Deep dive on specific topic
```

### 6. Auto-Cleanup

**Rules:**
- **Research mode (success)**: Auto-cleanup worktree (only `answer.md` matters)
- **Work mode (success)**: Keep worktree for review (no auto-cleanup)
- **Work mode (success + quick-merge)**: Auto-cleanup after merge
- **Failure**: Only cleanup after all rescue attempts exhausted

**Manual cleanup:**
```bash
bash skills/agent-orchestration/scripts/agent-discard.sh "$RUN_ID"
```

## Provider-Specific Details

### Cursor Provider

**Features:**
- Uses `cursor-agent` CLI tool
- Supports Tavily MCP tools for web search (research mode)
- Model selection via `--model` flag (default: `auto`)
- Non-fatal auth errors filtered (logged as warnings)
- Real-time output capture to `out.ndjson`

**Research Mode Instructions:**
- Explicitly instructed to use Tavily search tools
- Told to write final answer to `answer.md`
- Full write access for experiments

**Work Mode Instructions:**
- Full write access to all files
- Told to make code changes as specified

### Codex Provider

**Status:** Placeholder (not yet implemented)

### Gemini Provider

**Status:** Placeholder (not yet implemented)

## File Structure

```
.ada/
├── data/
│   └── agents/
│       └── runs/
│           └── <runId>/
│               ├── meta.json          # Agent metadata
│               ├── result.json        # Structured results
│               ├── out.ndjson         # Agent output log
│               ├── patch.diff         # Git diff of changes
│               ├── changed_files.txt  # List of modified files
│               ├── diffstat.txt       # Diff statistics (work mode)
│               └── answer.md          # Research mode answer
└── temp/
    └── agents/
        └── worktrees/
            └── <runId>/               # Agent's git worktree
                ├── prompt.md          # Task instructions
                ├── progress.md        # Progress tracking (optional)
                ├── .agent-level       # Agent level (immutable)
                └── [agent's files]    # Agent's work
```

## Best Practices

### 1. Prompt Writing

**Good Prompts:**
- Clear, specific task description
- Include expected output format
- Specify file locations (e.g., "Write to answer.md in root")
- For research: Explicitly mention using Tavily search tools

**Bad Prompts:**
- Vague or ambiguous tasks
- Missing output format specification
- Too many requirements in one prompt

### 2. Mode Selection

**Use Research Mode When:**
- Answering questions
- Conducting research
- Analyzing information
- Web search needed

**Use Work Mode When:**
- Making code changes
- Implementing features
- Refactoring code
- Updating documentation

### 3. Runtime Selection

**Use Await When:**
- Need results immediately
- Sequential workflow
- Research tasks (always await)

**Use Fire-and-Forget When:**
- Background tasks
- Documentation updates
- Non-critical changes
- With `--quick-merge` for auto-merge

### 4. Hierarchical Agents

**When to Use:**
- Complex tasks requiring sub-tasks
- Parallel research on different topics
- Breaking down large implementations

**Best Practices:**
- Keep max depth at 2 (default) unless necessary
- Use 3 levels only for very complex tasks
- Ensure sub-agents have clear, focused prompts
- Monitor token usage (context scoping helps)

### 5. Error Handling

**Always:**
- Check `result.json` status field
- Review `patch.diff` even if `answer.md` missing
- Use `agent-status.sh` to monitor long-running agents
- Review `out.ndjson` for agent output/logs

**Rescue Logic:**
- System automatically attempts rescue (max 2 attempts)
- Check `rescueAttempts` in `result.json`
- Review `escalationLevel` if rescue failed

## Troubleshooting

### Agent Not Producing Results

1. **Check patch.diff**: System uses patch-first approach, so check if any changes were made
   ```bash
   cat .ada/data/agents/runs/<runId>/patch.diff
   ```

2. **Check out.ndjson**: Review agent's output/logs
   ```bash
   cat .ada/data/agents/runs/<runId>/out.ndjson | jq '.'
   ```

3. **Check status**: Use `agent-status.sh` to see current state
   ```bash
   bash skills/agent-orchestration/scripts/agent-status.sh <runId>
   ```

4. **Rescue logic**: System should automatically attempt rescue, but you can manually trigger:
   ```bash
   # Re-collect (triggers rescue if needed)
   bash skills/agent-orchestration/scripts/agent-collect.sh <runId>
   ```

### Agent Process Not Running

1. **Check PID**: Verify process exists
   ```bash
   kill -0 <PID>  # Returns 0 if process exists
   ```

2. **Check cursor-agent**: For cursor provider, check if cursor-agent processes are running
   ```bash
   ps aux | grep cursor-agent
   ```

3. **Check meta.json**: Review process status
   ```bash
   cat .ada/data/agents/runs/<runId>/meta.json | jq '.processStatus'
   ```

### Merge Conflicts

1. **Review changes**: Check patch.diff before merging
   ```bash
   cat .ada/data/agents/runs/<runId>/patch.diff
   ```

2. **Use auto-resolve**: Try `--auto-resolve` flag
   ```bash
   bash skills/agent-orchestration/scripts/agent-merge.sh <runId> main --auto-resolve
   ```

3. **Manual resolution**: Merge manually if auto-resolve fails
   ```bash
   # Get worktree path
   WORKTREE=$(cat .ada/data/agents/runs/<runId>/meta.json | jq -r '.worktreePath')
   cd "$WORKTREE"
   # Resolve conflicts manually, then merge
   ```

## Integration with Other Skills

### Using with Research Skill

```bash
# Spawn agent to conduct research using research skill patterns
PROMPT="Use the research skill approach to research microservices. Create evidence cards, search academic papers, and write comprehensive findings to answer.md."

RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)
```

### Using with Search Skill (Tavily)

Research agents automatically have access to Tavily MCP tools via cursor-agent. No additional setup needed.

## Security Considerations

- **Isolated Worktrees**: Each agent operates in isolation
- **Read-Only for Research**: Research mode has full write access (for experiments), but only `answer.md` is kept
- **Audit Trail**: All agent actions logged to `out.ndjson`
- **Process Isolation**: Agents run in separate processes
- **Git Safety**: Changes only merged after explicit approval

## Performance Tips

1. **Use Fire-and-Forget for Non-Critical Tasks**: Frees up orchestrator immediately
2. **Parallel Agents**: Spawn multiple agents in parallel for independent tasks
3. **Context Scoping**: Hierarchical agents use minimal context to reduce token usage
4. **Cleanup Regularly**: Use `agent-cleanup.sh` to remove old runs

## Limitations

- **Batch Orchestration**: Currently a placeholder (full implementation coming)
- **Codex/Gemini Providers**: Not yet implemented (placeholders)
- **Smart Conflict Resolution**: Basic implementation (enhancements planned)
- **Quality Review**: Basic implementation (enhancements planned)

## See Also

- `.test/skills/agent-orchestration/` - Test scripts and examples
- `references/plan.json.example` - Batch orchestration plan example
- `scripts/lib/agent-utils.sh` - Core utility functions
- `scripts/providers/` - Provider implementations

