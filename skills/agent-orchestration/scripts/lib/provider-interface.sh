#!/bin/bash
# Provider interface for AI model providers

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="${SCRIPT_DIR}/../providers"

# Load provider script
# Usage: load_provider providerName
load_provider() {
  local provider="$1"
  local providerScript="${PROVIDERS_DIR}/${provider}.sh"
  
  if [ ! -f "$providerScript" ]; then
    echo "Error: Provider script not found: $providerScript" >&2
    return 1
  fi
  
  source "$providerScript"
}

# Provider interface functions
# These must be implemented by each provider

# Run provider
# Usage: provider_run workspace mode runtime prompt_file out_ndjson env_vars provider [model]
provider_run() {
  local workspace="$1"
  local mode="$2"
  local runtime="$3"
  local prompt_file="$4"
  local out_ndjson="$5"
  local env_vars="$6"
  local provider="$7"
  local model="${8:-auto}"
  
  # Load provider
  load_provider "$provider" || return 1
  
  # Call provider-specific run function
  case "$provider" in
    cursor)
      cursor_run "$workspace" "$mode" "$runtime" "$prompt_file" "$out_ndjson" "$env_vars" "$model"
      ;;
    codex)
      codex_run "$workspace" "$mode" "$runtime" "$prompt_file" "$out_ndjson" "$env_vars" "$model"
      ;;
    gemini)
      gemini_run "$workspace" "$mode" "$runtime" "$prompt_file" "$out_ndjson" "$env_vars" "$model"
      ;;
    *)
      echo "Error: Unknown provider: $provider" >&2
      return 1
      ;;
  esac
}

# Check if provider is done
# Usage: provider_done out_ndjson pid
provider_done() {
  local out_ndjson="$1"
  local pid="$2"
  
  # Check if process is still alive
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0  # Process is done
  fi
  
  return 1  # Still running
}

# Extract output from provider
# Usage: provider_extract workspace mode runDir
provider_extract() {
  local workspace="$1"
  local mode="$2"
  local runDir="$3"
  
  if [ "$mode" = "research" ]; then
    # Extract answer.md
    if [ -f "${workspace}/answer.md" ]; then
      cp "${workspace}/answer.md" "${runDir}/answer.md"
    fi
  fi
}

