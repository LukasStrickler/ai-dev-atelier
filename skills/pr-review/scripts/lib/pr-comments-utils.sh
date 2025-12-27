#!/bin/bash
# Shared utility functions for PR comments scripts
# This file should be sourced by PR comments scripts, not executed directly

# Constants
if [ -z "${GITHUB_DIR:-}" ]; then
  readonly GITHUB_DIR=".ada/data/pr-comments"
fi

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

# Ensure .ada/data/pr-comments directory exists
ensure_github_dir() {
  if ! mkdir -p "$GITHUB_DIR" 2>/dev/null; then
    log_error "Failed to create PR comments directory: $GITHUB_DIR"
    return 1
  fi
  
  if [ ! -d "$GITHUB_DIR" ] || [ ! -w "$GITHUB_DIR" ]; then
    log_error "PR comments directory is not writable: $GITHUB_DIR"
    return 1
  fi
}

# Generate timestamp in format YYYYMMDD-HHMMSS
get_pr_comments_timestamp() {
  date +"%Y%m%d-%H%M%S"
}

# Generate PR comments markdown file path
# Usage: get_pr_comments_file_path <pr_number> <commit_sha>
get_pr_comments_file_path() {
  local pr_number="$1"
  local commit_sha="${2:-}"
  if [ -n "$commit_sha" ]; then
    echo "${GITHUB_DIR}/pr-comments-${pr_number}-${commit_sha}.md"
  else
    echo "${GITHUB_DIR}/pr-comments-${pr_number}.md"
  fi
}

# Generate PR comments metadata file path
# Usage: get_pr_comments_metadata_path <pr_number> <commit_sha>
get_pr_comments_metadata_path() {
  local pr_number="$1"
  local commit_sha="${2:-}"
  if [ -n "$commit_sha" ]; then
    echo "${GITHUB_DIR}/pr-comments-${pr_number}-${commit_sha}.json"
  else
    echo "${GITHUB_DIR}/pr-comments-${pr_number}.json"
  fi
}

# Hash comments content for deduplication
# Usage: hash_comments <review_comments_json> <issue_comments_json>
hash_comments() {
  local review_comments_json="$1"
  local issue_comments_json="$2"
  
  # Combine both JSON arrays and hash them
  local combined
  if command -v jq &> /dev/null; then
    combined=$(echo "$review_comments_json" "$issue_comments_json" | jq -c -s 'sort_by(.id)' 2>/dev/null || echo "$review_comments_json$issue_comments_json")
  else
    combined="$review_comments_json$issue_comments_json"
  fi
  
  # Generate hash (SHA256 if available, otherwise MD5, otherwise simple hash)
  if command -v shasum &> /dev/null; then
    echo "$combined" | shasum -a 256 | cut -d' ' -f1
  elif command -v sha256sum &> /dev/null; then
    echo "$combined" | sha256sum | cut -d' ' -f1
  elif command -v md5sum &> /dev/null; then
    echo "$combined" | md5sum | cut -d' ' -f1
  elif command -v md5 &> /dev/null; then
    echo "$combined" | md5 | cut -d' ' -f1
  else
    # Fallback: simple hash based on content length and first few chars
    echo "$combined" | head -c 100 | od -An -tx1 | tr -d ' \n' | head -c 32
  fi
}

# Extract timestamp from PR comments filename
# Usage: extract_timestamp_from_pr_comments_filename <filename>
extract_timestamp_from_pr_comments_filename() {
  local filename="$1"
  local basename
  basename=$(basename "$filename" .md)
  echo "$basename" | sed 's/pr-comments-//'
}

# Extract repository owner/repo from git remote
# Usage: get_repo_owner_repo
# Returns: owner/repo or empty string on error
get_repo_owner_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  
  if [ -z "$remote_url" ]; then
    log_error "No git remote 'origin' found"
    return 1
  fi
  
  # Handle both HTTPS and SSH URLs
  # HTTPS: https://github.com/owner/repo.git or https://github.com/owner/repo
  # SSH: git@github.com:owner/repo.git or git@github.com:owner/repo
  local owner_repo
  owner_repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]([^/]+)/([^/]+)(\.git)?$|\1/\2|')
  
  if [ -z "$owner_repo" ] || [ "$owner_repo" = "$remote_url" ]; then
    log_error "Could not extract owner/repo from remote URL: $remote_url"
    return 1
  fi
  
  echo "$owner_repo"
}

