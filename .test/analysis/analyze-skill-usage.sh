#!/usr/bin/env bash
# analyze-skill-usage.sh - Core skill usage statistics
# Usage: analyze-skill-usage.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - Total events
#   - Unique skills used
#   - Skill usage counts (descending)
#   - Skill usage percentages
#   - Load vs script execution ratio

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

# Read file once and cache
DATA=$(cat "$INPUT_FILE")
TOTAL=$(echo "$DATA" | wc -l | tr -d ' ')

if [[ "$TOTAL" -eq 0 ]]; then
  echo "No events found in $INPUT_FILE"
  exit 0
fi

echo "=== Skill Usage Analysis ==="
echo "File: $INPUT_FILE"
echo "Total events: $TOTAL"
echo ""

# Unique skills
UNIQUE_SKILLS=$(echo "$DATA" | jq -r '.skill' | sort -u | wc -l | tr -d ' ')
echo "Unique skills: $UNIQUE_SKILLS"
echo ""

# Skill usage counts (descending)
echo "--- Skill Usage Counts ---"
echo "$DATA" | jq -r '.skill' | sort | uniq -c | sort -rn | while read -r count skill; do
  pct=$(awk "BEGIN {printf \"%.1f\", ($count / $TOTAL) * 100}")
  printf "  %-25s %5d (%5s%%)\n" "$skill" "$count" "$pct"
done
echo ""

# Load vs script execution breakdown
echo "--- Event Type Breakdown ---"
LOADS=$(echo "$DATA" | jq -r 'select(.event == "load") | .skill' | wc -l | tr -d ' ')
SCRIPTS=$(echo "$DATA" | jq -r 'select(.event != "load") | .skill' | wc -l | tr -d ' ')
echo "  Skill loads:       $LOADS"
echo "  Script executions: $SCRIPTS"
if [[ "$LOADS" -gt 0 ]]; then
  RATIO=$(awk "BEGIN {printf \"%.2f\", $SCRIPTS / $LOADS}")
  echo "  Scripts per load:  $RATIO"
fi
echo ""

# Top script executions
echo "--- Top Script Executions ---"
echo "$DATA" | jq -r 'select(.event != "load") | "\(.skill)/\(.event)"' | sort | uniq -c | sort -rn | head -10 | while read -r count script; do
  printf "  %-35s %5d\n" "$script" "$count"
done
