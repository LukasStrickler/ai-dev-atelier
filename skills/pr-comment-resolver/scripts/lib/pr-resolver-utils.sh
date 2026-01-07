#!/bin/bash
# Shared utility functions for PR comment resolver scripts
# Self-contained - does NOT depend on pr-review skill
# Source this file, do not execute directly

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

PR_RESOLVER_DATA_DIR="${PR_RESOLVER_DATA_DIR:-.ada/data/pr-resolver}"
MAX_COMMENTS_PER_CLUSTER="${MAX_COMMENTS_PER_CLUSTER:-5}"
DICE_THRESHOLD_SHORT="${DICE_THRESHOLD_SHORT:-0.90}"
DICE_THRESHOLD_MEDIUM="${DICE_THRESHOLD_MEDIUM:-0.85}"
DICE_THRESHOLD_LONG="${DICE_THRESHOLD_LONG:-0.80}"

# ============================================================================
# Logging
# ============================================================================

log_error() { echo "Error: $1" >&2; }
log_success() { echo "$1"; }
log_info() { echo "$1" >&2; }
log_warning() { echo "Warning: $1" >&2; }

# ============================================================================
# Prerequisites
# ============================================================================

check_prerequisites() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository"
    return 1
  fi
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found. Install: https://cli.github.com/"
    return 1
  fi
  if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI not authenticated. Run: gh auth login"
    return 1
  fi
  if ! command -v jq &> /dev/null; then
    log_error "jq not found. Install: https://stedolan.github.io/jq/"
    return 1
  fi
  return 0
}

ensure_pr_resolver_dir() {
  mkdir -p "$PR_RESOLVER_DATA_DIR" 2>/dev/null || {
    log_error "Failed to create directory: $PR_RESOLVER_DATA_DIR"
    return 1
  }
}

# ============================================================================
# File Paths (PR-numbered folder for encapsulation)
# ============================================================================

get_pr_dir() {
  local pr_number="$1"
  echo "${PR_RESOLVER_DATA_DIR}/pr-${pr_number}"
}

get_pr_data_path() {
  local pr_number="$1"
  echo "$(get_pr_dir "$pr_number")/data.json"
}

# ============================================================================
# Git/GitHub Helpers
# ============================================================================

get_repo_owner_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -z "$remote_url" ]; then
    log_error "No git remote 'origin' found"
    return 1
  fi
  local owner_repo
  owner_repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]([^/]+)/([^/]+)(\.git)?$|\1/\2|')
  if [ -z "$owner_repo" ] || [ "$owner_repo" = "$remote_url" ]; then
    log_error "Could not extract owner/repo from: $remote_url"
    return 1
  fi
  echo "$owner_repo"
}

parse_owner_repo() {
  local owner_repo="$1"
  local owner repo
  owner=$(echo "$owner_repo" | cut -d'/' -f1)
  repo=$(echo "$owner_repo" | cut -d'/' -f2 | sed 's/\.git$//')
  echo "$owner $repo"
}

validate_pr_number() {
  local pr_number="$1"
  [ -n "$pr_number" ] && echo "$pr_number" | grep -qE '^[0-9]+$'
}

validate_comment_id() {
  local comment_id="$1"
  [ -n "$comment_id" ] && echo "$comment_id" | grep -qE '^[0-9]+$'
}

detect_pr_number() {
  local pr_number=""
  # Method 1: Most recent PR data folder
  if [ -d "$PR_RESOLVER_DATA_DIR" ]; then
    local latest_file
    latest_file=$(find "$PR_RESOLVER_DATA_DIR" -name "data.json" -type f 2>/dev/null | sort -r | head -1)
    if [ -n "$latest_file" ] && [ -f "$latest_file" ]; then
      pr_number=$(jq -r '.pr_number // empty' "$latest_file" 2>/dev/null || echo "")
      if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
        echo "$pr_number"
        return 0
      fi
    fi
  fi
  # Method 2: Match by commit SHA
  if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    local current_sha
    current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -n "$current_sha" ]; then
      pr_number=$(gh pr list --json number,headRefOid --jq --arg sha "$current_sha" '.[] | select(.headRefOid == $sha) | .number' 2>/dev/null | head -1)
      if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
        echo "$pr_number"
        return 0
      fi
    fi
  fi
  # Method 3: gh pr view
  if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    pr_number=$(gh pr view --json number --jq '.number // empty' 2>/dev/null || echo "")
    if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
      echo "$pr_number"
      return 0
    fi
  fi
  echo ""
  return 1
}