# Check if GitHub CLI is installed and authenticated
# Usage: check_gh_cli
check_gh_cli() {
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found"
    echo "   Install it with:"
    echo "   - macOS: brew install gh"
    echo "   - Linux: See https://cli.github.com/manual/installation"
    echo "   - Or visit: https://cli.github.com/"
    return 1
  fi
  
  # Check if authenticated
  if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    return 1
  fi
  
  return 0
}

# Find PR comments files for a specific PR number
# Usage: find_pr_comments_files <pr_number>
find_pr_comments_files() {
  local pr_number="$1"
  find "$GITHUB_DIR" -name "pr-comments-*.json" -type f 2>/dev/null | while IFS= read -r file; do
    if command -v jq &> /dev/null; then
      if jq -e --arg pr "$pr_number" '.pr_number == ($pr | tonumber)' "$file" &> /dev/null; then
        echo "$file"
      fi
    else
      # Fallback: check if PR number appears in file (less reliable)
      if grep -q "\"pr_number\": *${pr_number}" "$file" 2>/dev/null; then
        echo "$file"
      fi
    fi
  done | sort -r
}

# Get latest PR comments metadata file for a PR
# Usage: get_latest_pr_comments_metadata <pr_number>
get_latest_pr_comments_metadata() {
  local pr_number="$1"
  find_pr_comments_files "$pr_number" | head -1
}

# Detect PR number from various sources
# Usage: detect_pr_number
# Returns: PR number or empty string if not found
# Tries multiple methods: existing comment files, commit SHA matching, branch matching, gh pr view
detect_pr_number() {
  local pr_number=""
  
  # Method 1: Check for most recent PR comment file (most reliable if we've fetched before)
  if [ -d "$GITHUB_DIR" ]; then
    local latest_file
    latest_file=$(find "$GITHUB_DIR" -name "pr-comments-*.json" -type f 2>/dev/null | sort -r | head -1)
    
    if [ -n "$latest_file" ] && [ -f "$latest_file" ] && command -v jq &> /dev/null; then
      pr_number=$(jq -r '.pr_number // empty' "$latest_file" 2>/dev/null || echo "")
      if [ -n "$pr_number" ] && [ "$pr_number" != "null" ] && [ "$pr_number" != "" ]; then
        echo "$pr_number"
        return 0
      fi
    fi
  fi
  
  # Method 2: Match by current commit SHA (works with GitButler)
  # This is the most reliable method for GitButler since it matches by actual commit SHA
  if command -v gh &> /dev/null && gh auth status &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    local current_sha
    current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
    
    if [ -n "$current_sha" ] && [ "$current_sha" != "" ]; then
      # Get all open PRs and match by headRefOid
      pr_number=$(gh pr list --json number,headRefOid --jq --arg sha "$current_sha" '.[] | select(.headRefOid == $sha) | .number' 2>/dev/null | head -1)
      if [ -n "$pr_number" ] && [ "$pr_number" != "null" ] && [ "$pr_number" != "" ]; then
        echo "$pr_number"
        return 0
      fi
    fi
  fi
  
  # Method 3: Try gh pr view (works if GitHub CLI can detect the PR)
  if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    pr_number=$(gh pr view --json number --jq '.number // empty' 2>/dev/null || echo "")
    if [ -n "$pr_number" ] && [ "$pr_number" != "null" ] && [ "$pr_number" != "" ]; then
      echo "$pr_number"
      return 0
    fi
  fi
  
  # No PR number found
  echo ""
  return 1
}

# Extract PR number from metadata file
# Usage: extract_pr_number_from_metadata <metadata_file>
extract_pr_number_from_metadata() {
  local metadata_file="$1"
  
  if command -v jq &> /dev/null; then
    jq -r '.pr_number // empty' "$metadata_file" 2>/dev/null || echo ""
  else
    # Fallback: grep for pr_number
    grep -oE '"pr_number":\s*[0-9]+' "$metadata_file" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo ""
  fi
}

