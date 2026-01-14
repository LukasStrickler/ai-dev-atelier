#!/bin/bash
# CodeRabbit review script
# Usage: ./review.sh [task|pr]
#   task: Review uncommitted files
#   pr: Review all files vs main branch

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -r "${SCRIPT_DIR}/lib/review-utils.sh" ]; then
  echo "❌ Error: review-utils.sh not found or not readable: ${SCRIPT_DIR}/lib/review-utils.sh" >&2
  exit 1
fi
source "${SCRIPT_DIR}/lib/review-utils.sh"

# Check if CodeRabbit CLI is installed
check_coderabbit() {
  if ! command -v coderabbit &> /dev/null; then
    log_error "CodeRabbit CLI not found"
    echo "   Install it with: npm install -g @coderabbitai/cli"
    echo "   Or visit: https://docs.coderabbit.ai/cli/installation"
    exit 1
  fi
}

# Check if we're in a git repository
check_git_repo() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository"
    exit 1
  fi
}

# Get main branch name
get_main_branch() {
  local main_branch
  
  # Try to get from remote branches first
  # Filter out symbolic refs (lines with ->) and get actual branch names
  main_branch=$(git branch -r 2>/dev/null | grep -E 'origin/(main|master)' | grep -v ' -> ' | head -1 | sed 's|origin/||' | xargs 2>/dev/null || echo "")
  
  # Fallback to local branches
  if [ -z "$main_branch" ]; then
    main_branch=$(git branch 2>/dev/null | grep -E '^\s*(main|master)' | head -1 | sed 's/^\s*\|\s*$//g' | xargs 2>/dev/null || echo "")
  fi
  
  # Default to main if still empty
  if [ -z "$main_branch" ]; then
    main_branch="main"
  fi
  
  echo "$main_branch"
}

# Extract all issue types dynamically from review output
# Returns a newline-separated list of "type:count" pairs
extract_issue_types() {
  local review_output="$1"
  echo "$review_output" | grep -oE "Type: [a-z_]+" | sed 's/Type: //' | sort | uniq -c | awk '{print $2 ":" $1}'
}

# Process types list in a single pass: build JSON, calculate total, and count types
# Returns: total_issues|types_json|types_count
process_types_data() {
  local types_list="$1"
  local total=0
  local types_count=0
  local types_json
  
  # Use jq if available for reliable JSON building
  if command -v jq &> /dev/null; then
    # Build JSON using jq (more reliable and handles escaping)
    types_json=$(echo "$types_list" | while IFS=: read -r type_name count; do
      [ -z "$type_name" ] && continue
      echo "{\"key\":\"$type_name\",\"value\":$count}"
    done | jq -s 'map({(.key): .value}) | add' 2>/dev/null || echo "{}")
    
    # Calculate totals in same pass
    while IFS=: read -r type_name count; do
      [ -z "$type_name" ] && continue
      total=$((total + count))
      types_count=$((types_count + 1))
    done <<< "$types_list"
  else
    # Fallback: manual JSON building (single pass)
    types_json="{"
    local first=true
    
    while IFS=: read -r type_name count; do
      [ -z "$type_name" ] && continue
      
      [ "$first" = false ] && types_json="${types_json},"
      first=false
      types_json="${types_json}\"${type_name}\":${count}"
      total=$((total + count))
      types_count=$((types_count + 1))
    done <<< "$types_list"
    
    types_json="${types_json}}"
  fi
  
  echo "${total}|${types_json}|${types_count}"
}

# Format type name for display (replace underscores with spaces, capitalize)
format_type_name() {
  local type_name="$1"
  # Convert underscores to spaces, then capitalize first letter of each word using POSIX-compliant approach
  echo "$type_name" | sed 's/_/ /g' | awk '{
    for (i=1; i<=NF; i++) {
      word = $i
      if (length(word) > 0) {
        first = substr(word, 1, 1)
        rest = substr(word, 2)
        # Convert first char to uppercase using tr
        first_upper = first
        if (first ~ /[a-z]/) {
          first_upper = toupper(first)
        }
        $i = first_upper rest
      }
    }
    print
  }'
}

