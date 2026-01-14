#!/bin/bash
# List all evidence cards and research sessions

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/research-utils.sh"
source "${SCRIPT_DIR}/lib/research-status-utils.sh" 2>/dev/null || true

# Parse command line arguments
TOPIC_FILTER=""
DATE_FROM=""
DATE_TO=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --topic)
      TOPIC_FILTER="$2"
      shift 2
      ;;
    --from)
      DATE_FROM="$2"
      shift 2
      ;;
    --to)
      DATE_TO="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--topic <topic>] [--from <date>] [--to <date>]"
      exit 1
      ;;
  esac
done

# Check if evidence cards directory exists
if [ ! -d "$EVIDENCE_CARDS_DIR" ]; then
  echo "📁 No evidence cards directory found"
  echo "   Directory: $EVIDENCE_CARDS_DIR"
  exit 0
fi

echo "📚 Research Evidence Cards"
echo ""

  count=0
for card_dir in "$EVIDENCE_CARDS_DIR"/*; do
  if [ -d "$card_dir" ]; then
  card_name=$(basename "$card_dir")
  ref_file="${card_dir}/references.json"
    
    # Extract topic and timestamp from directory name
  topic=""
  timestamp=""
    if [[ "$card_name" =~ ^(.+)-([0-9]{8}-[0-9]{6})$ ]]; then
      topic="${BASH_REMATCH[1]}"
      timestamp="${BASH_REMATCH[2]}"
    fi
    
    # Apply filters
    if [ -n "$TOPIC_FILTER" ] && [[ ! "$topic" == *"$TOPIC_FILTER"* ]]; then
      continue
    fi
    
    if [ -n "$DATE_FROM" ] || [ -n "$DATE_TO" ]; then
  card_date=$(echo "$timestamp" | cut -d'-' -f1)
      if [ -n "$DATE_FROM" ] && [[ "$card_date" < "$DATE_FROM" ]]; then
        continue
      fi
      if [ -n "$DATE_TO" ] && [[ "$card_date" > "$DATE_TO" ]]; then
        continue
      fi
    fi
    
    count=$((count + 1))
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 $card_name"
    echo ""
    
    # Extract metadata from references.json
    if [ -f "$ref_file" ] && command -v jq &> /dev/null; then
  ref_topic=$(jq -r '.topic // "Unknown"' "$ref_file" 2>/dev/null)
  created=$(jq -r '.created // "Unknown"' "$ref_file" 2>/dev/null)
  papers_count=$(jq -r '.papers | length' "$ref_file" 2>/dev/null)
  approaches_count=$(jq -r '.approaches | length // 0' "$ref_file" 2>/dev/null)
  evidence_cards_count=$(jq -r '.evidence_cards | length // 0' "$ref_file" 2>/dev/null)
  has_report=$(jq -e '.research_report' "$ref_file" > /dev/null 2>&1 && echo "yes" || echo "no")
      
      echo "   Topic: $ref_topic"
      echo "   Created: $created"
      echo "   Papers: $papers_count"
      echo "   Approaches: $approaches_count"
      echo "   Evidence Cards: $evidence_cards_count"
      
      # Show status if status utils available
      if command -v detect_current_step &> /dev/null 2>&1; then
        step_status=$(detect_current_step "$card_dir" 2>/dev/null || echo "")
        if [ -n "$step_status" ]; then
          step=$(echo "$step_status" | cut -d':' -f1)
          status=$(echo "$step_status" | cut -d':' -f2)
          step_name=$(get_step_name "$step" 2>/dev/null || echo "Step $step")
          next_action=$(determine_next_action "$card_dir" "$step_status" 2>/dev/null | head -1 || echo "")
          
          echo "   Status: $step_name ($status)"
          if [ -n "$next_action" ] && [ "$next_action" != "Research complete" ]; then
            echo "   Next: $next_action"
          fi
        fi
      fi
      
      # Show approaches
      if [ "$approaches_count" -gt 0 ]; then
        echo "   Approaches:"
        jq -r '.approaches[] | "      - \(.name) (\(.evidence_card)) - \(.papers | length) papers"' "$ref_file" 2>/dev/null
      fi
      
      # Show report status
      if [ "$has_report" = "yes" ]; then
  report_file=$(jq -r '.research_report' "$ref_file" 2>/dev/null)
        echo "   Report: ✅ $report_file"
      fi
      
      # Show PDF status
  pdfs_exist=0
  pdfs_cleared=0
      while IFS= read -r pdf_path; do
        if [ -n "$pdf_path" ] && [ -f "$pdf_path" ]; then
          pdfs_exist=$((pdfs_exist + 1))
        fi
      done < <(jq -r '.papers[] | select(.pdf_path != null) | .pdf_path' "$ref_file" 2>/dev/null)
      
      while IFS= read -r cleared; do
        if [ "$cleared" = "true" ]; then
          pdfs_cleared=$((pdfs_cleared + 1))
        fi
      done < <(jq -r '.papers[] | select(.pdf_cleared == true) | .pdf_cleared' "$ref_file" 2>/dev/null)
      
      echo "   PDFs: $pdfs_exist exist, $pdfs_cleared cleared"
      
      # Add status command hint
      echo "   [Run: ada::research:status $card_name --next]"
    else
      echo "   Topic: $topic"
      echo "   Timestamp: $timestamp"
    fi
    
    echo ""
  fi
done

if [ $count -eq 0 ]; then
  echo "   No research sessions found"
  if [ -n "$TOPIC_FILTER" ] || [ -n "$DATE_FROM" ] || [ -n "$DATE_TO" ]; then
    echo "   (Try removing filters)"
  fi
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📊 Total: $count research session(s)"
fi

