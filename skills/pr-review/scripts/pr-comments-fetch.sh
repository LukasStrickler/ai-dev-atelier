#!/bin/bash
# PR comments script
# Usage: ./pr-comments.sh [read|resolve|list] [PR_NUMBER] [--verbose]
#   list: List all open PRs in the repository
#   read: Fetch and save PR comments in structured format
#   resolve: Mark comments as resolved after fixes
#   --verbose: Enable verbose logging (disabled by default)

set -euo pipefail

# Verbose logging flag (disabled by default)
VERBOSE=false

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -r "${SCRIPT_DIR}/lib/pr-comments-utils.sh" ]; then
  echo "❌ Error: pr-comments-utils.sh not found or not readable: ${SCRIPT_DIR}/lib/pr-comments-utils.sh" >&2
  exit 1
fi
source "${SCRIPT_DIR}/lib/pr-comments-utils.sh"

# Prompt for PR number if not provided
get_pr_number() {
  local pr_number="$1"
  
  if [ -z "$pr_number" ]; then
    read -p "Enter PR number: " pr_number
    if [ -z "$pr_number" ]; then
      log_error "PR number is required"
      exit 1
    fi
  fi
  
  # Validate PR number is numeric
  if ! echo "$pr_number" | grep -qE '^[0-9]+$'; then
    log_error "Invalid PR number: $pr_number (must be numeric)"
    exit 1
  fi
  
  echo "$pr_number"
}

