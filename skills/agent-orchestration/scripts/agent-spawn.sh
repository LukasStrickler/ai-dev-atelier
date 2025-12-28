#!/bin/bash
# Spawn a new agent

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"
source "${SCRIPT_DIR}/lib/provider-interface.sh"

# Parse arguments
PROVIDER="cursor"
MODE="work"
RUNTIME="await"
BASE_BRANCH="main"
PROMPT=""
PARENT_RUN_ID=""
MAX_DEPTH="3"
MODEL="auto"
QUICK_MERGE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --runtime)
      RUNTIME="$2"
      shift 2
      ;;
    --base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --parent-run-id)
      PARENT_RUN_ID="$2"
      shift 2
      ;;
    --max-depth)
      MAX_DEPTH="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --quick-merge)
      QUICK_MERGE="true"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 --provider <provider> --mode <work|research> --runtime <await|ff> --prompt <prompt> [--base <branch>] [--parent-run-id <id>] [--max-depth <n>] [--model <model>] [--quick-merge]" >&2
      exit 1
      ;;
  esac
done

# Validate arguments
if [ -z "$PROMPT" ]; then
  echo "Error: --prompt is required" >&2
  exit 1
fi


if [ "$MODE" != "work" ] && [ "$MODE" != "research" ]; then
  echo "Error: --mode must be 'work' or 'research'" >&2
  exit 1
fi

if [ "$RUNTIME" != "await" ] && [ "$RUNTIME" != "ff" ]; then
  echo "Error: --runtime must be 'await' or 'ff'" >&2
  exit 1
fi

# Generate run ID
RUN_ID=$(generate_run_id)
RUN_DIR=$(get_run_directory "$RUN_ID")
mkdir -p "$RUN_DIR"

# Calculate agent level
CALCULATED_LEVEL=$(get_agent_level "$PARENT_RUN_ID")

# Validate level
if ! validate_level "$CALCULATED_LEVEL" "$MAX_DEPTH"; then
  echo "Error: Level $CALCULATED_LEVEL exceeds maxDepth $MAX_DEPTH" >&2
  exit 1
fi

# Create worktree
WORKTREE_PATH=$(create_worktree "$RUN_ID" "$BASE_BRANCH")
if [ $? -ne 0 ]; then
  echo "Error: Failed to create worktree" >&2
  exit 1
fi

# Create level file (immutable)
create_level_file "$WORKTREE_PATH" "$CALCULATED_LEVEL"

# Create prompt.md
create_prompt_file "$WORKTREE_PATH" "$PROMPT" "$CALCULATED_LEVEL" "$MODE"

# Create progress.md
create_progress_file "$WORKTREE_PATH"

# Research mode: create answer.md placeholder
if [ "$MODE" = "research" ]; then
  create_answer_file "$WORKTREE_PATH"
fi

# Persist prompt.md into run directory for reference
cp "${WORKTREE_PATH}/prompt.md" "${RUN_DIR}/prompt.md"

# Prepare environment variables JSON
ENV_VARS_JSON=$(cat <<EOF
{
  "AGENT_LEVEL": "$CALCULATED_LEVEL",
  "PARENT_RUN_ID": "${PARENT_RUN_ID:-}",
  "PROMPT_FILE": "${WORKTREE_PATH}/prompt.md",
  "WORKSPACE_PATH": "$WORKTREE_PATH",
  "MODE": "$MODE",
  "RUNTIME": "$RUNTIME",
  "COMMUNICATION_PATTERN": "up_down_only",
  "MODEL": "$MODEL"
}
EOF
)

# Initialize metadata
OUT_NDJSON="${RUN_DIR}/out.ndjson"
touch "$OUT_NDJSON"

# Spawn provider process in background
PID=$(provider_run "$WORKTREE_PATH" "$MODE" "$RUNTIME" "${WORKTREE_PATH}/prompt.md" "$OUT_NDJSON" "$ENV_VARS_JSON" "$PROVIDER" "$MODEL")

# Write metadata atomically (including initial process tracking)
write_meta_json "$RUN_ID" \
  "runId" "$RUN_ID" \
  "provider" "$PROVIDER" \
  "model" "$MODEL" \
  "mode" "$MODE" \
  "runtime" "$RUNTIME" \
  "baseBranch" "$BASE_BRANCH" \
  "worktreePath" "$WORKTREE_PATH" \
  "level" "$CALCULATED_LEVEL" \
  "parentRunId" "${PARENT_RUN_ID:-}" \
  "pid" "$PID" \
  "pidTimestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  "startedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  "status" "running" \
  "processStatus" "starting" \
  "lastCheckAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  "elapsedSeconds" "0" \
  "quickMerge" "$QUICK_MERGE"

# Register cleanup handler
register_cleanup_handler "$RUN_ID"

# Output runId
echo "$RUN_ID"

# If await mode, wait for completion
if [ "$RUNTIME" = "await" ]; then
  # Recalculate script directory to ensure correct path (sourcing might affect SCRIPT_DIR)
  AGENT_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bash "${AGENT_SCRIPTS_DIR}/agent-wait.sh" "$RUN_ID"
fi
