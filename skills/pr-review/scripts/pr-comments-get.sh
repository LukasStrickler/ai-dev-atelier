#!/bin/bash
# Get a single PR comment with full context
# Usage: ./get-pr-comment.sh [PR_NUMBER] [INDEX_OR_ID] [--verbose]
#   PR_NUMBER: The PR number (optional, defaults to latest detected PR)
#   INDEX_OR_ID: Either a number (1-based index of unresolved comments) or a comment ID (optional, defaults to 1)
#   --verbose: Enable verbose logging
# 
# Examples:
#   $0                    # Auto-detect PR, get first unresolved comment (index 1)
#   $0 1                  # Auto-detect PR, get comment at index 1 or by ID 1
#   $0 1 2                # PR #1, get comment at index 2 or by ID 2
#   $0 2507015942         # Auto-detect PR, get comment by ID 2507015942

set -euo pipefail

# Initialize script using utility function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "${SCRIPT_DIR}/lib/pr-comments-utils.sh" || ! setup_pr_comments_script; then
  exit 1
fi

# Parse verbose flag using utils
VERBOSE=$(parse_verbose_flag "$@")

# Export VERBOSE so log_verbose() can use it
export VERBOSE

# Parse arguments - both PR_NUMBER and INDEX_OR_ID are optional
PR_NUMBER=""
INDEX_OR_ID=""

# Collect non-flag arguments
NON_FLAG_ARGS=()
for arg in "$@"; do
  if [ "$arg" != "--verbose" ] && [ "$arg" != "-v" ]; then
    if echo "$arg" | grep -qE '^[0-9]+$'; then
      NON_FLAG_ARGS+=("$arg")
    else
      log_error "Invalid argument: $arg (must be numeric)"
      exit 1
    fi
  fi
done

