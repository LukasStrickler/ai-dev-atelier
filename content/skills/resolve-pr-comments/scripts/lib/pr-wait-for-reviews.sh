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

get_required_checks() {
  local repo="$1" pr="$2" base_ref
  base_ref=$(gh pr view "$pr" --repo "$repo" --json baseRefName -q '.baseRefName' 2>/dev/null || echo "")
  [ -z "$base_ref" ] && return 0

  {
    gh api "repos/${repo}/rules/branches/${base_ref}" 2>/dev/null | jq -r '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[]? | .context' || true
    gh api "repos/${repo}/branches/${base_ref}/protection/required_status_checks" 2>/dev/null | jq -r '.contexts[]?, .checks[]?.context' || true
  } | awk 'NF' | sort -u
}

get_ci_status() {
  local repo="$1" pr="$2"
  local rollup failed_jobs="" pending_jobs="" sha=""
  local pending=0 passed=0
  local missing_required=()
  
  declare -A check_state
  declare -A check_name
  record_state() {
    local name="$1" state="$2" key value current
    key="${name,,}"
    case "$state" in
      failed) value=2 ;;
      pending) value=1 ;;
      passed) value=0 ;;
      *) return ;;
    esac
    current="${check_state[$key]-}"
    if [ -z "$current" ] || [ "$value" -gt "$current" ]; then
      check_state[$key]="$value"
      check_name[$key]="$name"
    fi
  }
  
  rollup=$(gh pr view "$pr" --repo "$repo" --json statusCheckRollup 2>/dev/null || echo "")
  [ -z "$rollup" ] && rollup='{"statusCheckRollup":[]}'
  
  while IFS=$'\t' read -r name status conclusion; do
    [ -z "$name" ] && continue
    is_ignored_job "$name" && continue
    
    case "$status" in
      COMPLETED|SUCCESS)
        case "$conclusion" in
          FAILURE|TIMED_OUT|CANCELLED|ACTION_REQUIRED) record_state "$name" failed ;;
          *) record_state "$name" passed ;;
        esac
        ;;
      PENDING|QUEUED|IN_PROGRESS|WAITING|REQUESTED|"")
        record_state "$name" pending
        ;;
    esac
  done < <(echo "$rollup" | jq -r '.statusCheckRollup[] | select(.name != null or .context != null) | "\(.name // .context)\t\(.status // .state)\t\(.conclusion // "")"')
  
  sha=$(gh pr view "$pr" --repo "$repo" --json headRefOid -q '.headRefOid' 2>/dev/null || echo "")
  if [ -n "$sha" ]; then
    while IFS=$'\t' read -r name status conclusion; do
      [ -z "$name" ] && continue
      is_ignored_job "$name" && continue
      
      case "$status" in
        COMPLETED|SUCCESS)
          case "$conclusion" in
            FAILURE|TIMED_OUT|CANCELLED|ACTION_REQUIRED) record_state "$name" failed ;;
            *) record_state "$name" passed ;;
          esac
          ;;
        PENDING|QUEUED|IN_PROGRESS|WAITING|REQUESTED|"")
          record_state "$name" pending
          ;;
      esac
    done < <(gh api "repos/${repo}/commits/${sha}/check-runs" 2>/dev/null | jq -r '.check_runs[] | "\(.name)\t\(.status // "")\t\(.conclusion // "")"' || true)
    
    while IFS=$'\t' read -r name status; do
      [ -z "$name" ] && continue
      is_ignored_job "$name" && continue
      
      case "$status" in
        success) record_state "$name" passed ;;
        failure|error) record_state "$name" failed ;;
        pending) record_state "$name" pending ;;
      esac
    done < <(gh api "repos/${repo}/commits/${sha}/status" 2>/dev/null | jq -r '.statuses[] | "\(.context)\t\(.state)"' || true)
  fi
  
  while IFS=$'\t' read -r name bucket; do
    [ -z "$name" ] && continue
    is_ignored_job "$name" && continue
    
    case "$bucket" in
      pass) record_state "$name" passed ;;
      fail|cancel) record_state "$name" failed ;;
      pending) record_state "$name" pending ;;
    esac
  done < <((gh pr checks "$pr" --repo "$repo" --json name,bucket 2>/dev/null || true) | jq -r '.[] | "\(.name)\t\(.bucket // "")"')
  
  for key in "${!check_state[@]}"; do
    case "${check_state[$key]}" in
      2) failed_jobs="${failed_jobs}${check_name[$key]} (FAILURE), " ;;
      1)
        pending_jobs="${pending_jobs}${check_name[$key]}, "
        pending=$((pending + 1))
        ;;
      0) passed=$((passed + 1)) ;;
    esac
  done
  
  while IFS= read -r required_check; do
    [ -z "$required_check" ] && continue
    is_ignored_job "$required_check" && continue
    if [ -z "${check_state["${required_check,,}"]+x}" ]; then
      pending=$((pending + 1))
      pending_jobs="${pending_jobs}${required_check}, "
      missing_required+=("$required_check")
    fi
  done < <(get_required_checks "$repo" "$pr")
  
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
  local last_pending_jobs="" last_requested_bots=0 ci_failed_jobs=""
  local ci_failed=false
  local first_iteration=true
  
  log "[WAIT] PR #${pr}: Waiting for CI + AI reviews (max 10 min)"
  log "[DEBUG] repo='$repo' pr='$pr'"
  
  while ! is_timed_out; do
    local ci_result pending passed pending_jobs failed_jobs
    local ci_raw
    ci_raw="$(get_ci_status "$repo" "$pr")"
    IFS='|' read -r ci_result passed pending failed_jobs pending_jobs <<< "$ci_raw"
    
    # Debug: log first iteration values to understand instant returns
    if $first_iteration; then
      log "[DEBUG] CI raw='$ci_raw'"
      log "[DEBUG] ci_result='$ci_result' passed='$passed' pending='$pending'"
    fi
    
    case "$ci_result" in
      failed)
        if ! $ci_failed; then
          log "[FAIL] CI failed: $failed_jobs"
        fi
        ci_failed=true
        ci_failed_jobs="$failed_jobs"
        ;;
      pending)
        last_pending_jobs="$pending_jobs"
        ;;
    esac
    
    local running requested running_names
    local ai_raw
    ai_raw="$(get_ai_review_status "$repo" "$pr")"
    IFS='|' read -r running requested running_names <<< "$ai_raw"
    last_requested_bots="$requested"
    
    # Debug: log first iteration AI values
    if $first_iteration; then
      log "[DEBUG] AI raw='$ai_raw'"
      log "[DEBUG] running='$running' requested='$requested'"
      first_iteration=false
    fi
    
    if [ "$pending" -eq 0 ] && [ "$running" -eq 0 ] && [ "$requested" -eq 0 ]; then
      if $ci_failed || [ "$ci_result" = "failed" ]; then
        log "[FAIL] CI failed: $ci_failed_jobs"
      fi
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
