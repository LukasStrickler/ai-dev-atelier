#!/bin/bash
# Cleanup PR comments script
# Usage: ./pr-comments-cleanup.sh [--all] [PR_NUMBER]
#   --all: Delete all PR comment files
#   PR_NUMBER: Delete files for a specific PR number

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -r "${SCRIPT_DIR}/lib/pr-comments-utils.sh" ]; then
  echo "❌ Error: pr-comments-utils.sh not found or not readable: ${SCRIPT_DIR}/lib/pr-comments-utils.sh" >&2
  exit 1
fi
source "${SCRIPT_DIR}/lib/pr-comments-utils.sh"

# Check prerequisites (skip git check for cleanup)
if ! check_prerequisites "true"; then
  exit 1
fi

# Parse arguments
DELETE_ALL=false
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      DELETE_ALL=true
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        PR_NUMBER="$1"
      else
        log_error "Invalid argument: $1"
        echo "   Usage: $0 [--all] [PR_NUMBER]"
        exit 1
      fi
      shift
      ;;
  esac
done

# Ensure .ada/data/pr-comments directory exists
if ! ensure_github_dir; then
  exit 1
fi

# Find PR comment files
if [ "$DELETE_ALL" = "true" ]; then
  log_info "Deleting all PR comment files..."
  files_to_delete=$(find "$GITHUB_DIR" -name "pr-comments-*.json" -o -name "pr-comments-*.md" 2>/dev/null | sort)
elif [ -n "$PR_NUMBER" ]; then
  # Validate PR number
  if ! validate_pr_number "$PR_NUMBER"; then
    log_error "Invalid PR number: $PR_NUMBER (must be numeric)"
    exit 1
  fi
  
  log_info "Deleting PR comment files for PR #${PR_NUMBER}..."
  files_to_delete=$(find "$GITHUB_DIR" -name "pr-comments-${PR_NUMBER}-*.json" -o -name "pr-comments-${PR_NUMBER}-*.md" -o -name "pr-comments-${PR_NUMBER}.json" -o -name "pr-comments-${PR_NUMBER}.md" 2>/dev/null | sort)
else
  log_error "No action specified. Use --all to delete all files or provide a PR number."
  echo "   Usage: $0 [--all] [PR_NUMBER]"
  exit 1
fi

# Count files (filter out empty lines)
file_count=$(echo "$files_to_delete" | grep -v '^$' | wc -l | tr -d ' ')

if [ "$file_count" -eq 0 ]; then
  log_warning "No PR comment files found to delete"
  exit 0
fi

# Show files to be deleted
echo ""
echo "Files to be deleted:"
echo "$files_to_delete" | grep -v '^$' | while IFS= read -r file; do
  if [ -n "$file" ] && [ -f "$file" ]; then
    echo "  - $file"
  fi
done
echo ""
echo "Total: ${file_count} file(s)"

# Confirm deletion
read -p "Are you sure you want to delete these files? (yes/no): " confirm

if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
  log_warning "Deletion cancelled"
  exit 0
fi

# Delete files
deleted_count=0
failed_count=0

while IFS= read -r file; do
  if [ -n "$file" ] && [ -f "$file" ]; then
    if rm -f "$file" 2>/dev/null; then
      deleted_count=$((deleted_count + 1))
      log_verbose "Deleted: $file"
    else
      failed_count=$((failed_count + 1))
      log_error "Failed to delete: $file"
    fi
  fi
done <<< "$files_to_delete"

echo ""
if [ "$deleted_count" -gt 0 ]; then
  log_success "Deleted ${deleted_count} file(s)"
else
  log_warning "No files were deleted"
fi

if [ "$failed_count" -gt 0 ]; then
  log_warning "${failed_count} file(s) failed to delete"
fi

# Clean up empty directory if it exists
if [ -d "$GITHUB_DIR" ] && [ -z "$(ls -A "$GITHUB_DIR" 2>/dev/null)" ]; then
  rmdir "$GITHUB_DIR" 2>/dev/null && log_info "Removed empty directory: $GITHUB_DIR" || true
fi

