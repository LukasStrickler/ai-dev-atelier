#!/usr/bin/env bash
# analyze-cooccurrence.sh - Skills used together in sessions
# Usage: analyze-cooccurrence.sh [telemetry.jsonl]
# Default: ~/.ada/skill-events.jsonl
#
# Outputs:
#   - Skill pair co-occurrence matrix
#   - Most common skill combinations
#   - Skills that predict other skills

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

echo "=== Skill Co-occurrence Analysis ==="
echo "File: $INPUT_FILE"
echo ""

# Get unique skills per session
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Create session-skill pairs
echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq > "$TMPFILE"

SESSIONS=$(cut -f1 "$TMPFILE" | sort -u | wc -l | tr -d ' ')
echo "Sessions with skill data: $SESSIONS"
echo ""

# Find skill pairs within sessions
echo "--- Most Common Skill Pairs ---"
# For each session, generate all pairs of skills used together
awk -F'\t' '
{
  session = $1
  skill = $2
  if (session != prev_session && prev_session != "") {
    # Output all pairs from previous session
    n = length(skills)
    for (i = 1; i <= n; i++) {
      for (j = i + 1; j <= n; j++) {
        if (skills[i] < skills[j]) {
          print skills[i] " + " skills[j]
        } else {
          print skills[j] " + " skills[i]
        }
      }
    }
    delete skills
    n = 0
  }
  skills[++n] = skill
  prev_session = session
}
END {
  # Last session
  n = length(skills)
  for (i = 1; i <= n; i++) {
    for (j = i + 1; j <= n; j++) {
      if (skills[i] < skills[j]) {
        print skills[i] " + " skills[j]
      } else {
        print skills[j] " + " skills[i]
      }
    }
  }
}
' "$TMPFILE" | sort | uniq -c | sort -rn | head -15 | while read -r count pair; do
  printf "  %-45s %5d sessions\n" "$pair" "$count"
done
echo ""

# Skills most often followed by another skill (sequences)
echo "--- Skill Sequences (A -> B) ---"
echo "$DATA" | jq -rs '
  sort_by(.sessionID)
  | group_by(.sessionID) 
  | map(sort_by(.timestamp) | [.[].skill])
  | map(
      . as $arr 
      | range(0; length - 1) 
      | "\($arr[.]) -> \($arr[. + 1])"
    )
  | flatten
  | sort
  | group_by(.) 
  | map({seq: .[0], count: length}) 
  | sort_by(-.count) 
  | .[0:15]
  | .[] 
  | "  \(.seq): \(.count)"
' 2>/dev/null || {
  echo "  (requires jq with -rs support for sequence analysis)"
}
echo ""

# Co-occurrence with specific important skills
echo "--- What Skills Co-occur with code-quality? ---"
grep -E $'\t''code-quality' "$TMPFILE" | cut -f1 | while read -r session; do
  grep "^${session}"$'\t' "$TMPFILE" | cut -f2
done | grep -v '^code-quality$' | sort | uniq -c | sort -rn | head -10 | while read -r count skill; do
  printf "  %-25s %5d times\n" "$skill" "$count"
done
echo ""

echo "--- What Skills Co-occur with git-commit? ---"
grep -E $'\t''git-commit' "$TMPFILE" | cut -f1 | while read -r session; do
  grep "^${session}"$'\t' "$TMPFILE" | cut -f2
done | grep -v '^git-commit$' | sort | uniq -c | sort -rn | head -10 | while read -r count skill; do
  printf "  %-25s %5d times\n" "$skill" "$count"
done
