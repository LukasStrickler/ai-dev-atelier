#!/usr/bin/env bash
# analyze-all.sh - Run all analysis scripts and produce summary report
# Usage: analyze-all.sh [telemetry.jsonl] [--json]
# Default: ~/.ada/skill-events.jsonl
#
# Options:
#   --json    Output results as JSON (for programmatic use)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="${1:-${HOME}/.ada/skill-events.jsonl}"
OUTPUT_JSON=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    --json)
      OUTPUT_JSON=true
      ;;
  esac
done

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: File not found: $INPUT_FILE" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

if [[ "$OUTPUT_JSON" == "true" ]]; then
  # JSON output mode
  DATA=$(cat "$INPUT_FILE")
  TOTAL_EVENTS=$(echo "$DATA" | wc -l | tr -d ' ')
  UNIQUE_SKILLS=$(echo "$DATA" | jq -r '.skill' | sort -u | wc -l | tr -d ' ')
  UNIQUE_SESSIONS=$(echo "$DATA" | jq -r '.sessionID' | sort -u | wc -l | tr -d ' ')
  UNIQUE_REPOS=$(echo "$DATA" | jq -r '.repo' | sort -u | wc -l | tr -d ' ')
  
  # Skill usage breakdown
  SKILL_USAGE=$(echo "$DATA" | jq -r '.skill' | sort | uniq -c | sort -rn | awk '{printf "{\"skill\":\"%s\",\"count\":%d},", $2, $1}' | sed 's/,$//')
  
  # Top co-occurring pairs (simplified)
  PAIRS=$(echo "$DATA" | jq -r '[.sessionID, .skill] | @tsv' | sort | uniq | awk -F'\t' '
    { skills[$1] = skills[$1] " " $2 }
    END {
      for (s in skills) {
        n = split(skills[s], arr, " ")
        for (i = 1; i <= n; i++) {
          for (j = i + 1; j <= n; j++) {
            if (arr[i] != "" && arr[j] != "") {
              if (arr[i] < arr[j]) print arr[i], arr[j]
              else print arr[j], arr[i]
            }
          }
        }
      }
    }
  ' | sort | uniq -c | sort -rn | head -5 | awk '{printf "{\"pair\":\"%s + %s\",\"count\":%d},", $2, $3, $1}' | sed 's/,$//')
  
  cat <<EOF
{
  "file": "$INPUT_FILE",
  "summary": {
    "total_events": $TOTAL_EVENTS,
    "unique_skills": $UNIQUE_SKILLS,
    "unique_sessions": $UNIQUE_SESSIONS,
    "unique_repos": $UNIQUE_REPOS
  },
  "skill_usage": [$SKILL_USAGE],
  "top_pairs": [$PAIRS]
}
EOF
else
  # Text output mode
  echo "╔════════════════════════════════════════════════════════════════════════════╗"
  echo "║                    SKILL TELEMETRY ANALYSIS REPORT                         ║"
  echo "╚════════════════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Input file: $INPUT_FILE"
  echo ""
  echo "════════════════════════════════════════════════════════════════════════════"
  
  # Run each analysis
  for script in analyze-skill-usage.sh analyze-sessions.sh analyze-cooccurrence.sh \
                analyze-trends.sh analyze-versions.sh analyze-repos.sh analyze-retention.sh; do
    if [[ -x "$SCRIPT_DIR/$script" ]]; then
      echo ""
      "$SCRIPT_DIR/$script" "$INPUT_FILE"
      echo ""
      echo "════════════════════════════════════════════════════════════════════════════"
    fi
  done
  
  echo ""
  echo "Report complete."
fi
