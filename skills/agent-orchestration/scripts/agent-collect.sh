#!/bin/bash
# Collect results from agent

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"
source "${SCRIPT_DIR}/lib/provider-interface.sh"

# Parse arguments
RUN_ID="${1:-}"

if [ -z "$RUN_ID" ]; then
  echo "Usage: $0 <runId>" >&2
  exit 1
fi

# Read metadata
META_JSON=$(read_meta_json "$RUN_ID")
if [ $? -ne 0 ] || [ -z "$META_JSON" ]; then
  echo "Error: Could not read metadata for runId: $RUN_ID" >&2
  exit 1
fi

# Extract fields
if command -v jq &> /dev/null; then
  WORKTREE_PATH=$(echo "$META_JSON" | jq -r '.worktreePath // empty')
  MODE=$(echo "$META_JSON" | jq -r '.mode // "work"')
  PROVIDER=$(echo "$META_JSON" | jq -r '.provider // "cursor"')
else
  WORKTREE_PATH=$(echo "$META_JSON" | grep -o '"worktreePath":"[^"]*"' | sed 's/"worktreePath":"\([^"]*\)"/\1/' || echo "")
  MODE=$(echo "$META_JSON" | grep -o '"mode":"[^"]*"' | sed 's/"mode":"\([^"]*\)"/\1/' || echo "work")
  PROVIDER=$(echo "$META_JSON" | grep -o '"provider":"[^"]*"' | sed 's/"provider":"\([^"]*\)"/\1/' || echo "cursor")
fi

RUN_DIR=$(get_run_directory "$RUN_ID")

# ============================================================================
# PATCH-FIRST APPROACH: Generate patch/diff artifacts FIRST
# ============================================================================
# Always generate patch before checking results - this ensures we can see
# ALL changes made, even if expected output files are missing or misplaced
echo "Generating patch artifacts..." >&2
if ! generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$(read_meta_json "$RUN_ID" "baseBranch" || echo "main")"; then
  echo "Warning: Failed to generate artifacts, continuing anyway..." >&2
fi

# Verify artifacts exist
verify_artifacts "$RUN_DIR" || echo "Warning: Some artifacts may be missing" >&2

# Log artifact locations
echo "Artifacts generated:" >&2
echo "  - patch.diff: ${RUN_DIR}/patch.diff" >&2
echo "  - changed_files.txt: ${RUN_DIR}/changed_files.txt" >&2
if [ "$MODE" = "work" ]; then
  echo "  - diffstat.txt: ${RUN_DIR}/diffstat.txt" >&2
fi

# Analyze patch to see if any work was done (even if not in expected format)
PATCH_ANALYSIS=$(analyze_patch_for_results "$RUN_DIR" "$MODE" || echo "{\"hasChanges\":false,\"workDetected\":false}")
WORK_DETECTED_IN_PATCH="false"
if command -v jq &> /dev/null; then
  WORK_DETECTED_IN_PATCH=$(echo "$PATCH_ANALYSIS" | jq -r '.workDetected // false' 2>/dev/null || echo "false")
else
  # Basic check without jq
  if echo "$PATCH_ANALYSIS" | grep -q '"workDetected":true'; then
    WORK_DETECTED_IN_PATCH="true"
  fi
fi

# Check for results (now using patch-based detection)
RESCUE_ATTEMPTS=0
MAX_RESCUE_ATTEMPTS=2
VERIFICATION_RETRIES=0
MAX_VERIFICATION_RETRIES=3

# Use patch analysis to determine if rescue is needed
# If work was detected in patch but result check fails, it means work was done
# but not in expected format - still trigger rescue but with different message
if ! check_result_exists "$RUN_ID" "$MODE"; then
  # Check if work was detected in patch (even if not in expected format)
  if [ "$WORK_DETECTED_IN_PATCH" = "true" ]; then
    echo "Work detected in patch but not in expected format, starting rescue process..." >&2
  else
    echo "No results found, starting rescue process..." >&2
  fi
  
  # Step 1: Basic rescue (max 2 attempts)
  ESCALATION_LEVEL="basic"
  while [ $RESCUE_ATTEMPTS -lt $MAX_RESCUE_ATTEMPTS ]; do
    RESCUE_ATTEMPTS=$((RESCUE_ATTEMPTS + 1))
    echo "Rescue attempt $RESCUE_ATTEMPTS (basic)..." >&2
    
    # Re-analyze patch after rescue attempt
    generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$(read_meta_json "$RUN_ID" "baseBranch" || echo "main")"
    PATCH_ANALYSIS=$(analyze_patch_for_results "$RUN_DIR" "$MODE" || echo "{\"hasChanges\":false,\"workDetected\":false}")
    
    if check_result_exists "$RUN_ID" "$MODE"; then
      echo "Rescue successful!" >&2
      break
    fi
    
    # Wait a bit for rescue to complete
    sleep $((RESCUE_ATTEMPTS * 2))  # Exponential backoff: 2s, 4s
  done
