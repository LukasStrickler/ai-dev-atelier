#!/bin/bash
# Shared utility functions for CodeRabbit review scripts
# This file should be sourced by review scripts, not executed directly

set -euo pipefail

# Constants
readonly REVIEW_DIR=".ada/data/reviews"
readonly KEEP_TASK_REVIEWS=2
readonly KEEP_PR_REVIEWS=2

# Logging functions
log_error() {
  echo "❌ Error: $1" >&2
}

log_success() {
  echo "✅ $1"
}

log_info() {
  echo "🔍 $1" >&2
}

log_warning() {
  echo "⚠️  $1" >&2
}

# Ensure review directory exists
ensure_review_dir() {
  if ! mkdir -p "$REVIEW_DIR" 2>/dev/null; then
    log_error "Failed to create review directory: $REVIEW_DIR"
    return 1
  fi
  
  if [ ! -d "$REVIEW_DIR" ] || [ ! -w "$REVIEW_DIR" ]; then
    log_error "Review directory is not writable: $REVIEW_DIR"
    return 1
  fi
}

# Generate timestamp in format YYYYMMDD-HHMMSS
get_review_timestamp() {
  date +"%Y%m%d-%H%M%S"
}

# Generate review file path
# Usage: get_review_file_path <review_type> <timestamp>
get_review_file_path() {
  local review_type="$1"
  local timestamp="$2"
  echo "${REVIEW_DIR}/${review_type}-review-${timestamp}.md"
}

# Generate metadata file path
# Usage: get_metadata_file_path <review_type> <timestamp>
get_metadata_file_path() {
  local review_type="$1"
  local timestamp="$2"
  echo "${REVIEW_DIR}/${review_type}-review-${timestamp}.json"
}

# Extract timestamp from review filename
# Usage: extract_timestamp_from_filename <filename>
extract_timestamp_from_filename() {
  local filename="$1"
  local basename
  basename=$(basename "$filename" .md)
  echo "$basename" | sed 's/.*-review-//'
}

# Extract review type from filename
# Usage: extract_review_type_from_filename <filename>
extract_review_type_from_filename() {
  local filename="$1"
  local basename
  basename=$(basename "$filename" .md)
  echo "$basename" | sed 's/-review-.*//'
}

# Count review files by type
# Usage: count_review_files <review_type>
count_review_files() {
  local review_type="$1"
  local files
  local count=0
  
  files=$(find "$REVIEW_DIR" -name "${review_type}-review-*.md" -type f 2>/dev/null | sort -r)
  
  if [ -z "$files" ]; then
    echo "0"
    return
  fi
  
  count=$(echo "$files" | grep -c . 2>/dev/null || echo "0")
  count=$(echo "$count" | tr -d ' \n')
  echo "$count"
}

# Find review files by type
# Usage: find_review_files <review_type>
find_review_files() {
  local review_type="$1"
  find "$REVIEW_DIR" -name "${review_type}-review-*.md" -type f 2>/dev/null | sort -r
}

# Get numeric count (sanitized)
# Usage: get_numeric_count <count_string>
get_numeric_count() {
  local count="$1"
  local sanitized
  sanitized=$(printf "%s" "$count" | tr -d ' \n')
  if [ -z "$sanitized" ]; then
    echo "0"
  else
    echo "$sanitized"
  fi
}

