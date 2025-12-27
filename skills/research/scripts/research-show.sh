#!/bin/bash
# Show specific evidence card and associated information

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/research-utils.sh"
source "${SCRIPT_DIR}/lib/research-status-utils.sh" 2>/dev/null || true

# Parse command line arguments
SHOW_PDF_STATUS=false
SHOW_REFERENCES=false
SHOW_APPROACHES=false
APPROACH_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --pdf-status)
      SHOW_PDF_STATUS=true
      shift
      ;;
    --references)
      SHOW_REFERENCES=true
      shift
      ;;
    --approaches)
      SHOW_APPROACHES=true
      shift
      ;;
    --approach)
      APPROACH_NAME="$2"
      shift 2
      ;;
    *)
      if [ -z "${CARD_NAME:-}" ]; then
        CARD_NAME="$1"
      else
        echo "Unknown option: $1"
        echo "Usage: $0 <card-name> [--pdf-status] [--references] [--approaches] [--approach <name>]"
        exit 1
      fi
      shift
      ;;
  esac
done

# Check if card name provided
if [ -z "${CARD_NAME:-}" ]; then
  echo "Error: Research session name required"
  echo "Usage: $0 <session-name> [--pdf-status] [--references] [--approaches] [--approach <name>]"
  echo ""
  echo "Example: $0 microservices-20250115-103000"
  echo "Example: $0 microservices-20250115-103000 --approach approach-1"
  echo ""
  echo "Run 'research-list.sh' to see available research sessions"
  exit 1
fi

# Find research session directory
SESSION_DIR="${EVIDENCE_CARDS_DIR}/${CARD_NAME}"

if [ ! -d "$SESSION_DIR" ]; then
  echo "❌ Research session not found: $CARD_NAME"
  echo "   Directory: $SESSION_DIR"
  echo ""
  echo "Run 'research-list.sh' to see available research sessions"
  exit 1
fi

REF_FILE="${SESSION_DIR}/references.json"

echo "📋 Research Session: $CARD_NAME"

# Show status header if status utils available
if command -v detect_current_step &> /dev/null 2>&1; then
  step_status=$(detect_current_step "$SESSION_DIR" 2>/dev/null || echo "")
  if [ -n "$step_status" ]; then
    step=$(echo "$step_status" | cut -d':' -f1)
    status=$(echo "$step_status" | cut -d':' -f2)
    step_name=$(get_step_name "$step" 2>/dev/null || echo "Step $step")
    
    if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
      cards_count=$(jq -r '.evidence_cards | length // 0' "$REF_FILE" 2>/dev/null || echo "0")
      if [ "$step" = "3" ] && [ "$cards_count" -gt 0 ]; then
        echo "📍 Status: $step_name ($status) - $cards_count/5+ evidence cards"
      else
        echo "📍 Status: $step_name ($status)"
      fi
    else
      echo "📍 Status: $step_name ($status)"
    fi
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show approaches if requested or if specific approach requested
if [ "$SHOW_APPROACHES" = true ] || [ -n "$APPROACH_NAME" ]; then
  if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔬 Approaches"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ -n "$APPROACH_NAME" ]; then
      # Show specific approach evidence card
      local approach_data=$(jq --arg name "$APPROACH_NAME" '.approaches[] | select(.id == $name or .name == $name)' "$REF_FILE" 2>/dev/null)
      if [ -n "$approach_data" ]; then
        local evidence_card=$(echo "$approach_data" | jq -r '.evidence_card')
        local card_file="${SESSION_DIR}/${evidence_card}"
        if [ -f "$card_file" ]; then
          cat "$card_file"
        else
          echo "⚠️  Evidence card file not found: $card_file"
        fi
      else
        echo "❌ Approach not found: $APPROACH_NAME"
        echo ""
        echo "Available approaches:"
        jq -r '.approaches[] | "  - \(.id) (\(.name))"' "$REF_FILE" 2>/dev/null
      fi
    else
      # List all approaches
      local approaches_count=$(jq -r '.approaches | length // 0' "$REF_FILE" 2>/dev/null)
      if [ "$approaches_count" -gt 0 ]; then
        jq -r '.approaches[] | "\(.name) (\(.evidence_card)) - \(.papers | length) papers"' "$REF_FILE" 2>/dev/null
      else
        echo "   No approaches found"
      fi
    fi
    echo ""
  fi
