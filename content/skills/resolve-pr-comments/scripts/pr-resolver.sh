#!/bin/bash
# Fetch and cluster PR review comments in one call
# Usage: bash pr-resolver.sh [PR_NUMBER] [--repo owner/repo]
# Output: .ada/data/pr-resolver/pr-{N}/data.json (encapsulated per PR)
#
# Clusters include BOTH resolved and unresolved comments for context.
# Resolved comments are marked with resolved:true so you know what's already done.
#
# Fork/Upstream Support:
#   For PRs from forks to upstream repos, use --repo to specify the upstream:
#   bash pr-resolver.sh 123 --repo upstream-owner/upstream-repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
if [ ! -f "${SCRIPT_DIR}/lib/pr-resolver-utils.sh" ]; then
  echo "Error: pr-resolver-utils.sh not found" >&2
  exit 1
fi
source "${SCRIPT_DIR}/lib/pr-resolver-utils.sh"

# Check prerequisites
if ! check_prerequisites; then
  exit 1
fi

# Parse arguments
PR_NUMBER=""
TARGET_REPO=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        log_error "--repo requires a value (owner/repo)"
        echo "Usage: $0 [PR_NUMBER] [--repo owner/repo]" >&2
        exit 1
      fi
      TARGET_REPO="$2"
      shift 2
      ;;
    -*)
      log_error "Unknown option: $1"
      echo "Usage: $0 [PR_NUMBER] [--repo owner/repo]" >&2
      exit 1
      ;;
    *)
      if [ -z "$PR_NUMBER" ]; then
        PR_NUMBER="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PR_NUMBER" ]; then
  log_info "No PR number provided, detecting..."
  PR_NUMBER=$(detect_pr_number 2>/dev/null || echo "")
  if [ -z "$PR_NUMBER" ]; then
    log_error "Could not detect PR number"
    echo "Usage: $0 <PR_NUMBER> [--repo owner/repo]" >&2
    exit 1
  fi
  log_info "Detected PR: #${PR_NUMBER}"
fi

if ! validate_pr_number "$PR_NUMBER"; then
  log_error "Invalid PR number: $PR_NUMBER"
  exit 1
fi

# Get repository info (uses --repo if provided, else auto-detects with fork support)
OWNER_REPO=$(get_effective_repo "$TARGET_REPO")
if [ -z "$OWNER_REPO" ]; then
  exit 1
fi
read -r OWNER REPO <<< "$(parse_owner_repo "$OWNER_REPO")"

# Determine if we should show --repo in examples
# Show when: explicit --repo provided, OR get_effective_repo detected upstream (fork)
SHOW_REPO_FLAG=false
if [ -n "$TARGET_REPO" ]; then
  SHOW_REPO_FLAG=true
else
  # Check if OWNER_REPO differs from origin (means upstream was used)
  ORIGIN_REPO=$(get_repo_owner_repo 2>/dev/null || echo "")
  if [ -n "$ORIGIN_REPO" ] && [ "${OWNER_REPO,,}" != "${ORIGIN_REPO,,}" ]; then
    SHOW_REPO_FLAG=true
  fi
fi

# Ensure data directory exists
ensure_pr_resolver_dir

PR_DIR=$(get_pr_dir "$PR_NUMBER")
mkdir -p "$PR_DIR"
OUTPUT_FILE=$(get_pr_data_path "$PR_NUMBER")

# ============================================================================
# PHASE 1: Fetch comments from GitHub
# ============================================================================

log_info "Fetching review comments for PR #${PR_NUMBER}..."

fetch_review_comments() {
  local response
  
  # Use gh api with pagination, fix malformed JSON from GitHub API
  # gh api --paginate concatenates arrays, so we use jq -s 'add' to merge them
  response=$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments?per_page=100" \
    --paginate 2>/dev/null | fix_json_newlines | jq -s 'add // []' 2>/dev/null)
  
  if [ -z "$response" ] || [ "$response" = "null" ]; then
    log_error "Failed to fetch comments"
    echo "[]"
    return 1
  fi
  
  response=$(printf '%s' "$response" | sanitize_json)
  
  if ! printf '%s' "$response" | jq -e '.' >/dev/null 2>&1; then
    log_error "Invalid JSON response after sanitization"
    echo "[]"
    return 1
  fi
  
  normalize_json_array "$response"
}

