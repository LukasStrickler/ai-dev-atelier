#!/bin/bash
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

is_release_command() {
  local cmd="$1"
  
  # Block by file path/name (release.yml) with word boundaries
  [[ "$cmd" =~ gh[[:space:]]+workflow[[:space:]]+run[[:space:]]+.*\brelease\.yml\b ]] && return 0
  # Also block invoking the workflow by its display name ("Release")
  [[ "$cmd" =~ gh[[:space:]]+workflow[[:space:]]+run[[:space:]]+[\"\']*Release[\"\']* ]] && return 0
  [[ "$cmd" =~ gh[[:space:]]+release[[:space:]]+create ]] && return 0
  
  return 1
}

has_bypass() {
  [[ "$1" == *"BYPASS_RELEASE:"* ]]
}

main() {
  local cmd
  cmd=$(get_command) || exit 0
  [ -z "$cmd" ] && exit 0
  
  is_release_command "$cmd" || exit 0
  has_bypass "$cmd" && exit 0
  
  cat >&2 <<EOF
🚫 BLOCKED: Releases require human approval.

Detected: $cmd

AI agents cannot trigger releases directly.

Agent: Provide a copy-pastable command for the human to run:
  gh workflow run release.yml -f version=X.Y.Z

Bypass (not recommended): # BYPASS_RELEASE: <reason>
EOF
  exit 2
}

main
