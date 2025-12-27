#!/bin/bash
# Dismiss PR review comments with a reason
# Usage: ./dismiss-pr-comment.sh [PR_NUMBER] <COMMENT_ID> <REASON>
#   PR_NUMBER: The PR number (optional, defaults to latest detected PR)
#   COMMENT_ID: The comment ID to dismiss (required)
#   REASON: The reason for dismissal (required, e.g., "not applicable", "false positive", "out of scope")

set -euo pipefail

# Initialize script using utility function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "${SCRIPT_DIR}/lib/pr-comments-utils.sh" || ! setup_pr_comments_script; then
  exit 1
fi

# Parse arguments
if [ $# -lt 2 ]; then
  log_error "Usage: $0 [PR_NUMBER] <COMMENT_ID> <REASON>"
  echo ""
  echo "Examples:"
  echo "  $0 2507094339 \"not applicable\"        # Dismiss comment (auto-detect PR)"
  echo "  $0 1 2507094339 \"not applicable\"       # Dismiss comment from PR #1"
  echo "  $0 2507094339 \"false positive\"         # Dismiss with reason"
  echo ""
  echo "Note: REASON should be a short description of why the comment is being dismissed."
  exit 1
fi

# Check if first argument is a PR number (small number < 1000) or comment ID (large number)
FIRST_ARG="$1"
if echo "$FIRST_ARG" | grep -qE '^[0-9]+$' && [ "$FIRST_ARG" -lt 1000 ]; then
  # First argument is likely a PR number
  PR_NUMBER="$FIRST_ARG"
  COMMENT_ID="$2"
  REASON="$3"
else
  # First argument is likely a comment ID, auto-detect PR
  PR_NUMBER=""
  COMMENT_ID="$1"
  REASON="$2"
fi

# Auto-detect PR number if not provided
if [ -z "$PR_NUMBER" ]; then
  log_info "No PR number provided, detecting latest PR..."
  PR_NUMBER=$(detect_pr_number)
  if [ -z "$PR_NUMBER" ]; then
    log_error "Could not detect PR number automatically"
    echo ""
    echo "Try one of these methods:"
    echo "  1. Run 'bun run pr:comments <PR_NUMBER>' first to create a metadata file"
    echo "  2. Use 'gh pr view' to see if GitHub CLI can detect the PR"
    echo "  3. Manually specify the PR number: $0 <PR_NUMBER> <COMMENT_ID> <REASON>"
    exit 1
  fi
  log_info "Detected PR: #${PR_NUMBER}"
fi

# Validate PR number using utils
if ! validate_pr_number "$PR_NUMBER"; then
  log_error "Invalid PR number: $PR_NUMBER (must be numeric)"
  exit 1
fi

# Validate comment ID using utility function
if ! validate_comment_id "$COMMENT_ID"; then
  log_error "Invalid comment ID: ${COMMENT_ID} (must be numeric)"
  echo "   Use 'bun run pr:comments:get <PR_NUMBER> <INDEX>' to find comment IDs."
  exit 1
fi

# Validate reason (not empty)
if [ -z "$REASON" ]; then
  log_error "Dismissal reason cannot be empty"
  exit 1
fi

# Get repository owner/repo
OWNER_REPO=$(get_repo_owner_repo)
if [ -z "$OWNER_REPO" ]; then
  exit 1
fi

# Parse owner/repo using utils
read -r OWNER REPO <<< "$(parse_owner_repo "$OWNER_REPO")"

log_info "Repository: ${OWNER}/${REPO}"
log_info "PR: #${PR_NUMBER}"
log_info "Comment ID: ${COMMENT_ID}"
log_info "Reason: ${REASON}"
echo ""

# Find thread ID for the comment ID using utility function
log_info "Finding thread for comment ID ${COMMENT_ID}..."

# Build array of comment IDs for jq
COMMENT_IDS_JSON=$(echo "[$COMMENT_ID]" | jq -c .)

# Find threads for comment IDs using utility function
THREAD_MAP=$(find_threads_for_comments "$OWNER" "$REPO" "$PR_NUMBER" "$COMMENT_IDS_JSON")

# Extract thread info for this comment
THREAD_INFO=$(echo "$THREAD_MAP" | jq -c --arg comment_id "$COMMENT_ID" '.[] | select(.comment_id == ($comment_id | tonumber)) | {id: .thread_id, isResolved: .is_resolved}' 2>/dev/null | head -1)

if [ -z "$THREAD_INFO" ] || [ "$THREAD_INFO" = "null" ]; then
  log_error "Thread not found for comment ID ${COMMENT_ID}"
  exit 1
fi

THREAD_ID=$(echo "$THREAD_INFO" | jq -r '.id // empty' 2>/dev/null)
IS_RESOLVED=$(echo "$THREAD_INFO" | jq -r '.isResolved // false' 2>/dev/null || echo "false")

if [ -z "$THREAD_ID" ]; then
  log_error "Failed to extract thread ID for comment ${COMMENT_ID}"
  exit 1
fi

if [ "$IS_RESOLVED" = "true" ]; then
  log_warning "Thread ${THREAD_ID} is already resolved"
  log_info "Note: Adding dismissal comment will not unresolve the thread."
  # Skip resolving if already resolved (non-interactive for LLM agents)
  SKIP_RESOLVE=true
else
  SKIP_RESOLVE=false
fi

echo ""
log_info "Found thread ${THREAD_ID} for comment ${COMMENT_ID}"
echo ""

# Dismiss the comment using utility function
# Pass PR number, owner, repo, thread ID, comment ID, reason, and skip_resolve flag
if dismiss_review_comment "$PR_NUMBER" "$OWNER" "$REPO" "$THREAD_ID" "$COMMENT_ID" "$REASON" "$SKIP_RESOLVE"; then
  echo ""
  log_success "Comment dismissed successfully"
  
  # Automatically refresh comments to get latest data
  log_info "Refreshing comments to get latest data..."
  bash "${SCRIPT_DIR}/pr-comments-fetch.sh" read "$PR_NUMBER" > /dev/null 2>&1 || log_warning "Failed to refresh comments"
  
  echo ""
  log_info "Done!"
else
  echo ""
  log_error "Failed to dismiss comment"
  exit 1
fi

echo ""