# Get list of files reviewed (includes both staged and unstaged for task reviews)
get_files_reviewed() {
  local review_type="$1"
  local main_branch="${2:-main}"
  local files
  
  if [ "$review_type" = "task" ]; then
    # Combine unstaged and staged changes, deduplicate
    files=$( (git diff --name-only HEAD 2>/dev/null || true; git diff --name-only --cached HEAD 2>/dev/null || true) | sort -u )
  else
    files=$(git diff --name-only "$main_branch" 2>/dev/null || echo "")
  fi
  
  echo "$files"
}

# Handle common errors
handle_review_error() {
  local review_file="$1"
  local exit_code="$2"
  
  log_error "CodeRabbit review failed with exit code: $exit_code"
  echo "   Check the review file for details: $review_file"
  echo ""
  
  # Check for common error messages and provide helpful guidance
  if grep -q "max files limit" "$review_file" 2>/dev/null; then
    log_warning "Too many files to review (exceeds CodeRabbit limit of 100 files)"
    echo "   CodeRabbit has a 100 file limit per review, even for public repos."
    echo "   Try:"
    echo "   - Commit some files first to reduce uncommitted changes"
    echo "   - Break large changes into smaller PRs (under 100 files each)"
    echo "   - Use path filters in .coderabbit.yaml to exclude non-essential files"
    echo "   - Upgrade to CodeRabbit Pro plan for higher limits"
  elif grep -q -i "not authenticated\|authentication\|login" "$review_file" 2>/dev/null; then
    log_warning "Authentication issue"
    echo "   Run: coderabbit auth login"
  elif grep -q -i "no changes\|nothing to review" "$review_file" 2>/dev/null; then
    log_warning "No changes to review"
    echo "   Make sure you have uncommitted changes (task) or differences from main (pr)"
  else
    echo "   Review the error output in: $review_file"
  fi
}