fi

# Show research report if exists
REPORT_FILE="${SESSION_DIR}/research-report.md"
if [ -f "$REPORT_FILE" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Research Report"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  cat "$REPORT_FILE"
  echo ""
fi

# Show all evidence cards if no specific approach requested
if [ -z "$APPROACH_NAME" ] && [ "$SHOW_APPROACHES" != true ]; then
  if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
    local evidence_cards=$(jq -r '.evidence_cards[]?.file // empty' "$REF_FILE" 2>/dev/null)
    if [ -n "$evidence_cards" ]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "📄 Evidence Cards"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      while IFS= read -r card_file; do
        if [ -n "$card_file" ]; then
          local full_path="${SESSION_DIR}/${card_file}"
          if [ -f "$full_path" ]; then
            echo "📋 ${card_file}"
            echo ""
            cat "$full_path"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
          fi
        fi
      done <<< "$evidence_cards"
    fi
  fi
fi

# Show references.json if requested
if [ "$SHOW_REFERENCES" = true ] && [ -f "$REF_FILE" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📚 References"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  if command -v jq &> /dev/null; then
    cat "$REF_FILE" | jq '.'
  else
    cat "$REF_FILE"
  fi
  echo ""
fi

# Show PDF status if requested
if [ "$SHOW_PDF_STATUS" = true ] && [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📄 PDF Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local pdf_count=0
  while IFS= read -r paper_data; do
    if [ -n "$paper_data" ]; then
      local paper_id=$(echo "$paper_data" | jq -r '.id')
      local title=$(echo "$paper_data" | jq -r '.title')
      local pdf_path=$(echo "$paper_data" | jq -r '.pdf_path // ""')
      local pdf_cleared=$(echo "$paper_data" | jq -r '.pdf_cleared // false')
      
      pdf_count=$((pdf_count + 1))
      echo "Paper $pdf_count: $title"
      echo "   ID: $paper_id"
      
      if [ -n "$pdf_path" ]; then
        if [ -f "$pdf_path" ]; then
          local size=$(du -h "$pdf_path" 2>/dev/null | cut -f1 || echo "unknown")
          echo "   PDF: ✅ Exists ($size)"
          echo "   Path: $pdf_path"
        else
          if [ "$pdf_cleared" = "true" ]; then
            echo "   PDF: 🗑️  Cleared (can be re-downloaded)"
          else
            echo "   PDF: ❌ Not found"
          fi
          echo "   Path: $pdf_path"
        fi
        
        # Show URLs for re-downloading
        local urls=$(echo "$paper_data" | jq -r '.urls // {}')
        if [ "$urls" != "{}" ]; then
          echo "   URLs:"
          echo "$urls" | jq -r 'to_entries[] | "      \(.key): \(.value)"' 2>/dev/null || echo "      (available in references.json)"
        fi
      else
        echo "   PDF: No path recorded"
      fi
      echo ""
    fi
  done < <(jq -c '.papers[]' "$REF_FILE" 2>/dev/null)
  
  if [ $pdf_count -eq 0 ]; then
    echo "   No papers found in references.json"
  fi
  echo ""
fi

# Show approaches summary
if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
  local approaches_count=$(jq -r '.approaches | length // 0' "$REF_FILE" 2>/dev/null)
  if [ "$approaches_count" -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔬 Approaches Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    jq -r '.approaches[] | "\(.name): \(.papers | length) papers → \(.evidence_card)"' "$REF_FILE" 2>/dev/null
    echo ""
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Tip: Use --pdf-status, --references, --approaches, or --approach <name> for more details"
echo ""

