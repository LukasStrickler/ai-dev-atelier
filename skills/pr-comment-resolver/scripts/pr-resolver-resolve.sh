#!/bin/bash
# Resolve PR review comment thread(s) in GitHub
# Usage: bash pr-resolver-resolve.sh <PR_NUMBER> <COMMENT_ID> [COMMENT_ID_2] ...
# 
# This resolves the thread containing the comment(s) in GitHub.
# Use after you've fixed the issue the comment refers to.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pr-resolver-utils.sh"

if ! check_prerequisites; then
  exit 1
fi

# Parse arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <PR_NUMBER> <COMMENT_ID> [COMMENT_ID_2] ..."
  echo ""
  echo "Examples:"
  echo "  $0 7 2666193945               # Resolve single comment thread"
  echo "  $0 7 2666193945 2666191192    # Resolve multiple comment threads"
  exit 1
fi

PR_NUMBER="$1"
shift
COMMENT_IDS=("$@")

if ! validate_pr_number "$PR_NUMBER"; then
  log_error "Invalid PR number: $PR_NUMBER"
  exit 1
fi

for cid in "${COMMENT_IDS[@]}"; do
  if ! validate_comment_id "$cid"; then
    log_error "Invalid comment ID: $cid"
    exit 1
  fi
done

OWNER_REPO=$(get_repo_owner_repo)
if [ -z "$OWNER_REPO" ]; then
  exit 1
fi
read -r OWNER REPO <<< "$(parse_owner_repo "$OWNER_REPO")"

log_info "Resolving ${#COMMENT_IDS[@]} comment(s) for PR #${PR_NUMBER}..."

RESOLVED_COUNT=0
FAILED_COUNT=0
ALREADY_RESOLVED=0

QUERY_TEMPLATE=$(get_review_threads_query_template)
ALL_THREADS=$(fetch_graphql_paginated "$QUERY_TEMPLATE" "$OWNER" "$REPO" "$PR_NUMBER" 100)

for COMMENT_ID in "${COMMENT_IDS[@]}"; do
  log_info "Finding thread for comment $COMMENT_ID..."

  THREAD_ID=$(find_thread_for_comment "$OWNER" "$REPO" "$PR_NUMBER" "$COMMENT_ID")

  if [ -z "$THREAD_ID" ]; then
    log_warning "Could not find thread for comment $COMMENT_ID"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  # Check if already resolved
  IS_RESOLVED=$(echo "$ALL_THREADS" | jq -r --arg tid "$THREAD_ID" '.[] | select(.id == $tid) | .isResolved' 2>/dev/null || echo "false")
  
  if [ "$IS_RESOLVED" = "true" ]; then
    log_info "Comment $COMMENT_ID is already in a resolved thread"
    ALREADY_RESOLVED=$((ALREADY_RESOLVED + 1))
    continue
  fi
  
  if resolve_thread "$THREAD_ID"; then
    log_success "Resolved thread for comment $COMMENT_ID"
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
  else
    log_error "Failed to resolve thread for comment $COMMENT_ID"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Resolved:         $RESOLVED_COUNT"
echo "Already resolved: $ALREADY_RESOLVED"
echo "Failed:           $FAILED_COUNT"
echo ""

if [ "$FAILED_COUNT" -gt 0 ]; then
  exit 1
fi
