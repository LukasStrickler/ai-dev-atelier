#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPAWN_ROLE="${SCRIPT_DIR}/agent-spawn-role.sh"

ROLE=""
TASK=""
WORKSTREAM=""
MODE=""
RUNTIME="await"
PROVIDER="cursor"
MODEL="auto"
PARENT_RUN_ID=""
MAX_DEPTH="3"
BASE_BRANCH="main"
QUICK_MERGE="false"
ORCH_BRIEF=""
CONTEXT_FILE=""
MERGE="false"
AUTO_RESOLVE="false"
MERGE_BRANCH=""

usage() {
  cat >&2 <<USAGE
Usage: $0 <role> <task> [options]

Examples:
  $0 researcher "Summarize repo in 3 bullets"
  $0 implementer "Update README with new command"

Options:
  --workstream <id>        Override workstream ID (defaults by role)
  --mode <work|research>   Override default mode
  --runtime <await|ff>     Default: await
  --provider <name>        cursor|codex|gemini (default: cursor)
  --model <model>          Default: auto
  --parent-run-id <id>
  --max-depth <n>          Default: 3
  --base <branch>          Default: main
  --quick-merge            Alias for --merge
  --merge                  Merge after collect (work mode only)
  --merge-branch <branch>  Target branch for merge (default: current base)
  --auto-resolve           Pass --auto-resolve to agent-merge.sh
  --orchestrator-brief <path>
  --context-file <path>
USAGE
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

ROLE="$1"
TASK="$2"
shift 2

normalize_role() {
  local role
  role="$(echo "$1" | tr 'A-Z' 'a-z' | tr '_' '-')"
  echo "$role"
}

role_default_workstream() {
  case "$1" in
    researcher|research|research-specialist)
      echo "R1"
      ;;
    implementer|implementation|coder|engineer)
      echo "I1"
      ;;
    tester|test|qa)
      echo "T1"
      ;;
    doc|docs|doc-writer|documentation|documenter)
      echo "D1"
      ;;
    reviewer|verify|verification)
      echo "V1"
      ;;
    helper|assistant)
      echo "H1"
      ;;
    *)
      echo ""
      ;;
  esac
}

role_default_mode() {
  case "$1" in
    researcher|research|research-specialist)
      echo "research"
      ;;
    *)
      echo "work"
      ;;
  esac
}

validate_mode() {
  case "$1" in
    work|research) return 0 ;;
    *) return 1 ;;
  esac
}

validate_runtime() {
  case "$1" in
    await|ff) return 0 ;;
    *) return 1 ;;
  esac
}

ROLE_NORM="$(normalize_role "$ROLE")"
WORKSTREAM_DEFAULT="$(role_default_workstream "$ROLE_NORM")"
MODE_DEFAULT="$(role_default_mode "$ROLE_NORM")"

if [ -z "$WORKSTREAM_DEFAULT" ]; then
  echo "Error: Unknown role: $ROLE" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workstream)
      WORKSTREAM="$2"
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
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
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
    --base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    --quick-merge)
      QUICK_MERGE="true"
      shift
      ;;
    --merge)
      MERGE="true"
      shift
      ;;
    --merge-branch)
      MERGE_BRANCH="$2"
      shift 2
      ;;
    --auto-resolve)
      AUTO_RESOLVE="true"
      shift
      ;;
    --orchestrator-brief)
      ORCH_BRIEF="$2"
      shift 2
      ;;
    --context-file)
      CONTEXT_FILE="$2"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [ -z "$WORKSTREAM" ]; then
  WORKSTREAM="$WORKSTREAM_DEFAULT"
fi

if [ -z "$MODE" ]; then
  MODE="$MODE_DEFAULT"
fi

if ! validate_mode "$MODE"; then
  echo "Error: --mode must be 'work' or 'research'" >&2
  exit 1
fi

if ! validate_runtime "$RUNTIME"; then
  echo "Error: --runtime must be 'await' or 'ff'" >&2
  exit 1
fi

if [ "$MODE" = "research" ] && [ "$RUNTIME" = "ff" ]; then
  echo "Warning: research mode forces runtime=await; overriding ff." >&2
  RUNTIME="await"
fi

ARGS=(
  --role "$ROLE"
  --workstream "$WORKSTREAM"
  --task "$TASK"
  --mode "$MODE"
  --runtime "$RUNTIME"
  --provider "$PROVIDER"
  --model "$MODEL"
  --max-depth "$MAX_DEPTH"
  --base "$BASE_BRANCH"
)

if [ -n "$PARENT_RUN_ID" ]; then
  ARGS+=(--parent-run-id "$PARENT_RUN_ID")
fi

if [ -n "$ORCH_BRIEF" ]; then
  ARGS+=(--orchestrator-brief "$ORCH_BRIEF")
fi

if [ -n "$CONTEXT_FILE" ]; then
  ARGS+=(--context-file "$CONTEXT_FILE")
fi

if [ "$QUICK_MERGE" = "true" ] && [ "$MERGE" = "false" ]; then
  MERGE="true"
fi

RUN_ID=$(bash "$SPAWN_ROLE" "${ARGS[@]}")
echo "Spawned runId: $RUN_ID" >&2

if [ "$RUNTIME" = "ff" ]; then
  bash "${SCRIPT_DIR}/agent-wait.sh" "$RUN_ID"
fi

RESULT_JSON=$(bash "${SCRIPT_DIR}/agent-collect.sh" "$RUN_ID")

if [ "$MERGE" = "true" ] && [ "$MODE" = "work" ]; then
  MERGE_ARGS=("$RUN_ID")
  if [ -n "$MERGE_BRANCH" ]; then
    MERGE_ARGS+=("$MERGE_BRANCH")
  fi
  if [ "$AUTO_RESOLVE" = "true" ]; then
    MERGE_ARGS+=(--auto-resolve)
  fi
  bash "${SCRIPT_DIR}/agent-merge.sh" "${MERGE_ARGS[@]}"
fi

echo "$RESULT_JSON"
