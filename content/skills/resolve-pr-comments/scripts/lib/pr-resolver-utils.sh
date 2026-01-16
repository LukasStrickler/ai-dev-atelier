#!/bin/bash
# Shared utility functions for PR comment resolver scripts
# Self-contained - does NOT depend on pr-review skill
# Source this file, do not execute directly

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

PR_RESOLVER_DATA_DIR="${PR_RESOLVER_DATA_DIR:-.ada/data/pr-resolver}"
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

retry_with_backoff() {
  local max_attempts="$1"
  local initial_delay="$2"
  shift 2
  local command=("$@")
  local attempt=1
  local delay="$initial_delay"

  while [ "$attempt" -le "$max_attempts" ]; do
    if "${command[@]}"; then
      return 0
    fi

    if [ "$attempt" -lt "$max_attempts" ]; then
      log_warning "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
      [ "$delay" -gt 30 ] && delay=30
    fi

    attempt=$((attempt + 1))
  done

  log_error "Failed after $max_attempts attempts"
  return 1
}

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
  if ! command -v python3 &> /dev/null; then
    log_error "python3 not found. Install: https://www.python.org/downloads/"
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

# WARNING: Callers MUST validate returned PR number against workspace state
# before performing destructive operations to prevent acting on wrong PR.

get_repo_owner_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -z "$remote_url" ]; then
    log_error "No git remote 'origin' found"
    return 1
  fi
  local owner_repo
  owner_repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]([^/]+)/([^/]+)(\.git)?$|\1/\2|' | sed 's/\.git$//')
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

