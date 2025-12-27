#!/bin/bash
# Read latest CodeRabbit review
# Reads the most recent review (task or PR) from .ada/data/reviews/ directory

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/review-utils.sh"

# Check if .ada/data/reviews directory exists
if [ ! -d "$REVIEW_DIR" ]; then
  log_error ".ada/data/reviews directory not found"
  echo "   Run a review first with: bun run review:task or bun run review:pr"
  exit 1
fi

# Find latest successful review file (task or PR) - one that has a corresponding metadata file
# This skips failed reviews that don't have metadata
LATEST_REVIEW=""
while IFS= read -r -d '' review_file; do
  review_type=$(extract_review_type_from_filename "$review_file")
  timestamp=$(extract_timestamp_from_filename "$review_file")
  metadata_file=$(get_metadata_file_path "$review_type" "$timestamp")
  
  # Check if metadata exists (indicates successful review)
  if [ -f "$metadata_file" ]; then
    LATEST_REVIEW="$review_file"
    break
  fi
done < <(find "$REVIEW_DIR" -name "*-review-*.md" -type f -print0 2>/dev/null | sort -zr)

# If no successful review found, check if there are any review files at all
if [ -z "$LATEST_REVIEW" ]; then
  ANY_REVIEW=$(find "$REVIEW_DIR" -name "*-review-*.md" -type f 2>/dev/null | sort -r | head -1)
  if [ -n "$ANY_REVIEW" ]; then
    # Found review files but none have metadata (all failed)
    log_warning "No successful reviews found"
    echo "   All recent reviews failed (likely rate limit)"
    echo "   Latest failed review: $(basename "$ANY_REVIEW")"
    echo ""
    echo "   Wait for rate limit to expire, then run: bun run review:task"
    exit 0
  else
    log_error "No review files found in .ada/data/reviews/"
    echo "   Run a review first with: bun run review:task or bun run review:pr"
    exit 1
  fi
fi

# Extract review type and timestamp from filename
REVIEW_TYPE=$(extract_review_type_from_filename "$LATEST_REVIEW")
TIMESTAMP=$(extract_timestamp_from_filename "$LATEST_REVIEW")

# Get metadata file path
METADATA_FILE=$(get_metadata_file_path "$REVIEW_TYPE" "$TIMESTAMP")

# Check if this is a failed review
if [ ! -f "$METADATA_FILE" ]; then
  if grep -E -q "Rate limit exceeded|Review failed|ERROR:" "$LATEST_REVIEW" 2>/dev/null; then
    log_warning "Latest review failed (no metadata file found)"
    echo "   This review encountered an error (likely rate limit)"
    echo "   Showing the error output below:"
    echo ""
  fi
fi

log_info "Latest CodeRabbit Review"
echo ""
echo "Type: ${REVIEW_TYPE}"
echo "Timestamp: ${TIMESTAMP}"
echo ""

# Format type name for display (replace underscores with spaces, capitalize)
format_type_name() {
  local type_name="$1"
  echo "$type_name" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1'
}

# Read and display metadata if it exists
if [ -f "$METADATA_FILE" ]; then
  if command -v jq &> /dev/null; then
    # Display statistics if available
    if jq -e '.statistics' "$METADATA_FILE" > /dev/null 2>&1; then
      echo "📊 Statistics:"
      FILES_COUNT=$(jq -r '.statistics.files_count // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
      TYPES_COUNT=$(jq -r '.statistics.types_count // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
      TOTAL_ISSUES=$(jq -r '.statistics.total_issues // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
      DURATION=$(jq -r '.statistics.review_duration_seconds // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
      
      echo "   Files reviewed: ${FILES_COUNT}"
      echo "   Issue types: ${TYPES_COUNT}"
      echo "   Total issues: ${TOTAL_ISSUES}"
      [ "$DURATION" != "0" ] && echo "   Review duration: ${DURATION}s"
      echo ""
    else
      # Fallback to old structure
      echo "📊 Issue Summary:"
      TOTAL=$(jq -r '.issues_summary.total // 0' "$METADATA_FILE" 2>/dev/null || echo "0")
      echo "   Total: ${TOTAL}"
      echo ""
    fi
    
    # Show issue types if available
    if jq -e '.types' "$METADATA_FILE" > /dev/null 2>&1; then
      TYPES_JSON_COUNT=$(jq -r '.types | length' "$METADATA_FILE" 2>/dev/null || echo "0")
      if [ "$TYPES_JSON_COUNT" -gt 0 ]; then
        echo "📋 Issue Types:"
        # Iterate JSON entries directly to safely handle colons in type names
        jq -r '.types | to_entries[] | .key + "|" + (.value | tostring)' "$METADATA_FILE" 2>/dev/null | while IFS='|' read -r type_name count; do
          display_name=$(format_type_name "$type_name")
          echo "   ${display_name}: ${count}"
        done
        echo ""
      fi
    fi
    
    # Show files reviewed if available
    FILES_REVIEWED_COUNT=$(jq -r '.files_reviewed | length' "$METADATA_FILE" 2>/dev/null || echo "0")
    if [ "$FILES_REVIEWED_COUNT" -gt 0 ]; then
      echo "📁 Files Reviewed: ${FILES_REVIEWED_COUNT}"
      jq -r '.files_reviewed[]' "$METADATA_FILE" 2>/dev/null | head -5 | sed 's/^/   - /'
      if [ "$FILES_REVIEWED_COUNT" -gt 5 ]; then
        echo "   ... and $((FILES_REVIEWED_COUNT - 5)) more"
      fi
      echo ""
    fi
  else
    echo "📊 Issue Summary:"
    echo "   (Install jq for detailed summary)"
    echo ""
  fi
else
  log_warning "Metadata file not found: $METADATA_FILE"
  echo ""
fi

echo "📄 Review Content:"
echo ""
cat "$LATEST_REVIEW"
