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
  local TEXT_CMDS="echo|printf|cat|grep|egrep|fgrep|awk|sed|less|more|head|tail|wc|cut|tr|sort|uniq|diff|cmp|file|strings|od|hexdump|xxd|base64"
  local END='([[:space:]]|$|[]"'"'"'`);|&><[])'
  local pattern line
  local WRITE_INDICATORS='(-X[[:space:]]*([Pp][Oo][Ss][Tt]|[Pp][Uu][Tt]|[Pp][Aa][Tt][Cc][Hh]|[Dd][Ee][Ll][Ee][Tt][Ee])|--request([[:space:]]|=)*([Pp][Oo][Ss][Tt]|[Pp][Uu][Tt]|[Pp][Aa][Tt][Cc][Hh]|[Dd][Ee][Ll][Ee][Tt][Ee])|--method([[:space:]]|=)*([Pp][Oo][Ss][Tt]|[Pp][Uu][Tt]|[Pp][Aa][Tt][Cc][Hh]|[Dd][Ee][Ll][Ee][Tt][Ee])|--json([[:space:]]|=)|--data([[:space:]]|=|@)|--data-raw([[:space:]]|=|@)|--data-urlencode([[:space:]]|=|@)|--data-ascii([[:space:]]|=|@)|-d([[:space:]]|=|@|[^[:space:]])|--data-binary([[:space:]]|=|@)|--form([[:space:]]|=|@)|-F([[:space:]]|=|@|[^[:space:]])|--upload-file([[:space:]]|=|@)|-T([[:space:]]|=|@|[^[:space:]])|--post-data([[:space:]]|=|@)|--post-file([[:space:]]|=|@))'
  
  cmd="${cmd//$'\u200B'/ }"
  cmd="${cmd//$'\u200C'/ }"
  cmd="${cmd//$'\u200D'/ }"
  cmd="${cmd//$'\uFEFF'/ }"
  cmd="${cmd//$'\u00A0'/ }"
  cmd="${cmd//\\ / }"
  cmd="${cmd//$'\047\047'/}"
  cmd="${cmd//$'\"\"'/}"
  
  [[ "$cmd" =~ --help ]] && return 1
  
  if [[ "$cmd" =~ (at|batch|crontab)[[:space:]].*gh[[:space:]]+(release|workflow) ]]; then
    return 0
  fi
  if [[ "$cmd" =~ \|[[:space:]]*(at|batch|crontab) ]] && [[ "$cmd" =~ gh[[:space:]]+(release|workflow) ]]; then
    return 0
  fi
  
  if [[ "$cmd" =~ (docker|podman)[[:space:]]+(run|exec) ]] && [[ "$cmd" =~ gh[[:space:]]+(workflow|release) ]]; then
    return 0
  fi
  
  if [[ "$cmd" =~ (socat|ncat|nc|telnet|openssl)[[:space:]].*api\.github\.com ]]; then
    return 0
  fi
  
  # curl/wget to releases endpoint - only block write operations
  if [[ "$cmd" =~ (curl|wget)[[:space:]].*api\.github\.com.*/releases ]]; then
    # Block if it has write indicators
    if [[ "$cmd" =~ $WRITE_INDICATORS ]]; then
      return 0
    fi
    # Allow GET requests (default behavior)
  fi
  if [[ "$cmd" =~ (curl|wget)[[:space:]].*api\.github\.com.*/dispatches ]]; then
    # Block if it has write indicators
    if [[ "$cmd" =~ $WRITE_INDICATORS ]]; then
      return 0
    fi
    # Allow GET requests (default behavior)
  fi

  # httpie to releases endpoint - block explicit methods or implicit POST with data fields
  if [[ "$cmd" =~ (http|https)[[:space:]].*api\.github\.com.*/releases ]]; then
    if [[ "$cmd" =~ (http|https)[[:space:]].*(-f([[:space:]]|$)|--form([[:space:]]|=|$)|--multipart([[:space:]]|=|$)|--json([[:space:]]|=|$)) ]] || [[ "$cmd" =~ ([[:space:]]|^)-j([[:space:]]|$) ]]; then
      return 0
    fi
    if [[ "$cmd" =~ ([Pp][Oo][Ss][Tt]|[Pp][Uu][Tt]|[Pp][Aa][Tt][Cc][Hh]|[Dd][Ee][Ll][Ee][Tt][Ee])[[:space:]]+(https?://)?api\.github\.com ]]; then
      return 0
    fi
    if [[ "$cmd" =~ (http|https)[[:space:]]+[^[:space:]]*api\.github\.com[^[:space:]]*/releases[^[:space:]]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*(:=|=([^=]|$)) ]]; then
      return 0
    fi
  fi
  if [[ "$cmd" =~ (http|https)[[:space:]].*api\.github\.com.*/dispatches ]]; then
    if [[ "$cmd" =~ (http|https)[[:space:]].*(-f([[:space:]]|$)|--form([[:space:]]|=|$)|--multipart([[:space:]]|=|$)|--json([[:space:]]|=|$)) ]] || [[ "$cmd" =~ ([[:space:]]|^)-j([[:space:]]|$) ]]; then
      return 0
    fi
    if [[ "$cmd" =~ ([Pp][Oo][Ss][Tt]|[Pp][Uu][Tt]|[Pp][Aa][Tt][Cc][Hh]|[Dd][Ee][Ll][Ee][Tt][Ee])[[:space:]]+(https?://)?api\.github\.com ]]; then
      return 0
    fi
    if [[ "$cmd" =~ (http|https)[[:space:]]+[^[:space:]]*api\.github\.com[^[:space:]]*/dispatches[^[:space:]]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*(:=|=([^=]|$)) ]]; then
      return 0
    fi
  fi
  
  # gh api releases - only block write operations (POST, PUT, PATCH, DELETE, -f data)
  if [[ "$cmd" =~ gh[[:space:]]+api.*/releases ]]; then
    # Block if it has write indicators
    if [[ "$cmd" =~ (-X[[:space:]]*(POST|PUT|PATCH|DELETE)|--method[[:space:]]*(POST|PUT|PATCH|DELETE)|-f[[:space:]]|-F[[:space:]]|--field[[:space:]]|--raw-field[[:space:]]) ]]; then
      return 0
    fi
    # Allow GET requests (default behavior)
  fi
  if [[ "$cmd" =~ gh[[:space:]]+api.*dispatches ]]; then
    return 0
  fi
  if [[ "$cmd" =~ gh[[:space:]]+api.*graphql.*[Rr]elease ]]; then
    return 0
  fi
  
  if [[ "$cmd" =~ (curl|wget|http|https).*api\.github\.com/graphql.*[Rr]elease ]]; then
    return 0
  fi
  if [[ "$cmd" =~ (curl|wget|http|https).*api\.github\.com/graphql.*createRelease ]]; then
    return 0
  fi
  
  if [[ "$cmd" =~ hub[[:space:]]+release[[:space:]]+create ]]; then
    return 0
  fi
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    local normalized="${line//\\/}"
    normalized="${normalized//\'\'/}"
    normalized="${normalized//\"\"/}"
    
    pattern="gh[[:space:]]+workflow[[:space:]]+run[[:space:]]+(--[a-z-]+[[:space:]]+)*[\"']*([^[:space:]]*/)?release\.yml[\"']*${END}"
    if [[ "$normalized" =~ $pattern ]]; then
      [[ "$normalized" =~ ^[[:space:]]*($TEXT_CMDS)[[:space:]].*gh[[:space:]]+workflow[[:space:]]+run ]] && continue
      return 0
    fi
    
    pattern="gh[[:space:]]+workflow[[:space:]]+run[[:space:]]+[\"']*Release[\"']*${END}"
    if [[ "$normalized" =~ $pattern ]]; then
      [[ "$normalized" =~ ^[[:space:]]*($TEXT_CMDS)[[:space:]].*gh[[:space:]]+workflow[[:space:]]+run ]] && continue
      return 0
    fi
    
    if [[ "$normalized" =~ gh[[:space:]]+release[[:space:]]+create ]]; then
      [[ "$normalized" =~ ^[[:space:]]*($TEXT_CMDS)[[:space:]].*gh[[:space:]]+release[[:space:]]+create ]] && continue
      return 0
    fi
  done <<< "$cmd"
  
  return 1
}

main() {
  local cmd
  cmd=$(get_command) || exit 0
  [ -z "$cmd" ] && exit 0
  
  is_release_command "$cmd" || exit 0
  
  cat >&2 <<EOF
🚫 BLOCKED: Releases require human approval.

Detected: $cmd

AI agents cannot trigger releases. Provide a copy-pastable command for the human:

  gh workflow run release.yml -f version=X.Y.Z

The human must run this command manually.
EOF
  exit 2
}

main
