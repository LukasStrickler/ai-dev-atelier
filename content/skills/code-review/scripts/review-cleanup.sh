#!/bin/bash
# Cleanup CodeRabbit reviews
# Keeps only the latest 2 task reviews and 2 PR reviews, deletes all others

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/review-utils.sh"

# Cleanup reviews for a specific type
# Usage: cleanup_review_type <review_type> <keep_count>
cleanup_review_type() {
  local review_type="$1"
  local keep_count="$2"
  local reviews
  local count
  local count_num
  local deleted=0
  
  # Find and count review files
  reviews=$(find_review_files "$review_type")
  count=$(count_review_files "$review_type")
  count_num=$(get_numeric_count "$count")
  
  if [ "$count_num" -gt "$keep_count" ]; then
    echo "📝 ${review_type} reviews: Found $count_num, keeping latest $keep_count"
    
    # Get files to delete (skip first N)
    local delete_list
    delete_list=$(echo "$reviews" | tail -n +$((keep_count + 1)))
    
    # Delete review files and their corresponding metadata
    while IFS= read -r review_file; do
      if [ -n "$review_file" ]; then
        # Delete the review file
        if rm -f "$review_file" 2>/dev/null; then
          deleted=$((deleted + 1))
        fi
        
        # Delete corresponding metadata file
        local timestamp
        timestamp=$(extract_timestamp_from_filename "$review_file")
        local metadata_file
        metadata_file=$(get_metadata_file_path "$review_type" "$timestamp")
        rm -f "$metadata_file" 2>/dev/null
      fi
    done <<< "$delete_list"
    
    echo "   Deleted $deleted ${review_type} review(s)"
  else
    echo "📝 ${review_type} reviews: Found $count_num, all kept"
  fi
}

# Main script
main() {
  # Check if .ada/data/reviews directory exists
  if [ ! -d "$REVIEW_DIR" ]; then
    log_warning ".ada/data/reviews directory not found"
    echo "   No reviews to clean up"
    exit 0
  fi
  
  log_info "Cleaning up old CodeRabbit reviews..."
  echo ""
  
  # Cleanup task reviews
  cleanup_review_type "task" "$KEEP_TASK_REVIEWS"
  echo ""
  
  # Cleanup PR reviews
  cleanup_review_type "pr" "$KEEP_PR_REVIEWS"
  echo ""
  
  # Count remaining files
  local remaining_task
  remaining_task=$(count_review_files "task")
  remaining_task=$(get_numeric_count "$remaining_task")
  
  local remaining_pr
  remaining_pr=$(count_review_files "pr")
  remaining_pr=$(get_numeric_count "$remaining_pr")
  
  log_success "Cleanup complete!"
  echo ""
  echo "📊 Remaining reviews:"
  echo "   Task reviews: $remaining_task"
  echo "   PR reviews: $remaining_pr"
  echo "   Total: $((remaining_task + remaining_pr))"
}

# Run main function
main
