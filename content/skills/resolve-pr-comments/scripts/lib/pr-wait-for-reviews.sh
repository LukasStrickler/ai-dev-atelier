#!/bin/bash
# Wait for PR CI and  AI reviews before fetching comments
# Returns: 0=ready, 1=CI failed, 2=timeout (with actionable guidance)
# Timeout: 10 minutes TOTAL for both CI and AI review phases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CI_FILTERS_FILE="${SKILL_DIR}/ci-job-filters.txt"

MAX_WAIT_SECONDS=600
POLL_INTERVAL=15
LOG_INTERVAL=60
START_TIME=$(date +%s)
LAST_LOG_TIME=$START_TIME

log() { echo "$1" >&2; }
log_progress() {
  local now remaining
  now=$(date +%s)
  remaining=$(time_remaining)
  if [ $((now - LAST_LOG_TIME)) -ge "$LOG_INTERVAL" ]; then
    LAST_LOG_TIME=$now
    log "[WAIT] ${remaining}s | $1"
  fi
}

time_remaining() { echo $((MAX_WAIT_SECONDS - $(date +%s) + START_TIME)); }
is_timed_out() { [ "$(time_remaining)" -le 0 ]; }

load_ci_filters() {
  [ ! -f "$CI_FILTERS_FILE" ] && return 0
  grep -v '^[[:space:]]*#' "$CI_FILTERS_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' || true
}

is_ignored_job() {
  local job_name_lower filters
  job_name_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  filters=$(load_ci_filters)
  [ -z "$filters" ] && return 1
  
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    local regex
    regex=$(echo "$pattern" | tr '[:upper:]' '[:lower:]' | sed 's/\*/.*/g')
    [[ "$job_name_lower" =~ ^${regex}$ ]] && return 0
  done <<< "$filters"
  return 1
}

get_ci_status() {
  local repo="$1" pr="$2"
  local rollup pending=0 passed=0 failed_jobs="" pending_jobs="" sha=""
  
  rollup=$(gh pr view "$pr" --repo "$repo" --json statusCheckRollup 2>/dev/null || echo "")
  [ -z "$rollup" ] && rollup='{"statusCheckRollup":[]}'
  
  declare -A seen_checks
  while IFS=$'\t' read -r name status conclusion; do
    [ -z "$name" ] && continue
    is_ignored_job "$name" && continue
    seen_checks["${name,,}"]=1
    
    case "$status" in
      COMPLETED|SUCCESS)
        case "$conclusion" in
          FAILURE|TIMED_OUT|CANCELLED|ACTION_REQUIRED)
            failed_jobs="${failed_jobs}${name} (${conclusion}), "
            ;;
          *) passed=$((passed + 1)) ;;
        esac
        ;;
      PENDING|QUEUED|IN_PROGRESS|WAITING|REQUESTED|"")
        pending=$((pending + 1))
        pending_jobs="${pending_jobs}${name}, "
        ;;
    esac
  done < <(echo "$rollup" | jq -r '.statusCheckRollup[] | select(.name != null or .context != null) | "\(.name // .context)\t\(.status // .state)\t\(.conclusion // "")"')
  
  sha=$(gh pr view "$pr" --repo "$repo" --json headRefOid -q '.headRefOid' 2>/dev/null || echo "")
  if [ -n "$sha" ]; then
    while IFS=$'\t' read -r name status conclusion; do
      [ -z "$name" ] && continue
      is_ignored_job "$name" && continue
      [ -n "${seen_checks["${name,,}"]+x}" ] && continue
      
      case "$status" in
        COMPLETED|SUCCESS)
          case "$conclusion" in
            FAILURE|TIMED_OUT|CANCELLED|ACTION_REQUIRED)
              failed_jobs="${failed_jobs}${name} (${conclusion}), "
              ;;
            *) passed=$((passed + 1)) ;;
          esac
          ;;
        PENDING|QUEUED|IN_PROGRESS|WAITING|REQUESTED|"")
          pending=$((pending + 1))
          pending_jobs="${pending_jobs}${name}, "
          ;;
      esac
    done < <(gh api "repos/${repo}/commits/${sha}/check-runs" 2>/dev/null | jq -r '.check_runs[] | "\(.name)\t\(.status // "")\t\(.conclusion // "")"' || true)
  fi
  
  [ -n "$failed_jobs" ] && echo "failed|$passed|$pending|${failed_jobs%, }|${pending_jobs%, }" && return
  [ "$pending" -eq 0 ] && echo "passed|$passed|0||" && return
  echo "pending|$passed|$pending||${pending_jobs%, }"
}

