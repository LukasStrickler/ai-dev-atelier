#!/bin/bash
# Codex provider implementation (placeholder)

# Run codex agent
# Usage: codex_run workspace mode runtime prompt_file out_ndjson env_vars model
codex_run() {
  local workspace="$1"
  local mode="$2"
  local runtime="$3"
  local prompt_file="$4"
  local out_ndjson="$5"
  local env_vars="$6"
  local model="${7:-auto}"
  
  echo "Error: Codex provider not yet implemented" >&2
  # Placeholder implementation
  echo "$$"  # Return current PID as placeholder
}

# Check if codex agent is done
# Usage: codex_done out_ndjson pid
codex_done() {
  local out_ndjson="$1"
  local pid="$2"
  
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  
  return 1
}

# Extract output from codex agent
# Usage: codex_extract workspace mode runDir
codex_extract() {
  local workspace="$1"
  local mode="$2"
  local runDir="$3"
  
  if [ "$mode" = "research" ]; then
    if [ -f "${workspace}/answer.md" ]; then
      cp "${workspace}/answer.md" "${runDir}/answer.md"
    fi
  fi
}