# Parse owner/repo string into owner and repo
# Usage: parse_owner_repo <owner_repo>
# Returns: "owner repo" (space-separated)
parse_owner_repo() {
  local owner_repo="$1"
  local owner repo
  
  owner=$(echo "$owner_repo" | cut -d'/' -f1)
  repo=$(echo "$owner_repo" | cut -d'/' -f2 | sed 's/\.git$//')
  
  echo "$owner $repo"
}

# Validate PR number is numeric
# Usage: validate_pr_number <pr_number>
# Returns: 0 if valid, 1 if invalid
validate_pr_number() {
  local pr_number="$1"
  
  if [ -z "$pr_number" ]; then
    return 1
  fi
  
  if ! echo "$pr_number" | grep -qE '^[0-9]+$'; then
    return 1
  fi
  
  return 0
}

# Validate comment ID is numeric
# Usage: validate_comment_id <comment_id>
# Returns: 0 if valid, 1 if invalid
validate_comment_id() {
  local comment_id="$1"
  
  if [ -z "$comment_id" ]; then
    return 1
  fi
  
  if ! echo "$comment_id" | grep -qE '^[0-9]+$'; then
    return 1
  fi
  
  return 0
}

# Validate JSON string
# Usage: validate_json <json_string>
# Returns: 0 if valid, 1 if invalid
validate_json() {
  local json_string="$1"
  
  if [ -z "$json_string" ] || [ "$json_string" = "null" ]; then
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    # Without jq, we can't validate properly, assume valid
    return 0
  fi
  
  if echo "$json_string" | jq . > /dev/null 2>&1; then
    return 0
  fi
  
  return 1
}

# Normalize JSON to array format
# Handles paginated responses, wrapped arrays, multiple arrays
# Usage: normalize_json_array <json_string>
# Returns: normalized JSON array or empty array on error
normalize_json_array() {
  local json_string="$1"
  
  if [ -z "$json_string" ] || [ "$json_string" = "null" ]; then
    echo "[]"
    return 0
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "$json_string"
    return 0
  fi
  
  # Validate JSON first
  if ! echo "$json_string" | jq . > /dev/null 2>&1; then
    log_warning "Invalid JSON in normalize_json_array"
    echo "[]"
    return 1
  fi
  
  # Check if already an array
  local json_type
  json_type=$(echo "$json_string" | jq -r 'type' 2>/dev/null || echo "unknown")
  
  if [ "$json_type" = "array" ]; then
    echo "$json_string"
    return 0
  fi
  
  # Try to extract array from wrapped response
  local array_content
  array_content=$(echo "$json_string" | jq -c 'if type == "array" then . elif .data then .data elif .items then .items else [] end' 2>/dev/null || echo "[]")
  
  local fixed_type
  fixed_type=$(echo "$array_content" | jq -r 'type' 2>/dev/null || echo "unknown")
  
  if [ "$fixed_type" = "array" ]; then
    echo "$array_content"
    return 0
  fi
  
  # Handle multiple arrays (from pagination)
  local line_count
  line_count=$(echo "$json_string" | wc -l | tr -d ' ')
  
  if [ "$line_count" -gt 1 ]; then
    array_content=$(echo "$json_string" | jq -s 'add' 2>/dev/null || echo "[]")
    fixed_type=$(echo "$array_content" | jq -r 'type' 2>/dev/null || echo "unknown")
    
    if [ "$fixed_type" = "array" ]; then
      echo "$array_content"
      return 0
    fi
  fi
  
  log_warning "Could not normalize JSON to array format"
  echo "[]"
  return 1
}

