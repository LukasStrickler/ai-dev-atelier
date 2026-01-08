#!/bin/bash
# PreToolUse hook for blocking direct gh cli/api calls for PR comments
# Blocks wasteful token-heavy calls that should use pr-resolver.sh instead
#
# IMPORTANT: Only blocks calls to the CURRENT repository's OPEN/DRAFT PRs.
# - Closed/merged PRs: ALLOWED (historical research)
# - External repo queries: ALLOWED (for research, examples, etc.)
#
# Input: JSON via stdin (oh-my-opencode / Claude Code format)
# Output: Exit 0 = allow, Exit 2 + stderr = block

set -euo pipefail

STDIN_DATA=$(cat)

get_command() {
  [[ -z "${STDIN_DATA:-}" ]] && return
  if command -v jq &>/dev/null; then
    jq -r '.tool_input.command // empty' 2>/dev/null <<< "$STDIN_DATA"
  else
    sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<< "$STDIN_DATA" 2>/dev/null | head -1
  fi
}

CURRENT_REPO=""
get_current_repo() {
  [[ -n "$CURRENT_REPO" ]] && { echo "$CURRENT_REPO"; return 0; }
  
  local remote_url
  remote_url=$(git config --get remote.origin.url 2>/dev/null) || return 1
  
  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+?)(\.git)?$ ]]; then
    CURRENT_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    CURRENT_REPO="${CURRENT_REPO%.git}"
    CURRENT_REPO="${CURRENT_REPO,,}"
    echo "$CURRENT_REPO"
    return 0
  fi
  return 1
}

is_pr_open() {
  local pr_number="$1"
  command -v gh &>/dev/null || return 1
  
  local pr_state
  pr_state=$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null) || return 1
  [[ "$pr_state" == "OPEN" ]]
}

check_blocked() {
  local cmd="$1"
  
  [[ "$cmd" != gh\ * ]] && return 1
  
  local current_repo pr_number="" blocked_pattern="" is_current_repo=false
  
  if [[ "$cmd" =~ ^gh\ pr\ view\ ([0-9]+).*--json\ +([^#]+) ]]; then
    local pr_num="${BASH_REMATCH[1]}"
    local json_fields="${BASH_REMATCH[2]}"
    
    local field
    for field in ${json_fields//,/ }; do
      field="${field## }"; field="${field%% }"
      if [[ "$field" == "comments" || "$field" == "reviews" ]]; then
        pr_number="$pr_num"
        blocked_pattern="gh pr view --json comments/reviews"
        is_current_repo=true
        break
      fi
    done
  fi
  
  if [[ -z "$blocked_pattern" && "$cmd" =~ ^gh\ pr\ view\ ([0-9]+).*--comments ]]; then
    pr_number="${BASH_REMATCH[1]}"
    blocked_pattern="gh pr view --comments"
    is_current_repo=true
  fi
  
  if [[ -z "$blocked_pattern" && "$cmd" =~ ^gh\ api\ (.+) ]]; then
    local api_args="${BASH_REMATCH[1]}"
    local api_path="$api_args"
    
    while [[ "$api_path" == -* ]]; do
      api_path="${api_path#* }"
    done
    api_path="${api_path%% *}"
    api_path="${api_path#/}"
    
    if [[ "$api_path" =~ ^repos/([^/]+/[^/]+)/pulls/([0-9]+)/(comments|reviews)$ ]]; then
      local target_repo="${BASH_REMATCH[1],,}"
      current_repo=$(get_current_repo) || return 1
      
      if [[ "$target_repo" == "$current_repo" ]]; then
        pr_number="${BASH_REMATCH[2]}"
        blocked_pattern="gh api .../pulls/N/${BASH_REMATCH[3]}"
        is_current_repo=true
      else
        return 1
      fi
    elif [[ "$api_path" =~ ^pulls/([0-9]+)/(comments|reviews)$ ]]; then
      pr_number="${BASH_REMATCH[1]}"
      blocked_pattern="gh api pulls/N/${BASH_REMATCH[2]}"
      is_current_repo=true
    fi
  fi
  
  if [[ -z "$blocked_pattern" && "$cmd" =~ gh\ api\ graphql.*-f\ query=.*pullRequest ]]; then
    current_repo=${current_repo:-$(get_current_repo)} || return 1
    local owner="${current_repo%%/*}"
    local repo="${current_repo##*/}"
    if [[ "$cmd" == *"$current_repo"* ]] || [[ "$cmd" == *"\"$owner\""* && "$cmd" == *"\"$repo\""* ]]; then
      blocked_pattern="gh api graphql (pullRequest)"
      is_current_repo=true
    fi
  fi
  
  [[ -z "$blocked_pattern" ]] && return 1
  [[ "$is_current_repo" != "true" ]] && return 1
  
  if [[ -n "$pr_number" ]] && ! is_pr_open "$pr_number"; then
    return 1
  fi
  
  echo "${blocked_pattern}:/resolve-pr-comments"
  return 0
}

main() {
  local cmd
  cmd=$(get_command) || exit 0
  [[ -z "$cmd" ]] && exit 0
  
  [[ "$cmd" == *"BYPASS_PR_COMMENTS:"* ]] && exit 0
  
  local matched
  matched=$(check_blocked "$cmd") || exit 0
  
  local blocked_cmd="${matched%%:*}"
  local skill="${matched#*:}"
  
  cat >&2 <<EOF
⚠️ BLOCKED: Direct gh cli/api for PR comments wastes 10-50x tokens.

Instead of: $blocked_cmd
Use skill: $skill

The pr-resolver.sh script fetches, clusters, and deduplicates PR comments
into token-efficient actionable.json (500-2,000 tokens vs 10,000-50,000).

Correct workflow:
  1. bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER>
  2. Read .ada/data/pr-resolver/pr-<N>/actionable.json
  3. Spawn subagents per cluster

Load the skill for proper workflow:
  /skill resolve-pr-comments

Quick reference:
  pr-resolver.sh <N>  - Fetch and cluster PR comments
  pr-dismiss.sh <N>   - Dismiss resolved comments
  pr-resolve.sh <N>   - Mark threads as resolved

Note: This block only applies to OPEN PRs in this repo.
Closed/merged PRs and external repos are allowed.

Bypass (not recommended): # BYPASS_PR_COMMENTS: <reason>
EOF
  exit 2
}

main
