#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ROLE_TEMPLATES="${SCRIPT_DIR}/../references/role-templates.md"
RESULT_CONTRACT="${SCRIPT_DIR}/../references/result-contract.md"
AGENT_SPAWN="${PROJECT_ROOT}/skills/agent-orchestration/scripts/agent-spawn.sh"

ROLE_RAW=""
ROLE_HEADING=""
WORKSTREAM=""
TASK_BRIEF=""
ORCH_BRIEF=""
CONTEXT_FILE=""
MODE=""
RUNTIME=""
PROVIDER="cursor"
MODEL="auto"
PARENT_RUN_ID=""
MAX_DEPTH="3"
BASE_BRANCH="main"
QUICK_MERGE="false"
PROMPT_TEXT=""
TASK_TEXT=""

usage() {
  cat >&2 <<USAGE
Usage: $0 --role <role> --workstream <id> [options]

Required:
  --role <role>            Role (researcher|implementer|tester|documenter|reviewer|helper)
  --workstream <id>        Workstream ID (e.g., R1, I1, T1, D1)

Options:
  --task-brief <path>      Subagent task brief file
  --orchestrator-brief <path>
  --context-file <path>    Extra context snippet file
  --prompt <text>          Inline prompt (used if no task brief)
  --task <text>            Inline task (alias for --prompt)
  --provider <name>        cursor|codex|gemini (default: cursor)
  --mode <work|research>   Default: work
  --runtime <await|ff>     Default: await
  --model <model>          Default: auto
  --parent-run-id <id>
  --max-depth <n>          Default: 3
  --base <branch>          Default: main
  --quick-merge            Enable auto-merge (ff work mode only)
USAGE
}

normalize_role() {
  local role
  role="$(echo "$1" | tr 'A-Z' 'a-z' | tr '_' '-' )"
  case "$role" in
    researcher|research|research-specialist)
      ROLE_HEADING="Researcher"
      ;;
    implementer|implementation|coder|engineer)
      ROLE_HEADING="Implementer"
      ;;
    tester|test|qa)
      ROLE_HEADING="Tester"
      ;;
    doc|docs|doc-writer|documentation|documenter)
      ROLE_HEADING="Documenter"
      ;;
    reviewer|verify|verification)
      ROLE_HEADING="Reviewer"
      ;;
    helper|assistant)
      ROLE_HEADING="Helper"
      ;;
    *)
      return 1
      ;;
  esac
}

role_default_mode() {
  case "$ROLE_HEADING" in
    Researcher)
      echo "research"
      ;;
    *)
      echo "work"
      ;;
  esac
}

extract_role_prompt() {
  local heading="$1"
  awk -v role="$heading" '
    $0 ~ "^## " role "$" {found=1; next}
    found && $0 ~ "^## " {exit}
    found {print}
  ' "$ROLE_TEMPLATES"
}

other_roles_context() {
  case "$ROLE_HEADING" in
    Researcher)
      cat <<EOF
- Implementer: code changes
- Tester: run tests and fix failures
- Documenter: update docs
- Reviewer: verify requirements/tests/docs
EOF
      ;;
    Implementer)
      cat <<EOF
- Researcher: gather info, write answer.md
- Tester: run tests and fix failures
- Documenter: update docs
- Reviewer: verify requirements/tests/docs
EOF
      ;;
    Tester)
      cat <<EOF
- Researcher: gather info, write answer.md
- Implementer: code changes
- Documenter: update docs
- Reviewer: verify requirements/tests/docs
EOF
      ;;
    Documenter)
      cat <<EOF
- Researcher: gather info, write answer.md
- Implementer: code changes
- Tester: run tests and fix failures
- Reviewer: verify requirements/tests/docs
EOF
      ;;
    Reviewer)
      cat <<EOF
- Researcher: gather info, write answer.md
- Implementer: code changes
- Tester: run tests and fix failures
- Documenter: update docs
EOF
      ;;
    Helper)
      cat <<EOF
- You are a helper for the parent specialist
- Do not duplicate work handled by other roles
EOF
      ;;
    *)
      echo "- Other roles handle research, implementation, testing, documentation, and verification"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      ROLE_RAW="$2"
      shift 2
      ;;
    --workstream)
      WORKSTREAM="$2"
      shift 2
      ;;
    --task-brief)
      TASK_BRIEF="$2"
      shift 2
      ;;
    --orchestrator-brief)
      ORCH_BRIEF="$2"
      shift 2
      ;;
    --context-file)
      CONTEXT_FILE="$2"
      shift 2
      ;;
    --prompt)
      PROMPT_TEXT="$2"
      shift 2
      ;;
    --task)
      TASK_TEXT="$2"
      shift 2
      ;;
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
    *)
      usage
      exit 1
      ;;
  esac
done

if [ -z "$ROLE_RAW" ] || [ -z "$WORKSTREAM" ]; then
  usage
  exit 1
fi

if ! normalize_role "$ROLE_RAW"; then
  echo "Error: Unknown role: $ROLE_RAW" >&2
  exit 1
fi

if [ -z "$MODE" ]; then
  MODE="$(role_default_mode)"
