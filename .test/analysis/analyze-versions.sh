#!/usr/bin/env bash
# analyze-versions.sh - Version adoption and upgrade tracking
# Usage: analyze-versions.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - Version distribution per skill
#   - Version adoption over time
#   - Skills without version tracking

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

echo "=== Version Analysis ==="
echo "File: $INPUT_FILE"
echo ""

# Events with version vs without
WITH_VERSION=$(echo "$DATA" | jq -r 'select(.version != null and .version != "") | .skill' | wc -l | tr -d ' ')
WITHOUT_VERSION=$(echo "$DATA" | jq -r 'select(.version == null or .version == "") | .skill' | wc -l | tr -d ' ')
echo "Events with version:    $WITH_VERSION"
echo "Events without version: $WITHOUT_VERSION"
if [[ "$TOTAL_EVENTS" -gt 0 ]]; then
  VERSION_PCT=$(awk "BEGIN {printf \"%.1f\", ($WITH_VERSION / $TOTAL_EVENTS) * 100}")
  echo "Version tracking rate:  ${VERSION_PCT}%"
fi
echo ""

# Version distribution per skill
echo "--- Version Distribution by Skill ---"
echo "$DATA" | jq -rs '
  group_by(.skill) 
  | map({
      skill: .[0].skill, 
      versions: (group_by(.version) | map({version: (.[0].version // "null"), count: length}))
    }) 
  | sort_by(.skill)
  | .[] 
  | "\(.skill):\n" + (.versions | map("    v\(.version): \(.count)") | join("\n"))
' 2>/dev/null || {
  # Fallback
  echo "$DATA" | jq -r '"\(.skill)|\(.version // "null")"' | sort | uniq -c | while read -r count pair; do
    skill="${pair%|*}"
    version="${pair#*|}"
    printf "  %-20s v%-8s %5d\n" "$skill" "$version" "$count"
  done
}
echo ""

# Skills missing version tracking
echo "--- Skills Missing Version Data ---"
MISSING=$(echo "$DATA" | jq -r 'select(.version == null or .version == "") | .skill' | sort -u)
if [[ -n "$MISSING" ]]; then
  echo "$MISSING" | while read -r skill; do
    count=$(echo "$DATA" | jq -r --arg s "$skill" 'select(.skill == $s and (.version == null or .version == "")) | .skill' | wc -l | tr -d ' ')
    printf "  %-25s %5d events without version\n" "$skill" "$count"
  done
else
  echo "  All skills have version data!"
fi
echo ""

# Version changes over time (for upgrades)
echo "--- Version Adoption Timeline ---"
echo "$DATA" | jq -rs '
  sort_by(.timestamp)
  | group_by(.skill)
  | map({
      skill: .[0].skill,
      timeline: (
        group_by(.version)
        | map({
            version: .[0].version,
            first_seen: (sort_by(.timestamp) | .[0].timestamp | split("T")[0])
          })
        | sort_by(.first_seen)
      )
    })
  | .[]
  | select(.timeline | length > 1)
  | "\(.skill): " + (.timeline | map("v\(.version) (\(.first_seen))") | join(" -> "))
' 2>/dev/null || {
  echo "  (requires jq with -rs support for timeline analysis)"
}
