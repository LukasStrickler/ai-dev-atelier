# Operations and Troubleshooting

## Architecture Notes

### Patch-First Result Detection
- `agent-collect.sh` generates `patch.diff` first
- Detects work even if output files are misplaced

### Worktrees and Isolation
- Each run uses a dedicated git worktree
- Worktrees live under `.ada/temp/agents/worktrees/<runId>`
- `prompt.md` is written in the worktree and mirrored in `.ada/data/agents/runs/<runId>/prompt.md`
- `prompt.md` is excluded from patch/diff output

### Monitoring and Status
- `agent-wait.sh` tracks process status
- `agent-status.sh` reports PID, elapsed time, artifacts

### Rescue Logic
- Up to 2 rescue attempts
- Patch analysis determines if work happened
- `agent-collect.sh` will wait briefly if the run is still active
- If no results are detected after rescue, status is marked `failed` and escalation is set to `human`
- A failed run emits `rescue.md` and `rescue.sh` in the run directory for follow-up
- Backoff uses base delay * attempt with jitter; override via `RESCUE_MAX_DELAY` and `RESCUE_JITTER_PCT`

### Cleanup
- Research: auto-cleanup on success
- Work: keep worktree unless quick cleanup

### Providers
- Cursor: implemented
- Codex/Gemini: placeholders

### Limitations
- Batch orchestration via `agent-orchestrate.sh` is still placeholder
- Auto-resolve uses a `-X theirs` retry and aborts cleanly on failure

## Troubleshooting

### Agent did not produce answer.md
- Check `patch.diff` in `.ada/data/agents/runs/<runId>/`
- Check `out.ndjson` for model output
- Re-run `agent-collect.sh` to trigger rescue logic

### Agent process not running
- Check PID in `meta.json`
- Use `agent-status.sh <runId>`

### Merge conflicts
- Review `patch.diff`
- Use `agent-merge.sh <runId> --auto-resolve`
- Resolve manually in the worktree if needed
