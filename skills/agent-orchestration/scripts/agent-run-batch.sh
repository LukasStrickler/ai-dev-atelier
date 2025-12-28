#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPAWN_ROLE="${SCRIPT_DIR}/agent-spawn-role.sh"
WAIT_SCRIPT="${SCRIPT_DIR}/agent-wait.sh"
COLLECT_SCRIPT="${SCRIPT_DIR}/agent-collect.sh"
MERGE_SCRIPT="${SCRIPT_DIR}/agent-merge.sh"

ROLE=""
MODE=""
RUNTIME="ff"
PROVIDER="cursor"
MODEL="auto"
PARENT_RUN_ID=""
MAX_DEPTH="3"
BASE_BRANCH="main"
QUICK_MERGE="false"
ORCH_BRIEF=""
CONTEXT_FILE=""
WORKSTREAM_PREFIX=""
WORKSTREAM_START="1"
TASKS_FILE=""
MERGE="false"
AUTO_RESOLVE="false"
MERGE_BRANCH=""

TASKS=()
RUN_IDS=()

usage() {
  cat >&2 <<USAGE
Usage: $0 <role> [options] --task "..." [--task "..."]
       $0 <role> --tasks-file <path>

Options:
  --tasks-file <path>       File with one task per line (blank lines ignored)
  --task <text>             Inline task (repeatable)
  --workstream-prefix <X>   Default prefix by role (R/I/T/D/V/H)
  --workstream-start <N>    Default: 1
  --mode <work|research>    Override default mode by role
  --runtime <await|ff>      Default: ff (spawns in parallel)
  --provider <name>         cursor|codex|gemini (default: cursor)
  --model <model>           Default: auto
  --parent-run-id <id>
  --max-depth <n>           Default: 3
  --base <branch>           Default: main
  --quick-merge             Alias for --merge
  --merge                   Merge after collect (work mode only)
  --merge-branch <branch>   Target branch for merge
  --auto-resolve            Pass --auto-resolve to agent-merge.sh
  --orchestrator-brief <path>
  --context-file <path>
USAGE
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ROLE="$1"
shift 1

normalize_role() {
  local role
  role="$(echo "$1" | tr 'A-Z' 'a-z' | tr '_' '-')"
  echo "$role"
}

role_default_prefix() {
  case "$1" in
    researcher|research|research-specialist)
      echo "R"
      ;;
    implementer|implementation|coder|engineer)
      echo "I"
      ;;
    tester|test|qa)
      echo "T"
      ;;
    doc|docs|doc-writer|documentation|documenter)
      echo "D"
      ;;
    reviewer|verify|verification)
      echo "V"
      ;;
    helper|assistant)
      echo "H"
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
PREFIX_DEFAULT="$(role_default_prefix "$ROLE_NORM")"
MODE_DEFAULT="$(role_default_mode "$ROLE_NORM")"

if [ -z "$PREFIX_DEFAULT" ]; then
  echo "Error: Unknown role: $ROLE" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks-file)
      TASKS_FILE="$2"
      shift 2
      ;;
    --task)
      TASKS+=("$2")
      shift 2
      ;;
    --workstream-prefix)
      WORKSTREAM_PREFIX="$2"
      shift 2
      ;;
    --workstream-start)
      WORKSTREAM_START="$2"
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

if [ -n "$TASKS_FILE" ]; then
  if [ ! -f "$TASKS_FILE" ]; then
    echo "Error: Tasks file not found: $TASKS_FILE" >&2
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$line" ] && [ "${line#\#}" = "$line" ]; then
      TASKS+=("$line")
    fi
  done < "$TASKS_FILE"
fi

if [ ${#TASKS[@]} -eq 0 ]; then
  echo "Error: Provide at least one --task or --tasks-file" >&2
  exit 1
fi

if [ -z "$WORKSTREAM_PREFIX" ]; then
  WORKSTREAM_PREFIX="$PREFIX_DEFAULT"
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

INDEX="$WORKSTREAM_START"
for TASK in "${TASKS[@]}"; do
  WORKSTREAM_ID="${WORKSTREAM_PREFIX}${INDEX}"
  INDEX=$((INDEX + 1))

  ARGS=(
    --role "$ROLE"
    --workstream "$WORKSTREAM_ID"
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
  echo "Spawned $WORKSTREAM_ID -> $RUN_ID" >&2
  RUN_IDS+=("$RUN_ID")

done

STATUS=0
for RUN_ID in "${RUN_IDS[@]}"; do
  if [ "$RUNTIME" = "ff" ]; then
    bash "$WAIT_SCRIPT" "$RUN_ID"
  fi

  bash "$COLLECT_SCRIPT" "$RUN_ID" >/dev/null

  if [ "$MERGE" = "true" ] && [ "$MODE" = "work" ]; then
    MERGE_ARGS=("$RUN_ID")
    if [ -n "$MERGE_BRANCH" ]; then
      MERGE_ARGS+=("$MERGE_BRANCH")
    fi
    if [ "$AUTO_RESOLVE" = "true" ]; then
      MERGE_ARGS+=(--auto-resolve)
    fi
    if ! bash "$MERGE_SCRIPT" "${MERGE_ARGS[@]}"; then
      echo "Merge failed for $RUN_ID" >&2
      STATUS=1
    fi
  fi

done

exit $STATUS