# ============================================================================
# JSON Helpers
# ============================================================================

normalize_json_array() {
  local json_string="$1"
  if [ -z "$json_string" ] || [ "$json_string" = "null" ]; then
    echo "[]"
    return 0
  fi
  local json_type
  json_type=$(echo "$json_string" | jq -r 'type' 2>/dev/null || echo "unknown")
  if [ "$json_type" = "array" ]; then
    echo "$json_string"
    return 0
  fi
  # Handle multiple arrays from pagination
  local line_count
  line_count=$(echo "$json_string" | wc -l | tr -d ' ')
  if [ "$line_count" -gt 1 ]; then
    echo "$json_string" | jq -s 'add' 2>/dev/null || echo "[]"
    return 0
  fi
  echo "[]"
}

# ============================================================================
# GraphQL Helpers
# ============================================================================

get_review_threads_query_template() {
  cat <<'EOF'
query($owner: String!, $repo: String!, $pr_number: Int!, $page_size: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr_number) {
      reviewThreads(first: $page_size, after: $cursor) {
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
}
EOF
}

fetch_graphql_paginated() {
  local query_template="$1"
  local owner="$2"
  local repo="$3"
  local pr_number="$4"
  local page_size="${5:-100}"
  local verbose="${6:-false}"
  local page_info_path="${7:-.data.repository.pullRequest.reviewThreads.pageInfo}"
  local nodes_path="${8:-.data.repository.pullRequest.reviewThreads.nodes}"
  
  local all_nodes="[]"
  local cursor=""
  local has_next_page=true
  
  while [ "$has_next_page" = "true" ]; do
    local response
    # Use gh api graphql -F for proper variable interpolation (handles special chars)
    if [ -z "$cursor" ]; then
      response=$(gh api graphql \
        -f query="$query_template" \
        -F owner="$owner" \
        -F repo="$repo" \
        -F pr_number="$pr_number" \
        -F page_size="$page_size" \
        2>/dev/null || echo "")
    else
      response=$(gh api graphql \
        -f query="$query_template" \
        -F owner="$owner" \
        -F repo="$repo" \
        -F pr_number="$pr_number" \
        -F page_size="$page_size" \
        -f cursor="$cursor" \
        2>/dev/null || echo "")
    fi
    
    if [ -z "$response" ]; then
      break
    fi
    
    local nodes
    nodes=$(echo "$response" | jq -c "${nodes_path} // []" 2>/dev/null || echo "[]")
    
    if [ "$all_nodes" = "[]" ]; then
      all_nodes="$nodes"
    else
      all_nodes=$(echo "$all_nodes" "$nodes" | jq -s 'add' 2>/dev/null || echo "$all_nodes")
    fi
    
    local page_info
    page_info=$(echo "$response" | jq -r "${page_info_path} // {}" 2>/dev/null || echo "{}")
    has_next_page=$(echo "$page_info" | jq -r '.hasNextPage // false' 2>/dev/null || echo "false")
    cursor=$(echo "$page_info" | jq -r '.endCursor // empty' 2>/dev/null || echo "")
    
    if [ "$has_next_page" != "true" ] || [ -z "$cursor" ]; then
      has_next_page="false"
    fi
  done
  
  echo "$all_nodes"
}

# ============================================================================
# Thread Resolution (self-contained, no pr-review dependency)
# ============================================================================

find_thread_for_comment() {
  local owner="$1"
  local repo="$2"
  local pr_number="$3"
  local comment_id="$4"
  
  local query_template
  query_template=$(get_review_threads_query_template)
  local all_threads
  all_threads=$(fetch_graphql_paginated "$query_template" "$owner" "$repo" "$pr_number" 100)
  
  if [ -z "$all_threads" ] || [ "$all_threads" = "[]" ]; then
    echo ""
    return 1
  fi
  
  # Find thread containing this comment
  echo "$all_threads" | jq -r --arg cid "$comment_id" '
    .[] | select(.comments.nodes | map(.databaseId | tostring) | index($cid)) | .id
  ' 2>/dev/null | head -1
}

resolve_thread() {
  local thread_id="$1"
  if [ -z "$thread_id" ]; then
    log_error "Thread ID required"
    return 1
  fi
  
  local mutation='mutation($threadId: ID!) { resolveReviewThread(input: {threadId: $threadId}) { thread { id isResolved } } }'
  local response
  response=$(gh api graphql -f query="$mutation" -f threadId="$thread_id" 2>/dev/null || echo "")
  
  if [ -z "$response" ]; then
    log_error "Failed to resolve thread: $thread_id"
    return 1
  fi
  
  local is_resolved
  is_resolved=$(echo "$response" | jq -r '.data.resolveReviewThread.thread.isResolved // false' 2>/dev/null)
  
  if [ "$is_resolved" = "true" ]; then
    return 0
  else
    log_error "Thread not resolved: $thread_id"
    return 1
  fi
}

add_reply_comment() {
  local owner="$1"
  local repo="$2"
  local pr_number="$3"
  local comment_id="$4"
  local body="$5"
  
  local api_endpoint="repos/${owner}/${repo}/pulls/${pr_number}/comments/${comment_id}/replies"
  local response
  response=$(gh api "$api_endpoint" -X POST -f body="$body" 2>/dev/null || echo "")
  
  if [ -z "$response" ]; then
    log_warning "Failed to add reply comment"
    return 1
  fi
  
  # Check for error
  if echo "$response" | jq -e '.message' > /dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null)
    log_warning "Failed to add reply: $error_msg"
    return 1
  fi
  
  return 0
}