# Fetch GraphQL data with pagination
# Usage: fetch_graphql_paginated <query_template> <owner> <repo> <pr_number> <page_size> [verbose]
# Returns: combined JSON array of all nodes
fetch_graphql_paginated() {
  local query_template="$1"
  local owner="$2"
  local repo="$3"
  local pr_number="$4"
  local page_size="${5:-100}"
  local verbose="${6:-false}"
  
  local all_nodes="[]"
  local cursor="null"
  local page_count=0
  local has_next_page=true
  
  while [ "$has_next_page" = "true" ]; do
    page_count=$((page_count + 1))
    
    local cursor_param=""
    if [ "$cursor" != "null" ] && [ -n "$cursor" ]; then
      cursor_param=", after: \"$cursor\""
    fi
    
    # Replace placeholders in query template
    local query
    query=$(echo "$query_template" | sed "s/\${owner}/${owner}/g" | sed "s/\${repo}/${repo}/g" | sed "s/\${pr_number}/${pr_number}/g" | sed "s/\${page_size}/${page_size}/g" | sed "s/\${cursor_param}/${cursor_param}/g")
    
    if [ "$verbose" = "true" ]; then
      log_info "Fetching GraphQL page ${page_count}..."
    fi
    
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(gh api graphql -f query="$query" 2>"$stderr_file")
    local exit_code=$?
    
    if [ $exit_code -ne 0 ] || [ -s "$stderr_file" ]; then
      local error_msg
      error_msg=$(cat "$stderr_file" 2>/dev/null || echo "")
      rm -f "$stderr_file"
      log_warning "GraphQL query failed (exit code: $exit_code): $error_msg"
      break
    fi
    
    rm -f "$stderr_file"
    
    # Extract page info and nodes (query template should specify path)
    # Default path: .data.repository.pullRequest.reviewThreads
    local page_info_path="${7:-.data.repository.pullRequest.reviewThreads.pageInfo}"
    local nodes_path="${8:-.data.repository.pullRequest.reviewThreads.nodes}"
    
    local page_info
    page_info=$(echo "$response" | jq -r "${page_info_path} // {}" 2>/dev/null || echo "{}")
    local nodes
    nodes=$(echo "$response" | jq -c "${nodes_path} // []" 2>/dev/null || echo "[]")
    
    if [ -z "$nodes" ] || [ "$nodes" = "null" ]; then
      if [ "$verbose" = "true" ]; then
        log_warning "No nodes in GraphQL response"
      fi
      break
    fi
    
    # Merge nodes
    if [ "$all_nodes" = "[]" ]; then
      all_nodes="$nodes"
    else
      all_nodes=$(echo "$all_nodes" "$nodes" | jq -s 'add' 2>/dev/null || echo "$all_nodes")
    fi
    
    has_next_page=$(echo "$page_info" | jq -r '.hasNextPage // false' 2>/dev/null || echo "false")
    cursor=$(echo "$page_info" | jq -r '.endCursor // null' 2>/dev/null || echo "null")
    
    if [ "$has_next_page" != "true" ] || [ "$cursor" = "null" ]; then
      has_next_page="false"
    fi
  done
  
  echo "$all_nodes"
}

# Clean HTML from comment body
# Usage: clean_html_body <body>
# Returns: cleaned body text
clean_html_body() {
  local body="$1"
  
  if [ -z "$body" ]; then
    echo ""
    return 0
  fi
  
  echo "$body" | \
    sed -E 's/<details>.*<\/details>//g' | \
    sed -E 's/<summary>.*<\/summary>//g' | \
    sed -E 's/<!--[^>]*-->//g' | \
    grep -v '^<details>' | \
    grep -v '^</details>' | \
    grep -v '^<summary>' | \
    grep -v '^</summary>' | \
    sed 's/^[[:space:]]*//' | \
    sed 's/[[:space:]]*$//' | \
    head -30
}

# Get latest commit SHA for PR
# Usage: get_pr_commit_sha <pr_number>
# Returns: commit SHA or empty string on error
get_pr_commit_sha() {
  local pr_number="$1"
  local commit_sha
  
  commit_sha=$(gh pr view "$pr_number" --json headRefOid --jq '.headRefOid // ""' 2>/dev/null || echo "")
  
  if [ -z "$commit_sha" ]; then
    log_error "Failed to get latest commit SHA for PR #${pr_number}"
    return 1
  fi
  
  echo "$commit_sha"
  return 0
}