get_ai_review_status() {
  local repo="$1" pr="$2"
  local sha running=0 requested=0 running_names=""
  
  sha=$(gh pr view "$pr" --repo "$repo" --json headRefOid -q '.headRefOid' 2>/dev/null || echo "")
  [ -z "$sha" ] && echo "0|0|" && return
  
  while IFS=$'\t' read -r name status; do
    [ -z "$name" ] && continue
    running=$((running + 1))
    running_names="${running_names}${name}, "
  done < <(gh api "repos/${repo}/actions/runs?head_sha=${sha}" 2>/dev/null | jq -r '.workflow_runs[] | select(.status != "completed") | "\(.name)\t\(.status)"' || true)
  
  requested=$(gh api "repos/${repo}/pulls/${pr}/requested_reviewers" 2>/dev/null | jq -r '[.users[] | select(.type == "Bot") | .login] | length' || echo "0")
  
  echo "${running}|${requested}|${running_names%, }"
}

wait_for_all() {
  local repo="$1" pr="$2"
  local last_pending_jobs="" last_requested_bots=0
  
  log "[WAIT] PR #${pr}: Waiting for CI + AI reviews (max 10 min)"
  
  while ! is_timed_out; do
    local ci_result pending passed pending_jobs failed_jobs
    IFS='|' read -r ci_result passed pending failed_jobs pending_jobs <<< "$(get_ci_status "$repo" "$pr")"
    
    case "$ci_result" in
      failed)
        log "[FAIL] CI failed: $failed_jobs"
        return 1
        ;;
      pending)
        last_pending_jobs="$pending_jobs"
        ;;
    esac
    
    local running requested running_names
    IFS='|' read -r running requested running_names <<< "$(get_ai_review_status "$repo" "$pr")"
    last_requested_bots="$requested"
    
    if { [ "$ci_result" = "passed" ] || [ "$ci_result" = "none" ]; } && [ "$running" -eq 0 ] && [ "$requested" -eq 0 ]; then
      log "[OK] Ready to fetch comments"
      return 0
    fi
    
    if [ "$ci_result" = "passed" ]; then
      log_progress "CI: 0 pending, $passed passed | Bots: $requested requested"
    else
      log_progress "CI: $pending pending, $passed passed | Bots: $requested requested"
    fi
    
    sleep "$POLL_INTERVAL"
  done
  
  log ""
  log "[TIMEOUT] 10 minutes exceeded"
  log ""
  log "Check status:  gh pr checks $pr --repo $repo"
  log "Then either:   wait longer, OR re-run with --skip-wait \"<reason>\""
  [ -n "$last_pending_jobs" ] && log "Last pending:  $last_pending_jobs"
  [ "$last_requested_bots" -gt 0 ] && log "Pending bots:  $last_requested_bots"
  return 2
}

main() {
  command -v jq &>/dev/null || { log "✗ jq required"; exit 1; }
  command -v gh &>/dev/null || { log "✗ gh required"; exit 1; }

  local pr_number="" target_repo=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --repo)
        [[ $# -lt 2 || "$2" == -* ]] && { log "✗ --repo requires value"; exit 1; }
        target_repo="$2"; shift 2 ;;
      -*) log "✗ Unknown option: $1"; exit 1 ;;
      *) [ -z "$pr_number" ] && pr_number="$1"; shift ;;
    esac
  done

  [ -z "$pr_number" ] && { log "✗ PR number required"; exit 1; }

  local owner_repo="$target_repo"
  if [ -z "$owner_repo" ]; then
    if [ -f "${SCRIPT_DIR}/../pr-resolver-utils.sh" ]; then
      source "${SCRIPT_DIR}/../pr-resolver-utils.sh"
      owner_repo=$(get_effective_repo "")
    else
      owner_repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
    fi
  fi

  [ -z "$owner_repo" ] && { log "✗ Could not determine repository"; exit 1; }

  wait_for_all "$owner_repo" "$pr_number"
}

main "$@"
