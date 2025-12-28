# Command Reference

This file contains the full command surface for agent orchestration. Prefer the role-aware wrappers unless you need low-level control.

## Recommended Wrappers

### agent-run.sh
One-call spawn that waits, collects, and optionally merges.

```bash
bash skills/agent-orchestration/scripts/agent-run.sh <role> "<task>" [options]
```

Options:
- `--workstream <id>`: Override workstream ID
- `--mode <work|research>`: Override default mode by role
- `--runtime <await|ff>`: Default `await` (research forces `await`)
- `--provider <cursor|codex|gemini>`
- `--model <model>`
- `--parent-run-id <id>`
- `--max-depth <n>`: Default 3
- `--base <branch>`: Default main
- `--merge`: Merge after collect (work mode)
- `--merge-branch <branch>`: Target branch for merge
- `--auto-resolve`: Pass to merge tool
- `--quick-merge`: Alias for `--merge`
- `--orchestrator-brief <path>`
- `--context-file <path>`

Note: wrappers write `prompt.md` to both the worktree and the run directory for reference.

### agent-run-batch.sh
Spawn many tasks in parallel, wait/collect all, optional merge.

```bash
bash skills/agent-orchestration/scripts/agent-run-batch.sh <role> --tasks-file <path> [options]
```

Options:
- `--tasks-file <path>`: One task per line
- `--task <text>`: Repeatable inline tasks
- `--workstream-prefix <X>`: Default by role
- `--workstream-start <N>`: Default 1
- `--runtime <await|ff>`: Default ff (research forces `await`)
- `--merge`: Merge after collect (work mode)
- `--merge-branch <branch>`
- `--auto-resolve`
- `--quick-merge`: Alias for `--merge`
- Shared options: provider, model, parent-run-id, max-depth, base, orchestrator-brief, context-file

### agent-spawn-role.sh
Role-aware wrapper that injects role prompt + result contract.

```bash
bash skills/agent-orchestration/scripts/agent-spawn-role.sh \
  --role <researcher|implementer|tester|documenter|reviewer|helper> \
  --workstream <id> \
  --task "<task>" \
  [--mode <work|research>] \
  [--runtime <await|ff>]
```
Defaults: `--mode` follows role (researcher → research; others → work). Research mode forces `runtime=await`.

## Low-Level Commands

### agent-spawn.sh
Spawns a new agent run.

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

### agent-wait.sh
```bash
bash skills/agent-orchestration/scripts/agent-wait.sh <runId> [timeout]
```

### agent-collect.sh
```bash
bash skills/agent-orchestration/scripts/agent-collect.sh <runId>
```

### agent-merge.sh
```bash
bash skills/agent-orchestration/scripts/agent-merge.sh <runId> [targetBranch] [--auto-resolve]
```
Default target branch uses the run's base branch (falls back to `main` if missing). `--auto-resolve` retries merge with `-X theirs`.

### agent-status.sh
```bash
bash skills/agent-orchestration/scripts/agent-status.sh <runId>
```

### agent-discard.sh
```bash
bash skills/agent-orchestration/scripts/agent-discard.sh <runId>
```

### agent-cleanup.sh
```bash
bash skills/agent-orchestration/scripts/agent-cleanup.sh [retentionDays]
```