# Validate that a PR number matches the current commit SHA
# Usage: validate_pr_matches_commit <pr_number> [current_sha]
# Returns: 0 if matches, 1 if doesn't match or error
# If current_sha is not provided, uses git rev-parse HEAD
validate_pr_matches_commit() {
  local pr_number="$1"
  local current_sha="${2:-}"
  
  # Get current commit SHA if not provided
  if [ -z "$current_sha" ]; then
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
      log_error "Not in a git repository"
      return 1
    fi
    current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -z "$current_sha" ]; then
      log_error "Failed to get current commit SHA"
      return 1
    fi
  fi
  
  # Get PR's head commit SHA
  local pr_head_sha
  pr_head_sha=$(get_pr_commit_sha "$pr_number" 2>/dev/null || echo "")
  
  if [ -z "$pr_head_sha" ]; then
    log_error "Failed to get PR #${pr_number} head commit SHA"
    return 1
  fi
  
  # Compare SHAs - exact match
  if [ "$current_sha" = "$pr_head_sha" ]; then
    return 0
  fi
  
  # Check if PR head is an ancestor of current commit (user is ahead, e.g., GitButler workspace commits)
  if git merge-base --is-ancestor "$pr_head_sha" "$current_sha" 2>/dev/null; then
    log_verbose "PR #${pr_number} head (${pr_head_sha:0:8}...) is an ancestor of current commit (${current_sha:0:8}...) - validation passed"
    return 0
  fi
  
  # Check if current commit is an ancestor of PR head (user is behind)
  if git merge-base --is-ancestor "$current_sha" "$pr_head_sha" 2>/dev/null; then
    log_verbose "Current commit (${current_sha:0:8}...) is an ancestor of PR #${pr_number} head (${pr_head_sha:0:8}...) - validation passed"
    return 0
  fi
  
  # No relationship found - commits are on different branches
  log_warning "PR #${pr_number} head commit (${pr_head_sha:0:8}...) doesn't match current commit (${current_sha:0:8}...) and they're not related"
  return 1
}

# Check all prerequisites at once
# Usage: check_prerequisites [skip_git]
# Returns: 0 if all OK, 1 if any missing
check_prerequisites() {
  local skip_git="${1:-false}"
  
  # Check git repository
  if [ "$skip_git" != "true" ]; then
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
      log_error "Not in a git repository"
      return 1
    fi
  fi
  
  # Check GitHub CLI
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found"
    echo "   Install: https://cli.github.com/"
    return 1
  fi
  
  # Check authentication
  if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    return 1
  fi
  
  # Check jq
  if ! command -v jq &> /dev/null; then
    log_error "jq not found"
    echo "   Install: https://stedolan.github.io/jq/download/"
    return 1
  fi
  
  return 0
}