# Main script
main() {
  # Validate prerequisites
  check_coderabbit
  check_git_repo
  
  # Parse review type
  local review_type="${1:-task}"
  
  if [ "$review_type" != "task" ] && [ "$review_type" != "pr" ]; then
    log_error "Invalid review type. Use 'task' or 'pr'"
    echo "   Usage: $0 [task|pr]"
    exit 1
  fi
  
  # Ensure review directory exists
  ensure_review_dir
  
  # Generate timestamp and file paths
  local timestamp
  timestamp=$(get_review_timestamp)
  local review_file
  review_file=$(get_review_file_path "$review_type" "$timestamp")
  local metadata_file
  metadata_file=$(get_metadata_file_path "$review_type" "$timestamp")
  
  log_info "Running CodeRabbit ${review_type} review..."
  echo ""
  
  # Build CodeRabbit command based on review type
  local coderabbit_cmd
  local main_branch=""
  
  if [ "$review_type" = "task" ]; then
    echo "📝 Reviewing uncommitted files..."
    
    # Check if there are uncommitted changes (both staged and unstaged)
    local uncommitted_count
    local staged_files unstaged_files all_files
    staged_files=$(git diff --cached --name-only 2>/dev/null || echo "")
    unstaged_files=$(git diff --name-only HEAD 2>/dev/null || echo "")
    all_files=$(printf '%s\n' "$staged_files" "$unstaged_files" | sort -u | grep -v '^$')
    uncommitted_count=$(echo "$all_files" | wc -l | tr -d ' ' || echo "0")
    
    if [ "$uncommitted_count" = "0" ]; then
      log_warning "No uncommitted files to review"
      echo "   Make some changes first, or use 'bun run review:pr' to review vs main"
      exit 0
    fi
    
    echo "   Found ${uncommitted_count} uncommitted file(s)"
    coderabbit_cmd="coderabbit --prompt-only -t uncommitted"
  else
    echo "📝 Reviewing all files vs main branch..."
    main_branch=$(get_main_branch)
    echo "   Base branch: $main_branch"
    
    # Check if there are committed changes vs main
    local committed_count
    committed_count=$(git log --oneline "$main_branch"..HEAD 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    
    # Check total files changed vs main
    local changed_count
    changed_count=$(git diff --name-only "$main_branch" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    
    if [ "$committed_count" -gt 0 ] && [ "$changed_count" -le 100 ]; then
      # Use 'all' type if we have committed changes and under file limit
      # This reviews all changes (committed + uncommitted) vs base branch
      coderabbit_cmd="coderabbit --prompt-only -t all --base $main_branch"
    elif [ "$changed_count" -le 100 ]; then
      # If no commits but have uncommitted changes, use 'all' type
      coderabbit_cmd="coderabbit --prompt-only -t all --base $main_branch"
    else
      # Too many files, use 'all' but it will likely fail with file limit error
      coderabbit_cmd="coderabbit --prompt-only -t all --base $main_branch"
    fi
  fi
  
  # Run CodeRabbit and capture output
  echo "⏳ CodeRabbit is analyzing your code (this may take a few minutes)..."
  echo ""
  
  # Track review start time
  local review_start_time
  review_start_time=$(date +%s)
  
  # Run CodeRabbit and capture both stdout and stderr
  if $coderabbit_cmd > "$review_file" 2>&1; then
    local review_end_time review_duration
    review_end_time=$(date +%s)
    review_duration=$((review_end_time - review_start_time))
    
    local review_output
    review_output=$(cat "$review_file")
    
    # Extract all issue types dynamically (single pass)
    local types_list
    types_list=$(extract_issue_types "$review_output")
    
    # Process types data in single pass: JSON, total, count
    local types_data
    types_data=$(process_types_data "$types_list")
    local total_issues types_json types_count
    total_issues="${types_data%%|*}"
    types_json="${types_data#*|}"
    types_json="${types_json%|*}"
    types_count="${types_data##*|}"
    
    # Get list of files reviewed
    local files_reviewed
    files_reviewed=$(get_files_reviewed "$review_type" "$main_branch")
    
    # Count files
    local files_count
    files_count=$(echo "$files_reviewed" | grep -c . || echo "0")
    
    # Build files JSON array (optimized)
    local files_json
    if command -v jq &> /dev/null; then
      files_json=$(echo "$files_reviewed" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
    else
      # Fallback: build JSON array without jq using printf for safe escaping
      files_json="["
      local first=true
      while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ "$first" = false ] && files_json="${files_json},"
        first=false
        # Use printf %q to safely escape the filename, then wrap in quotes
        escaped_file=$(printf '%s' "$file" | sed 's/\\/\\\\/g; s/"/\\"/g')
        files_json="${files_json}\"${escaped_file}\""
      done <<< "$files_reviewed"
      files_json="${files_json}]"
    fi
    
    # Create metadata file with enhanced statistics
    cat > "$metadata_file" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "review_type": "$review_type",
  "files_reviewed": $files_json,
  "statistics": {
    "files_count": ${files_count},
    "types_count": ${types_count},
    "total_issues": ${total_issues},
    "review_duration_seconds": ${review_duration}
  },
  "issues_summary": {
    "total": ${total_issues}
  },
  "types": $types_json,
  "status": "completed"
}
EOF
    
    log_success "Review completed!"
    echo ""
    echo "📄 Review saved to: $review_file"
    echo "📊 Metadata saved to: $metadata_file"
    echo ""
    echo "📊 Statistics:"
    echo "   Files reviewed: ${files_count}"
    echo "   Issue types: ${types_count}"
    echo "   Total issues: ${total_issues}"
    echo "   Review duration: ${review_duration}s"
    echo ""
    echo "📋 Issue Types:"
    while IFS=: read -r type_name count; do
      [ -z "$type_name" ] && continue
      local display_name
      display_name=$(format_type_name "$type_name")
      echo "   ${display_name}: ${count}"
    done <<< "$types_list"
    echo ""
    echo "💡 Read the review with: bun run review:read"
  else
    local exit_code=$?
    handle_review_error "$review_file" "$exit_code"
    exit $exit_code
  fi
}

# Run main function
main "$@"
