#!/usr/bin/env bash
# analyze-repos.sh - Repository-level analysis
# Usage: analyze-repos.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - Repository usage counts
#   - Repository skill preferences
#   - Cross-repo skill patterns

set -euo pipefail

INPUT_FILE="${1:-${HOME}/.ada/skill-events.jsonl}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: File not found: $INPUT_FILE" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

DATA=$(cat "$INPUT_FILE")
TOTAL_EVENTS=$(echo "$DATA" | wc -l | tr -d ' ')

if [[ "$TOTAL_EVENTS" -eq 0 ]]; then
  echo "No events found in $INPUT_FILE"
  exit 0
fi

echo "=== Repository Analysis ==="
echo "File: $INPUT_FILE"
echo ""

# Unique repositories
REPOS=$(echo "$DATA" | jq -r '.repo' | sort -u | wc -l | tr -d ' ')
echo "Total repositories: $REPOS"
echo ""

# Repository usage counts
echo "--- Repository Usage Counts ---"
echo "$DATA" | jq -r '.repo' | sort | uniq -c | sort -rn | head -15 | while read -r count repo; do
  pct=$(awk "BEGIN {printf \"%.1f\", ($count / $TOTAL_EVENTS) * 100}")
  printf "  %-30s %5d (%5s%%)\n" "$repo" "$count" "$pct"
done
echo ""

# Skills per repository
echo "--- Top Skills by Repository ---"
echo "$DATA" | jq -rs '
  sort_by(.repo)
  | group_by(.repo)
  | map({
      repo: .[0].repo,
      total: length,
      skills: (sort_by(.skill) | group_by(.skill) | map({skill: .[0].skill, count: length}) | sort_by(-.count) | .[0:3])
    })
  | sort_by(-.total)
  | .[0:10]
  | .[]
  | "\(.repo) (\(.total) events):\n" + (.skills | map("    \(.skill): \(.count)") | join("\n"))
' 2>/dev/null || {
  # Fallback for older jq
  for repo in $(echo "$DATA" | jq -r '.repo' | sort -u | head -10); do
    count=$(echo "$DATA" | jq -r --arg r "$repo" 'select(.repo == $r) | .skill' | wc -l | tr -d ' ')
    echo "$repo ($count events):"
    echo "$DATA" | jq -r --arg r "$repo" 'select(.repo == $r) | .skill' | sort | uniq -c | sort -rn | head -3 | while read -r c s; do
      printf "    %s: %d\n" "$s" "$c"
    done
  done
}
echo ""

# Repository diversity: how many different skills each repo uses
echo "--- Repository Skill Diversity ---"
echo "$DATA" | jq -r '[.repo, .skill] | @tsv' | sort | uniq | cut -f1 | uniq -c | sort -rn | head -10 | while read -r count repo; do
  printf "  %-30s %2d unique skills\n" "$repo" "$count"
done
echo ""

# Cross-repository patterns: skills used across many repos
echo "--- Skills Used Across Most Repositories ---"
echo "$DATA" | jq -r '[.repo, .skill] | @tsv' | sort | uniq | cut -f2 | sort | uniq -c | sort -rn | while read -r count skill; do
  pct=$(awk "BEGIN {printf \"%.1f\", ($count / $REPOS) * 100}")
  printf "  %-25s %3d repos (%5s%%)\n" "$skill" "$count" "$pct"
done