# Parse verbose flag from arguments
# Usage: parse_verbose_flag "$@"
# Returns: "true" or "false"
parse_verbose_flag() {
  local args="$*"
  if [[ "$args" == *"--verbose"* ]] || [[ "$args" == *"-v"* ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Load PR metadata file
# Usage: load_pr_metadata <pr_number>
# Returns: metadata file path or exits with error
# Sets: LATEST_COMMIT_SHA (global variable)
load_pr_metadata() {
  local pr_number="$1"
  
  # Get latest commit SHA from PR using utils
  LATEST_COMMIT_SHA=$(get_pr_commit_sha "$pr_number" 2>/dev/null || echo "")
  
  if [ -z "$LATEST_COMMIT_SHA" ]; then
    log_error "Failed to get latest commit SHA for PR #${pr_number}"
    return 1
  fi
  
  # Get metadata file for this PR
  local metadata_file
  metadata_file=$(get_pr_comments_metadata_path "$pr_number" "$LATEST_COMMIT_SHA")
  
  if [ -z "$metadata_file" ] || [ ! -f "$metadata_file" ]; then
    log_error "No comments file found for PR #${pr_number} (commit: ${LATEST_COMMIT_SHA:0:8}...)"
    echo "   Run 'bun run pr:comments ${pr_number}' first to fetch comments"
    return 1
  fi
  
  echo "$metadata_file"
  return 0
}

# Get comment by index or ID from metadata file
# Usage: get_comment_by_index_or_id <metadata_file> <index_or_id>
# Returns: JSON object with "comment" and "comment_id" fields
get_comment_by_index_or_id() {
  local metadata_file="$1"
  local index_or_id="$2"
  
  if ! echo "$index_or_id" | grep -qE '^[0-9]+$'; then
    log_error "Invalid index or ID: ${index_or_id} (must be numeric)"
    return 1
  fi
  
  # Check if it's a small number (likely an index) or large number (likely an ID)
  # Comment IDs are typically 10+ digits, indices are usually 1-100
  if [ "$index_or_id" -lt 1000 ]; then
    # Treat as index (1-based)
    local index
    index=$((index_or_id - 1))  # Convert to 0-based for jq
    
    # Get unresolved comments and find by index
    local unresolved_comments
    unresolved_comments=$(jq -c '[.review_comments[] | select(.resolved == false)]' "$metadata_file" 2>/dev/null || echo "[]")
    
    local comment_count
    comment_count=$(echo "$unresolved_comments" | jq 'length // 0' 2>/dev/null || echo "0")
    
    if [ "$comment_count" -eq 0 ]; then
      # Return special exit code 2 to indicate all comments are resolved
      return 2
    fi
    
    if [ "$index" -lt 0 ] || [ "$index" -ge "$comment_count" ]; then
      log_error "Index ${index_or_id} is out of range. There are ${comment_count} unresolved comments (1-${comment_count})"
      return 1
    fi
    
    local comment
    comment=$(echo "$unresolved_comments" | jq -c ".[${index}]" 2>/dev/null || echo "")
    
    if [ -z "$comment" ] || [ "$comment" = "null" ]; then
      log_error "Failed to get comment at index ${index_or_id}"
      return 1
    fi
    
    local comment_id
    comment_id=$(echo "$comment" | jq -r '.id // empty' 2>/dev/null || echo "")
    echo "$comment" | jq -c --arg id "$comment_id" '{comment: ., comment_id: ($id | tonumber)}'
    return 0
  else
    # Treat as comment ID
    local comment_id="$index_or_id"
    
    # Find comment by ID
    local comment
    comment=$(jq -c --arg id "$comment_id" '.review_comments[] | select(.id == ($id | tonumber))' "$metadata_file" 2>/dev/null || echo "")
    
    if [ -z "$comment" ] || [ "$comment" = "null" ]; then
      log_error "Comment ID ${comment_id} not found"
      return 1
    fi
    
    echo "$comment" | jq -c --arg id "$comment_id" '{comment: ., comment_id: ($id | tonumber)}'
    return 0
  fi
}

# Extract all comment details in single jq call
# Usage: extract_comment_details <comment_json>
# Returns: JSON object with all comment fields
extract_comment_details() {
  local comment_json="$1"
  
  if [ -z "$comment_json" ] || [ "$comment_json" = "null" ]; then
    echo "{}"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "{}"
    return 1
  fi
  
  # Extract all fields in single jq call
  echo "$comment_json" | jq -c '{
    id: (.id // empty),
    path: (.path // .file // empty),
    line: (.line // empty),
    author: (.user.login // .author // .author.login // empty),
    body: (.body // empty),
    resolved: (.resolved // false)
  }' 2>/dev/null || echo "{}"
}

# Show file context with line numbers
# Usage: show_file_context <file_path> <line_number> <context_lines>
# Returns: formatted file context with highlighted line
show_file_context() {
  local file_path="$1"
  local line_number="${2:-}"
  local context_lines="${3:-10}"
  
  if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
    return 1
  fi
  
  if [ -n "$line_number" ] && [ "$line_number" != "null" ] && [ "$line_number" != "" ]; then
    # Show context around the line
    local start_line end_line
    start_line=$((line_number - context_lines))
    end_line=$((line_number + context_lines))
    
    if [ "$start_line" -lt 1 ]; then
      start_line=1
    fi
    
    # Show line numbers with context and highlight target line
    sed -n "${start_line},${end_line}p" "$file_path" | nl -v "$start_line" -ba | sed "s/^[[:space:]]*${line_number}[[:space:]]*/>>> ${line_number} /" | sed "s/^[[:space:]]*\([0-9]\+\)[[:space:]]*/    \1 /"
  else
    # No line number, show first 30 lines
    head -30 "$file_path" | nl -ba | sed 's/^[[:space:]]*\([0-9]\+\)[[:space:]]*/    \1 /'
  fi
}

# Verbose logging function (only logs when VERBOSE flag is set)
# Usage: log_verbose <message>
# Requires: VERBOSE variable to be set (true/false)
log_verbose() {
  local message="$1"
  if [ "${VERBOSE:-false}" = "true" ]; then
    log_info "$message"
  fi
}

# Get GraphQL query template for review threads
# Usage: get_review_threads_query_template
# Returns: GraphQL query template string with placeholders
get_review_threads_query_template() {
  echo '{
  repository(owner: "${owner}", name: "${repo}") {
    pullRequest(number: ${pr_number}) {
      reviewThreads(first: ${page_size}${cursor_param}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              databaseId
            }
          }
        }
      }
    }
  }
}'
}

# Find threads for comment IDs
# Usage: find_threads_for_comments <owner> <repo> <pr_number> <comment_ids_json>
# Returns: JSON array of {comment_id, thread_id, is_resolved}
find_threads_for_comments() {
  local owner="$1"
  local repo="$2"
  local pr_number="$3"
  local comment_ids_json="$4"
  
  if [ -z "$owner" ] || [ -z "$repo" ] || [ -z "$pr_number" ] || [ -z "$comment_ids_json" ]; then
    log_error "find_threads_for_comments: missing required arguments"
    echo "[]"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    log_error "jq is required for find_threads_for_comments"
    echo "[]"
    return 1
  fi
  
  # Get query template
  local query_template
  query_template=$(get_review_threads_query_template)
  
  # Fetch all threads using pagination utility
  local all_threads
  all_threads=$(fetch_graphql_paginated "$query_template" "$owner" "$repo" "$pr_number" 100 "false" ".data.repository.pullRequest.reviewThreads.pageInfo" ".data.repository.pullRequest.reviewThreads.nodes")
  
  if [ -z "$all_threads" ] || [ "$all_threads" = "[]" ] || [ "$all_threads" = "null" ]; then
    log_warning "No threads found for PR #${pr_number}"
    echo "[]"
    return 0
  fi
  
  # Find all threads for all comment IDs in single jq call
  # This creates a map: comment_id -> {thread_id, is_resolved}
  local thread_map
  thread_map=$(echo "$all_threads" | jq -c --argjson comment_ids "$comment_ids_json" '
    # For each thread, find matching comment IDs
    map({
      thread_id: .id,
      is_resolved: .isResolved,
      matching_comments: [.comments.nodes[].databaseId | select(. as $cid | $comment_ids | index($cid) != null)]
    }) |
    # Filter to only threads with matching comments
    map(select(.matching_comments | length > 0)) |
    # Flatten to one entry per comment
    map(.matching_comments[] as $cid | {comment_id: $cid, thread_id: .thread_id, is_resolved: .is_resolved}) |
    flatten
  ' 2>/dev/null || echo "[]")
  
  if [ -z "$thread_map" ] || [ "$thread_map" = "null" ]; then
    echo "[]"
    return 0
  fi
  
  echo "$thread_map"
}

# Resolve a review thread using GraphQL mutation
# Usage: resolve_review_thread <thread_id>
# Returns: 0 on success, 1 on failure
resolve_review_thread() {
  local thread_id="$1"
  
  if [ -z "$thread_id" ]; then
    log_error "Thread ID is required for resolve_review_thread"
    return 1
  fi
  
  # Validate thread ID format (should be a GraphQL ID string)
  if ! echo "$thread_id" | grep -qE '^[A-Za-z0-9_/-]+$'; then
    log_error "Invalid thread ID format: ${thread_id}"
    return 1
  fi
  
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI is required for resolve_review_thread"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    log_error "jq is required for resolve_review_thread"
    return 1
  fi
  
  local resolve_mutation
  resolve_mutation="mutation {
    resolveReviewThread(input: {threadId: \"${thread_id}\"}) {
      thread {
        id
        isResolved
      }
    }
  }"
  
  log_info "Resolving thread ${thread_id}..."
  local resolve_response
  resolve_response=$(gh api graphql -f query="$resolve_mutation" 2>/dev/null || echo "")
  
  if [ -z "$resolve_response" ]; then
    log_error "Failed to resolve thread ${thread_id}"
    return 1
  fi
  
  # Check if thread was resolved successfully
  local is_resolved
  is_resolved=$(echo "$resolve_response" | jq -r '.data.resolveReviewThread.thread.isResolved // false' 2>/dev/null || echo "false")
  
  if [ "$is_resolved" = "true" ]; then
    log_success "Resolved thread ${thread_id}"
    return 0
  else
    log_error "Failed to resolve thread ${thread_id}"
    return 1
  fi
}

# Setup common script initialization
# Usage: setup_pr_comments_script
# Note: Utils should already be sourced by caller before calling this function
# Checks prerequisites only
# Returns: 0 on success, 1 on failure
setup_pr_comments_script() {
  # Check prerequisites (utils should already be sourced)
  if ! check_prerequisites; then
    return 1
  fi
  
  return 0
}

# Dismiss review comment with reason
# Usage: dismiss_review_comment <pr_number> <owner> <repo> <thread_id> <comment_id> <reason> [skip_resolve]
# Returns: 0 on success, 1 on failure
# Adds a comment reply to the review comment with dismissal reason, then resolves the thread (unless skip_resolve=true)
dismiss_review_comment() {
  local pr_number="$1"
  local owner="$2"
  local repo="$3"
  local thread_id="$4"
  local comment_id="$5"
  local reason="$6"
  local skip_resolve="${7:-false}"
  
  if [ -z "$thread_id" ]; then
    log_error "Thread ID is required"
    return 1
  fi
  
  if [ -z "$comment_id" ]; then
    log_error "Comment ID is required"
    return 1
  fi
  
  if [ -z "$reason" ]; then
    log_error "Dismissal reason is required"
    return 1
  fi
  
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI is required for dismiss_review_comment"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    log_error "jq is required for dismiss_review_comment"
    return 1
  fi
  
  # Format dismissal message
  local dismissal_message="Dismissed - (${reason})"
  
  # Add comment reply using REST API
  # Use POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies to reply directly to the comment
  log_info "Adding dismissal comment as reply to comment ${comment_id}..."
  local api_endpoint="repos/${owner}/${repo}/pulls/${pr_number}/comments/${comment_id}/replies"
  local add_response
  add_response=$(gh api "$api_endpoint" -X POST -f body="$dismissal_message" 2>/dev/null || echo "")
  
  if [ -z "$add_response" ]; then
    log_error "Failed to add dismissal comment"
    return 1
  fi
  
  # Check for error in response
  if echo "$add_response" | jq -e '.message' > /dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "$add_response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
    log_error "Failed to add dismissal comment: ${error_msg}"
    return 1
  fi
  
  # Extract reply ID from successful response
  local reply_id
  reply_id=$(echo "$add_response" | jq -r '.id // empty' 2>/dev/null || echo "")
  if [ -n "$reply_id" ] && [ "$reply_id" != "null" ]; then
    log_info "Dismissal comment added as reply: ${reply_id}"
  else
    log_warning "Comment may not have been added, but continuing to resolve thread..."
  fi
  
  # Resolve the thread using utility function (unless skip_resolve is true)
  if [ "$skip_resolve" != "true" ]; then
    if resolve_review_thread "$thread_id"; then
      log_success "Thread ${thread_id} dismissed and resolved"
      return 0
    else
      return 1
    fi
  else
    log_info "Skipping thread resolution (already resolved or requested to skip)"
    return 0
  fi
}

