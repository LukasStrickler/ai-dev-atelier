#!/bin/bash
# Resolve PR review comments in GitHub
# Usage: ./resolve-pr-comments.sh [PR_NUMBER] <COMMENT_ID_1> [COMMENT_ID_2] ...
#   PR_NUMBER: The PR number (optional, defaults to latest detected PR)
#   COMMENT_ID: One or more comment IDs to resolve (databaseId from REST API, required)

set -euo pipefail

# Initialize script using utility function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "${SCRIPT_DIR}/lib/pr-comments-utils.sh" || ! setup_pr_comments_script; then
  exit 1
fi

# Parse arguments
if [ $# -lt 1 ]; then
  log_error "Usage: $0 [PR_NUMBER] <COMMENT_ID_1> [COMMENT_ID_2] ..."
  echo ""
  echo "Examples:"
  echo "  $0 2507094339                    # Resolve comment by ID (auto-detect PR)"
  echo "  $0 1 2507094339                  # Resolve comment by ID from PR #1"
  echo "  $0 2507094339 2507094340        # Resolve multiple comments (auto-detect PR)"
  echo ""
  echo "Note: Only comment IDs are accepted (not indices)."
  echo "      Use 'bun run pr:comments:get' to find comment IDs."
  exit 1
fi

# Check if first argument is a PR number (small number < 1000) or comment ID (large number)
FIRST_ARG="$1"
if echo "$FIRST_ARG" | grep -qE '^[0-9]+$' && [ "$FIRST_ARG" -lt 1000 ]; then
  # First argument is likely a PR number
  PR_NUMBER="$FIRST_ARG"
shift
COMMENT_IDS=("$@")
else
  # First argument is likely a comment ID, auto-detect PR
  PR_NUMBER=""
  COMMENT_IDS=("$@")
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
    echo "  3. Manually specify the PR number: $0 <PR_NUMBER> <COMMENT_ID_1> ..."
    exit 1
  fi
  log_info "Detected PR: #${PR_NUMBER}"
fi

# Validate PR number using utils
if ! validate_pr_number "$PR_NUMBER"; then
  log_error "Invalid PR number: $PR_NUMBER (must be numeric)"
  exit 1
fi

# Check if we have any comment IDs
if [ ${#COMMENT_IDS[@]} -eq 0 ]; then
  log_error "No comment IDs provided"
  echo "   Usage: $0 [PR_NUMBER] <COMMENT_ID_1> [COMMENT_ID_2] ..."
  exit 1
fi

# Validate all arguments are comment IDs using utility function
for COMMENT_ID in "${COMMENT_IDS[@]}"; do
  if ! validate_comment_id "$COMMENT_ID"; then
    log_error "Invalid comment ID: ${COMMENT_ID} (must be numeric)"
    echo "   Use 'bun run pr:comments:get <PR_NUMBER> <INDEX>' to find comment IDs."
    exit 1
  fi
done

# Get repository owner/repo
OWNER_REPO=$(get_repo_owner_repo)
if [ -z "$OWNER_REPO" ]; then
  exit 1
fi

  # Parse owner/repo using utils
  read -r OWNER REPO <<< "$(parse_owner_repo "$OWNER_REPO")"

log_info "Repository: ${OWNER}/${REPO}"
log_info "PR: #${PR_NUMBER}"
log_info "Comment IDs to resolve: ${COMMENT_IDS[*]}"
echo ""

# Fetch all review threads to find thread IDs for the comment IDs
log_info "Fetching review threads to find thread IDs..."

# Build array of comment IDs for jq (as numbers, not strings)
COMMENT_IDS_JSON=$(printf '%s\n' "${COMMENT_IDS[@]}" | jq -R 'tonumber' | jq -s .)

# Find threads for comment IDs using utility function
THREAD_MAP=$(find_threads_for_comments "$OWNER" "$REPO" "$PR_NUMBER" "$COMMENT_IDS_JSON")

THREAD_IDS_TO_RESOLVE=()

# Process thread map to extract thread IDs
if [ -n "$THREAD_MAP" ] && [ "$THREAD_MAP" != "[]" ] && [ "$THREAD_MAP" != "null" ]; then
while IFS= read -r entry; do
  if [ -n "$entry" ] && [ "$entry" != "null" ]; then
    COMMENT_ID=$(echo "$entry" | jq -r '.comment_id // empty' 2>/dev/null)
    THREAD_ID=$(echo "$entry" | jq -r '.thread_id // empty' 2>/dev/null)
    IS_RESOLVED=$(echo "$entry" | jq -r '.is_resolved // false' 2>/dev/null || echo "false")
    
      if [ -z "$THREAD_ID" ]; then
        continue
      fi
      
      if [ "$IS_RESOLVED" = "true" ]; then
        log_warning "Comment ${COMMENT_ID} is already in a resolved thread (thread: ${THREAD_ID})"
      else
        THREAD_IDS_TO_RESOLVE+=("$THREAD_ID")
        log_info "Found thread ${THREAD_ID} for comment ${COMMENT_ID}"
      fi
    fi
  done <<< "$(echo "$THREAD_MAP" | jq -c '.[]' 2>/dev/null || echo "")"
fi


# Remove duplicates from thread IDs
if [ ${#THREAD_IDS_TO_RESOLVE[@]} -gt 0 ]; then
  UNIQUE_THREAD_IDS=()
  while IFS= read -r line; do
    [ -n "$line" ] && UNIQUE_THREAD_IDS+=("$line")
  done < <(printf '%s\n' "${THREAD_IDS_TO_RESOLVE[@]}" | sort -u)
else
  UNIQUE_THREAD_IDS=()
fi

if [ ${#UNIQUE_THREAD_IDS[@]} -eq 0 ]; then
  log_warning "No threads found to resolve"
  exit 0
fi

# Show threads to resolve
echo ""
echo "📋 Threads to resolve:"
for THREAD_ID in "${UNIQUE_THREAD_IDS[@]}"; do
  echo "  - ${THREAD_ID}"
done
echo ""

# Resolve each thread using utility function (non-interactive for LLM agents)
log_info "Resolving threads..."
RESOLVED_COUNT=0
FAILED_COUNT=0

for THREAD_ID in "${UNIQUE_THREAD_IDS[@]}"; do
  if resolve_review_thread "$THREAD_ID"; then
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
  else
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

echo ""
# Show accurate success/failure status
if [ "$RESOLVED_COUNT" -gt 0 ] && [ "$FAILED_COUNT" -eq 0 ]; then
  # All threads resolved successfully
  log_success "Resolved ${RESOLVED_COUNT} thread(s)"
elif [ "$RESOLVED_COUNT" -gt 0 ] && [ "$FAILED_COUNT" -gt 0 ]; then
  # Partial success - some resolved, some failed
  log_warning "Partially resolved: ${RESOLVED_COUNT} succeeded, ${FAILED_COUNT} failed"
  echo ""
  echo "⚠️  Some threads failed to resolve. This may indicate:"
  echo "   - Threads were already resolved"
  echo "   - Network/API errors"
  echo "   - Permission issues"
  echo "   - Invalid thread IDs"
  echo ""
  echo "Check the error messages above for details."
elif [ "$RESOLVED_COUNT" -eq 0 ] && [ "$FAILED_COUNT" -gt 0 ]; then
  # All failed
  log_error "Failed to resolve ${FAILED_COUNT} thread(s)"
  echo ""
  echo "❌ No threads were resolved. This may indicate:"
  echo "   - Threads were already resolved"
  echo "   - Network/API errors"
  echo "   - Permission issues"
  echo "   - Invalid thread IDs"
  echo ""
  echo "Check the error messages above for details."
  exit 1
else
  # No threads to resolve (shouldn't happen, but handle gracefully)
  log_warning "No threads were resolved"
fi

# Automatically refresh comments to get latest data
if [ "$RESOLVED_COUNT" -gt 0 ]; then
  echo ""
  log_info "Refreshing comments to get latest data..."
  if bash "${SCRIPT_DIR}/pr-comments-fetch.sh" read "$PR_NUMBER" > /dev/null 2>&1; then
    log_verbose "Comments refreshed successfully"
  else
    log_warning "Failed to refresh comments (this is non-critical)"
  fi
fi

echo ""
if [ "$RESOLVED_COUNT" -gt 0 ] && [ "$FAILED_COUNT" -eq 0 ]; then
  log_info "Done!"
else
  log_warning "Done (with warnings - see above)"
fi