# Detect if current repo (from origin) is a fork and get upstream/parent repo
# Returns: parent owner/repo if fork, empty otherwise
get_upstream_repo() {
  local repo_info
  repo_info=$(gh repo view --json isFork,parent --jq 'if .isFork then .parent.nameWithOwner else "" end' 2>/dev/null) || return 1
  
  if [[ -n "$repo_info" && "$repo_info" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "${repo_info,,}"
    return 0
  fi
  return 1
}

# Get effective repo for PR operations
# If --repo arg provided, use it. If fork detected, use upstream. Otherwise use origin.
# Args: $1 = optional explicit repo override
get_effective_repo() {
  local explicit_repo="${1:-}"
  
  # If explicit repo provided, validate and use it
  if [ -n "$explicit_repo" ]; then
    if [[ ! "$explicit_repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
      log_error "Invalid repo format: $explicit_repo (expected: owner/repo)"
      return 1
    fi
    echo "$explicit_repo"
    return 0
  fi
  
  # Try to detect upstream (fork scenario)
  # Note: || true prevents script crash under set -e when not a fork
  local upstream
  upstream=$(get_upstream_repo 2>/dev/null || true)
  if [ -n "$upstream" ]; then
    log_info "Detected fork - using upstream: $upstream"
    echo "$upstream"
    return 0
  fi
  
  # Fall back to origin
  get_repo_owner_repo
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
    latest_file=$(ls -t "$PR_RESOLVER_DATA_DIR"/*/data.json 2>/dev/null | head -1)
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
      pr_number=$(gh pr list --json number,headRefOid --jq '.[] | select(.headRefOid == "'"$current_sha"'") | .number' 2>/dev/null | head -1)
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

# Sanitize JSON string by removing control characters that break jq parsing
# Preserves: tab (\t, 0x09), newline (\n, 0x0a), carriage return (\r, 0x0d)
# Removes: null (0x00-0x08), vertical tab (0x0b), form feed (0x0c), and 0x0e-0x1f
sanitize_json() {
  tr -d '\000-\010\013\014\016-\037'
}
export -f sanitize_json

# Fix malformed JSON from GitHub API where newlines appear literally inside string values
# GitHub's diff_hunk and body fields often contain raw newlines that should be \n escapes
fix_json_newlines() {
  python3 -c '
import sys
raw = sys.stdin.read()
result = []
in_string = False
escaped = False
for char in raw:
    if escaped:
        result.append(char)
        escaped = False
        continue
    if char == "\\":
        escaped = True
        result.append(char)
        continue
    if char == "\"":
        in_string = not in_string
        result.append(char)
    elif char == "\n":
        result.append("\\n" if in_string else char)
    elif char == "\r":
        result.append("\\r" if in_string else char)
    else:
        result.append(char)
print("".join(result), end="")
' 2>/dev/null || cat
}
export -f fix_json_newlines

normalize_json_array() {
  local json_string="$1"
  if [ -z "$json_string" ] || [ "$json_string" = "null" ]; then
    echo "[]"
    return 0
  fi
  # Sanitize control characters before jq processing (CodeRabbit emojis can include problematic bytes)
  json_string=$(printf '%s' "$json_string" | sanitize_json)
  local json_type
  json_type=$(printf '%s' "$json_string" | jq -r 'type' 2>/dev/null || echo "unknown")
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
  local page_info_path="${6:-.data.repository.pullRequest.reviewThreads.pageInfo}"
  local nodes_path="${7:-.data.repository.pullRequest.reviewThreads.nodes}"
  
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
        2>/dev/null | fix_json_newlines || echo "")
    else
      response=$(gh api graphql \
        -f query="$query_template" \
        -F owner="$owner" \
        -F repo="$repo" \
        -F pr_number="$pr_number" \
        -F page_size="$page_size" \
        -f cursor="$cursor" \
        2>/dev/null | fix_json_newlines || echo "")
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
  # Use perl for true multi-line matching (handles single-line tags)
  printf "%s" "$body" | perl -0777 -pe 's/<details>.*?<\/details>//gs; s/```.*?```//gs; s/<!--.*?-->//gs'
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
  if [[ "$text" =~ (security|vulnerability|injection|xss|csrf|authentication|authorization|authenticate|authorize|authorized|(^|[^[:alnum:]_])auth([^[:alnum:]_]|$)|secret|credential|password) ]]; then
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
  if [[ "$text" =~ (consider|should|might|could|suggest|recommend|prefer|better|best[[:space:]]practice|convention|style|redundant|simplif|refactor|clean[[:space:]]up|optional|nitpick|phony|portability|portable|backtick|wrap[[:space:]].*in|please[[:space:]]wrap|denote|clarity|consistency) ]]; then
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
  
  if echo "$body_lower" | grep -qE '!\[high\]'; then
    echo "high"
  elif echo "$body_lower" | grep -qE '!\[medium\]'; then
    echo "medium"
  elif echo "$body_lower" | grep -qE '!\[low\]'; then
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

# Check if a comment is a semantic duplicate of any in the cache
# Uses single-process awk for O(n) comparison instead of O(n) subprocess spawns
# Returns: "DUPLICATE:similarity:original_id" or "UNIQUE"
check_semantic_duplicate() {
  local new_body="$1"
  local cache_file="$2"
  
  [ ! -f "$cache_file" ] && { echo "UNIQUE"; return 0; }
  [ ! -s "$cache_file" ] && { echo "UNIQUE"; return 0; }
  
  # Escape newlines for awk -v (awk doesn't accept literal newlines in -v values)
  # Use ASCII RS (record separator, octal 036) as placeholder
  local escaped_body
  escaped_body=$(printf '%s' "$new_body" | tr '\n' '\036')
  
  awk -v new_body="$escaped_body" '
  function normalize(s) {
    # Convert octal 036 (RS) placeholder back to spaces to match cache sanitization
    gsub(/\036/, " ", s)
    gsub(/!\[(high|medium|low)\]/, "", s)
    gsub(/\*\*[^*]+\*\*/, "", s)
    gsub(/`[^`]+`/, "", s)
    gsub(/(consider|should|please|i suggest|you might|could you)/i, "", s)
    gsub(/[[:punct:]]/, "", s)
    gsub(/[[:space:]]+/, " ", s)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    return tolower(s)
  }
  
  function get_bigrams(s, bigrams,    i, len, bg) {
    delete bigrams
    len = length(s)
    for (i = 1; i < len; i++) {
      bg = substr(s, i, 2)
      bigrams[bg] = 1
    }
  }
  
  function count_arr(arr,    k, n) {
    n = 0
    for (k in arr) n++
    return n
  }
  
  function dice_with_cache(cached_body,    b2, c1, c2, inter, k, norm_cached) {
    norm_cached = normalize(cached_body)
    if (norm_new == "" || norm_cached == "") return 0.0
    if (norm_new == norm_cached) return 1.0
    
    get_bigrams(norm_cached, b2)
    c1 = count_arr(new_bigrams)
    c2 = count_arr(b2)
    
    inter = 0
    for (k in new_bigrams) if (k in b2) inter++
    
    return (c1 + c2) == 0 ? 0.0 : (2.0 * inter) / (c1 + c2)
  }
  
  BEGIN {
    FS = "\t"
    norm_new = normalize(new_body)
    get_bigrams(norm_new, new_bigrams)
    
    len = length(norm_new)
    if (len < 20) threshold = 0.90
    else if (len < 100) threshold = 0.85
    else threshold = 0.80
    
    found = 0
  }
  
  {
    cached_id = $1
    cached_body = $2
    if (cached_id == "") next
    
    sim = dice_with_cache(cached_body)
    if (sim >= threshold) {
      printf "DUPLICATE:%.2f:%s\n", sim, cached_id
      found = 1
      exit 0
    }
  }
  
  END {
    if (!found) print "UNIQUE"
  }
  ' "$cache_file" 2>/dev/null
}
export -f check_semantic_duplicate

add_to_semantic_cache() {
  local comment_id="$1"
  local body="$2"
  local cache_file="$3"
  
  # Sanitize body: replace tabs/newlines with spaces for TSV compatibility
  local sanitized_body
  sanitized_body=$(printf "%s" "$body" | tr '\t\n' '  ')
  printf "%s\t%s\n" "$comment_id" "$sanitized_body" >> "$cache_file"
}
export -f add_to_semantic_cache
