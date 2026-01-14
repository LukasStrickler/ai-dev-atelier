#!/usr/bin/env bash
# analyze-trends.sh - Temporal usage trends
# Usage: analyze-trends.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - Daily usage trends
#   - Weekly usage patterns
#   - Skill adoption over time
#   - Recent vs historical usage

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

echo "=== Usage Trends Analysis ==="
echo "File: $INPUT_FILE"
echo ""

# Date range
FIRST_DATE=$(echo "$DATA" | jq -r '.timestamp' | sort | head -1 | cut -d'T' -f1)
LAST_DATE=$(echo "$DATA" | jq -r '.timestamp' | sort | tail -1 | cut -d'T' -f1)
echo "Date range: $FIRST_DATE to $LAST_DATE"
echo ""

# Daily usage
echo "--- Daily Usage (Last 14 Days) ---"
echo "$DATA" | jq -r '.timestamp | split("T")[0]' | sort | uniq -c | tail -14 | while read -r count date; do
  # Create simple bar chart
  bar_len=$((count / 5))
  if (( bar_len > 0 )); then
    bar=$(printf '█%.0s' $(seq 1 "$bar_len") 2>/dev/null || printf '#%.0s' $(seq 1 "$bar_len"))
  else
    bar=""
  fi
  printf "  %s: %4d %s\n" "$date" "$count" "$bar"
done
echo ""

# Day of week patterns
echo "--- Day of Week Patterns ---"
echo "$DATA" | jq -r '.timestamp' | while read -r ts; do
  # Extract day of week (requires GNU date or compatible)
  if command -v gdate &>/dev/null; then
    gdate -d "${ts%Z}" +%A 2>/dev/null || echo "Unknown"
  else
    date -d "${ts%Z}" +%A 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${ts%.???Z}" +%A 2>/dev/null || echo "Unknown"
  fi
done | sort | uniq -c | sort -k2 -M 2>/dev/null | while read -r count day; do
  printf "  %-10s %5d\n" "$day" "$count"
done
echo ""

# Hour of day patterns
echo "--- Hour of Day Patterns ---"
echo "$DATA" | jq -r '.timestamp | split("T")[1] | split(":")[0]' | sort | uniq -c | sort -k2 -n | while read -r count hour; do
  bar_len=$((count / 3))
  if (( bar_len > 0 )); then
    bar=$(printf '█%.0s' $(seq 1 "$bar_len") 2>/dev/null || printf '#%.0s' $(seq 1 "$bar_len"))
  else
    bar=""
  fi
  printf "  %sh: %4d %s\n" "$hour" "$count" "$bar"
done
echo ""

# Skill adoption: first seen dates
echo "--- Skill First Seen Dates ---"
echo "$DATA" | jq -rs 'sort_by(.skill) | group_by(.skill) | map({skill: .[0].skill, first_seen: (sort_by(.timestamp) | .[0].timestamp | split("T")[0])}) | sort_by(.first_seen) | .[] | "  \(.first_seen): \(.skill)"' 2>/dev/null || {
  echo "  (requires jq with -rs support)"
}
echo ""

# Recent activity (last 7 days vs previous 7 days)
echo "--- Recent vs Historical Usage ---"
NOW_EPOCH=$(date +%s)
SEVEN_DAYS_AGO=$((NOW_EPOCH - 604800))
FOURTEEN_DAYS_AGO=$((NOW_EPOCH - 1209600))

RECENT=0
OLDER=0
while read -r ts; do
  # Parse timestamp to epoch
  TS_CLEAN="${ts%.???Z}"
  if command -v gdate &>/dev/null; then
    TS_EPOCH=$(gdate -d "$TS_CLEAN" +%s 2>/dev/null || echo 0)
  else
    TS_EPOCH=$(date -d "$TS_CLEAN" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$TS_CLEAN" +%s 2>/dev/null || echo 0)
  fi
  
  if [[ "$TS_EPOCH" -ge "$SEVEN_DAYS_AGO" ]]; then
    RECENT=$((RECENT + 1))
  elif [[ "$TS_EPOCH" -ge "$FOURTEEN_DAYS_AGO" ]]; then
    OLDER=$((OLDER + 1))
  fi
done < <(echo "$DATA" | jq -r '.timestamp')

echo "  Last 7 days:     $RECENT events"
echo "  Previous 7 days: $OLDER events"
if [[ "$OLDER" -gt 0 ]]; then
  CHANGE=$(awk "BEGIN {printf \"%.1f\", (($RECENT - $OLDER) / $OLDER) * 100}")
  echo "  Change:          ${CHANGE}%"
fi
