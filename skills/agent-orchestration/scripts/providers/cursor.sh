#!/bin/bash
# Cursor provider implementation

set -euo pipefail

# Run cursor agent
# Usage: cursor_run workspace mode runtime prompt_file out_ndjson env_vars model
cursor_run() {
  local workspace="$1"
  local mode="$2"
  local runtime="$3"
  local prompt_file="$4"
  local out_ndjson="$5"
  local env_vars="$6"
  local model="${7:-auto}"
  
  # Read prompt
  local prompt=$(cat "$prompt_file" 2>/dev/null || echo "")
  
  # Build instructions based on mode
  local instructions=""
  if [ "$mode" = "research" ]; then
    instructions="You are a research agent. Your task is to:
1. Use Tavily search tools (tavily_search, tavily_extract) to gather information
2. Use deep reasoning to analyze and synthesize the information
3. Write your final comprehensive answer to answer.md in the root of this directory
4. You have full write access - feel free to experiment, but the final answer.md is what matters

Available MCP tools:
- tavily_search: Search the web (use search_depth: 'advanced' for thorough research)
- tavily_extract: Extract full content from URLs (use extract_depth: 'advanced' for complete content)
- tavily_crawl: Crawl multiple pages from a website
- tavily_map: Map website structure

For research tasks, use Tavily search tools to gather current information, then write a comprehensive answer to answer.md."
  else
    instructions="You are a work agent. Your task is to make code changes as specified. You have full write access to all files."
  fi
  
  # Combine instructions with prompt
  local full_prompt="${instructions}

## Task

${prompt}

## Instructions

- Review prompt.md in this directory to understand your task
- For research mode: Write your final answer to answer.md
- For work mode: Make the necessary code changes
- All edits are allowed"
  
  # Escape JSON for logging
  escape_json() {
    local text="$1"
    echo "$text" | tr '\n' ' ' | tr '\r' ' ' | sed 's/"/\\"/g'
  }
  
  # Log start
  {
    echo "{\"type\":\"start\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"mode\":\"$mode\",\"workspace\":\"$workspace\"}"
  } >> "$out_ndjson"
  
  # Run cursor-agent in background
  # Use nohup and background execution for macOS compatibility
  (
    cd "$workspace" || exit 1
    
    # Create temporary file for output capture
    local temp_output=$(mktemp)
    
    # Run cursor-agent synchronously within the background bash process
    # cursor-agent handles its own async operations internally
    # Capture both stdout and stderr to temp file first
    cursor-agent --print --model "$model" --force --approve-mcps <<EOF > "$temp_output" 2>&1
$full_prompt
EOF
    
    # Process output and log to NDJSON
    while IFS= read -r line || [ -n "$line" ]; do
      # Filter out non-fatal auth errors
      if echo "$line" | grep -q "Incompatible auth server"; then
        {
          echo "{\"type\":\"warning\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"message\":\"$(escape_json "$line")\"}"
        } >> "$out_ndjson"
      else
        {
          echo "{\"type\":\"output\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"content\":\"$(escape_json "$line")\"}"
        } >> "$out_ndjson"
      fi
    done < "$temp_output"
    
    # Log completion
    {
      echo "{\"type\":\"complete\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
    } >> "$out_ndjson"
    
    rm -f "$temp_output"
  ) >/dev/null 2>&1 &
  
  # Return PID of the background bash process
  echo $!
}

# Check if cursor agent is done
# Usage: cursor_done out_ndjson pid
cursor_done() {
  local out_ndjson="$1"
  local pid="$2"
  
  # Check if process is still alive
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0  # Process is done
  fi
  
  # Also check for completion signal in output
  if [ -f "$out_ndjson" ]; then
    if grep -q '"type":"complete"' "$out_ndjson" 2>/dev/null; then
      return 0  # Completion signal found
    fi
  fi
  
  return 1  # Still running
}

# Extract output from cursor agent
# Usage: cursor_extract workspace mode runDir
cursor_extract() {
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

