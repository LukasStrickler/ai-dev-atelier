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
    local pattern_lower regex
    pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
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
  local pending_jobs=""

  log_info "Waiting for CI checks on PR #${pr_number} (max $(time_remaining)s)..."

  local empty_output_count=0
  local last_checks=""

  while ! is_timed_out; do
    local checks_output
    checks_output=$(gh pr checks "$pr_number" --repo "$repo" 2>/dev/null || echo "")

    if [ -z "$checks_output" ]; then
      empty_output_count=$((empty_output_count + 1))
      log_info "No checks found yet ($(time_remaining)s remaining)"
      sleep "$poll_interval"
      
      # If checks output is empty for 3 consecutive polls (45s), 
      # check if there are any workflow runs at all
      if [ "$empty_output_count" -ge 3 ]; then
        local workflow_runs
        workflow_runs=$(gh api "repos/${repo}/actions/runs?per_page=10&event=pull_request" 2>/dev/null || echo "")
        if [ -n "$workflow_runs" ]; then
          # Has workflow runs but no checks - assume they're still running
          log_warn "Workflow runs found but no check results - jobs likely in progress"
          # Don't exit, continue waiting for checks to appear
          continue
        fi
        # No workflow runs either - genuinely no CI or PR is stale
        if [ "$empty_output_count" -ge 6 ]; then
          log_warn "No checks or workflow runs found after 90s - assuming CI not configured"
          return 0  # Not a CI failure, just no CI
        fi
      fi
      continue
    fi

    # Reset counter if we got actual output
    empty_output_count=0
    last_checks="$checks_output"

    local pending=0
    local failed=""
    pending_jobs=""

    while IFS=$'\t' read -r name status _; do
      [ -z "$name" ] && continue
      if is_ignored_job "$name"; then
        continue
      fi

      case "$status" in
        pass|success|skipping|neutral) ;;
        pending|in_progress|queued|waiting)
          pending=$((pending + 1))
          pending_jobs="${pending_jobs}\n  - ${name} (${status})"
          ;;
        fail|failure|cancelled|timed_out|action_required)
          failed="${failed}\n  - ${name} (${status})"
          ;;
      esac
    done <<< "$checks_output"

    if [ -n "$failed" ]; then
      log_error "CI failed:${failed}"
      return 1
    fi

    if [ "$pending" -eq 0 ]; then
      log_success "All CI checks passed"
      return 0
    fi

    log_info "Waiting for ${pending} check(s) ($(time_remaining)s remaining)"
    sleep "$poll_interval"
  done

  log_warn "CI timeout after ${MAX_WAIT_SECONDS}s"
  if [ -n "$pending_jobs" ]; then
    log_warn "Still pending:${pending_jobs}"
  fi
  log_warn "Agent should alert user: CI checks did not complete in time"
  return 2
}

wait_for_ai_reviews() {
  local repo="$1"
  local pr_number="$2"
  local max_wait=300
  local start=$(date +%s)

  log_info "Waiting for AI reviews to complete..."

  while [ $(($(date +%s) - start)) -lt "$max_wait" ]; do
    # Check for ACTIVE bot tasks (Review Requests in progress or Check Runs in progress)
    local active_bots
    active_bots=$(gh pr view "$pr_number" --repo "$repo" --json reviewRequests,statusCheckRollup --jq '
      [
        (.reviewRequests[] | select(.type == "Bot" or (.login | endswith("[bot]"))),
        (.statusCheckRollup[] | select(.status != "COMPLETED") | select(.name | ascii_downcase | test("coderabbit|copilot|gemini|ai-review")))
      ] | unique | .[]' 2>/dev/null)

    if [ -z "$active_bots" ]; then
      # No active bots found. Check if any bot has ALREADY posted a review
      local finished_bots
      finished_bots=$(gh api "repos/${repo}/pulls/${pr_number}/reviews" \
        --jq '.[] | select(.user.type == "Bot" or (.user.login | endswith("[bot]")))' 2>/dev/null)
      
      if [ -n "$finished_bots" ]; then
        log_success "AI reviews complete."
        return 0
      fi
      
      # No active bots AND no finished reviews yet. Wait at least 60s before proceeding.
      local elapsed=$(($(date +%s) - start))
      if [ "$elapsed" -ge 60 ]; then
        log_info "No AI bots detected after ${elapsed}s. Proceeding."
        return 0
      fi
    else
      log_info "Active AI reviews: $(echo "$active_bots" | tr '\n' ' ')"
    fi

    sleep 15
  done

  log_warn "Timed out waiting for AI reviews. Proceeding anyway."
  return 0
}

main() {
  command -v jq &>/dev/null || { log_error "jq required"; exit 1; }
  command -v gh &>/dev/null || { log_error "gh required"; exit 1; }
  gh auth status &>/dev/null || { log_error "gh not authenticated"; exit 1; }

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
    2) log_warn "CI timeout - alerting user recommended"; exit 2 ;;
    *) log_error "Unexpected error"; exit 1 ;;
  esac

  wait_for_ai_reviews "$owner_repo" "$pr_number"

  log_success "Ready to fetch PR comments"
  exit 0
}

main "$@"
