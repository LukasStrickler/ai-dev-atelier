#!/bin/bash
# Agent orchestration utilities for managing worktrees, metadata, processes, and results

# Get the project root directory (assuming script is in skills/agent-orchestration/scripts/lib/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
ADA_DIR="${PROJECT_ROOT}/.ada"
DATA_DIR="${ADA_DIR}/data/agents"
RUNS_DIR="${DATA_DIR}/runs"
TEMP_DIR="${ADA_DIR}/temp/agents"
WORKTREES_DIR="${TEMP_DIR}/worktrees"

# Ensure directories exist
mkdir -p "$RUNS_DIR" "$WORKTREES_DIR"

# ============================================================================
# Run ID Generation
# ============================================================================

# Generate unique run ID
# Format: YYYYMMDD-HHMMSS-<random>
generate_run_id() {
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local random=$(openssl rand -hex 3 2>/dev/null || echo $(date +%s | sha256sum | cut -c1-6))
  echo "${timestamp}-${random}"
}

# ============================================================================
# Worktree Management
# ============================================================================

# Create isolated worktree
# Usage: create_worktree runId baseBranch
create_worktree() {
  local runId="$1"
  local baseBranch="${2:-main}"
  local worktreePath="${WORKTREES_DIR}/${runId}"
  local branchName="agent-${runId}"
  
  # Create worktree (suppress "HEAD is now at..." output)
  (
    cd "$PROJECT_ROOT" || return 1
    git worktree add -b "$branchName" "$worktreePath" "$baseBranch" >/dev/null 2>&1
  )
  
  if [ $? -eq 0 ] && [ -d "$worktreePath" ]; then
    echo "$worktreePath"
    return 0
  else
    return 1
  fi
}

# Cleanup worktree
# Usage: cleanup_worktree runId
cleanup_worktree() {
  local runId="$1"
  local worktreePath="${WORKTREES_DIR}/${runId}"
  local branchName="agent-${runId}"
  
  if [ -d "$worktreePath" ]; then
    (
      cd "$PROJECT_ROOT" || return 1
      git worktree remove "$worktreePath" -f >/dev/null 2>&1 || true
      git branch -D "$branchName" >/dev/null 2>&1 || true
    )
  fi
}

# Get worktree path
# Usage: get_worktree_path runId
get_worktree_path() {
  local runId="$1"
  local worktreePath="${WORKTREES_DIR}/${runId}"
  
  if [ -d "$worktreePath" ]; then
    echo "$worktreePath"
  else
    return 1
  fi
}

# ============================================================================
# Metadata & State
# ============================================================================

# Get run directory
# Usage: get_run_directory runId
get_run_directory() {
  local runId="$1"
  echo "${RUNS_DIR}/${runId}"
}