# Fetch all review comments using REST API with pagination
fetch_all_review_comments_rest() {
  local pr_number="$1"
  local owner_repo="$2"
  
  # Parse owner/repo using utils
  local owner repo
  read -r owner repo <<< "$(parse_owner_repo "$owner_repo")"
  
  log_verbose "Fetching all review comments for PR #${pr_number} using REST API..."
  log_verbose "Repository: ${owner}/${repo}"
  
  # Construct the API endpoint
  local api_endpoint="repos/${owner}/${repo}/pulls/${pr_number}/comments"
  log_verbose "API endpoint: ${api_endpoint}"
  log_verbose "Using gh api --paginate to fetch all pages automatically..."
  
  local stderr_file
  stderr_file=$(mktemp)
  local response
  response=$(gh api "$api_endpoint" --paginate 2>"$stderr_file")
  local exit_code=$?
  
  # Log stderr for debugging (only in verbose mode)
  if [ -s "$stderr_file" ]; then
    local error_msg
    error_msg=$(cat "$stderr_file" 2>/dev/null || echo "")
    log_verbose "Stderr output: $error_msg"
  fi
  
  if [ $exit_code -ne 0 ]; then
    local error_msg
    error_msg=$(cat "$stderr_file" 2>/dev/null || echo "")
    rm -f "$stderr_file"
    log_error "Failed to fetch review comments (exit code: $exit_code): $error_msg"
    echo "[]"
    return 1
  fi
  
  rm -f "$stderr_file"
  
  # Log response length for debugging (only in verbose mode)
  if [ "$VERBOSE" = "true" ]; then
    local response_length
    response_length=$(echo "$response" | wc -c | tr -d ' ')
    log_verbose "Response length: ${response_length} characters"
    
    if [ -n "$response" ]; then
      local response_preview
      response_preview=$(echo "$response" | head -c 200)
      log_verbose "Response preview: ${response_preview}..."
    fi
  fi
  
  # Normalize JSON array using utils
  local normalized_response
  normalized_response=$(normalize_json_array "$response")
  
  if [ "$VERBOSE" = "true" ] && command -v jq &> /dev/null; then
    local comment_count
    comment_count=$(echo "$normalized_response" | jq 'length // 0' 2>/dev/null || echo "0")
    log_verbose "Successfully fetched ${comment_count} review comment(s) from REST API"
    
    if [ "$comment_count" -gt 0 ]; then
      local sample_ids
      sample_ids=$(echo "$normalized_response" | jq -r '.[0:3] | .[] | .id' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      log_verbose "Sample comment IDs: ${sample_ids}"
    fi
  fi
  
  echo "$normalized_response"
}

# Fetch resolved status for review comments using GraphQL (minimal query)
fetch_resolved_status_simple() {
  local pr_number="$1"
  local owner_repo="$2"
  
  # Parse owner/repo using utils
  local owner repo
  read -r owner repo <<< "$(parse_owner_repo "$owner_repo")"
  
  log_verbose "Fetching resolved status for review comments using GraphQL..."
  
  # GraphQL query template for resolved status
  local query_template='{
    repository(owner: "${owner}", name: "${repo}") {
      pullRequest(number: ${pr_number}) {
        reviewThreads(first: ${page_size}${cursor_param}) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
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
  
  # Fetch all threads using pagination utility
  local all_threads
  all_threads=$(fetch_graphql_paginated "$query_template" "$owner" "$repo" "$pr_number" 100 "$VERBOSE" ".data.repository.pullRequest.reviewThreads.pageInfo" ".data.repository.pullRequest.reviewThreads.nodes")
  
  local total_threads
  total_threads=$(echo "$all_threads" | jq 'length // 0' 2>/dev/null || echo "0")
  log_verbose "Fetched ${total_threads} thread(s) with resolved status"
  
  # Build map: {comment_id: isResolved}
  log_verbose "Building resolved status map from ${total_threads} thread(s)..."
  local resolved_map
  resolved_map=$(echo "$all_threads" | jq -c 'reduce .[] as $thread ({}; . + reduce $thread.comments.nodes[] as $comment ({}; .[$comment.databaseId | tostring] = $thread.isResolved))' 2>/dev/null || echo "{}")
  
  if [ -z "$resolved_map" ] || [ "$resolved_map" = "null" ]; then
    log_warning "Failed to build resolved status map, returning empty map"
    echo "{}"
    return 0
  fi
  
  # Calculate statistics in single jq call
  local stats
  stats=$(echo "$resolved_map" | jq -c '[to_entries | length as $total | [.[] | select(.value == true)] | length as $resolved | [.[] | select(.value == false)] | length as $unresolved | {total: $total, resolved: $resolved, unresolved: $unresolved}] | .[0]' 2>/dev/null || echo '{"total":0,"resolved":0,"unresolved":0}')
  
  local total_mapped resolved_count unresolved_count
  total_mapped=$(echo "$stats" | jq -r '.total // 0' 2>/dev/null || echo "0")
  resolved_count=$(echo "$stats" | jq -r '.resolved // 0' 2>/dev/null || echo "0")
  unresolved_count=$(echo "$stats" | jq -r '.unresolved // 0' 2>/dev/null || echo "0")
  
  log_verbose "Resolved status map: ${total_mapped} total entries, ${resolved_count} resolved, ${unresolved_count} unresolved"
  
  # Log sample entries for debugging (only in verbose mode)
  if [ "$total_mapped" -gt 0 ] && [ "$VERBOSE" = "true" ]; then
    local sample_entries
    sample_entries=$(echo "$resolved_map" | jq -r 'to_entries[0:3] | .[] | "\(.key):\(.value)"' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    log_verbose "Sample resolved map entries: ${sample_entries}"
  fi
  
  echo "$resolved_map"
}




# Fetch issue comments using GitHub CLI
fetch_issue_comments() {
  local pr_number="$1"
  local owner_repo="$2"
  
  log_info "Fetching issue comments for PR #${pr_number}..." >&2
  
  # Parse owner/repo using utils
  local owner repo
  read -r owner repo <<< "$(parse_owner_repo "$owner_repo")"
  
  # Use GitHub API to get issue comments (PR comments that are not line-specific)
  # Note: PRs are also issues, so we use /issues/{pr_number}/comments
  local stderr_file
  stderr_file=$(mktemp)
  local response
  local error_output
  response=$(gh api "repos/${owner}/${repo}/issues/${pr_number}/comments" 2> "$stderr_file")
  local exit_code=$?
  error_output=$(cat "$stderr_file" 2>/dev/null || echo "")
  rm -f "$stderr_file"
  
  if [ $exit_code -ne 0 ]; then
    log_error "Failed to fetch issue comments"
    [ -n "$error_output" ] && echo "$error_output" >&2
    echo "[]"
    return 1
  fi
  
  # Return empty array if response is empty or invalid
  if [ -z "$response" ] || [ "$response" = "null" ]; then
    echo "[]"
    return 0
  fi
  
  # Validate JSON and return
  if command -v jq &> /dev/null; then
    if echo "$response" | jq . > /dev/null 2>&1; then
      echo "$response"
    else
      log_warning "Invalid JSON response for issue comments, returning empty array"
      [ -n "$error_output" ] && log_warning "Error output: $error_output"
      echo "[]"
    fi
  else
    echo "$response"
  fi
}

# Format review comment for markdown - simplified version for LLMs
format_review_comment_markdown_simple() {
  local comment_json="$1"
  
  if command -v jq &> /dev/null; then
    local id author body path line side
    id=$(echo "$comment_json" | jq -r '.id // empty')
    author=$(echo "$comment_json" | jq -r '.author.login // .author // empty')
    body=$(echo "$comment_json" | jq -r '.body // empty')
    path=$(echo "$comment_json" | jq -r '.path // empty')
    line=$(echo "$comment_json" | jq -r '.line // empty')
    side=$(echo "$comment_json" | jq -r '.side // empty')
    
    # Clean HTML from body using utils
    local clean_body
    clean_body=$(clean_html_body "$body")
    
    echo "### Comment ID: ${id}"
    if [ -n "$path" ]; then
      if [ -n "$line" ] && [ "$line" != "null" ]; then
        echo "**Location:** \`${path}:${line}\` (${side} side)"
      else
        echo "**Location:** \`${path}\`"
      fi
    fi
    if [ -n "$author" ]; then
      echo "**Author:** @${author}"
    fi
    echo "**Comment:**"
    echo ""
    echo "$clean_body"
    echo ""
    echo "---"
    echo ""
  else
    # Fallback: basic formatting without jq
    echo "### Comment (JSON parsing requires jq)"
    echo "\`\`\`json"
    echo "$comment_json"
    echo "\`\`\`"
    echo ""
  fi
}

# Format issue comment for markdown - simplified version for LLMs
format_issue_comment_markdown_simple() {
  local comment_json="$1"
  
  if command -v jq &> /dev/null; then
    local id author body
    id=$(echo "$comment_json" | jq -r '.id // empty')
    author=$(echo "$comment_json" | jq -r '.author.login // .author // empty')
    body=$(echo "$comment_json" | jq -r '.body // empty')
    
    # Clean HTML from body using utils
    local clean_body
    clean_body=$(clean_html_body "$body")
    
    echo "### Comment ID: ${id}"
    if [ -n "$author" ]; then
      echo "**Author:** @${author}"
    fi
    echo "**Comment:**"
    echo ""
    echo "$clean_body"
    echo ""
    echo "---"
    echo ""
  else
    # Fallback: basic formatting without jq
    echo "### Comment (JSON parsing requires jq)"
    echo "\`\`\`json"
    echo "$comment_json"
    echo "\`\`\`"
    echo ""
  fi
}

# Build markdown file - only unresolved comments, simplified for LLMs
build_markdown_file() {
  local pr_number="$1"
  local review_comments_json="$2"
  local issue_comments_json="$3"
  local markdown_file="$4"
  local metadata_file="${5:-}"
  
  {
    echo "# PR Comments for #${pr_number}"
    echo ""
    echo "> Only unresolved comments are shown here. For full details, see the JSON metadata file."
    echo ""
    
    # Review comments section - only unresolved
    echo "## Review Comments"
    echo ""
    
    if [ -n "$review_comments_json" ] && [ "$review_comments_json" != "[]" ]; then
      if command -v jq &> /dev/null; then
        # Validate JSON before processing
        if echo "$review_comments_json" | jq . > /dev/null 2>&1; then
          # Get unresolved comment IDs from metadata if available
          local unresolved_ids
          if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
            unresolved_ids=$(jq -r '.review_comments[] | select(.resolved == false) | .id' "$metadata_file" 2>/dev/null || echo "")
          fi
          
          # Process only unresolved comments
          if [ -n "$unresolved_ids" ] && [ "$unresolved_ids" != "" ]; then
            # Filter to only unresolved comments
            echo "$review_comments_json" | jq -c --argjson unresolved_ids "$(echo "$unresolved_ids" | jq -s '.')" '.[] | select(.id as $id | $unresolved_ids | index($id) != null)' 2>/dev/null | while IFS= read -r comment; do
              [ -n "$comment" ] && format_review_comment_markdown_simple "$comment"
            done
          else
            # No metadata yet, show all comments as unresolved
            echo "$review_comments_json" | jq -c '.[]' 2>/dev/null | while IFS= read -r comment; do
              [ -n "$comment" ] && format_review_comment_markdown_simple "$comment"
            done
          fi
        else
          log_warning "Invalid JSON for review comments, skipping"
          echo "No review comments found."
          echo ""
        fi
      else
        echo "⚠️  Review comments require jq for formatting"
        echo ""
      fi
    else
      echo "No review comments found."
      echo ""
    fi
  } > "$markdown_file"
}

# Map resolved status to comments
map_resolved_status() {
  local review_comments_json="$1"
  local resolved_map="$2"
  
  if [ -z "$review_comments_json" ] || [ "$review_comments_json" = "[]" ]; then
    log_warning "No review comments to map resolved status"
    echo "[]"
    return 0
  fi
  
  if [ -z "$resolved_map" ] || [ "$resolved_map" = "{}" ]; then
    log_warning "No resolved status map provided, all comments will be marked as unresolved"
    echo "$review_comments_json" | jq -c 'map(. + {type: "review", resolved: false})' 2>/dev/null || echo "$review_comments_json"
    return 0
  fi
  
  log_verbose "Mapping resolved status to comments..."
  
  # Log resolved map for debugging (only in verbose mode)
  if [ "$VERBOSE" = "true" ]; then
    # Get all debug info in single jq call
    local debug_info
    debug_info=$(echo "$resolved_map" "$review_comments_json" | jq -s '{
      map_size: (.[0] | length),
      sample_keys: (.[0] | keys[0:3] | .[]),
      sample_comment_ids: (.[1] | .[0:3] | .[] | .id | tostring)
    }' 2>/dev/null || echo '{"map_size":0,"sample_keys":[],"sample_comment_ids":[]}')
    
    local resolved_map_size
    resolved_map_size=$(echo "$debug_info" | jq -r '.map_size // 0' 2>/dev/null || echo "0")
    log_verbose "Resolved map contains ${resolved_map_size} entries"
    
    local sample_keys
    sample_keys=$(echo "$debug_info" | jq -r '.sample_keys[]' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    if [ -n "$sample_keys" ]; then
      log_verbose "Sample resolved map keys: ${sample_keys}"
    fi
    
    local sample_comment_ids
    sample_comment_ids=$(echo "$debug_info" | jq -r '.sample_comment_ids[]' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    if [ -n "$sample_comment_ids" ]; then
      log_verbose "Sample comment IDs from REST API: ${sample_comment_ids}"
    fi
  fi
  
  # Apply resolved status to each comment by matching id
  # REST API returns 'id' field which is the databaseId
  # GraphQL returns databaseId, so we map using .id from REST API (as string)
  local mapped_comments
  mapped_comments=$(echo "$review_comments_json" | jq -c --argjson resolved_map "$resolved_map" 'map(. + {
    type: "review",
    resolved: ($resolved_map[(.id | tostring)] // false)
  })' 2>/dev/null || echo "$review_comments_json")
  
  if [ -z "$mapped_comments" ] || [ "$mapped_comments" = "null" ]; then
    log_error "Failed to map resolved status, returning original comments"
    echo "$review_comments_json" | jq -c 'map(. + {type: "review", resolved: false})' 2>/dev/null || echo "$review_comments_json"
    return 1
  fi
  
  # Calculate statistics in single jq call
  local stats
  stats=$(echo "$mapped_comments" | jq -c '{
    total: length,
    resolved: ([.[] | select(.resolved == true)] | length),
    unresolved: ([.[] | select(.resolved == false)] | length)
  }' 2>/dev/null || echo '{"total":0,"resolved":0,"unresolved":0}')
  
  local final_total final_resolved final_unresolved
  final_total=$(echo "$stats" | jq -r '.total // 0' 2>/dev/null || echo "0")
  final_resolved=$(echo "$stats" | jq -r '.resolved // 0' 2>/dev/null || echo "0")
  final_unresolved=$(echo "$stats" | jq -r '.unresolved // 0' 2>/dev/null || echo "0")
  
  log_verbose "Mapped status: ${final_total} total, ${final_resolved} resolved, ${final_unresolved} unresolved"
  echo "$mapped_comments"
}

# Build JSON metadata file
build_metadata_file() {
  local pr_number="$1"
  local owner_repo="$2"
  local review_comments_json="$3"
  local issue_comments_json="$4"
  local metadata_file="$5"
  local timestamp="$6"
  local latest_commit_sha="${7:-}"
  
  local review_count=0
  local issue_count=0
  
  if command -v jq &> /dev/null; then
    review_count=$(echo "$review_comments_json" | jq 'length // 0' 2>/dev/null || echo "0")
    issue_count=0  # Skip issue comments for now
    
    # Review comments already have resolved status mapped
    local review_comments_array
    if [ -n "$review_comments_json" ] && [ "$review_comments_json" != "[]" ] && echo "$review_comments_json" | jq . > /dev/null 2>&1; then
      review_comments_array="$review_comments_json"
      
      # Log classification statistics
      local final_resolved
      final_resolved=$(echo "$review_comments_array" | jq '[.[] | select(.resolved == true)] | length' 2>/dev/null || echo "0")
      local final_unresolved
      final_unresolved=$(echo "$review_comments_array" | jq '[.[] | select(.resolved == false)] | length' 2>/dev/null || echo "0")
      local final_total
      final_total=$(echo "$review_comments_array" | jq 'length' 2>/dev/null || echo "0")
      
      log_verbose "Classification: ${final_total} total, ${final_resolved} resolved, ${final_unresolved} unresolved"
    else
      review_comments_array="[]"
      log_warning "No review comments to process"
    fi
    
    # Skip issue comments for now
    local issue_comments_array="[]"
    
    # Build final metadata JSON
    local total_comments
    total_comments=$((review_count + issue_count))
    
    jq -n \
      --arg timestamp "$timestamp" \
      --argjson pr_number "$pr_number" \
      --arg owner_repo "$owner_repo" \
      --argjson review_comments "$review_comments_array" \
      --argjson issue_comments "$issue_comments_array" \
      --argjson total "$total_comments" \
      --argjson review_count "$review_count" \
      --argjson issue_count "$issue_count" \
      --arg latest_commit_sha "$latest_commit_sha" \
      '{
        timestamp: $timestamp,
        pr_number: $pr_number,
        repository: $owner_repo,
        latest_commit_sha: $latest_commit_sha,
        review_comments: $review_comments,
        issue_comments: $issue_comments,
        statistics: {
          total_comments: $total,
          review_comments_count: $review_count,
          issue_comments_count: $issue_count
        }
      }' > "$metadata_file" 2>/dev/null || {
      log_warning "Failed to build metadata with jq, creating basic structure"
      build_basic_metadata_file "$pr_number" "$owner_repo" "$review_count" "$issue_count" "$metadata_file" "$timestamp" "$latest_commit_sha"
    }
  else
    # Fallback: basic JSON without jq
    build_basic_metadata_file "$pr_number" "$owner_repo" "$review_count" "$issue_count" "$metadata_file" "$timestamp" "$latest_commit_sha"
  fi
}

# Build basic metadata file without jq
build_basic_metadata_file() {
  local pr_number="$1"
  local owner_repo="$2"
  local review_count="$3"
  local issue_count="$4"
  local metadata_file="$5"
  local timestamp="$6"
  local latest_commit_sha="${7:-}"
  
  local total_comments
  total_comments=$((review_count + issue_count))
  
  cat > "$metadata_file" <<EOF
{
  "timestamp": "${timestamp}",
  "pr_number": ${pr_number},
  "repository": "${owner_repo}",
  "latest_commit_sha": "${latest_commit_sha}",
  "review_comments": [],
  "issue_comments": [],
  "statistics": {
    "total_comments": ${total_comments},
    "review_comments_count": ${review_count},
    "issue_comments_count": ${issue_count}
  }
}
EOF
}

# Read mode: Fetch and save PR comments
read_mode() {
  local pr_number="$1"
  
  # Check all prerequisites at once using utils
  if ! check_prerequisites; then
    exit 1
  fi
  
  # Get repository owner/repo
  local owner_repo
  owner_repo=$(get_repo_owner_repo)
  if [ -z "$owner_repo" ]; then
    exit 1
  fi
  
  log_verbose "Repository: ${owner_repo}"
  
  # Ensure .github directory exists
  ensure_github_dir
  
  log_verbose "Fetching comments for PR #${pr_number}..."
  
  # Get latest commit SHA from PR using utils
  local latest_commit_sha
  if ! latest_commit_sha=$(get_pr_commit_sha "$pr_number"); then
    exit 1
  fi
  
  # Generate file paths (using PR number and commit hash)
  local markdown_file
  markdown_file=$(get_pr_comments_file_path "$pr_number" "$latest_commit_sha")
  local metadata_file
  metadata_file=$(get_pr_comments_metadata_path "$pr_number" "$latest_commit_sha")
  
  # Always fetch fresh data and overwrite existing files
  # This ensures we get the latest resolved status even if the commit hasn't changed
  log_verbose "PR #${pr_number} (commit: ${latest_commit_sha:0:8}...), fetching comments..."
  
  # Fetch all comments using REST API with pagination
  local review_comments_json
  review_comments_json=$(fetch_all_review_comments_rest "$pr_number" "$owner_repo")
  local issue_comments_json="[]"  # Skip issue comments for now
  
  # Fetch resolved status using GraphQL
  local resolved_map
  resolved_map=$(fetch_resolved_status_simple "$pr_number" "$owner_repo")
  
  # Map resolved status to comments
  local review_comments_with_status
  review_comments_with_status=$(map_resolved_status "$review_comments_json" "$resolved_map")
  
  # Build files (overwrite existing)
  # Note: build_markdown_file needs to filter unresolved comments from metadata
  # We'll build metadata first, then use it to filter unresolved comments for MD
  build_metadata_file "$pr_number" "$owner_repo" "$review_comments_with_status" "$issue_comments_json" "$metadata_file" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$latest_commit_sha"
  
  # Build markdown with only unresolved comments
  build_markdown_file "$pr_number" "$review_comments_with_status" "$issue_comments_json" "$markdown_file" "$metadata_file"
  
  # Display statistics from metadata file (single jq call for all stats)
  local stats
  if [ -f "$metadata_file" ] && command -v jq &> /dev/null; then
    stats=$(jq -c '{
      total: (.statistics.total_comments // 0),
      resolved: ([.review_comments[]? | select(.resolved == true)] | length),
      unresolved: ([.review_comments[]? | select(.resolved == false)] | length)
    }' "$metadata_file" 2>/dev/null || echo '{"total":0,"resolved":0,"unresolved":0}')
  else
    stats='{"total":0,"resolved":0,"unresolved":0}'
  fi
  
  local total_count resolved_count unresolved_count
  total_count=$(echo "$stats" | jq -r '.total // 0' 2>/dev/null || echo "0")
  resolved_count=$(echo "$stats" | jq -r '.resolved // 0' 2>/dev/null || echo "0")
  unresolved_count=$(echo "$stats" | jq -r '.unresolved // 0' 2>/dev/null || echo "0")
  
  log_success "Comments ready!"
  echo ""
  echo "📄 Markdown: $markdown_file"
  echo "📊 Metadata: $metadata_file"
  echo ""
  echo "📊 Statistics:"
  echo "   Total comments: ${total_count}"
  echo "   Resolved: ${resolved_count}"
  echo "   Unresolved: ${unresolved_count}"
  echo ""
  echo "Next: use pr-comments-get.sh ${pr_number} <INDEX_OR_ID> to review comments one by one."
  echo "If multiple unresolved comments exist, avoid reading the full markdown file."
  echo ""
}

# Resolve mode: Mark comments as resolved
resolve_mode() {
  local pr_number="$1"
  
  # Check all prerequisites at once using utils
  if ! check_prerequisites; then
    exit 1
  fi
  
  # Get repository owner/repo
  local owner_repo
  owner_repo=$(get_repo_owner_repo)
  if [ -z "$owner_repo" ]; then
    exit 1
  fi
  
  log_info "Repository: ${owner_repo}"
  echo ""
  
  # Get latest commit SHA from PR using utils
  local latest_commit_sha
  if ! latest_commit_sha=$(get_pr_commit_sha "$pr_number"); then
    exit 1
  fi
  
  # Get metadata file for this PR (using PR number and commit hash)
  local metadata_file
  metadata_file=$(get_pr_comments_metadata_path "$pr_number" "$latest_commit_sha")
  
  if [ -z "$metadata_file" ] || [ ! -f "$metadata_file" ]; then
    log_error "No comments file found for PR #${pr_number} (commit: ${latest_commit_sha:0:8}...)"
    echo "   Run 'bun run pr:comments ${pr_number}' first to fetch comments"
    exit 1
  fi
  
  log_info "Using comments file: $(basename "$metadata_file")"
  echo ""
  
  # Load unresolved comments
  if ! command -v jq &> /dev/null; then
    log_error "jq is required for resolve mode"
    echo "   Install jq: https://stedolan.github.io/jq/download/"
    exit 1
  fi
  
  # Get unresolved comments and counts in single jq call
  local unresolved_data
  unresolved_data=$(jq -c '{
    review: [.review_comments[] | select(.resolved == false)],
    issue: [.issue_comments[] | select(.resolved == false)],
    review_count: ([.review_comments[] | select(.resolved == false)] | length),
    issue_count: ([.issue_comments[] | select(.resolved == false)] | length)
  }' "$metadata_file" 2>/dev/null || echo '{"review":[],"issue":[],"review_count":0,"issue_count":0}')
  
  local unresolved_review unresolved_issue unresolved_review_count unresolved_issue_count
  unresolved_review=$(echo "$unresolved_data" | jq -c '.review // []' 2>/dev/null || echo "[]")
  unresolved_issue=$(echo "$unresolved_data" | jq -c '.issue // []' 2>/dev/null || echo "[]")
  unresolved_review_count=$(echo "$unresolved_data" | jq -r '.review_count // 0' 2>/dev/null || echo "0")
  unresolved_issue_count=$(echo "$unresolved_data" | jq -r '.issue_count // 0' 2>/dev/null || echo "0")
  
  if [ "$unresolved_review_count" -eq 0 ] && [ "$unresolved_issue_count" -eq 0 ]; then
    log_warning "No unresolved comments found for PR #${pr_number}"
    exit 0
  fi
  
  echo "📋 Unresolved Comments:"
  echo "   Review comments: ${unresolved_review_count}"
  echo "   Issue comments: ${unresolved_issue_count}"
  echo ""
  
  # Display unresolved comments
  if [ "$unresolved_review_count" -gt 0 ]; then
    echo "Review Comments:"
    echo "$unresolved_review" | jq -r '.[] | "  ID: \(.id) | File: \(.file) | Line: \(.line // "N/A") | Author: @\(.author)"' 2>/dev/null || true
    echo ""
  fi
  
  if [ "$unresolved_issue_count" -gt 0 ]; then
    echo "Issue Comments:"
    echo "$unresolved_issue" | jq -r '.[] | "  ID: \(.id) | Author: @\(.author)"' 2>/dev/null || true
    echo ""
  fi
  
  # Prompt for IDs to resolve
  echo "Enter comma-separated comment IDs to mark as resolved:"
  read -r ids_input
  
  if [ -z "$ids_input" ]; then
    log_warning "No IDs provided, exiting"
    exit 0
  fi
  
  # Parse IDs (remove spaces, split by comma)
  local ids_array
  ids_array=$(echo "$ids_input" | tr -d ' ' | tr ',' '\n' | grep -v '^$' || echo "")
  
  if [ -z "$ids_array" ]; then
    log_error "No valid IDs found"
    exit 1
  fi
  
  # Validate IDs exist in metadata
  local valid_ids=()
  while IFS= read -r id; do
    if [ -n "$id" ]; then
      # Check if ID exists in review or issue comments
      local exists
      exists=$(jq -e --arg id "$id" '.review_comments[]? | select(.id == ($id | tonumber)) or .issue_comments[]? | select(.id == ($id | tonumber))' "$metadata_file" 2>/dev/null || echo "false")
      if [ "$exists" != "false" ]; then
        valid_ids+=("$id")
      else
        log_warning "Comment ID ${id} not found in metadata, skipping"
      fi
    fi
  done <<< "$ids_array"
  
  if [ ${#valid_ids[@]} -eq 0 ]; then
    log_error "No valid comment IDs found"
    exit 1
  fi
  
  # Show selected comments for validation
  echo ""
  echo "📝 Selected Comments to Resolve:"
  for id in "${valid_ids[@]}"; do
    local comment_info
    comment_info=$(jq -c --arg id "$id" '.review_comments[]? | select(.id == ($id | tonumber)) // .issue_comments[]? | select(.id == ($id | tonumber))' "$metadata_file" 2>/dev/null || echo "")
    
    if [ -n "$comment_info" ]; then
      local type file line author body_preview
      type=$(echo "$comment_info" | jq -r '.type // "unknown"')
      file=$(echo "$comment_info" | jq -r '.file // "N/A"')
      line=$(echo "$comment_info" | jq -r '.line // "N/A"')
      author=$(echo "$comment_info" | jq -r '.author // "unknown"')
      body_preview=$(echo "$comment_info" | jq -r '.body // ""' | head -c 100)
      
      echo "  ID: ${id} | Type: ${type}"
      if [ "$type" = "review" ]; then
        echo "    File: ${file} | Line: ${line} | Author: @${author}"
      else
        echo "    Author: @${author}"
      fi
      echo "    Preview: ${body_preview}..."
      echo ""
    fi
  done
  
  # Confirm before resolving
  echo "Confirm resolve these ${#valid_ids[@]} comment(s)? (yes/no)"
  read -r confirm
  
  if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
    log_warning "Cancelled by user"
    exit 0
  fi
  
  # Resolve comments
  echo ""
  log_info "Resolving comments..."
  
  local resolved_count=0
  local failed_count=0
  
  for id in "${valid_ids[@]}"; do
    local comment_info
    comment_info=$(jq -c --arg id "$id" '.review_comments[]? | select(.id == ($id | tonumber)) // .issue_comments[]? | select(.id == ($id | tonumber))' "$metadata_file" 2>/dev/null || echo "")
    
    if [ -z "$comment_info" ]; then
      continue
    fi
    
    local type
    type=$(echo "$comment_info" | jq -r '.type // "unknown"')
    
    # Extract owner and repo from owner_repo
    local owner repo
    owner=$(echo "$owner_repo" | cut -d'/' -f1)
    repo=$(echo "$owner_repo" | cut -d'/' -f2)
    
    if [ "$type" = "review" ]; then
      # For review comments, we can mark the thread as resolved using the API
      # Note: This requires the comment to be part of a review thread
      # We'll mark it in metadata and optionally add a reply
      resolved_count=$((resolved_count + 1))
      echo "  ✅ Marked review comment ${id} as resolved (metadata)"
    elif [ "$type" = "issue" ]; then
      # For issue comments, we can add a reply comment to indicate resolution
      # Use gh pr comment to add a new comment (not a reply, but indicates resolution)
      if gh pr comment "$pr_number" --body "✅ Resolved comment ${id} via pr-comments.sh script" &> /dev/null; then
        resolved_count=$((resolved_count + 1))
        echo "  ✅ Resolved issue comment ${id} (added resolution comment)"
      else
        # If comment fails, just mark in metadata
        resolved_count=$((resolved_count + 1))
        echo "  ✅ Marked issue comment ${id} as resolved (metadata only)"
      fi
    fi
  done
  
  # Update metadata file to mark comments as resolved
  # Update each ID separately (more reliable than building complex jq expression)
  for id in "${valid_ids[@]}"; do
    local temp_file
    temp_file=$(mktemp)
    if jq --arg id "$id" '(.review_comments[]? | select(.id == ($id | tonumber)) | .resolved) = true | (.issue_comments[]? | select(.id == ($id | tonumber)) | .resolved) = true' "$metadata_file" > "$temp_file" 2>/dev/null; then
      mv "$temp_file" "$metadata_file"
    else
      rm -f "$temp_file"
      log_warning "Failed to update metadata for comment ID ${id}"
    fi
  done
  
  echo ""
  log_success "Resolved ${resolved_count} comment(s)"
  if [ "$failed_count" -gt 0 ]; then
    log_warning "${failed_count} comment(s) failed to resolve"
  fi
  echo ""
  echo "📊 Metadata updated: $metadata_file"
}

# List mode: Show all open PRs
list_mode() {
  # Check all prerequisites at once using utils
  if ! check_prerequisites; then
    exit 1
  fi
  
  # Get repository owner/repo
  local owner_repo
  owner_repo=$(get_repo_owner_repo)
  if [ -z "$owner_repo" ]; then
    exit 1
  fi
  
  log_info "Fetching open PRs for ${owner_repo}..."
  echo ""
  
  # Fetch open PRs using GitHub CLI
  if ! gh pr list --json number,title,author,state,createdAt,url --jq '.[] | "\(.number)\t\(.title)\t@\(.author.login)\t\(.createdAt)\t\(.url)"' 2>/dev/null; then
    log_error "Failed to fetch PRs"
    echo "   Make sure you're authenticated: gh auth login"
    exit 1
  fi
  
  echo ""
  log_info "Use 'bun run pr:comments <PR_NUMBER>' to fetch comments for a PR"
}

# Main script
main() {
  local mode="${1:-read}"
  local pr_number="${2:-}"
  
  # Parse verbose flag using utils
  VERBOSE=$(parse_verbose_flag "$@")
  
  # Export VERBOSE so log_verbose() can use it
  export VERBOSE
  
  if [ "$mode" != "read" ] && [ "$mode" != "resolve" ] && [ "$mode" != "list" ]; then
    log_error "Invalid mode. Use 'read', 'resolve', or 'list'"
    echo "   Usage: $0 [read|resolve|list] [PR_NUMBER] [--verbose]"
    exit 1
  fi
  
  if [ "$mode" = "list" ]; then
    list_mode
    return
  fi
  
  # Get PR number (not needed for list mode)
  pr_number=$(get_pr_number "$pr_number")
  
  if [ "$mode" = "read" ]; then
    read_mode "$pr_number"
  else
    resolve_mode "$pr_number"
  fi
}

# Run main function
main "$@"