# Parse arguments based on count
if [ ${#NON_FLAG_ARGS[@]} -eq 0 ]; then
  # No arguments: auto-detect PR, use index 1
  PR_NUMBER=""
  INDEX_OR_ID="1"
elif [ ${#NON_FLAG_ARGS[@]} -eq 1 ]; then
  # One argument: could be PR number or index/ID
  ARG="${NON_FLAG_ARGS[0]}"
  if [ "$ARG" -lt 1000 ]; then
    # Small number - treat as index, auto-detect PR
    PR_NUMBER=""
    INDEX_OR_ID="$ARG"
  else
    # Large number - treat as comment ID, auto-detect PR
    PR_NUMBER=""
    INDEX_OR_ID="$ARG"
  fi
elif [ ${#NON_FLAG_ARGS[@]} -eq 2 ]; then
  # Two arguments: first is PR number, second is index/ID
  PR_NUMBER="${NON_FLAG_ARGS[0]}"
  INDEX_OR_ID="${NON_FLAG_ARGS[1]}"
else
  log_error "Too many arguments"
  echo "   Usage: $0 [PR_NUMBER] [INDEX_OR_ID] [--verbose]"
  exit 1
fi

# Auto-detect PR number if not provided
if [ -z "$PR_NUMBER" ]; then
  log_info "No PR number provided, detecting latest PR..."
  PR_NUMBER=$(detect_pr_number)
  if [ -z "$PR_NUMBER" ]; then
    log_error "Could not detect PR number automatically"
    echo "Try one of these methods:"
    echo "  1. Run 'bun run pr:comments <PR_NUMBER>' first to create a metadata file"
    echo "  2. Use 'gh pr view' to see if GitHub CLI can detect the PR"
    echo "  3. Manually specify the PR number: $0 <PR_NUMBER> [INDEX_OR_ID]"
  exit 1
fi
  log_info "Detected PR: #${PR_NUMBER}"
fi

# Default to first unresolved comment (index 1) if not provided
if [ -z "$INDEX_OR_ID" ]; then
  INDEX_OR_ID="1"
  log_info "No index/ID provided, using first unresolved comment (index 1)"
fi

# Validate PR number
if ! validate_pr_number "$PR_NUMBER"; then
  log_error "Invalid PR number: $PR_NUMBER (must be numeric)"
  exit 1
fi

# Get repository owner/repo
OWNER_REPO=$(get_repo_owner_repo)
if [ -z "$OWNER_REPO" ]; then
  exit 1
fi

log_verbose "Repository: ${OWNER_REPO}"
log_verbose "PR: #${PR_NUMBER}"

# Load metadata file using utils (sets LATEST_COMMIT_SHA as global)
METADATA_FILE=$(load_pr_metadata "$PR_NUMBER")
if [ $? -ne 0 ] || [ -z "$METADATA_FILE" ]; then
  exit 1
fi

log_verbose "Using comments file: $(basename "$METADATA_FILE")"

# Get comment by index or ID using utils
RESULT=$(get_comment_by_index_or_id "$METADATA_FILE" "$INDEX_OR_ID")
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ]; then
  # All comments are resolved - show completion message
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ All PR Comments Resolved"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Get statistics from metadata file
  TOTAL_COMMENTS=$(jq '.review_comments | length // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
  RESOLVED_COUNT=$(jq '[.review_comments[] | select(.resolved == true)] | length // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
  
  echo "  PR: #${PR_NUMBER}"
  echo "  Total comments: ${TOTAL_COMMENTS}"
  echo "  Resolved: ${RESOLVED_COUNT}"
  echo "  Unresolved: 0"
  echo ""
  echo "🎉 All PR review comments have been processed!"
  echo ""
  echo "Next steps:"
  echo "  - Review the changes and ensure everything is correct"
  echo "  - Run 'bun run agent:finalize' to verify code quality"
  echo "  - Commit and push your changes"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
elif [ $EXIT_CODE -ne 0 ]; then
  exit 1
fi

# Extract comment and comment_id from result
COMMENT=$(echo "$RESULT" | jq -c '.comment' 2>/dev/null || echo "")
COMMENT_ID=$(echo "$RESULT" | jq -r '.comment_id // empty' 2>/dev/null || echo "")

# Log which method was used
if [ "$INDEX_OR_ID" -lt 1000 ]; then
  log_info "Found comment at index ${INDEX_OR_ID} (ID: ${COMMENT_ID})"
else
  log_verbose "Found comment by ID: ${COMMENT_ID}"
fi

# Extract comment details in single jq call using utils
COMMENT_DETAILS=$(extract_comment_details "$COMMENT")
# Use COMMENT_ID from result if available, otherwise extract from details
if [ -z "$COMMENT_ID" ]; then
  COMMENT_ID=$(echo "$COMMENT_DETAILS" | jq -r '.id // empty' 2>/dev/null || echo "")
fi
FILE_PATH=$(echo "$COMMENT_DETAILS" | jq -r '.path // empty' 2>/dev/null || echo "")
LINE_NUMBER=$(echo "$COMMENT_DETAILS" | jq -r '.line // empty' 2>/dev/null || echo "")
AUTHOR=$(echo "$COMMENT_DETAILS" | jq -r '.author // empty' 2>/dev/null || echo "")
BODY=$(echo "$COMMENT_DETAILS" | jq -r '.body // empty' 2>/dev/null || echo "")
RESOLVED=$(echo "$COMMENT_DETAILS" | jq -r '.resolved // false' 2>/dev/null || echo "false")

# Display comment information
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 PR Comment Details"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  PR: #${PR_NUMBER}"
echo "  Comment ID: ${COMMENT_ID}"
echo "  Status: $([ "$RESOLVED" = "true" ] && echo "✅ Resolved" || echo "❌ Unresolved")"
echo "  Author: @${AUTHOR}"
echo "  File: ${FILE_PATH}"
if [ -n "$LINE_NUMBER" ] && [ "$LINE_NUMBER" != "null" ]; then
  echo "  Line: ${LINE_NUMBER}"
fi
echo ""

# Show comment body (cleaned)
if [ -n "$BODY" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "💬 Comment"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  CLEAN_BODY=$(clean_html_body "$BODY")
  echo "$CLEAN_BODY"
  echo ""
fi

# Show file context if file exists using utils
if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📄 File Context: ${FILE_PATH}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  show_file_context "$FILE_PATH" "$LINE_NUMBER" 10
  echo ""
else
  if [ -n "$FILE_PATH" ]; then
    log_warning "File not found: ${FILE_PATH}"
  fi
fi

# Show quick actions (LLM-optimized: non-interactive, shows commands to run)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Quick Actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ⚠️  CRITICAL: Think before fixing! Default to dismissing unless confident it's a real issue."
echo ""
echo "  Before deciding, ask yourself:"
echo "    1. Is this actually a problem? (Read the actual code, not just the comment)"
echo "    2. Is this worth fixing? (Will it improve code quality, or is it just pedantic?)"
echo "    3. Is this a false positive? (Is the reviewer misunderstanding the code?)"
echo "    4. Is this intentional? (Is the 'issue' actually by design?)"
echo "    5. Will fixing this cause problems? (Could the fix introduce bugs or complexity?)"
echo "    6. Is this consistent with the codebase? (Are similar patterns used elsewhere?)"
echo ""
echo "  When in doubt, DISMISS. Better to dismiss bloat than fix unnecessary things."
echo ""
echo "  If this is a REAL ISSUE (only fix if you're confident):"
echo "    1. Fix the issue in the code"
echo "    2. Run: bun run agent:finalize"
echo "    3. Run: bun run pr:comments:resolve ${PR_NUMBER} ${COMMENT_ID}"
echo ""
echo "  If this is BLOAT (not worth fixing - default to this):"
echo "    Run: bun run pr:comments:dismiss ${PR_NUMBER} ${COMMENT_ID} \"bloat\""
echo "    Example: bun run pr:comments:dismiss ${PR_NUMBER} ${COMMENT_ID} \"bloat\""
echo ""
echo "  If this should be DISMISSED (with custom reason):"
echo "    Run: bun run pr:comments:dismiss ${PR_NUMBER} ${COMMENT_ID} \"<REASON>\""
echo "    Examples:"
echo "      - bun run pr:comments:dismiss ${PR_NUMBER} ${COMMENT_ID} \"false positive\""
echo "      - bun run pr:comments:dismiss ${PR_NUMBER} ${COMMENT_ID} \"intentional design\""
echo "      - bun run pr:comments:dismiss ${PR_NUMBER} ${COMMENT_ID} \"not applicable\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