# Write metadata JSON atomically
# Usage: write_meta_json runId key1 value1 [key2 value2 ...]
write_meta_json() {
  local runId="$1"
  shift
  local runDir=$(get_run_directory "$runId")
  local metaFile="${runDir}/meta.json"
  local tempFile="${metaFile}.tmp"
  
  mkdir -p "$runDir"
  
  # Read existing JSON or start with empty object
  local existingJson="{}"
  if [ -f "$metaFile" ]; then
    existingJson=$(cat "$metaFile" 2>/dev/null || echo "{}")
  fi
  
  # Update JSON with new key-value pairs
  local updatedJson="$existingJson"
  if command -v jq &> /dev/null; then
    # Use jq if available
    while [ $# -ge 2 ]; do
      local key="$1"
      local value="$2"
      shift 2
      # Escape value for JSON
      local escapedValue=$(echo "$value" | jq -Rs . 2>/dev/null || echo "\"$value\"")
      updatedJson=$(echo "$updatedJson" | jq --arg k "$key" --argjson v "$escapedValue" '.[$k] = $v' 2>/dev/null || echo "$updatedJson")
    done
  else
    # Basic JSON update without jq
    # Parse and rebuild JSON manually
    local jsonPairs=""
    local inKeyValue=false
    local currentKey=""
    local currentValue=""
    
    # Simple approach: rebuild JSON from scratch with all key-value pairs
    # This is a simplified implementation - for production, a proper JSON parser would be better
    # For now, we'll use a basic string replacement approach
    updatedJson="$existingJson"
    while [ $# -ge 2 ]; do
      local key="$1"
      local value="$2"
      shift 2
      
      # Escape value for JSON
      local escapedValue=$(echo "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
      
      # Remove existing key if present, then add new one
      # This is a very basic implementation
      updatedJson=$(echo "$updatedJson" | sed "s/\"$key\":\"[^\"]*\"/\"$key\":\"$escapedValue\"/g" | sed "s/\"$key\":[^,}]*/\"$key\":\"$escapedValue\"/g")
      
      # If key doesn't exist, add it
      if ! echo "$updatedJson" | grep -q "\"$key\""; then
        # Add new key-value pair
        updatedJson=$(echo "$updatedJson" | sed 's/}$/,\n  "'"$key"'": "'"$escapedValue"'"}/')
      fi
    done
  fi
  
  # Write atomically
  echo "$updatedJson" > "$tempFile"
  mv "$tempFile" "$metaFile"
}

# Read metadata JSON
# Usage: read_meta_json runId [key]
read_meta_json() {
  local runId="$1"
  local key="${2:-}"
  local runDir=$(get_run_directory "$runId")
  local metaFile="${runDir}/meta.json"
  
  if [ ! -f "$metaFile" ]; then
    return 1
  fi
  
  local json=$(cat "$metaFile" 2>/dev/null || echo "{}")
  
  if [ -z "$key" ]; then
    echo "$json"
  else
    if command -v jq &> /dev/null; then
      echo "$json" | jq -r ".[\"$key\"] // empty" 2>/dev/null || echo ""
    else
      # Basic extraction without jq
      echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | sed "s/\"$key\":\"\([^\"]*\)\"/\1/" || echo ""
    fi
  fi
}

# ============================================================================
# Prompt & Progress
# ============================================================================

# Create prompt.md file
# Usage: create_prompt_file workspacePath prompt level mode
create_prompt_file() {
  local workspacePath="$1"
  local prompt="$2"
  local level="${3:-1}"
  local mode="${4:-work}"
  
  cat > "${workspacePath}/prompt.md" <<EOF
# Agent Task

**Level:** $level
**Mode:** $mode
**Created:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Task

$prompt

## Instructions

- Review this prompt.md file to understand your task
- For research mode: Write your final answer to answer.md
- For work mode: Make the necessary code changes
- Update progress.md as you work (optional)
EOF
}

# Create progress.md file
# Usage: create_progress_file workspacePath
create_progress_file() {
  local workspacePath="$1"
  
  cat > "${workspacePath}/progress.md" <<EOF
# Progress

**Started:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Status

In progress...

## Notes

(Update this file as you work)
EOF
}

# Create answer.md placeholder (research mode)
# Usage: create_answer_file workspacePath
create_answer_file() {
  local workspacePath="$1"
  
  cat > "${workspacePath}/answer.md" <<EOF
# Answer

Agent will write final answer here.

**Started:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
}

# Create .agent-level file (immutable)
# Usage: create_level_file workspacePath level
create_level_file() {
  local workspacePath="$1"
  local level="$2"
  
  mkdir -p "$workspacePath"
  echo "$level" > "${workspacePath}/.agent-level"
  chmod 444 "${workspacePath}/.agent-level" 2>/dev/null || true
}

# Read level from file
# Usage: read_level_file workspacePath
read_level_file() {
  local workspacePath="$1"
  local levelFile="${workspacePath}/.agent-level"
  
  if [ -f "$levelFile" ]; then
    cat "$levelFile" 2>/dev/null || echo "1"
  else
    echo "1"
  fi
}

# ============================================================================
# Process Management
# ============================================================================

# Check if process is alive
# Usage: check_process_alive pid
check_process_alive() {
  local pid="$1"
  if [ -z "$pid" ] || [ "$pid" = "null" ] || [ "$pid" = "0" ]; then
    return 1
  fi
  kill -0 "$pid" 2>/dev/null
}

# Check if cursor-agent process is actually running (by name, not just PID)
# Usage: check_cursor_agent_running pid
check_cursor_agent_running() {
  local pid="$1"
  if [ -z "$pid" ] || [ "$pid" = "null" ] || [ "$pid" = "0" ]; then
    return 1
  fi
  
  # Check if PID is still alive
  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  
  # Also check if there's a cursor-agent process running (might be child process)
  # On macOS, ps -p doesn't show child processes, so we check by name
  if ps aux | grep -E "[c]ursor-agent" | grep -q "$pid\|worker-server"; then
    return 0
  fi
  
  # Fallback: if PID is alive, assume it's running
  return 0
}

# Update process status in meta.json
# Usage: update_process_status runId pid [elapsedSeconds]
update_process_status() {
  local runId="$1"
  local pid="$2"
  local elapsedSeconds="${3:-0}"
  
  if [ -z "$runId" ] || [ -z "$pid" ]; then
    return 1
  fi
  
  # Determine process status
  local processStatus="unknown"
  local cursorAgentProcesses=0
  
  if check_process_alive "$pid"; then
    processStatus="running"
    
    # Count cursor-agent processes (for cursor provider)
    local provider
    provider=$(read_meta_json "$runId" "provider" 2>/dev/null || echo "")
    if [ "$provider" = "cursor" ]; then
      cursorAgentProcesses=$(ps aux | grep -E "[c]ursor-agent" | wc -l | tr -d ' ')
    fi
  else
    processStatus="stopped"
  fi
  
  # Update meta.json with status
  write_meta_json "$runId" \
    "lastCheckAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    "processStatus" "$processStatus" \
    "elapsedSeconds" "$elapsedSeconds" \
    "cursorAgentProcesses" "$cursorAgentProcesses"
}

# Get process status (quick check)
# Usage: get_process_status runId
get_process_status() {
  local runId="$1"
  local metaJson=$(read_meta_json "$runId" 2>/dev/null || echo "{}")
  
  if command -v jq &> /dev/null; then
    echo "$metaJson" | jq -r '{
      status: .status,
      processStatus: .processStatus,
      pid: .pid,
      elapsedSeconds: .elapsedSeconds,
      lastCheckAt: .lastCheckAt
    }'
  else
    # Basic extraction
    local status=$(echo "$metaJson" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/' || echo "unknown")
    local processStatus=$(echo "$metaJson" | grep -o '"processStatus":"[^"]*"' | sed 's/"processStatus":"\([^"]*\)"/\1/' || echo "unknown")
    local pid=$(echo "$metaJson" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/' || echo "")
    echo "Status: $status, Process: $processStatus, PID: $pid"
  fi
}

# Monitor process with timeout and status updates
# Usage: monitor_process pid timeout [runId]
monitor_process() {
  local pid="$1"
  local timeout="${2:-3600}"
  local runId="${3:-}"
  local elapsed=0
  local interval=2
  local last_status_update=0
  local status_update_interval=5  # Update status every 5 seconds
  
  echo "Monitoring process $pid (timeout: ${timeout}s)..." >&2
  
  # Initial status update
  if [ -n "$runId" ]; then
    update_process_status "$runId" "$pid" "$elapsed"
  fi
  
  while [ $elapsed -lt $timeout ]; do
    if ! check_process_alive "$pid"; then
      echo "Process $pid completed after ${elapsed}s" >&2
      # Final status update
      if [ -n "$runId" ]; then
        update_process_status "$runId" "$pid" "$elapsed"
      fi
      return 0  # Process completed
    fi
    
    # Check if cursor-agent is actually running (for cursor provider)
    if [ -n "$runId" ]; then
      local provider
      provider=$(read_meta_json "$runId" "provider" 2>/dev/null || echo "")
      if [ "$provider" = "cursor" ]; then
        if ! check_cursor_agent_running "$pid"; then
          echo "Warning: cursor-agent process not found, but PID $pid is alive" >&2
        fi
      fi
    fi
    
    # Update status in meta.json every 5 seconds
    if [ $((elapsed - last_status_update)) -ge $status_update_interval ]; then
      if [ -n "$runId" ]; then
        update_process_status "$runId" "$pid" "$elapsed"
      fi
      echo "[$(date +%H:%M:%S)] Process $pid still running (${elapsed}s elapsed)..." >&2
      last_status_update=$elapsed
    fi
    
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  
  echo "Process $pid timed out after ${timeout}s" >&2
  # Final status update on timeout
  if [ -n "$runId" ]; then
    update_process_status "$runId" "$pid" "$elapsed"
  fi
  return 2  # Timeout
}

# Kill entire process group
# Usage: kill_process_group pid
kill_process_group() {
  local pid="$1"
  if [ -z "$pid" ] || [ "$pid" = "null" ] || [ "$pid" = "0" ]; then
    return
  fi
  
  # Try to kill process group
  kill -TERM "-${pid}" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  sleep 2
  kill -KILL "-${pid}" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
}

# ============================================================================
# Artifacts
# ============================================================================

# Generate diff artifacts
# Usage: generate_diff_artifacts workspacePath runDir baseBranch
# Handles: uncommitted changes, branch commits, and empty states
generate_diff_artifacts() {
  local workspacePath="$1"
  local runDir="$2"
  local baseBranch="${3:-main}"
  local runId=$(basename "$runDir")
  local branchName="agent-${runId}"
  
  if [ ! -d "$workspacePath" ]; then
    echo "Warning: Worktree path does not exist: $workspacePath" >&2
    # Create empty artifacts
    echo "# No changes detected - worktree does not exist" > "${runDir}/patch.diff"
    touch "${runDir}/changed_files.txt"
    touch "${runDir}/diffstat.txt"
    return 0
  fi
  
  (
    cd "$workspacePath" || return 1
    
    # Check for uncommitted changes (working directory + staged + untracked)
    local hasUncommitted=false
    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
      hasUncommitted=true
    fi
    # Also check for untracked files (new files)
    local untrackedFiles=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    if [ "$untrackedFiles" -gt 0 ]; then
      hasUncommitted=true
    fi
    
    # Check if branch has commits (diverged from baseBranch)
    local branchExists=false
    local branchHasCommits=false
    if git rev-parse --verify "${branchName}" >/dev/null 2>&1; then
      branchExists=true
      # Check if branch has commits different from baseBranch
      if git rev-parse --verify "${baseBranch}" >/dev/null 2>&1; then
        if ! git diff --quiet "${baseBranch}..${branchName}" 2>/dev/null; then
          branchHasCommits=true
        fi
      fi
    fi
    
    # Generate patch.diff based on what exists
    if [ "$hasUncommitted" = "true" ]; then
      # Priority 1: Uncommitted changes (working directory + staged + untracked)
      {
        echo "# Diff of uncommitted changes (working directory + staged + untracked)"
        echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo ""
        git diff HEAD 2>/dev/null || true
        git diff --cached 2>/dev/null || true
        # Add untracked files as new files
        untrackedFiles=$(git ls-files --others --exclude-standard 2>/dev/null)
        if [ -n "$untrackedFiles" ]; then
          echo ""
          echo "# Untracked files (new files):"
          echo "$untrackedFiles" | while read -r file; do
            if [ -f "$file" ]; then
              echo "+++ b/$file"
              echo "@@ -0,0 +1,$(wc -l < "$file" | tr -d ' ') @@"
              cat "$file" | sed 's/^/+/'
            fi
          done
        fi
      } > "${runDir}/patch.diff"
      
      # Generate changed files from uncommitted changes + untracked
      {
        git diff --name-only HEAD 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
        git ls-files --others --exclude-standard 2>/dev/null || true
      } | sort -u > "${runDir}/changed_files.txt"
      
      # Generate diffstat from uncommitted changes
      {
        echo "# Diffstat of uncommitted changes"
        git diff --stat HEAD 2>/dev/null || true
        git diff --cached --stat 2>/dev/null || true
      } > "${runDir}/diffstat.txt"
      
    elif [ "$branchHasCommits" = "true" ]; then
      # Priority 2: Branch has commits different from baseBranch
      {
        echo "# Diff of branch ${branchName} against ${baseBranch}"
        echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo ""
        git diff "${baseBranch}..${branchName}" 2>/dev/null || true
      } > "${runDir}/patch.diff"
      
      git diff --name-only "${baseBranch}..${branchName}" 2>/dev/null > "${runDir}/changed_files.txt" || true
      git diff --stat "${baseBranch}..${branchName}" 2>/dev/null > "${runDir}/diffstat.txt" || true
      
    elif [ "$branchExists" = "true" ]; then
      # Priority 3: Branch exists but no commits (check against baseBranch working directory)
      {
        echo "# Diff of branch ${branchName} against ${baseBranch} (no commits, checking working directory)"
        echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo ""
        git diff "${baseBranch}" 2>/dev/null || true
      } > "${runDir}/patch.diff"
      
      git diff --name-only "${baseBranch}" 2>/dev/null > "${runDir}/changed_files.txt" || true
      git diff --stat "${baseBranch}" 2>/dev/null > "${runDir}/diffstat.txt" || true
      
    else
      # No changes detected - create empty artifacts with informative messages
      {
        echo "# No changes detected"
        echo "# Branch: ${branchName}"
        echo "# Base branch: ${baseBranch}"
        echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "#"
        echo "# No uncommitted changes, no branch commits, and branch does not exist."
      } > "${runDir}/patch.diff"
      
      echo "# No changed files" > "${runDir}/changed_files.txt"
      echo "# No changes" > "${runDir}/diffstat.txt"
    fi
    
    # Ensure files exist (even if empty)
    touch "${runDir}/patch.diff"
    touch "${runDir}/changed_files.txt"
    touch "${runDir}/diffstat.txt"
    
    # Log what was generated
    local patchSize=$(wc -c < "${runDir}/patch.diff" 2>/dev/null || echo "0")
    local fileCount=$(wc -l < "${runDir}/changed_files.txt" 2>/dev/null || echo "0")
    echo "Generated artifacts: patch.diff (${patchSize} bytes), ${fileCount} changed files" >&2
  )
  
  return 0  # Always succeed
}

# Verify artifacts exist
# Usage: verify_artifacts runDir
verify_artifacts() {
  local runDir="$1"
  local allExist=true
  
  if [ ! -f "${runDir}/patch.diff" ]; then
    echo "Warning: patch.diff missing" >&2
    allExist=false
  fi
  
  if [ ! -f "${runDir}/changed_files.txt" ]; then
    echo "Warning: changed_files.txt missing" >&2
    allExist=false
  fi
  
  if [ "$allExist" = "true" ]; then
    return 0
  else
    return 1
  fi
}

# Extract answer.md content from patch.diff
# Usage: extract_answer_from_patch patchFile runDir
# Returns: 0 on success, 1 on failure
extract_answer_from_patch() {
  local patchFile="$1"
  local runDir="$2"
  local answerFile="${runDir}/answer.md"
  
  if [ ! -f "$patchFile" ] || [ ! -s "$patchFile" ]; then
    return 1
  fi
  
  # Find answer.md in patch (any location)
  # Pattern: +++ b/answer.md or +++ b/path/to/answer.md
  # Escape + for grep (use -E with proper escaping)
  local answerLineNum=$(grep -nE "^\\+\\+\\+ b/.*answer\\.md" "$patchFile" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$answerLineNum" ]; then
    return 1
  fi
  
  # Extract content starting from the line after +++
  # Use awk to extract content between @@ markers
  local tempContent=$(mktemp)
  
  # Read from the answer.md file marker and extract content
  awk -v startLine="$answerLineNum" '
    BEGIN { inAnswerBlock = 0 }
    NR >= startLine {
      # Stop if we hit another file marker (but not the first one)
      if ($0 ~ /^\+\+\+ b\// && inAnswerBlock == 1) {
        exit
      }
      
      # Start extracting after we see the @@ line
      if ($0 ~ /^@@/) {
        inAnswerBlock = 1
        next
      }
      
      # Extract lines starting with + (new content)
      if (inAnswerBlock == 1) {
        if ($0 ~ /^\+/) {
          # Remove leading + and output
          print substr($0, 2)
        } else if ($0 ~ /^\-/) {
          # Skip deleted lines
          next
        } else if ($0 ~ /^ / || length($0) == 0) {
          # Context lines (starting with space) or empty - include them
          if (length($0) > 1) {
            print substr($0, 2)
          } else {
            print ""
          }
        }
      }
    }
  ' "$patchFile" > "$tempContent"
  
  # Check if we extracted any meaningful content
  if [ -s "$tempContent" ]; then
    local contentLength=$(wc -c < "$tempContent" 2>/dev/null || echo "0")
    if [ "$contentLength" -gt 50 ]; then
      {
        echo "# Answer (Extracted from Patch)"
        echo ""
        cat "$tempContent"
      } > "$answerFile"
      rm -f "$tempContent"
      echo "Extracted answer.md from patch.diff" >&2
      return 0
    fi
  fi
  
  rm -f "$tempContent"
  return 1
}

# Synthesize answer.md from out.ndjson
# Usage: synthesize_answer_from_ndjson ndjsonFile runDir
# Returns: 0 on success, 1 on failure
synthesize_answer_from_ndjson() {
  local ndjsonFile="$1"
  local runDir="$2"
  local answerFile="${runDir}/answer.md"
  
  if [ ! -f "$ndjsonFile" ] || [ ! -s "$ndjsonFile" ]; then
    return 1
  fi
  
  local tempContent=$(mktemp)
  
  # Parse NDJSON for type="output" entries
  if command -v jq &> /dev/null; then
    # Use jq for proper JSON parsing
    jq -r 'select(.type == "output" and .content != null) | .content' "$ndjsonFile" 2>/dev/null > "$tempContent"
  else
    # Basic parsing without jq
    grep '"type":"output"' "$ndjsonFile" 2>/dev/null | \
      grep -o '"content":"[^"]*"' | \
      sed 's/"content":"//g' | \
      sed 's/"$//g' | \
      sed 's/\\n/\n/g' | \
      sed 's/\\"/"/g' > "$tempContent" || true
  fi
  
  # Filter out empty lines and very short content
  if [ -s "$tempContent" ]; then
    local contentLength=$(wc -c < "$tempContent" 2>/dev/null || echo "0")
    if [ "$contentLength" -gt 50 ]; then
      {
        echo "# Answer (Synthesized from Agent Output)"
        echo ""
        echo "> **Note**: This answer was synthesized from the agent's output logs because answer.md was not found directly."
        echo ""
        cat "$tempContent"
      } > "$answerFile"
      rm -f "$tempContent"
      echo "Synthesized answer.md from out.ndjson" >&2
      return 0
    fi
  fi
  
  rm -f "$tempContent"
  return 1
}

# Extract answer.md from worktree to run directory (research mode)
# Usage: extract_answer_file workspacePath runDir [outputVar]
# Returns: 0 on success, 1 on failure
# If outputVar is provided, sets it to extraction method: "direct", "patch", "ndjson", or "failed"
extract_answer_file() {
  local workspacePath="$1"
  local runDir="$2"
  local outputVar="${3:-}"
  local patchFile="${runDir}/patch.diff"
  local changedFilesFile="${runDir}/changed_files.txt"
  local ndjsonFile="${runDir}/out.ndjson"
  local answerFile="${workspacePath}/answer.md"
  local extractionMethod="failed"
  
  # Method 1: Direct file extraction (existing behavior)
  if [ -f "$answerFile" ] && [ -s "$answerFile" ]; then
    cp "$answerFile" "${runDir}/answer.md"
    echo "Extracted answer.md from root location" >&2
    extractionMethod="direct"
    if [ -n "$outputVar" ]; then
      eval "$outputVar=\"$extractionMethod\""
    fi
    return 0
  fi
  
  # Search changed_files.txt for answer.md in any location
  if [ -f "$changedFilesFile" ] && [ -s "$changedFilesFile" ]; then
    local answerPath=$(grep "answer\.md" "$changedFilesFile" 2>/dev/null | head -1)
    if [ -n "$answerPath" ] && [ -f "${workspacePath}/${answerPath}" ]; then
      cp "${workspacePath}/${answerPath}" "${runDir}/answer.md"
      echo "Extracted answer.md from ${answerPath}" >&2
      extractionMethod="direct"
      if [ -n "$outputVar" ]; then
        eval "$outputVar=\"$extractionMethod\""
      fi
      return 0
    fi
  fi
  
  # Also check patch.diff directly for answer.md file path
  if [ -f "$patchFile" ] && [ -s "$patchFile" ]; then
    local answerPathInPatch=$(grep -E "^(\+\+\+|---).*answer\.md" "$patchFile" 2>/dev/null | head -1 | sed -E 's/^(\+\+\+|---) [ab]\/?//' | sed 's/\t.*//')
    if [ -n "$answerPathInPatch" ] && [ -f "${workspacePath}/${answerPathInPatch}" ]; then
      cp "${workspacePath}/${answerPathInPatch}" "${runDir}/answer.md"
      echo "Extracted answer.md from ${answerPathInPatch} (found in patch)" >&2
      extractionMethod="direct"
      if [ -n "$outputVar" ]; then
        eval "$outputVar=\"$extractionMethod\""
      fi
      return 0
    fi
  fi
  
  # Method 2: Extract from patch.diff content
  if extract_answer_from_patch "$patchFile" "$runDir"; then
    extractionMethod="patch"
    if [ -n "$outputVar" ]; then
      eval "$outputVar=\"$extractionMethod\""
    fi
    return 0
  fi
  
  # Method 3: Synthesize from out.ndjson
  if synthesize_answer_from_ndjson "$ndjsonFile" "$runDir"; then
    extractionMethod="ndjson"
    if [ -n "$outputVar" ]; then
      eval "$outputVar=\"$extractionMethod\""
    fi
    return 0
  fi
  
  # All methods failed - create placeholder
  {
    echo "# Answer Not Found"
    echo ""
    echo "The agent did not create an answer.md file, and no answer could be extracted from:"
    echo "- Direct file location"
    echo "- Patch content (patch.diff)"
    echo "- Agent output logs (out.ndjson)"
    echo ""
    echo "Please check the agent's worktree and output logs for more information."
  } > "${runDir}/answer.md"
  
  echo "Warning: Could not extract answer.md using any method. Placeholder created." >&2
  if [ -n "$outputVar" ]; then
    eval "$outputVar=\"$extractionMethod\""
  fi
  return 1
}

# Check if work was done based on patch analysis
# Usage: check_work_from_patch runDir mode
check_work_from_patch() {
  local runDir="$1"
  local mode="$2"
  local patchFile="${runDir}/patch.diff"
  
  if [ ! -f "$patchFile" ] || [ ! -s "$patchFile" ]; then
    return 1  # No patch = no work
  fi
  
  if [ "$mode" = "research" ]; then
    # Look for answer.md in patch (any location)
    if grep -q "answer\.md" "$patchFile" 2>/dev/null; then
      return 0  # Found answer.md in patch
    fi
    # Also check for other markdown files that might be answers
    if grep -qE "\+.*\.md" "$patchFile" 2>/dev/null; then
      return 0  # Found markdown files (potential answers)
    fi
  else
    # Work mode: check for actual code changes
    # Exclude metadata files (.agent-level, prompt.md, progress.md)
    if grep -vE "(\.agent-level|prompt\.md|progress\.md)" "$patchFile" 2>/dev/null | grep -qE "^\+|^-"; then
      return 0  # Found actual code changes
    fi
  fi
  
  return 1
}

# Analyze patch for results and return structured findings
# Usage: analyze_patch_for_results runDir mode
analyze_patch_for_results() {
  local runDir="$1"
  local mode="$2"
  local patchFile="${runDir}/patch.diff"
  local changedFilesFile="${runDir}/changed_files.txt"
  
  # Initialize findings
  local hasChanges="false"
  local answerLocation=""
  local changedFiles="[]"
  local patchSize=0
  local workDetected="false"
  
  # Check if patch exists and has content
  if [ -f "$patchFile" ] && [ -s "$patchFile" ]; then
    hasChanges="true"
    patchSize=$(wc -c < "$patchFile" 2>/dev/null || echo "0")
    
    # Get changed files
    if [ -f "$changedFilesFile" ] && [ -s "$changedFilesFile" ]; then
      # Convert file list to JSON array
      if command -v jq &> /dev/null; then
        changedFiles=$(cat "$changedFilesFile" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
      else
        # Basic conversion without jq
        local fileList=$(cat "$changedFilesFile" | grep -v "^$" | tr '\n' ',' | sed 's/,$//')
        if [ -n "$fileList" ]; then
          changedFiles="[\"$(echo "$fileList" | sed 's/,/","/g')\"]"
        fi
      fi
    fi
    
    # For research mode: find answer.md location
    if [ "$mode" = "research" ]; then
      if [ -f "$changedFilesFile" ]; then
        answerLocation=$(grep "answer\.md" "$changedFilesFile" 2>/dev/null | head -1 || echo "")
      fi
      
      # Check if work was detected
      if check_work_from_patch "$runDir" "$mode"; then
        workDetected="true"
      fi
    else
      # Work mode: check for code changes
      if check_work_from_patch "$runDir" "$mode"; then
        workDetected="true"
      fi
    fi
  fi
  
  # Return JSON (basic construction, jq preferred but not required)
  if command -v jq &> /dev/null; then
    jq -n \
      --arg hasChanges "$hasChanges" \
      --arg answerLocation "$answerLocation" \
      --argjson changedFiles "$changedFiles" \
      --arg patchSize "$patchSize" \
      --arg workDetected "$workDetected" \
      '{
        hasChanges: ($hasChanges == "true"),
        answerLocation: (if $answerLocation == "" then null else $answerLocation end),
        changedFiles: $changedFiles,
        patchSize: ($patchSize | tonumber),
        workDetected: ($workDetected == "true")
      }' 2>/dev/null || echo "{\"hasChanges\":$hasChanges,\"answerLocation\":\"$answerLocation\",\"changedFiles\":$changedFiles,\"patchSize\":$patchSize,\"workDetected\":$workDetected}"
  else
    # Basic JSON without jq - properly format null
    local answerLocationJson="null"
    if [ -n "$answerLocation" ]; then
      answerLocationJson="\"$answerLocation\""
    fi
    echo "{\"hasChanges\":$hasChanges,\"answerLocation\":$answerLocationJson,\"changedFiles\":$changedFiles,\"patchSize\":$patchSize,\"workDetected\":$workDetected}"
  fi
}

# Check if result exists
# Usage: check_result_exists runId mode
# PATCH-FIRST APPROACH: Check patch first, then fall back to file-based checks
check_result_exists() {
  local runId="$1"
  local mode="$2"
  local worktreePath=$(get_worktree_path "$runId")
  local runDir=$(get_run_directory "$runId")
  local patchFile="${runDir}/patch.diff"
  
  # Step 1: Check if patch exists and has content
  if [ ! -f "$patchFile" ] || [ ! -s "$patchFile" ]; then
    return 1  # No patch = no work done
  fi
  
  # Step 2: Analyze patch for work (PATCH-FIRST)
  if check_work_from_patch "$runDir" "$mode"; then
    return 0  # Work detected in patch
  fi
  
  # Step 3: Fall back to file-based checks (for backward compatibility)
  if [ "$mode" = "research" ]; then
    # Check for answer.md in root (existing behavior)
    if [ -f "${worktreePath}/answer.md" ] && [ -s "${worktreePath}/answer.md" ]; then
      local answer_content=$(cat "${worktreePath}/answer.md" 2>/dev/null)
      local content=$(echo "$answer_content" | grep -v "^#" | grep -v "^$" | head -c 200)
      
      # Check if content exists, is not placeholder, and has minimum length
      if [ -n "$content" ] && \
         ! echo "$answer_content" | grep -qi "Agent will write final answer here" && \
         ! echo "$answer_content" | grep -qE "^# Answer$" && \
         [ $(echo "$content" | wc -c) -gt 50 ]; then
        return 0
      fi
    fi
  elif [ "$mode" = "work" ]; then
    # Work mode: patch already checked above
    # Additional check: ensure patch has meaningful size
    local diffSize
    diffSize=$(wc -c < "$patchFile" 2>/dev/null || echo "0")
    if [ "$diffSize" -gt 100 ]; then  # At least 100 bytes of changes
      return 0
    fi
  fi
  
  return 1
}

# ============================================================================
# Cleanup
# ============================================================================

# Automatic cleanup based on mode and status
# Usage: auto_cleanup runId status mode quickMerge
auto_cleanup() {
  local runId="$1"
  local status="$2"
  local mode="$3"
  local quickMerge="${4:-false}"
  
  # Never cleanup on failure without rescue attempts
  if [ "$status" = "failed" ]; then
    local rescueAttempts
    rescueAttempts=$(read_meta_json "$runId" "rescueAttempts" 2>/dev/null || echo "0")
    if [ "$rescueAttempts" = "0" ] || [ -z "$rescueAttempts" ]; then
      # No rescue attempts made, don't cleanup
      return 0
    fi
  fi
  
  # Auto-cleanup rules
  if [ "$status" = "success" ]; then
    if [ "$mode" = "research" ]; then
      # Research mode: auto-cleanup on success
      cleanup_worktree "$runId"
    elif [ "$mode" = "work" ] && [ "$quickMerge" = "true" ]; then
      # Work mode with quick-merge: auto-cleanup after merge
      cleanup_worktree "$runId"
    fi
    # Work mode without quick-merge: keep worktree for review (no cleanup)
  elif [ "$status" = "failed" ]; then
    # Only cleanup if all rescue attempts exhausted
    local escalationLevel
    escalationLevel=$(read_meta_json "$runId" "escalationLevel" 2>/dev/null || echo "")
    if [ "$escalationLevel" = "human" ]; then
      # All options exhausted, cleanup
      cleanup_worktree "$runId"
    fi
  fi
}

# Register cleanup handler
# Usage: register_cleanup_handler runId
register_cleanup_handler() {
  local runId="$1"
  
  # Set up signal handlers for cleanup
  trap "cleanup_worktree $runId; exit" TERM INT
}

# ============================================================================
# Hierarchical
# ============================================================================

# Get agent level from parent
# Usage: get_agent_level parentRunId
get_agent_level() {
  local parentRunId="$1"
  
  if [ -z "$parentRunId" ] || [ "$parentRunId" = "null" ]; then
    echo "1"  # Level 1 (orchestrator)
    return
  fi
  
  local parentWorktreePath=$(get_worktree_path "$parentRunId")
  local parentLevel=$(read_level_file "$parentWorktreePath")
  echo $((parentLevel + 1))
}

# Validate level against maxDepth
# Usage: validate_level level maxDepth
validate_level() {
  local level="$1"
  local maxDepth="${2:-2}"
  
  if [ "$level" -gt "$maxDepth" ]; then
    echo "Level $level exceeds maxDepth $maxDepth" >&2
    return 1
  fi
  
  if [ "$level" -lt 1 ]; then
    echo "Invalid level: $level" >&2
    return 1
  fi
  
  return 0
}

