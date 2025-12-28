#!/bin/bash
# Merge changes from work-mode agent

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"

# Parse arguments
RUN_ID="${1:-}"
AUTO_RESOLVE="false"
TARGET_BRANCH=""

if [ -z "$RUN_ID" ]; then
  echo "Usage: $0 <runId> [targetBranch] [--auto-resolve]" >&2
  exit 1
fi

shift 1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-resolve)
      AUTO_RESOLVE="true"
      shift
      ;;
    *)
      if [ -z "$TARGET_BRANCH" ]; then
        TARGET_BRANCH="$1"
        shift
      else
        echo "Unknown option: $1" >&2
        exit 1
      fi
      ;;
  esac
done

# Read metadata
META_JSON=$(read_meta_json "$RUN_ID")
if [ $? -ne 0 ] || [ -z "$META_JSON" ]; then
  echo "Error: Could not read metadata for runId: $RUN_ID" >&2
  exit 1
fi

# Extract mode
if command -v jq &> /dev/null; then
  MODE=$(echo "$META_JSON" | jq -r '.mode // "work"')
else
  MODE=$(echo "$META_JSON" | grep -o '"mode":"[^"]*"' | sed 's/"mode":"\([^"]*\)"/\1/' || echo "work")
fi

if [ -z "$TARGET_BRANCH" ]; then
  TARGET_BRANCH=$(read_meta_json "$RUN_ID" "baseBranch" 2>/dev/null || echo "")
  if [ -z "$TARGET_BRANCH" ]; then
    TARGET_BRANCH="main"
  fi
fi

# Validate mode
if [ "$MODE" != "work" ]; then
  RUN_DIR=$(get_run_directory "$RUN_ID")
  echo "Error: Can only merge work-mode agents. Research mode results are available in ${RUN_DIR}/answer.md" >&2
  exit 1
fi

# Get worktree path
WORKTREE_PATH=$(get_worktree_path "$RUN_ID")
if [ $? -ne 0 ]; then
  echo "Error: Worktree not found for runId: $RUN_ID" >&2
  exit 1
fi

# Perform merge
(
  cd "$PROJECT_ROOT" || exit 1
  branchName="agent-${RUN_ID}"
  
  # Checkout target branch
  git checkout "$TARGET_BRANCH" >/dev/null 2>&1
  
  # Check if branch has commits
  if git rev-parse --verify "$branchName" >/dev/null 2>&1; then
    # Branch exists with commits - merge it
    if git merge --no-ff "$branchName" -m "Merge agent work: $RUN_ID" >/dev/null 2>&1; then
      echo "Merge successful" >&2
      write_meta_json "$RUN_ID" "mergedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "mergedTo" "$TARGET_BRANCH"
    else
      echo "Merge conflicts detected" >&2
      if [ -f ".git/MERGE_HEAD" ]; then
        git merge --abort >/dev/null 2>&1 || true
      fi
      if [ "$AUTO_RESOLVE" = "true" ]; then
        echo "Attempting auto-resolve (theirs strategy)..." >&2
        if git merge --no-ff -X theirs "$branchName" -m "Merge agent work: $RUN_ID" >/dev/null 2>&1; then
          echo "Auto-resolve merge successful" >&2
          write_meta_json "$RUN_ID" "mergedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "mergedTo" "$TARGET_BRANCH" "mergeStrategy" "theirs"
        else
          echo "Auto-resolve failed" >&2
          if [ -f ".git/MERGE_HEAD" ]; then
            git merge --abort >/dev/null 2>&1 || true
          fi
          exit 1
        fi
      else
        exit 1
      fi
    fi
  else
    # Branch doesn't exist or has no commits - copy files from worktree
    echo "Branch has no commits, copying files from worktree..." >&2
    
    # Get list of files to copy (exclude metadata files)
    filesToCopy=$(cd "$WORKTREE_PATH" && git ls-files --others --exclude-standard 2>/dev/null | grep -vE "(\.agent-level|prompt\.md|progress\.md)" || true)
    
    if [ -n "$filesToCopy" ]; then
      # Copy each file to main branch
      echo "$filesToCopy" | while read -r file; do
        if [ -f "$WORKTREE_PATH/$file" ]; then
          # Create directory if needed
          mkdir -p "$(dirname "$file")" 2>/dev/null || true
          cp "$WORKTREE_PATH/$file" "$file"
          echo "Copied: $file" >&2
        fi
      done
      
      # Also check for modified tracked files
      modifiedFiles=$(cd "$WORKTREE_PATH" && git diff --name-only HEAD 2>/dev/null | grep -vE "(\.agent-level|prompt\.md|progress\.md)" || true)
      if [ -n "$modifiedFiles" ]; then
        echo "$modifiedFiles" | while read -r file; do
          if [ -f "$WORKTREE_PATH/$file" ]; then
            cp "$WORKTREE_PATH/$file" "$file"
            echo "Updated: $file" >&2
          fi
        done
      fi
      
      echo "Files copied successfully" >&2
      write_meta_json "$RUN_ID" "mergedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "mergedTo" "$TARGET_BRANCH" "mergeMethod" "file-copy"
    else
      echo "No files to copy" >&2
    fi
  fi
)

# Cleanup worktree after successful merge
cleanup_worktree "$RUN_ID"

echo "Merge completed for $RUN_ID"
