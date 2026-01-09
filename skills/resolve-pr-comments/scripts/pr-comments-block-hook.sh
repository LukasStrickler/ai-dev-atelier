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

command -v jq &>/dev/null || { echo "jq required" >&2; exit 0; }

STDIN_DATA=$(cat)

get_command() {
  [[ -z "${STDIN_DATA:-}" ]] && return
  jq -r '.tool_input.command // empty' 2>/dev/null <<< "$STDIN_DATA"
}

get_current_repo() {
  local remote_url
  remote_url=$(git config --get remote.origin.url 2>/dev/null) || return 1
  
  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+?)(\.git)?$ ]]; then
    local repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    repo="${repo%.git}"
    echo "${repo,,}"
    return 0
  fi
  return 1
}

get_upstream_repo() {
  local repo_info
  repo_info=$(gh repo view --json isFork,parent --jq 'if .isFork then .parent.nameWithOwner else "" end' 2>/dev/null) || return 1
  
  if [[ -n "$repo_info" && "$repo_info" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "${repo_info,,}"
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
  
  local pr_number="" blocked_pattern="" needs_repo_check=false target_repo_from_cmd=""
  
  if [[ "$cmd" =~ ^gh\ pr\ view\ ([0-9]+).*--json[=\ ]+([^#]+) ]]; then
    local pr_num="${BASH_REMATCH[1]}"
    local json_fields="${BASH_REMATCH[2]}"
    
    local field
    for field in ${json_fields//,/ }; do
      field="${field## }"; field="${field%% }"
      if [[ "$field" == "comments" || "$field" == "reviews" ]]; then
        pr_number="$pr_num"
        blocked_pattern="gh pr view --json comments/reviews"
        needs_repo_check=true
        break
      fi
    done
  fi
  
  if [[ -z "$blocked_pattern" && "$cmd" =~ ^gh\ pr\ view\ ([0-9]+).*--comments ]]; then
    pr_number="${BASH_REMATCH[1]}"
    blocked_pattern="gh pr view --comments"
    needs_repo_check=true
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
      target_repo_from_cmd="${BASH_REMATCH[1],,}"
      pr_number="${BASH_REMATCH[2]}"
      blocked_pattern="gh api .../pulls/N/${BASH_REMATCH[3]}"
      needs_repo_check=true
    elif [[ "$api_path" =~ ^pulls/([0-9]+)/(comments|reviews)$ ]]; then
      pr_number="${BASH_REMATCH[1]}"
      blocked_pattern="gh api pulls/N/${BASH_REMATCH[2]}"
      needs_repo_check=true
    fi
  fi
  
  if [[ -z "$blocked_pattern" && "$cmd" =~ gh\ api\ graphql.*-f\ query=.*pullRequest ]]; then
    blocked_pattern="gh api graphql (pullRequest)"
    needs_repo_check=true
  fi
  
  [[ -z "$blocked_pattern" ]] && return 1
  [[ "$needs_repo_check" != "true" ]] && return 1
  
  local current_repo upstream_repo=""
  current_repo=$(get_current_repo) || return 1
  upstream_repo=$(get_upstream_repo 2>/dev/null || echo "")
  
  if [[ -n "$target_repo_from_cmd" ]]; then
    if [[ "$target_repo_from_cmd" != "$current_repo" ]] && [[ "$target_repo_from_cmd" != "$upstream_repo" ]]; then
      return 1
    fi
  fi
  
  if [[ "$blocked_pattern" == "gh api graphql (pullRequest)" ]]; then
    local owner="${current_repo%%/*}"
    local repo="${current_repo##*/}"
    local matches_current=false
    if [[ "$cmd" == *"$current_repo"* ]] || \
       [[ "$cmd" =~ owner:\ *\"$owner\".*name:\ *\"$repo\" ]] || \
       [[ "$cmd" =~ name:\ *\"$repo\".*owner:\ *\"$owner\" ]]; then
      matches_current=true
    fi
    if [[ -n "$upstream_repo" ]]; then
      local up_owner="${upstream_repo%%/*}"
      local up_repo="${upstream_repo##*/}"
      if [[ "$cmd" == *"$upstream_repo"* ]] || \
         [[ "$cmd" =~ owner:\ *\"$up_owner\".*name:\ *\"$up_repo\" ]] || \
         [[ "$cmd" =~ name:\ *\"$up_repo\".*owner:\ *\"$up_owner\" ]]; then
        matches_current=true
      fi
    fi
    [[ "$matches_current" != "true" ]] && return 1
  fi
  
  if [[ -n "$pr_number" ]] && ! is_pr_open "$pr_number"; then
    return 1
  fi
  
  if [[ -n "$upstream_repo" ]]; then
    echo "${blocked_pattern}:/resolve-pr-comments:fork:${upstream_repo}"
  else
    echo "${blocked_pattern}:/resolve-pr-comments"
  fi
  return 0
}

main() {
  local cmd
  cmd=$(get_command) || exit 0
  [[ -z "$cmd" ]] && exit 0
  
  [[ "$cmd" == *"BYPASS_PR_COMMENTS:"* ]] && exit 0
  
  local matched
  matched=$(check_blocked "$cmd") || exit 0
  
  local blocked_cmd skill is_fork upstream_repo
  blocked_cmd="${matched%%:/*}"
  local rest="${matched#*/}"
  skill="${rest%%:*}"
  
  is_fork=false
  upstream_repo=""
  if [[ "$rest" == *":fork:"* ]]; then
    is_fork=true
    upstream_repo="${rest##*:fork:}"
  fi
  
  if [[ "$is_fork" == "true" ]]; then
    cat >&2 <<EOF
BLOCKED: Direct gh cli/api for PR comments wastes 10-50x tokens.

Detected FORK of: $upstream_repo
PRs to upstream require --repo flag.

Instead of: $blocked_cmd
Use skill: $skill

Correct workflow for forks:
  1. bash skills/resolve-pr-comments/scripts/pr-resolver.sh <PR_NUMBER> --repo $upstream_repo
  2. Read .ada/data/pr-resolver/pr-<N>/actionable.json
  3. Spawn subagents per cluster

Load the skill for proper workflow:
  /skill resolve-pr-comments

Note: This block applies to OPEN PRs in this repo AND its upstream.
Closed/merged PRs and unrelated repos are allowed.

Bypass (not recommended): # BYPASS_PR_COMMENTS: <reason>
EOF
  else
    cat >&2 <<EOF
BLOCKED: Direct gh cli/api for PR comments wastes 10-50x tokens.

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
  fi
  exit 2
}

main
