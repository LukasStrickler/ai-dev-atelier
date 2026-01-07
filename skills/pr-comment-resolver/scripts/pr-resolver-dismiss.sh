#!/bin/bash
# Dismiss PR review comment with a reason, then resolve the thread
# Usage: bash pr-resolver-dismiss.sh <PR_NUMBER> <COMMENT_ID> "<REASON>"
#
# This adds a reply comment with the dismissal reason, then resolves the thread.
# Use when the comment is a false positive or not applicable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pr-resolver-utils.sh"

if ! check_prerequisites; then
  exit 1
fi

# Parse arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <PR_NUMBER> <COMMENT_ID> \"<REASON>\""
  echo ""
  echo "Examples:"
  echo "  $0 7 2666193945 \"False positive - the import is intentionally from the local module\""
  echo "  $0 7 2666191192 \"Not applicable - this is auto-generated code\""
  exit 1
fi

PR_NUMBER="$1"
COMMENT_ID="$2"
REASON="$3"

if ! validate_pr_number "$PR_NUMBER"; then
  log_error "Invalid PR number: $PR_NUMBER"
  exit 1
fi

if ! validate_comment_id "$COMMENT_ID"; then
  log_error "Invalid comment ID: $COMMENT_ID"
  exit 1
fi

if [ -z "$REASON" ]; then
  log_error "Dismissal reason is required"
  exit 1
fi

OWNER_REPO=$(get_repo_owner_repo)
if [ -z "$OWNER_REPO" ]; then
  exit 1
fi
read -r OWNER REPO <<< "$(parse_owner_repo "$OWNER_REPO")"

log_info "Dismissing comment $COMMENT_ID with reason: $REASON"

# Find thread for comment
THREAD_ID=$(find_thread_for_comment "$OWNER" "$REPO" "$PR_NUMBER" "$COMMENT_ID")

if [ -z "$THREAD_ID" ]; then
  log_error "Could not find thread for comment $COMMENT_ID"
  exit 1
fi

# Check if already resolved
QUERY_TEMPLATE=$(get_review_threads_query_template)
ALL_THREADS=$(fetch_graphql_paginated "$QUERY_TEMPLATE" "$OWNER" "$REPO" "$PR_NUMBER" 100)
IS_RESOLVED=$(echo "$ALL_THREADS" | jq -r --arg tid "$THREAD_ID" '.[] | select(.id == $tid) | .isResolved' 2>/dev/null || echo "false")

if [ "$IS_RESOLVED" = "true" ]; then
  log_info "Thread is already resolved"
  exit 0
fi

# Add dismissal comment as reply
DISMISSAL_MESSAGE="Dismissed: ${REASON}"
log_info "Adding dismissal comment..."

if add_reply_comment "$OWNER" "$REPO" "$PR_NUMBER" "$COMMENT_ID" "$DISMISSAL_MESSAGE"; then
  log_success "Added dismissal comment"
else
  log_warning "Failed to add dismissal comment (continuing anyway)"
fi

# Resolve the thread
log_info "Resolving thread..."
if resolve_thread "$THREAD_ID"; then
  log_success "Thread dismissed and resolved"
else
  log_error "Failed to resolve thread"
  exit 1
fi

echo ""
echo "Comment $COMMENT_ID dismissed with reason: $REASON"
