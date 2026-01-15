#!/bin/bash
# Wait for PR CI and AI reviews to complete before fetching comments
# Usage: Invoked by pr-resolver.sh, not meant to be called directly
#
# Waits for:
# 1. CI jobs to complete (excluding filtered jobs from ci-job-filters.txt)
# 2. AI review bots (CodeRabbit, Copilot, etc.) to post reviews
#
# Returns 0 when ready, 1 on CI failure, 2 on timeout
# Timeout: 10 minutes total (reports pending jobs on timeout)
# 

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CI_FILTERS_FILE="${SKILL_DIR}/ci-job-filters.txt"

MAX_WAIT_SECONDS=600
START_TIME=$(date +%s)

log_info() { echo "[WAIT] $1" >&2; }
log_success() { echo "✓ $1" >&2; }
log_error() { echo "✗ $1" >&2; }
log_warn() { echo "⚠ $1" >&2; }

time_remaining() {
  local elapsed=$(($(date +%s) - START_TIME))
  echo $((MAX_WAIT_SECONDS - elapsed))
}

is_timed_out() {
  [ "$(time_remaining)" -le 0 ]
}

load_ci_filters() {
  if [ ! -f "$CI_FILTERS_FILE" ]; then
    echo ""
    return 0
  fi
  grep -v '^[[:space:]]*#' "$CI_FILTERS_FILE" | grep -v '^[[:space:]]*$' || true
}

is_ignored_job() {
  local job_name="$1"
  local job_name_lower
  job_name_lower=$(echo "$job_name" | tr '[:upper:]' '[:lower:]')
  local filters
  filters=$(load_ci_filters)

  [ -z "$filters" ] && return 1

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    local pattern_lower
    pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
    local regex
    regex=$(printf '%s' "$pattern_lower" | sed 's/\*/.*/g')
    if [[ "$job_name_lower" =~ ^${regex}$ ]]; then
      return 0
    fi
  done <<< "$filters"

  return 1
}

wait_for_ci() {
  local repo="$1"
  local pr_number="$2"
  local poll_interval=15

  log_info "Waiting for CI checks on PR #${pr_number} (max $(time_remaining)s)..."

  local ci_complete=0

  while ! is_timed_out; do
    local rollup_output
    rollup_output=$(gh pr view "$pr_number" --repo "$repo" --json statusCheckRollup 2>/dev/null || echo "")

    if [ -z "$rollup_output" ]; then
      log_info "No checks found yet ($(time_remaining)s remaining)"
      sleep "$poll_interval"
      continue
    fi

    local pending=0
    local failed=""
    local passed=0
    local pending_jobs=""

    while IFS=$'\t' read -r name status conclusion; do
      [ -z "$name" ] && continue

      if is_ignored_job "$name"; then
        continue
      fi

      case "$status" in
        COMPLETED|SUCCESS)
          case "$conclusion" in
            failure|timed_out|cancelled|action_required)
              failed="${failed}  - ${name} (${conclusion})\n"
              ;;
            *)
              passed=$((passed + 1))
              ;;
          esac
          ;;
        PENDING|QUEUED|IN_PROGRESS|WAITING|REQUESTED)
          pending=$((pending + 1))
          pending_jobs="${pending_jobs}  - ${name} (${status})\n"
          ;;
      esac
    done < <(echo "$rollup_output" | jq -r '
      .statusCheckRollup[] | 
      select(.name != null or .context != null) | 
      "\(.name // .context)\t\(.status // .state)\t\(.conclusion // "")"
    ')

    if [ -n "$failed" ]; then
      log_error "CI failed:\n${failed}"
      return 1
    fi

    if [ "$pending" -eq 0 ]; then
      log_success "All CI checks passed (${passed} check(s))"
      ci_complete=1
      break
    fi

    log_info "Waiting for ${pending} check(s) (${passed} passed) ($(time_remaining)s remaining)"
    sleep "$poll_interval"
  done

  if [ "$ci_complete" -eq 0 ]; then
    log_warn "CI timeout after ${MAX_WAIT_SECONDS}s"
    if [ -n "$pending_jobs" ]; then
      log_warn "Still pending:\n${pending_jobs}"
    fi
    log_warn "Agent should alert user: CI checks did not complete in time"
    return 2
  fi

  return 0
}

wait_for_ai_reviews() {
  local repo="$1"
  local pr_number="$2"
  local max_wait=600
  local poll_interval=15
  local start_time=$(date +%s)

  log_info "Checking for running AI bot reviews (max ${max_wait}s)..."

  while true; do
    local elapsed=$(($(date +%s) - start_time))
    [ "$elapsed" -ge "$max_wait" ] && break

    local sha=""
    local running_reviews=0
    local pending_reviews=0

    sha=$(gh pr view "$pr_number" --repo "$repo" --json headRefOid -q '.headRefOid' 2>/dev/null || echo "")

    if [ -n "$sha" ]; then
      running_reviews=$(gh api "repos/${repo}/actions/runs?head_sha=${sha}" 2>/dev/null | jq -r '
        [.workflow_runs[] | select(.status != "completed") | .name] | length
      ' || echo "0")

      pending_reviews=$(gh pr view "$pr_number" --repo "$repo" --json reviewRequests -q '
        [.reviewRequests[] | select(.requestedReviewer.login | test("copilot|coderabbit|cubic|gemini"; "i"))] | length
      ' 2>/dev/null || echo "0")
    fi

    if [ "$running_reviews" -gt 0 ] || [ "$pending_reviews" -gt 0 ]; then
      local remaining=$((max_wait - elapsed))
      log_info "AI bot reviews in progress: ${running_reviews} running, ${pending_reviews} requested (${remaining}s remaining)"
      sleep "$poll_interval"
      continue
    fi

    log_success "No running AI bot reviews detected"
    return 0
  done

  log_warn "AI review wait timeout after ${max_wait}s - proceeding"
  return 0
}

main() {
  command -v jq &>/dev/null || { log_error "jq required"; exit 1; }
  command -v gh &>/dev/null || { log_error "gh required"; exit 1; }

  local pr_number=""
  local target_repo=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --repo)
        [[ $# -lt 2 || "$2" == -* ]] && { log_error "--repo requires value"; exit 1; }
        target_repo="$2"
        shift 2
        ;;
      -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
      *)
        [ -z "$pr_number" ] && pr_number="$1"
        shift
        ;;
    esac
  done

  [ -z "$pr_number" ] && { log_error "PR number required"; exit 1; }

  local owner_repo="$target_repo"
  if [ -z "$owner_repo" ]; then
    if [ -f "${SCRIPT_DIR}/pr-resolver-utils.sh" ]; then
      source "${SCRIPT_DIR}/pr-resolver-utils.sh"
      owner_repo=$(get_effective_repo "")
    else
      owner_repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
    fi
  fi

  [ -z "$owner_repo" ] && { log_error "Could not determine repository"; exit 1; }

  local ci_result=0
  wait_for_ci "$owner_repo" "$pr_number" || ci_result=$?

  case "$ci_result" in
    0) ;;
    1) log_error "CI failed - fix issues before fetching comments"; exit 1 ;;
    2) log_warn "CI timeout - alert user recommended"; exit 2 ;;
    *) log_error "Unexpected error"; exit 1 ;;
  esac

  wait_for_ai_reviews "$owner_repo" "$pr_number"

  log_success "Ready to fetch PR comments"
  exit 0
}

main "$@"
