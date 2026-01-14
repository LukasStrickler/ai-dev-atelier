#!/usr/bin/env bash
# analyze-retention.sh - Skill retention and adoption analysis
# Usage: analyze-retention.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - First-time vs repeat usage
#   - Session return rates
#   - Skill stickiness scores

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

echo "=== Skill Retention Analysis ==="
echo "File: $INPUT_FILE"
echo ""

TOTAL_SESSIONS=$(echo "$DATA" | jq -r '.sessionID' | sort -u | wc -l | tr -d ' ')
echo "Total sessions: $TOTAL_SESSIONS"
echo ""

# Sessions per skill (how many sessions use each skill)
echo "--- Skill Reach (Sessions Using Each Skill) ---"
echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq | cut -f2 | sort | uniq -c | sort -rn | while read -r count skill; do
  pct=$(awk "BEGIN {printf \"%.1f\", ($count / $TOTAL_SESSIONS) * 100}")
  printf "  %-25s %5d sessions (%5s%%)\n" "$skill" "$count" "$pct"
done
echo ""

# Repeat usage: skills used multiple times in same session
echo "--- Skill Depth (Avg Uses Per Session When Used) ---"
echo "$DATA" | jq -rs '
  sort_by(.skill)
  | group_by(.skill)
  | map({
      skill: .[0].skill,
      total_uses: length,
      sessions: ([.[].sessionID] | unique | length),
      avg_per_session: (length / ([.[].sessionID] | unique | length))
    })
  | sort_by(-.avg_per_session)
  | .[]
  | "  \(.skill): \(.avg_per_session | . * 100 | floor / 100) uses/session (\(.sessions) sessions)"
' 2>/dev/null || {
  echo "  (requires jq with -rs support)"
}
echo ""

# Stickiness: ratio of unique days used to total days in period
echo "--- Skill Stickiness (Days Active / Total Days) ---"
FIRST_DATE=$(echo "$DATA" | jq -r '.timestamp | split("T")[0]' | sort | head -1)
LAST_DATE=$(echo "$DATA" | jq -r '.timestamp | split("T")[0]' | sort | tail -1)

# Calculate total days in period
if command -v gdate &>/dev/null; then
  FIRST_EPOCH=$(gdate -d "$FIRST_DATE" +%s 2>/dev/null || echo 0)
  LAST_EPOCH=$(gdate -d "$LAST_DATE" +%s 2>/dev/null || echo 0)
else
  FIRST_EPOCH=$(date -d "$FIRST_DATE" +%s 2>/dev/null || date -jf "%Y-%m-%d" "$FIRST_DATE" +%s 2>/dev/null || echo 0)
  LAST_EPOCH=$(date -d "$LAST_DATE" +%s 2>/dev/null || date -jf "%Y-%m-%d" "$LAST_DATE" +%s 2>/dev/null || echo 0)
fi

TOTAL_DAYS=$(( (LAST_EPOCH - FIRST_EPOCH) / 86400 + 1 ))
if [[ "$TOTAL_DAYS" -lt 1 ]]; then
  TOTAL_DAYS=1
fi

echo "  Period: $FIRST_DATE to $LAST_DATE ($TOTAL_DAYS days)"
echo ""
echo "$DATA" | jq -r '"\(.skill)|\(.timestamp | split("T")[0])"' | sort | uniq | cut -d'|' -f1 | sort | uniq -c | sort -rn | while read -r days skill; do
  stickiness=$(awk "BEGIN {printf \"%.1f\", ($days / $TOTAL_DAYS) * 100}")
  printf "  %-25s %3d days (%5s%% stickiness)\n" "$skill" "$days" "$stickiness"
done
echo ""

# Cross-session skill return rate
echo "--- Session Return Rate (Skills Used in 2+ Sessions) ---"
MULTI_SESSION_SKILLS=$(echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq | cut -f2 | sort | uniq -c | awk '$1 >= 2 {print $2}')
TOTAL_SKILLS=$(echo "$DATA" | jq -r '.skill' | sort -u | wc -l | tr -d ' ')
MULTI_COUNT=$(echo "$MULTI_SESSION_SKILLS" | grep -c . 2>/dev/null || echo "0")

echo "  Skills used in 2+ sessions: $MULTI_COUNT / $TOTAL_SKILLS"
if [[ "$TOTAL_SKILLS" -gt 0 ]]; then
  RETURN_RATE=$(awk "BEGIN {printf \"%.1f\", ($MULTI_COUNT / $TOTAL_SKILLS) * 100}")
  echo "  Overall return rate: ${RETURN_RATE}%"
fi
