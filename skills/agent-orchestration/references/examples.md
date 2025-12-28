# Examples

## Researcher

```bash
bash skills/agent-orchestration/scripts/agent-run.sh researcher \
  "Summarize this repo in 3 bullets. Cite only files you read."
```

## Implementer + Auto-Merge

```bash
bash skills/agent-orchestration/scripts/agent-run.sh implementer \
  "Update README with the new command" \
  --merge
```

## Batch Implementers (Parallel)

```bash
cat > tasks.txt <<'TASKS'
Update docs for feature A
Add pagination to endpoint B
Refactor helper C for clarity
TASKS

bash skills/agent-orchestration/scripts/agent-run-batch.sh implementer \
  --tasks-file tasks.txt \
  --merge
```

## Full Orchestrator Flow

```bash
# Research
bash skills/agent-orchestration/scripts/agent-run.sh researcher \
  "Find how docs are currently updated and summarize in answer.md."

# Implement
bash skills/agent-orchestration/scripts/agent-run.sh implementer \
  "Update the API handler to include pagination." \
  --merge

# Test
bash skills/agent-orchestration/scripts/agent-run.sh tester \
  "Run the unit tests for the API handler and fix failures."

# Document
bash skills/agent-orchestration/scripts/agent-run.sh documenter \
  "Update docs for the new pagination fields."

# Verify
bash skills/agent-orchestration/scripts/agent-run.sh reviewer \
  "Verify requirements, tests, and docs coverage."
```
