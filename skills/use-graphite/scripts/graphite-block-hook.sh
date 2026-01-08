#!/bin/bash
# PreToolUse hook for Graphite-enabled repos
# Blocks git/gh commands that conflict with stacked PR workflow
# 
# Input: JSON via stdin (oh-my-opencode / Claude Code format)
# Output: Exit 0 = allow, Exit 2 + stderr = block

set -euo pipefail

STDIN_DATA=$(cat)

get_command() {
  [ -z "${STDIN_DATA:-}" ] && return
  if command -v jq &>/dev/null; then
    jq -r '.tool_input.command // empty' 2>/dev/null <<< "$STDIN_DATA"
  else
    sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<< "$STDIN_DATA" 2>/dev/null | head -1
  fi
}

is_graphite_repo() {
  local git_dir main_git_dir
  
  command -v gt &>/dev/null || return 1
  
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1
  
  if [ -f "$git_dir/commondir" ]; then
    main_git_dir=$(cat "$git_dir/commondir")
    [[ "$main_git_dir" != /* ]] && main_git_dir="$git_dir/$main_git_dir"
  else
    main_git_dir="$git_dir"
  fi
  
  [ -f "$main_git_dir/.graphite_repo_config" ]
}

check_blocked() {
  local cmd="$1"
  
  case "$cmd" in
    "git push"|"git push "*)
      echo "git push:gt submit"
      return 0 ;;
    "git checkout -b"*|"git checkout --branch "*)
      echo "git checkout -b:gt create <branch>"
      return 0 ;;
    "gh pr create"|"gh pr create "*)
      echo "gh pr create:gt submit"
      return 0 ;;
    "git rebase "*|"git rebase")
      [[ "$cmd" =~ (^|[[:space:]])(-i|--interactive)([[:space:]]|$|=) ]] && return 1
      echo "git rebase:gt restack"
      return 0 ;;
    "git switch -c"*)
      echo "git switch -c:gt create <branch>"
      return 0 ;;
    "git branch "*)
      [[ "$cmd" =~ ^git\ branch\ (-d|-D|--delete|--list|-l|-a|--all|-r|--remotes|-v|--verbose) ]] && return 1
      echo "git branch <name>:gt create <branch>"
      return 0 ;;
  esac
  return 1
}

has_bypass() {
  [[ "$1" == *"BYPASS_GRAPHITE:"* ]]
}

main() {
  local cmd matched
  cmd=$(get_command) || exit 0
  [ -z "$cmd" ] && exit 0
  
  matched=$(check_blocked "$cmd") || exit 0
  has_bypass "$cmd" && exit 0
  is_graphite_repo || exit 0
  
  local blocked_cmd="${matched%%:*}"
  local alternative="${matched#*:}"
  
  cat >&2 <<EOF
⚠️ BLOCKED: This repository uses Graphite for stacked PRs.

Instead of: $blocked_cmd
Use: $alternative

Load the skill for proper Graphite workflow:
  /skill use-graphite

Quick reference:
  gt create <name>  - Create new branch in stack
  gt submit         - Push and create/update PRs
  gt restack        - Rebase stack on trunk
  gt log short      - View current stack

Bypass (not recommended): # BYPASS_GRAPHITE: <reason>
EOF
  exit 2
}

main