# ============================================================================
# Comment Categorization
# ============================================================================

normalize_comment_for_category() {
  local body="$1"
  printf "%s" "$body" | \
    sed -E '/<details>/,/<\/details>/d' | \
    sed -E '/```/,/```/d' | \
    sed -E '/<!--/,/-->/d'
}
export -f normalize_comment_for_category

extract_comment_summary() {
  local body="$1"
  printf "%s" "$body" | awk '
    {
      line=$0
      sub(/\r$/, "", line)
      if (line ~ /^[[:space:]]*$/) next
      gsub(/^[[:space:]]+/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      lower=tolower(line)
      if (lower ~ /^_.*(nitpick|trivial|minor|medium|low|high|potential issue).*_.*$/) next
      if (lower ~ /^_.*_ *\| *_.*_$/) next
      print line
      exit
    }
  '
}
export -f extract_comment_summary

categorize_comment_text() {
  local text="$1"
  if [[ "$text" =~ (security|vulnerability|injection|xss|csrf|auth[^o]|secret|credential|password) ]]; then
    echo "security"
    return 0
  fi
  if [[ "$text" =~ (bug|error|fail|incorrect|broken|crash|exception|undefined|null[[:space:]]|missing) ]]; then
    echo "issue"
    return 0
  fi
  if [[ "$text" =~ (performance|slow|optimize|memory[[:space:]]leak|bottleneck|inefficient) ]]; then
    echo "performance"
    return 0
  fi
  if [[ "$text" =~ (^|[^[:alnum:]_])(import|export|require|module|modules)([^[:alnum:]_]|$) ]]; then
    echo "import-fix"
    return 0
  fi
  if [[ "$text" =~ (markdown|md0[0-9]+|fenced|code[[:space:]]*block|heading[[:space:]]syntax) ]]; then
    echo "markdown-lint"
    return 0
  fi
  if [[ "$text" =~ (type[[:space:]]error|typescript|type[[:space:]]safety|any[[:space:]]type|type[[:space:]]annotation) ]]; then
    echo "type-fix"
    return 0
  fi
  if [[ "$text" =~ ((^|[^[:alnum:]_])doc([[:space:]]*link)?([^[:alnum:]_]|$)|documentation|readme|jsdoc|comment) ]]; then
    echo "doc-fix"
    return 0
  fi
  if [[ "$text" =~ (consider|should|might|could|suggest|recommend|prefer|better|best[[:space:]]practice|convention|style|redundant|simplif|refactor|clean[[:space:]]up|optional|nitpick|phony|portability|portable) ]]; then
    echo "suggestion"
    return 0
  fi
  echo ""
}

is_reply_comment() {
  local body="$1"
  local body_lower
  body_lower=$(printf "%s" "$body" | tr '[:upper:]' '[:lower:]')
  
  if [[ "$body" =~ ^Dismissed[[:space:]]*[:\(\-] ]]; then
    return 0
  fi
  if [[ "$body_lower" =~ ^(done|fixed|addressed|resolved|will[[:space:]]fix) ]]; then
    return 0
  fi
  if [[ "$body_lower" =~ ^(wont[[:space:]]fix|won.t[[:space:]]fix) ]]; then
    return 0
  fi
  if [[ "$body" =~ ^@[A-Za-z0-9_-]+,?[[:space:]]+(Understood|Thanks|Thank|Got|Acknowledged) ]]; then
    return 0
  fi
  if [[ "$body_lower" =~ ^(acknowledged|thanks|thank[[:space:]]you|understood|got[[:space:]]it) ]]; then
    return 0
  fi
  return 1
}
export -f is_reply_comment

categorize_comment_body() {
  local body="$1"
  local body_lower cleaned summary summary_lower cleaned_lower category
  
  body_lower=$(printf "%s" "$body" | tr '[:upper:]' '[:lower:]')
  
  # CodeRabbit emoji header detection (before text analysis)
  if [[ "$body_lower" =~ potential[[:space:]]issue ]] || [[ "$body_lower" =~ ⚠️ ]]; then
    echo "issue"
    return 0
  fi
  if [[ "$body_lower" =~ refactor[[:space:]]suggestion ]] || [[ "$body_lower" =~ 🛠️ ]]; then
    echo "suggestion"
    return 0
  fi
  if [[ "$body_lower" =~ nitpick ]] || [[ "$body_lower" =~ 🧹 ]]; then
    echo "suggestion"
    return 0
  fi
  if [[ "$body_lower" =~ 🔴[[:space:]]critical ]] || [[ "$body_lower" =~ critical ]]; then
    echo "issue"
    return 0
  fi
  
  cleaned=$(normalize_comment_for_category "$body")
  summary=$(extract_comment_summary "$cleaned")
  if [ -z "$summary" ]; then
    summary="$cleaned"
  fi
  summary_lower=$(printf "%s" "$summary" | tr '[:upper:]' '[:lower:]')
  cleaned_lower=$(printf "%s" "$cleaned" | tr '[:upper:]' '[:lower:]')

  category=$(categorize_comment_text "$summary_lower")
  if [ -n "$category" ]; then
    echo "$category"
    return 0
  fi

  category=$(categorize_comment_text "$cleaned_lower")
  if [ -n "$category" ]; then
    echo "$category"
    return 0
  fi

  echo "uncategorized"
}
export -f categorize_comment_body

extract_severity() {
  local body_lower
  body_lower=$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')
  
  if echo "$body_lower" | grep -qE '!\[(high)\]'; then
    echo "high"
  elif echo "$body_lower" | grep -qE '!\[(medium)\]'; then
    echo "medium"
  elif echo "$body_lower" | grep -qE '!\[(low)\]'; then
    echo "low"
  else
    echo ""
  fi
}
export -f extract_severity

extract_backticked_identifiers() {
  local body="$1"
  local matches
  matches=$(printf "%s" "$body" | grep -oE '\`[^`\n]+\`' 2>/dev/null | sed -E 's/^`//; s/`$//')
  if [ -z "$matches" ]; then
    echo ""
    return 0
  fi
  printf "%s" "$matches" | tr '\n' ',' | sed -E 's/,+$//'
}
export -f extract_backticked_identifiers

# ============================================================================
# Semantic Duplicate Detection (Sørensen-Dice Coefficient)
# ============================================================================

# Normalize comment body for comparison
# Removes bot prefixes, badges, markdown, filler words
normalize_comment_for_comparison() {
  local body="$1"
  printf "%s" "$body" | \
    tr '[:upper:]' '[:lower:]' | \
    sed -E 's/!\[(high|medium|low)\]//g' | \
    sed -E 's/\*\*[^*]+\*\*//g' | \
    sed -E 's/`([^`]+)`/\1/g' | \
    sed -E 's/(consider|should|please|i suggest|you might|could you)//gi' | \
    tr -d '[:punct:]' | \
    tr -s '[:space:]' ' ' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
export -f normalize_comment_for_comparison

# Generate character bigrams from string
# Usage: get_bigrams "hello" -> "he el ll lo"
get_bigrams() {
  local str="$1"
  local len=${#str}
  local bigrams=""
  
  for ((i=0; i<len-1; i++)); do
    bigrams="${bigrams}${str:i:2}"$'\n'
  done
  
  printf "%s" "$bigrams" | sort -u | grep -v '^$'
}
export -f get_bigrams

# Calculate Sørensen-Dice coefficient between two strings
# Returns: coefficient as decimal (0.00 - 1.00)
dice_coefficient() {
  local s1="$1"
  local s2="$2"
  
  # Normalize both strings
  s1=$(normalize_comment_for_comparison "$s1")
  s2=$(normalize_comment_for_comparison "$s2")
  
  # Handle edge cases
  if [ -z "$s1" ] || [ -z "$s2" ]; then
    echo "0.00"
    return 0
  fi
  
  if [ "$s1" = "$s2" ]; then
    echo "1.00"
    return 0
  fi
  
  # Get bigrams
  local bigrams1 bigrams2
  bigrams1=$(get_bigrams "$s1")
  bigrams2=$(get_bigrams "$s2")
  
  local count1 count2 intersection
  count1=$(printf "%s" "$bigrams1" | grep -c '^' || echo "0")
  count2=$(printf "%s" "$bigrams2" | grep -c '^' || echo "0")
  
  # Count intersection using process substitution
  intersection=$(comm -12 <(printf "%s" "$bigrams1" | sort) <(printf "%s" "$bigrams2" | sort) | grep -c '^' || echo "0")
  
  # Calculate Dice coefficient: 2 * |intersection| / (|A| + |B|)
  if [ "$((count1 + count2))" -eq 0 ]; then
    echo "0.00"
  else
    # Use awk for floating point math (more portable than bc)
    awk -v i="$intersection" -v c1="$count1" -v c2="$count2" 'BEGIN { printf "%.2f", (2 * i) / (c1 + c2) }'
  fi
}
export -f dice_coefficient

# Get length-aware similarity threshold
# Shorter strings need higher threshold (more random overlap risk)
get_dice_threshold() {
  local len=$1
  if [ "$len" -lt 20 ]; then
    echo "${DICE_THRESHOLD_SHORT:-0.90}"
  elif [ "$len" -lt 100 ]; then
    echo "${DICE_THRESHOLD_MEDIUM:-0.85}"
  else
    echo "${DICE_THRESHOLD_LONG:-0.80}"
  fi
}
export -f get_dice_threshold

# Check if a comment is a semantic duplicate of any in the cache
# Usage: check_semantic_duplicate "comment body" "cache_file"
# Returns: "DUPLICATE:similarity:original_id" or "UNIQUE"
check_semantic_duplicate() {
  local new_body="$1"
  local cache_file="$2"
  
  [ ! -f "$cache_file" ] && { echo "UNIQUE"; return 0; }
  
  local normalized
  normalized=$(normalize_comment_for_comparison "$new_body")
  local len=${#normalized}
  local threshold
  threshold=$(get_dice_threshold "$len")
  
  while IFS=$'\t' read -r cached_id cached_body; do
    [ -z "$cached_id" ] && continue
    
    local similarity
    similarity=$(dice_coefficient "$new_body" "$cached_body")
    
    # Compare using awk (portable float comparison)
    if awk -v sim="$similarity" -v thresh="$threshold" 'BEGIN { exit !(sim >= thresh) }'; then
      echo "DUPLICATE:${similarity}:${cached_id}"
      return 0
    fi
  done < "$cache_file"
  
  echo "UNIQUE"
  return 0
}
export -f check_semantic_duplicate

# Add comment to semantic cache
# Usage: add_to_semantic_cache "comment_id" "comment_body" "cache_file"
add_to_semantic_cache() {
  local comment_id="$1"
  local body="$2"
  local cache_file="$3"
  
  printf "%s\t%s\n" "$comment_id" "$body" >> "$cache_file"
}
export -f add_to_semantic_cache