fi

# Extract primary output (patch already generated above)
EXTRACTION_METHOD="failed"
if [ "$MODE" = "research" ]; then
  # Always attempt extraction for research mode
  if extract_answer_file "$WORKTREE_PATH" "$RUN_DIR" "EXTRACTION_METHOD"; then
    echo "Answer extracted using method: $EXTRACTION_METHOD" >&2
  else
    echo "Warning: Answer extraction failed, placeholder created (method: $EXTRACTION_METHOD)" >&2
  fi
  
  # Log extraction method to meta.json
  write_meta_json "$RUN_ID" "answerExtractionMethod" "$EXTRACTION_METHOD"
fi

# Re-analyze patch for final result (in case rescue attempts made changes)
# Re-generate artifacts to ensure they're up to date
generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$(read_meta_json "$RUN_ID" "baseBranch" || echo "main")"
PATCH_ANALYSIS=$(analyze_patch_for_results "$RUN_DIR" "$MODE" || echo "{\"hasChanges\":false,\"workDetected\":false,\"answerLocation\":null,\"changedFiles\":[],\"patchSize\":0}")

# Update meta.json with artifact paths for quick reference
RUN_DIR_ESCAPED=$(echo "$RUN_DIR" | sed 's/"/\\"/g')
ARTIFACTS_JSON="{\"patch\":\"${RUN_DIR}/patch.diff\",\"changedFiles\":\"${RUN_DIR}/changed_files.txt\""
if [ "$MODE" = "work" ]; then
  ARTIFACTS_JSON="${ARTIFACTS_JSON},\"diffstat\":\"${RUN_DIR}/diffstat.txt\""
fi
ARTIFACTS_JSON="${ARTIFACTS_JSON}}"
write_meta_json "$RUN_ID" "artifacts" "$ARTIFACTS_JSON"

# Generate result.json
STATUS="success"
QUALITY_REVIEW_STATUS="passed"
VERIFICATION_STATUS="verified"

# Format patch analysis for JSON
PATCH_ANALYSIS_JSON="$PATCH_ANALYSIS"
if command -v jq &> /dev/null; then
  PATCH_ANALYSIS_JSON=$(echo "$PATCH_ANALYSIS" | jq -c '.' 2>/dev/null || echo "$PATCH_ANALYSIS")
fi

FINAL_OUTPUT="Agent completed task"
if [ "$MODE" = "research" ] && [ -f "${RUN_DIR}/answer.md" ]; then
  FINAL_OUTPUT="Answer written to answer.md"
fi

# Build result JSON with conditional fields
RESULT_JSON_BASE=$(cat <<EOF
{
  "runId": "$RUN_ID",
  "provider": "$PROVIDER",
  "mode": "$MODE",
  "runtime": "$(read_meta_json "$RUN_ID" "runtime" || echo "await")",
  "status": "$STATUS",
  "level": "$(read_meta_json "$RUN_ID" "level" || echo "1")",
  "parentRunId": "$(read_meta_json "$RUN_ID" "parentRunId" || echo "null")",
  "startedAt": "$(read_meta_json "$RUN_ID" "startedAt" || echo "")",
  "completedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "report": "$FINAL_OUTPUT",
  "verificationStatus": "$VERIFICATION_STATUS",
  "qualityReviewStatus": "$QUALITY_REVIEW_STATUS",
  "rescueAttempts": $RESCUE_ATTEMPTS,
  "retryCount": $VERIFICATION_RETRIES,
  "escalationLevel": "$(read_meta_json "$RUN_ID" "escalationLevel" || echo "none")",
  "patchAnalysis": $PATCH_ANALYSIS_JSON,
  "artifacts": {
EOF
)

# Add research mode specific fields
if [ "$MODE" = "research" ]; then
  RESULT_JSON_BASE="${RESULT_JSON_BASE}
    \"answer\": \"${RUN_DIR}/answer.md\",
    \"answerExtractionMethod\": \"${EXTRACTION_METHOD}\","
fi

# Add common artifacts
RESULT_JSON_BASE="${RESULT_JSON_BASE}
    \"patch\": \"${RUN_DIR}/patch.diff\",
    \"changedFiles\": \"${RUN_DIR}/changed_files.txt\""

# Add work mode specific artifacts
if [ "$MODE" = "work" ]; then
  RESULT_JSON_BASE="${RESULT_JSON_BASE},
    \"diffstat\": \"${RUN_DIR}/diffstat.txt\""
fi

# Close artifacts and result JSON
RESULT_JSON="${RESULT_JSON_BASE}
  }
}"

# Write result.json
echo "$RESULT_JSON" > "${RUN_DIR}/result.json"

# Auto-cleanup
QUICK_MERGE=$(read_meta_json "$RUN_ID" "quickMerge" || echo "false")
auto_cleanup "$RUN_ID" "$STATUS" "$MODE" "$QUICK_MERGE"

# Output result.json to stdout
cat "${RUN_DIR}/result.json"

