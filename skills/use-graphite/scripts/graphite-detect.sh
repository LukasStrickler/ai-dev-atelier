#!/bin/bash
# Detect if Graphite should be used. Returns JSON: {"enabled": true/false, ...}
# Exit: 0=Graphite active, 1=Graphite not active

set -euo pipefail

if ! command -v gt &>/dev/null; then
  echo '{"enabled":false,"reason":"gt CLI not installed"}'
  exit 1
fi

USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/graphite/user_config"
if [ ! -f "$USER_CONFIG" ]; then
  echo '{"enabled":false,"reason":"User not authenticated (no user_config)"}'
  exit 1
fi

if ! grep -q '"authToken"' "$USER_CONFIG" 2>/dev/null; then
  echo '{"enabled":false,"reason":"User not authenticated (no authToken)"}'
  exit 1
fi

GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || {
  echo '{"enabled":false,"reason":"Not a git repository"}'
  exit 1
}

if [ -f "$GIT_DIR/commondir" ]; then
  MAIN_GIT_DIR=$(cat "$GIT_DIR/commondir")
  [[ "$MAIN_GIT_DIR" != /* ]] && MAIN_GIT_DIR="$GIT_DIR/$MAIN_GIT_DIR"
else
  MAIN_GIT_DIR="$GIT_DIR"
fi

REPO_CONFIG="$MAIN_GIT_DIR/.graphite_repo_config"
if [ ! -f "$REPO_CONFIG" ]; then
  echo '{"enabled":false,"reason":"Repo not initialized with Graphite (run: gt repo init)"}'
  exit 1
fi

TRUNK=$(awk -F'"' '/"trunk"/ {print $4}' "$REPO_CONFIG" 2>/dev/null)
[ -z "$TRUNK" ] && TRUNK="main"

echo "{\"enabled\":true,\"trunk\":\"$TRUNK\",\"config\":\"$REPO_CONFIG\"}"
exit 0
