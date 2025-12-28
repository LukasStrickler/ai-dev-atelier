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
  PID=$(echo "$META_JSON" | jq -r '.pid // empty')
  STATUS=$(echo "$META_JSON" | jq -r '.status // "unknown"')
else
  WORKTREE_PATH=$(echo "$META_JSON" | grep -o '"worktreePath":"[^"]*"' | sed 's/"worktreePath":"\([^"]*\)"/\1/' || echo "")
  MODE=$(echo "$META_JSON" | grep -o '"mode":"[^"]*"' | sed 's/"mode":"\([^"]*\)"/\1/' || echo "work")
  PROVIDER=$(echo "$META_JSON" | grep -o '"provider":"[^"]*"' | sed 's/"provider":"\([^"]*\)"/\1/' || echo "cursor")
  PID=$(echo "$META_JSON" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/' || echo "")
  STATUS=$(echo "$META_JSON" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/' || echo "unknown")
fi

RUN_DIR=$(get_run_directory "$RUN_ID")
PROMPT_PATH="${RUN_DIR}/prompt.md"
if [ ! -f "$PROMPT_PATH" ] && [ -n "$WORKTREE_PATH" ]; then
  if [ -f "${WORKTREE_PATH}/prompt.md" ]; then
    PROMPT_PATH="${WORKTREE_PATH}/prompt.md"
  fi
fi

# If run is still active, wait briefly before collecting
if [ -n "$PID" ] && check_process_alive "$PID"; then
  if [ "$STATUS" != "completed" ] && [ "$STATUS" != "failed" ] && [ "$STATUS" != "timeout" ]; then
    COLLECT_WAIT_TIMEOUT="${COLLECT_WAIT_TIMEOUT:-300}"
    echo "Run $RUN_ID still active; waiting up to ${COLLECT_WAIT_TIMEOUT}s before collect..." >&2
    if ! bash "${SCRIPT_DIR}/agent-wait.sh" "$RUN_ID" "$COLLECT_WAIT_TIMEOUT"; then
      echo "Warning: agent-wait timed out; collecting partial artifacts" >&2
    fi
  fi
fi

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
RESULT_OK="false"
EXTRACTION_METHOD="failed"
RESCUE_PROMPT_PATH=""
RESCUE_SCRIPT_PATH=""
RESCUE_REASON=""

if check_result_exists "$RUN_ID" "$MODE"; then
  RESULT_OK="true"
fi

# Extract primary output (patch already generated above)
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

# Rescue if no results detected
if [ "$RESULT_OK" = "false" ]; then
  if [ "$WORK_DETECTED_IN_PATCH" = "true" ]; then
    echo "Work detected in patch but not in expected format; attempting rescue..." >&2
  else
    echo "No results found; attempting rescue..." >&2
  fi

  if [ -n "$WORKTREE_PATH" ] && [ ! -d "$WORKTREE_PATH" ]; then
    RESCUE_REASON="worktree_missing"
    echo "Worktree missing; skipping rescue attempts." >&2
  else
    while [ $RESCUE_ATTEMPTS -lt $MAX_RESCUE_ATTEMPTS ]; do
      RESCUE_ATTEMPTS=$((RESCUE_ATTEMPTS + 1))
      echo "Rescue attempt $RESCUE_ATTEMPTS (basic)..." >&2

      if [ -n "$PID" ] && check_process_alive "$PID"; then
        RESCUE_WAIT_TIMEOUT=$((RESCUE_ATTEMPTS * 30))
        echo "Waiting ${RESCUE_WAIT_TIMEOUT}s for agent completion..." >&2
        bash "${SCRIPT_DIR}/agent-wait.sh" "$RUN_ID" "$RESCUE_WAIT_TIMEOUT" || true
      fi

      generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$(read_meta_json "$RUN_ID" "baseBranch" || echo "main")"
      PATCH_ANALYSIS=$(analyze_patch_for_results "$RUN_DIR" "$MODE" || echo "{\"hasChanges\":false,\"workDetected\":false}")

      if [ "$MODE" = "research" ]; then
        extract_answer_file "$WORKTREE_PATH" "$RUN_DIR" "EXTRACTION_METHOD" || true
        write_meta_json "$RUN_ID" "answerExtractionMethod" "$EXTRACTION_METHOD"
      fi

      if check_result_exists "$RUN_ID" "$MODE"; then
        RESULT_OK="true"
        echo "Rescue successful!" >&2
        break
      fi

      BASE_DELAY=$((RESCUE_ATTEMPTS * 2))
      MAX_DELAY="${RESCUE_MAX_DELAY:-30}"
      if [ "$BASE_DELAY" -gt "$MAX_DELAY" ]; then
        BASE_DELAY="$MAX_DELAY"
      fi
      JITTER_PCT="${RESCUE_JITTER_PCT:-10}"
      JITTER_RANGE=$((BASE_DELAY * JITTER_PCT / 100))
      JITTER=0
      if [ "$JITTER_RANGE" -gt 0 ]; then
        JITTER=$((RANDOM % (JITTER_RANGE + 1)))
      fi
      SLEEP_FOR=$((BASE_DELAY + JITTER))
      echo "Backoff sleep ${SLEEP_FOR}s (base=${BASE_DELAY}s, jitter=${JITTER}s)" >&2
      sleep "$SLEEP_FOR"
    done
  fi
fi

if [ "$RESULT_OK" != "true" ]; then
  if [ -z "$RESCUE_REASON" ]; then
    RESCUE_REASON="no_results_detected"
  fi
  RESCUE_PROMPT_PATH="${RUN_DIR}/rescue.md"
  RESCUE_SCRIPT_PATH="${RUN_DIR}/rescue.sh"
  RESCUE_OUT_PATH="${RUN_DIR}/out.ndjson"
  BASE_BRANCH="$(read_meta_json "$RUN_ID" "baseBranch" 2>/dev/null || echo "main")"
  MODEL="$(read_meta_json "$RUN_ID" "model" 2>/dev/null || echo "auto")"
  PARENT_RUN_ID_RES="$(read_meta_json "$RUN_ID" "parentRunId" 2>/dev/null || echo "")"

  cat > "$RESCUE_PROMPT_PATH" <<EOF
# Rescue Prompt

Run ID: ${RUN_ID}
Reason: ${RESCUE_REASON}
Mode: ${MODE}
Provider: ${PROVIDER}
Model: ${MODEL}

## What happened
- No valid result was detected after rescue attempts.
- See \`${RUN_DIR}/patch.diff\` and \`${RESCUE_OUT_PATH}\` for diagnostics.

## Suggested follow-up
1. Review \`${PROMPT_PATH}\` for the original task.
2. Re-run using \`${RESCUE_SCRIPT_PATH}\`, or spawn manually with the same prompt.
3. Ensure the agent writes a valid output (answer.md for research, code changes for work).
EOF

  cat > "$RESCUE_SCRIPT_PATH" <<EOF
#!/bin/bash
set -euo pipefail

PROMPT_FILE="${PROMPT_PATH}"
if [ ! -f "\$PROMPT_FILE" ]; then
  echo "Missing prompt file: \$PROMPT_FILE" >&2
  exit 1
fi

PARENT_ARG=()
if [ -n "${PARENT_RUN_ID_RES}" ] && [ "${PARENT_RUN_ID_RES}" != "null" ]; then
  PARENT_ARG=(--parent-run-id "${PARENT_RUN_ID_RES}")
fi

bash "${PROJECT_ROOT}/skills/agent-orchestration/scripts/agent-spawn.sh" \\
  --provider "${PROVIDER}" \\
  --mode "${MODE}" \\
  --runtime "await" \\
  --prompt "\$(cat "\$PROMPT_FILE")" \\
  --base "${BASE_BRANCH}" \\
  --model "${MODEL}" \\
  "\${PARENT_ARG[@]}"
EOF

  chmod +x "$RESCUE_SCRIPT_PATH" 2>/dev/null || true
  write_meta_json "$RUN_ID" "rescuePromptPath" "$RESCUE_PROMPT_PATH" "rescueScriptPath" "$RESCUE_SCRIPT_PATH"
fi

# Re-analyze patch for final result (in case rescue attempts made changes)
# Re-generate artifacts to ensure they're up to date
generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$(read_meta_json "$RUN_ID" "baseBranch" || echo "main")"
PATCH_ANALYSIS=$(analyze_patch_for_results "$RUN_DIR" "$MODE" || echo "{\"hasChanges\":false,\"workDetected\":false,\"answerLocation\":null,\"changedFiles\":[],\"patchSize\":0}")

# Update meta.json with artifact paths for quick reference
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
if [ "$RESULT_OK" != "true" ]; then
  STATUS="failed"
  QUALITY_REVIEW_STATUS="unknown"
  VERIFICATION_STATUS="unverified"
  write_meta_json "$RUN_ID" "escalationLevel" "human" "failureReason" "${RESCUE_REASON:-no_results_detected}"
fi

# Format patch analysis for JSON
PATCH_ANALYSIS_JSON="$PATCH_ANALYSIS"
if command -v jq &> /dev/null; then
  PATCH_ANALYSIS_JSON=$(echo "$PATCH_ANALYSIS" | jq -c '.' 2>/dev/null || echo "$PATCH_ANALYSIS")
fi

FINAL_OUTPUT="Agent completed task"
if [ "$MODE" = "research" ] && [ -f "${RUN_DIR}/answer.md" ]; then
  FINAL_OUTPUT="Answer written to answer.md"
fi
if [ "$STATUS" = "failed" ]; then
  FINAL_OUTPUT="No results detected; see patch.diff and out.ndjson for diagnostics"
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
  "escalationLevel": "$(read_meta_json "$RUN_ID" "escalationLevel" || echo "none")",
  "rescuePromptPath": "$(read_meta_json "$RUN_ID" "rescuePromptPath" || echo "")",
  "rescueScriptPath": "$(read_meta_json "$RUN_ID" "rescueScriptPath" || echo "")",
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