# Fetch thread resolution status via GraphQL
fetch_resolved_map() {
  local query_template all_threads
  query_template=$(get_review_threads_query_template)
  all_threads=$(fetch_graphql_paginated "$query_template" "$OWNER" "$REPO" "$PR_NUMBER" 100 \
    ".data.repository.pullRequest.reviewThreads.pageInfo" \
    ".data.repository.pullRequest.reviewThreads.nodes")
  
  if [ -z "$all_threads" ] || [ "$all_threads" = "[]" ] || [ "$all_threads" = "null" ]; then
    echo "{}"
    return 0
  fi
  
  # Build map: comment_id -> {resolved, thread_id}
  echo "$all_threads" | jq -c 'reduce .[] as $thread ({};
    . + reduce $thread.comments.nodes[] as $comment ({};
      .[$comment.databaseId | tostring] = {
        resolved: $thread.isResolved,
        thread_id: $thread.id
      }
    )
  )' 2>/dev/null || echo "{}"
}

REVIEW_COMMENTS=$(fetch_review_comments)
log_info "Fetching thread resolution status..."
RESOLVED_MAP=$(fetch_resolved_map)

if [ -z "$REVIEW_COMMENTS" ] || [ "$REVIEW_COMMENTS" = "null" ]; then
  log_error "No review comments fetched"
  exit 1
fi

