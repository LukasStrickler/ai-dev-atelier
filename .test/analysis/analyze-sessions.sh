#!/usr/bin/env bash
# analyze-sessions.sh - Session-level analysis
# Usage: analyze-sessions.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - Total unique sessions
#   - Session depth (skills per session)
#   - Session entry points (first skill used)
#   - Skills per session distribution
#   - Multi-skill vs single-skill sessions

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

echo "=== Session Analysis ==="
echo "File: $INPUT_FILE"
echo ""

# Unique sessions
SESSIONS=$(echo "$DATA" | jq -r '.sessionID' | sort -u | wc -l | tr -d ' ')
echo "Total sessions: $SESSIONS"
echo ""

# Events per session stats
echo "--- Events Per Session ---"
SESSION_STATS=$(echo "$DATA" | jq -r '.sessionID' | sort | uniq -c | awk '
BEGIN { min=999999; max=0; sum=0; count=0 }
{ 
  if ($1 < min) min = $1
  if ($1 > max) max = $1
  sum += $1
  count++
}
END { 
  avg = sum / count
  printf "  Min: %d\n  Max: %d\n  Avg: %.1f\n", min, max, avg
}')
echo "$SESSION_STATS"
echo ""

# Session depth: unique skills per session
echo "--- Skills Per Session Distribution ---"
echo "$DATA" | jq -rs 'sort_by(.sessionID) | group_by(.sessionID) | map({session: .[0].sessionID, skills: ([.[].skill] | unique | length)}) | sort_by(.skills) | group_by(.skills) | map({depth: .[0].skills, count: length}) | sort_by(.depth) | .[] | "  \(.depth) skill(s): \(.count) session(s)"' 2>/dev/null || {
  # Fallback for older jq versions
  echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq | cut -f1 | uniq -c | awk '{print $1}' | sort -n | uniq -c | while read -r count depth; do
    printf "  %d skill(s): %d session(s)\n" "$depth" "$count"
  done
}
echo ""

# Entry points: first skill loaded in each session
echo "--- Session Entry Points (First Skill) ---"
echo "$DATA" | jq -rs 'sort_by(.sessionID) | group_by(.sessionID) | map(sort_by(.timestamp) | .[0]) | sort_by(.skill) | group_by(.skill) | map({skill: .[0].skill, count: length}) | sort_by(-.count) | .[] | "  \(.skill): \(.count)"' 2>/dev/null || {
  # Fallback
  echo "  (requires jq with -rs support)"
}
echo ""

# Single vs multi-skill sessions
echo "--- Session Complexity ---"
SINGLE=$(echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq | cut -f1 | uniq -c | awk '$1 == 1 {count++} END {print count+0}')
MULTI=$(echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq | cut -f1 | uniq -c | awk '$1 > 1 {count++} END {print count+0}')
echo "  Single-skill sessions: $SINGLE"
echo "  Multi-skill sessions:  $MULTI"
if [[ "$SESSIONS" -gt 0 ]]; then
  MULTI_PCT=$(awk "BEGIN {printf \"%.1f\", ($MULTI / $SESSIONS) * 100}")
  echo "  Multi-skill rate:      $MULTI_PCT%"
fi