fi

if [ -z "$RUNTIME" ]; then
  RUNTIME="await"
fi

case "$MODE" in
  work|research) ;;
  *)
    echo "Error: --mode must be 'work' or 'research'" >&2
    exit 1
    ;;
esac

case "$RUNTIME" in
  await|ff) ;;
  *)
    echo "Error: --runtime must be 'await' or 'ff'" >&2
    exit 1
    ;;
esac

if [ "$MODE" = "research" ] && [ "$RUNTIME" = "ff" ]; then
  echo "Warning: research mode forces runtime=await; overriding ff." >&2
  RUNTIME="await"
fi

if [ -n "$TASK_TEXT" ] && [ -n "$PROMPT_TEXT" ]; then
  echo "Error: Provide only one of --task or --prompt" >&2
  exit 1
fi

if [ -n "$TASK_TEXT" ] && [ -n "$TASK_BRIEF" ]; then
  echo "Error: Provide only one of --task or --task-brief" >&2
  exit 1
fi

if [ -z "$TASK_BRIEF" ] && [ -z "$PROMPT_TEXT" ] && [ -z "$TASK_TEXT" ]; then
  echo "Error: Provide --task-brief, --prompt, or --task" >&2
  exit 1
fi

if [ -n "$TASK_BRIEF" ] && [ ! -f "$TASK_BRIEF" ]; then
  echo "Error: Task brief not found: $TASK_BRIEF" >&2
  exit 1
fi

if [ -n "$ORCH_BRIEF" ] && [ ! -f "$ORCH_BRIEF" ]; then
  echo "Error: Orchestrator brief not found: $ORCH_BRIEF" >&2
  exit 1
fi

if [ -n "$CONTEXT_FILE" ] && [ ! -f "$CONTEXT_FILE" ]; then
  echo "Error: Context file not found: $CONTEXT_FILE" >&2
  exit 1
fi

ROLE_PROMPT="$(extract_role_prompt "$ROLE_HEADING")"
if [ -z "$ROLE_PROMPT" ]; then
  echo "Error: Role prompt not found for heading: $ROLE_HEADING" >&2
  exit 1
fi
OTHER_ROLES_TEXT="$(other_roles_context)"

TASK_BRIEF_TEXT=""
if [ -n "$TASK_BRIEF" ]; then
  TASK_BRIEF_TEXT="$(cat "$TASK_BRIEF")"
elif [ -n "$TASK_TEXT" ]; then
  TASK_BRIEF_TEXT="$TASK_TEXT"
else
  TASK_BRIEF_TEXT="$PROMPT_TEXT"
fi

ORCH_BRIEF_TEXT=""
if [ -n "$ORCH_BRIEF" ]; then
  ORCH_BRIEF_TEXT="$(cat "$ORCH_BRIEF")"
fi

CONTEXT_TEXT=""
if [ -n "$CONTEXT_FILE" ]; then
  CONTEXT_TEXT="$(cat "$CONTEXT_FILE")"
fi

RESULT_CONTRACT_TEXT="$(cat "$RESULT_CONTRACT")"

FULL_PROMPT=$(cat <<PROMPT_EOF
# Subagent Role

- Role: ${ROLE_HEADING}
- Workstream ID: ${WORKSTREAM}
- Parent Run ID: ${PARENT_RUN_ID:-none}
- Mode: ${MODE}
- Runtime: ${RUNTIME}

## Role Instructions

${ROLE_PROMPT}

## Role Boundaries (Other roles handle)

${OTHER_ROLES_TEXT}

## Task Brief

${TASK_BRIEF_TEXT}
PROMPT_EOF
)

if [ -n "$ORCH_BRIEF_TEXT" ]; then
  FULL_PROMPT="${FULL_PROMPT}

## Orchestrator Brief

${ORCH_BRIEF_TEXT}"
fi

if [ -n "$CONTEXT_TEXT" ]; then
  FULL_PROMPT="${FULL_PROMPT}

## Context Pack

${CONTEXT_TEXT}"
fi

FULL_PROMPT="${FULL_PROMPT}

## Output Contract

${RESULT_CONTRACT_TEXT}

## Guardrails

- Stay within scope. Do not change unrelated files or tasks.
- No lateral communication between specialists. Report only to the parent.
- If Level 2, you may spawn multiple helpers (Level 3) for tightly scoped subtasks. Helpers must not spawn further agents.
- For research mode, write the final answer to answer.md and include the result contract summary.
- The full role + task context is saved in prompt.md for reference.
"

ARGS=(
  --provider "$PROVIDER"
  --mode "$MODE"
  --runtime "$RUNTIME"
  --prompt "$FULL_PROMPT"
  --base "$BASE_BRANCH"
  --max-depth "$MAX_DEPTH"
  --model "$MODEL"
)

if [ -n "$PARENT_RUN_ID" ]; then
  ARGS+=(--parent-run-id "$PARENT_RUN_ID")
fi

if [ "$QUICK_MERGE" = "true" ]; then
  ARGS+=(--quick-merge)
fi

bash "$AGENT_SPAWN" "${ARGS[@]}"