# Merge resolution status into comments
REVIEW_COMMENTS_WITH_STATUS=$(echo "$REVIEW_COMMENTS" | jq -c --argjson resolved_map "$RESOLVED_MAP" '
  map(. + {
    resolved: ($resolved_map[(.id | tostring)].resolved // false),
    thread_id: ($resolved_map[(.id | tostring)].thread_id // null)
  })
')

# ============================================================================
# PHASE 2: Categorize and cluster ALL comments (mark resolved ones)
# ============================================================================

log_info "Categorizing and clustering comments..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

UNIQUE_FILE="$TMP_DIR/unique.jsonl"
DUPLICATES_FILE="$TMP_DIR/duplicates.jsonl"
IDENTITY_MAP="$TMP_DIR/identity.txt"
CODE_MAP="$TMP_DIR/code.txt"

: > "$UNIQUE_FILE"
: > "$DUPLICATES_FILE"
: > "$IDENTITY_MAP"
: > "$CODE_MAP"

CATEGORY_CACHE="$TMP_DIR/category_cache.txt"
: > "$CATEGORY_CACHE"

TOTAL_COMMENTS=$(echo "$REVIEW_COMMENTS_WITH_STATUS" | jq 'length')
TOTAL_RESOLVED=$(echo "$REVIEW_COMMENTS_WITH_STATUS" | jq '[.[] | select(.resolved == true)] | length')
TOTAL_UNRESOLVED=$(echo "$REVIEW_COMMENTS_WITH_STATUS" | jq '[.[] | select(.resolved == false)] | length')

# Process ALL comments (both resolved and unresolved) for full context
# Use ASCII unit separator (0x1F) as field delimiter
DELIM=$'\x1f'
echo "$REVIEW_COMMENTS_WITH_STATUS" | jq -r --arg d "$DELIM" '.[] | [
  (.id // ""),
  (.path // "unknown"),
  (.line // .original_line // ""),
  (.user.login // "unknown"),
  (.html_url // .url // ""),
  (.thread_id // ""),
  (.resolved // false),
  (.in_reply_to_id // ""),
  (.body // "" | @base64)
] | join($d)' | while IFS="$DELIM" read -r COMMENT_ID FILE_PATH LINE_NUMBER AUTHOR COMMENT_URL THREAD_ID RESOLVED IN_REPLY_TO BODY_ESCAPED; do
  [ -z "$COMMENT_ID" ] && continue

  # Decode base64-encoded body (safe for all Unicode content including newlines)
  BODY=$(printf '%s' "$BODY_ESCAPED" | base64 --decode 2>/dev/null || echo "$BODY_ESCAPED")

  CATEGORY=""
  if [ -n "$IN_REPLY_TO" ] && [ "$IN_REPLY_TO" != "null" ] && is_reply_comment "$BODY"; then
    CATEGORY=$(awk -F '\t' -v id="$IN_REPLY_TO" '$1==id {print $2; exit}' "$CATEGORY_CACHE")
  fi
  if [ -z "$CATEGORY" ]; then
    CATEGORY=$(categorize_comment_body "$BODY")
  fi
  printf "%s\t%s\n" "$COMMENT_ID" "$CATEGORY" >> "$CATEGORY_CACHE"
  
  SEVERITY=$(extract_severity "$BODY")
  
  # Only deduplicate unresolved comments (resolved ones are kept for context)
  if [ "$RESOLVED" = "false" ]; then
    # Identity dedup: same file + line + author
    IDENTITY_KEY="${FILE_PATH}|${LINE_NUMBER}|${AUTHOR}"
    DUPLICATE_OF=$(awk -F '\t' -v key="$IDENTITY_KEY" '$1==key {print $2; exit}' "$IDENTITY_MAP")
    if [ -n "$DUPLICATE_OF" ]; then
      jq -n --arg cid "$COMMENT_ID" --arg dup "$DUPLICATE_OF" --arg reason "identity" \
        '{comment_id: $cid, duplicate_of: $dup, reason: $reason}' >> "$DUPLICATES_FILE"
      continue
    fi
    printf "%s\t%s\n" "$IDENTITY_KEY" "$COMMENT_ID" >> "$IDENTITY_MAP"
    
    # Code fragment dedup: same backticked identifiers
    CODE_IDENTIFIERS=$(extract_backticked_identifiers "$BODY")
    if [ -n "$CODE_IDENTIFIERS" ]; then
      CODE_KEY="${FILE_PATH}|${LINE_NUMBER}|${CODE_IDENTIFIERS}"
      DUPLICATE_OF=$(awk -F '\t' -v key="$CODE_KEY" '$1==key {print $2; exit}' "$CODE_MAP")
      if [ -n "$DUPLICATE_OF" ]; then
        jq -n --arg cid "$COMMENT_ID" --arg dup "$DUPLICATE_OF" --arg reason "code-fragment" \
          '{comment_id: $cid, duplicate_of: $dup, reason: $reason}' >> "$DUPLICATES_FILE"
        continue
      fi
      printf "%s\t%s\n" "$CODE_KEY" "$COMMENT_ID" >> "$CODE_MAP"
    fi
    
    # Layer 3: Semantic dedup using Sørensen-Dice coefficient
    SEMANTIC_CACHE="$TMP_DIR/semantic.tsv"
    SEMANTIC_RESULT=$(check_semantic_duplicate "$BODY" "$SEMANTIC_CACHE")
    if [[ "$SEMANTIC_RESULT" == DUPLICATE:* ]]; then
      SIMILARITY=$(echo "$SEMANTIC_RESULT" | cut -d: -f2)
      DUPLICATE_OF=$(echo "$SEMANTIC_RESULT" | cut -d: -f3)
      jq -n --arg cid "$COMMENT_ID" --arg dup "$DUPLICATE_OF" --arg reason "semantic" --arg sim "$SIMILARITY" \
        '{comment_id: $cid, duplicate_of: $dup, reason: $reason, similarity: $sim}' >> "$DUPLICATES_FILE"
      continue
    fi
    add_to_semantic_cache "$COMMENT_ID" "$BODY" "$SEMANTIC_CACHE"
  fi
  
  CLUSTER_KEY="${FILE_PATH}|${CATEGORY}"
  jq -n \
    --arg id "$COMMENT_ID" \
    --arg path "$FILE_PATH" \
    --arg line "$LINE_NUMBER" \
    --arg author "$AUTHOR" \
    --arg body "$BODY" \
    --arg category "$CATEGORY" \
    --arg severity "$SEVERITY" \
    --arg url "$COMMENT_URL" \
    --arg thread_id "$THREAD_ID" \
    --argjson resolved "$RESOLVED" \
    --arg cluster_key "$CLUSTER_KEY" \
    '{
      id: $id,
      path: $path,
      line: (if $line == "" or $line == "null" then null else ($line | tonumber) end),
      author: $author,
      body: $body,
      category: $category,
      severity: $severity,
      url: $url,
      thread_id: (if $thread_id == "" then null else $thread_id end),
      resolved: $resolved,
      cluster_key: $cluster_key
    }' >> "$UNIQUE_FILE"
done

# Build arrays
if [ -s "$UNIQUE_FILE" ]; then
  UNIQUE_ARRAY=$(jq -s '.' "$UNIQUE_FILE")
else
  UNIQUE_ARRAY="[]"
fi

if [ -s "$DUPLICATES_FILE" ]; then
  DUPLICATES_ARRAY=$(jq -s '.' "$DUPLICATES_FILE")
else
  DUPLICATES_ARRAY="[]"
fi

# Cluster ALL comments, with resolved/unresolved counts per cluster
CLUSTERS_JSON=$(echo "$UNIQUE_ARRAY" | jq -c '
  def slugify($value): $value | gsub("[^A-Za-z0-9]+"; "-") | gsub("(^-|-$)"; "") | ascii_downcase;
  
  if length == 0 then [] else
    sort_by(.cluster_key)
    | group_by(.cluster_key)
    | map(
        . as $group
        | ($group[0].path) as $file
        | ($group[0].category) as $concern
        | ([$group[] | select(.resolved == false)] | length) as $unresolved
        | {
            cluster_id: (slugify($file) + "-" + $concern),
            file: $file,
            concern: $concern,
            comments: ($group | map(del(.cluster_key))),
            total_comments: ($group | length),
            resolved_count: ([$group[] | select(.resolved == true)] | length),
            unresolved_count: $unresolved,
            actionable: ($unresolved > 0)
          }
      )
  end
')

UNIQUE_COUNT=$(echo "$UNIQUE_ARRAY" | jq 'length')
DUPLICATES_COUNT=$(echo "$DUPLICATES_ARRAY" | jq 'length')
CLUSTERS_COUNT=$(echo "$CLUSTERS_JSON" | jq 'length')
ACTIONABLE_CLUSTERS=$(echo "$CLUSTERS_JSON" | jq '[.[] | select(.actionable == true)] | length')

# ============================================================================
# PHASE 3: Write unified output files
# ============================================================================

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
ACTIONABLE_OUTPUT_FILE="${PR_DIR}/actionable.json"
CLUSTERS_JSON_FILE="$TMP_DIR/clusters.json"
DUPLICATES_JSON_FILE="$TMP_DIR/duplicates.json"
ACTIONABLE_CLUSTERS_FILE="$TMP_DIR/actionable_clusters.json"

printf '%s\n' "$CLUSTERS_JSON" > "$CLUSTERS_JSON_FILE"
printf '%s\n' "$DUPLICATES_ARRAY" > "$DUPLICATES_JSON_FILE"

# Full data.json (all clusters, for historical context)
jq -n \
  --arg generated_at "$GENERATED_AT" \
  --argjson pr_number "$PR_NUMBER" \
  --arg repository "${OWNER}/${REPO}" \
  --slurpfile clusters "$CLUSTERS_JSON_FILE" \
  --slurpfile duplicates "$DUPLICATES_JSON_FILE" \
  --argjson total_comments "$TOTAL_COMMENTS" \
  --argjson resolved_comments "$TOTAL_RESOLVED" \
  --argjson unresolved_comments "$TOTAL_UNRESOLVED" \
  --argjson unique_comments "$UNIQUE_COUNT" \
  --argjson duplicates_detected "$DUPLICATES_COUNT" \
  --argjson clusters_created "$CLUSTERS_COUNT" \
  --argjson actionable_clusters "$ACTIONABLE_CLUSTERS" \
  '{
    pr_number: $pr_number,
    repository: $repository,
    generated_at: $generated_at,
    statistics: {
      total_comments: $total_comments,
      resolved_comments: $resolved_comments,
      unresolved_comments: $unresolved_comments,
      unique_in_clusters: $unique_comments,
      duplicates_detected: $duplicates_detected,
      clusters_created: $clusters_created,
      actionable_clusters: $actionable_clusters
    },
    clusters: $clusters[0],
    duplicates: $duplicates[0],
    results: []
  }' > "$OUTPUT_FILE"

log_success "PR #${PR_NUMBER} data saved to $OUTPUT_FILE"

# Actionable-only output (token-efficient for orchestrator)
# Contains only clusters with unresolved_count > 0
# Includes resolved comments within those clusters for context
jq '[.[] | select(.actionable == true)]' "$CLUSTERS_JSON_FILE" > "$ACTIONABLE_CLUSTERS_FILE"

jq -n \
  --arg generated_at "$GENERATED_AT" \
  --argjson pr_number "$PR_NUMBER" \
  --arg repository "${OWNER}/${REPO}" \
  --slurpfile clusters "$ACTIONABLE_CLUSTERS_FILE" \
  --argjson total_comments "$TOTAL_COMMENTS" \
  --argjson resolved_comments "$TOTAL_RESOLVED" \
  --argjson unresolved_comments "$TOTAL_UNRESOLVED" \
  --argjson actionable_clusters "$ACTIONABLE_CLUSTERS" \
  '{
    pr_number: $pr_number,
    repository: $repository,
    generated_at: $generated_at,
    note: "Token-efficient output: only actionable clusters (unresolved_count > 0). Use data.json for full historical context.",
    statistics: {
      total_comments: $total_comments,
      resolved_comments: $resolved_comments,
      unresolved_comments: $unresolved_comments,
      actionable_clusters: $actionable_clusters
    },
    clusters: $clusters[0]
  }' > "$ACTIONABLE_OUTPUT_FILE"

log_success "Actionable-only data saved to $ACTIONABLE_OUTPUT_FILE"

# ============================================================================
# PHASE 4: Generate cluster .md files for subagent consumption
# ============================================================================

CLUSTERS_DIR="${PR_DIR}/clusters"
mkdir -p "$CLUSTERS_DIR"

generate_cluster_markdown() {
  local cluster_json="$1"
  local output_file="$2"
  
  local cluster_id file concern total resolved unresolved actionable
  cluster_id=$(echo "$cluster_json" | jq -r '.cluster_id')
  file=$(echo "$cluster_json" | jq -r '.file')
  concern=$(echo "$cluster_json" | jq -r '.concern')
  total=$(echo "$cluster_json" | jq -r '.total_comments')
  resolved=$(echo "$cluster_json" | jq -r '.resolved_count')
  unresolved=$(echo "$cluster_json" | jq -r '.unresolved_count')
  actionable=$(echo "$cluster_json" | jq -r '.actionable')
  
  {
    echo "# Cluster: ${cluster_id}"
    echo ""
    echo "## Context"
    echo ""
    echo "| Property | Value |"
    echo "|----------|-------|"
    echo "| PR | #${PR_NUMBER} |"
    echo "| Repository | ${OWNER}/${REPO} |"
    echo "| File | \`${file}\` |"
    echo "| Concern | ${concern} |"
    echo "| Status | ${actionable} (${unresolved} unresolved, ${resolved} resolved) |"
    echo ""
    echo "## Comments"
    echo ""
    
    echo "$cluster_json" | jq -r '.comments[] | @base64' | while IFS= read -r encoded; do
      local comment_json id line author body category severity url resolved_status thread_id
      comment_json=$(echo "$encoded" | base64 --decode)
      
      id=$(echo "$comment_json" | jq -r '.id')
      line=$(echo "$comment_json" | jq -r '.line // "N/A"')
      author=$(echo "$comment_json" | jq -r '.author')
      body=$(echo "$comment_json" | jq -r '.body')
      category=$(echo "$comment_json" | jq -r '.category')
      severity=$(echo "$comment_json" | jq -r '.severity // "unknown"')
      url=$(echo "$comment_json" | jq -r '.url')
      resolved_status=$(echo "$comment_json" | jq -r '.resolved')
      thread_id=$(echo "$comment_json" | jq -r '.thread_id // "N/A"')
      
      local status_badge="UNRESOLVED"
      [ "$resolved_status" = "true" ] && status_badge="RESOLVED"
      
      echo "### Comment ${id} [${status_badge}]"
      echo ""
      echo "- **Line**: ${line}"
      echo "- **Author**: ${author}"
      echo "- **Category**: ${category}"
      echo "- **Severity**: ${severity}"
      echo "- **URL**: ${url}"
      echo "- **Thread ID**: ${thread_id}"
      echo ""
      echo "**Body**:"
      echo ""
      echo '```'
      echo "$body"
      echo '```'
      echo ""
      echo "---"
      echo ""
    done
    
    echo "## Completion Requirement"
    echo ""
    echo "**You must process ALL ${unresolved} unresolved comments above before completing.**"
    echo "Do not return until every [UNRESOLVED] comment has been:"
    echo "- Fixed and resolved, OR"
    echo "- Dismissed with evidence, OR"
    echo "- Deferred with documentation"
    echo ""
    
    echo "## Resolution Commands"
    echo ""
    echo "After fixing issues in this cluster:"
    echo ""
    echo '```bash'
    echo "# Resolve a specific comment thread"
    if [ "$SHOW_REPO_FLAG" = "true" ]; then
      echo "bash skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh ${PR_NUMBER} <COMMENT_ID> --repo ${OWNER}/${REPO}"
    else
      echo "bash skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh ${PR_NUMBER} <COMMENT_ID>"
    fi
    echo ""
    echo "# Dismiss as false positive"
    if [ "$SHOW_REPO_FLAG" = "true" ]; then
      echo 'bash skills/resolve-pr-comments/scripts/pr-resolver-dismiss.sh '"${PR_NUMBER}"' <COMMENT_ID> "reason" --repo '"${OWNER}/${REPO}"''
    else
      echo 'bash skills/resolve-pr-comments/scripts/pr-resolver-dismiss.sh '"${PR_NUMBER}"' <COMMENT_ID> "reason"'
    fi
    echo '```'
  } > "$output_file"
}

echo "$CLUSTERS_JSON" | jq -c '.[]' | while IFS= read -r cluster; do
  cluster_id=$(echo "$cluster" | jq -r '.cluster_id')
  md_file="${CLUSTERS_DIR}/${cluster_id}.md"
  generate_cluster_markdown "$cluster" "$md_file"
done

log_success "Generated cluster markdown files in ${CLUSTERS_DIR}/"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo "PR #${PR_NUMBER} - ${OWNER}/${REPO}"
echo "========================================"
echo "Total comments:       ${TOTAL_COMMENTS}"
echo "  - Resolved:         ${TOTAL_RESOLVED}"
echo "  - Unresolved:       ${TOTAL_UNRESOLVED}"
echo "  - Duplicates:       ${DUPLICATES_COUNT}"
echo ""
echo "Clusters:             ${CLUSTERS_COUNT}"
echo "  - With unresolved:  ${ACTIONABLE_CLUSTERS} (actionable)"
echo "  - All resolved:     $((CLUSTERS_COUNT - ACTIONABLE_CLUSTERS)) (for context only)"
echo ""
echo "Output files:"
echo "  - Full data:        ${OUTPUT_FILE}"
echo "  - Actionable only:  ${ACTIONABLE_OUTPUT_FILE}"
echo "  - Cluster files:    ${CLUSTERS_DIR}/"
echo ""

if [ "$ACTIONABLE_CLUSTERS" -eq 0 ]; then
  echo "No actionable clusters. All comments are resolved!"
  echo ""
  echo "Clusters still contain resolved comments for historical context."
else
  echo "Next steps:"
  echo "  1. Read actionable.json for token-efficient orchestration"
  echo "  2. For each actionable cluster, spawn @pr-comment-reviewer with the cluster file:"
  echo "     @pr-comment-reviewer @${CLUSTERS_DIR}/<cluster-id>.md"
  echo ""
  echo "  3. Or process manually:"
  echo "     - Read clusters from: ${OUTPUT_FILE}"
  echo "     - Focus on clusters where actionable=true"
  echo "     - After fixing, resolve threads with:"
  if [ "$SHOW_REPO_FLAG" = "true" ]; then
    echo "       bash skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh ${PR_NUMBER} <COMMENT_ID> --repo ${OWNER}/${REPO}"
  else
    echo "       bash skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh ${PR_NUMBER} <COMMENT_ID>"
  fi
fi
