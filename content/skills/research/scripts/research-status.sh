#!/bin/bash
# Research status and direction script
# Shows current state, next actions, and loads reference files on-demand

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/research-utils.sh"
source "${SCRIPT_DIR}/lib/research-status-utils.sh"

# Parse command line arguments
SESSION_NAME=""
SHOW_NEXT=false
LOAD_REF=""
CHECKPOINT=false
SUMMARY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --session)
      SESSION_NAME="$2"
      shift 2
      ;;
    --next)
      SHOW_NEXT=true
      shift
      ;;
    --ref)
      LOAD_REF="$2"
      shift 2
      ;;
    --checkpoint)
      CHECKPOINT=true
      shift
      ;;
    --summary)
      SUMMARY=true
      shift
      ;;
    *)
      if [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="$1"
      else
        echo "Unknown option: $1" >&2
        echo "Usage: $0 [session-name] [--session <name>] [--next] [--ref <file>] [--checkpoint] [--summary]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# If loading reference file, do that and exit
if [ -n "$LOAD_REF" ]; then
  load_reference_file "$LOAD_REF"
  exit 0
fi

# Auto-detect session if not provided
if [ -z "$SESSION_NAME" ]; then
  # Check if current directory is a research session
  if [ -f "references.json" ]; then
    SESSION_DIR="$(pwd)"
    SESSION_NAME="$(basename "$SESSION_DIR")"
  else
    # Find most recent session
    if [ -d "$EVIDENCE_CARDS_DIR" ]; then
      SESSION_NAME=$(find "$EVIDENCE_CARDS_DIR" -maxdepth 1 -type d -name "*-*" | sort -r | head -1 | xargs basename 2>/dev/null || echo "")
    fi
  fi
fi

# If still no session, list available
if [ -z "$SESSION_NAME" ]; then
  echo "❌ No research session found" >&2
  echo "" >&2
  echo "Available sessions:" >&2
  if [ -d "$EVIDENCE_CARDS_DIR" ]; then
    find "$EVIDENCE_CARDS_DIR" -maxdepth 1 -type d -name "*-*" | while read -r dir; do
      echo "  - $(basename "$dir")" >&2
    done
  fi
  echo "" >&2
  echo "Usage: $0 <session-name> [options]" >&2
  echo "   Or: $0 --ref <reference-name> to load reference files" >&2
  exit 1
fi

# Find research session directory
SESSION_DIR="${EVIDENCE_CARDS_DIR}/${SESSION_NAME}"

if [ ! -d "$SESSION_DIR" ]; then
  echo "❌ Research session not found: $SESSION_NAME" >&2
  echo "   Directory: $SESSION_DIR" >&2
  exit 1
fi

REF_FILE="${SESSION_DIR}/references.json"

# Checkpoint mode
if [ "$CHECKPOINT" = true ]; then
  echo "🔍 Research Checkpoint: $SESSION_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Check required files
  echo "✅ Required Files:"
  question_file="${SESSION_DIR}/research-question.md"
  if [ -f "$question_file" ]; then
    size=$(stat -f%z "$question_file" 2>/dev/null || stat -c%s "$question_file" 2>/dev/null || echo "unknown")
    echo "   ✅ research-question.md (exists, $size bytes)"
  else
    echo "   ❌ research-question.md (missing)"
  fi
  
  if [ -f "$REF_FILE" ]; then
    if command -v jq &> /dev/null; then
      if jq empty "$REF_FILE" 2>/dev/null; then
        papers_count=$(jq -r '.papers | length // 0' "$REF_FILE" 2>/dev/null)
        approaches_count=$(jq -r '.approaches | length // 0' "$REF_FILE" 2>/dev/null)
        echo "   ✅ references.json (valid JSON, $papers_count papers, $approaches_count approaches)"
      else
        echo "   ❌ references.json (invalid JSON)"
      fi
    else
      echo "   ⚠️  references.json (exists, but jq not available for validation)"
    fi
  else
    echo "   ❌ references.json (missing)"
  fi
  
  # Count evidence cards
  card_count=0
  if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
    card_count=$(jq -r '.evidence_cards | length // 0' "$REF_FILE" 2>/dev/null)
  fi
  card_files=$(find "$SESSION_DIR" -name "evidence-card-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "   ✅ evidence-card-*.md ($card_files cards found)"
  
  echo ""
  echo "⚠️  Issues Found:"
  issues=$(check_for_issues "$SESSION_DIR")
  if [ -z "$issues" ]; then
    echo "   (none)"
  else
    echo "$issues" | while IFS= read -r issue; do
      if [ -n "$issue" ]; then
        echo "   - $issue"
      fi
    done
  fi
  
  echo ""
  echo "📊 State Validation:"
  if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
    if jq empty "$REF_FILE" 2>/dev/null; then
      echo "   - JSON structure: ✅ Valid"
    else
      echo "   - JSON structure: ❌ Invalid"
    fi
    
    # Check file consistency
    cards_in_json=$(jq -r '.evidence_cards[]?.file // empty' "$REF_FILE" 2>/dev/null)
    all_exist=true
    while IFS= read -r card_file; do
      if [ -n "$card_file" ] && [ ! -f "${SESSION_DIR}/${card_file}" ]; then
        all_exist=false
        break
      fi
    done <<< "$cards_in_json"
    
    if [ "$all_exist" = true ]; then
      echo "   - File consistency: ✅ All cards referenced in JSON exist"
    else
      echo "   - File consistency: ⚠️  Some cards referenced in JSON are missing"
    fi
    
    # Check progress tracking
    updated=$(jq -r '.updated // ""' "$REF_FILE" 2>/dev/null)
    if [ -n "$updated" ] && [ "$updated" != "null" ]; then
      echo "   - Progress tracking: ✅ Up to date (last updated: $updated)"
    else
      echo "   - Progress tracking: ⚠️  No update timestamp"
    fi
  else
    echo "   - JSON structure: ⚠️  Cannot validate (jq not available)"
  fi
  
  echo ""
  echo "💡 Recommendations:"
  step_status=$(detect_current_step "$SESSION_DIR")
  step=$(echo "$step_status" | cut -d':' -f1)
  
  case "$step" in
    "0"|"1")
      echo "   - Complete research question setup before proceeding"
      ;;
    "2")
      echo "   - Continue searching for sources (target: 25+)"
      ;;
    "3")
      echo "   - Create more evidence cards (target: 5+)"
      ;;
    "3.5")
      echo "   - Perform critical evaluation before generating report"
      ;;
    "4")
      echo "   - Generate research report to complete research"
      ;;
    "complete")
      echo "   - Research is complete. Review and finalize."
      ;;
  esac
  
  exit 0
fi

# Summary mode
if [ "$SUMMARY" = true ]; then
  step_status=$(detect_current_step "$SESSION_DIR")
  step=$(echo "$step_status" | cut -d':' -f1)
  status=$(echo "$step_status" | cut -d':' -f2)
  step_name=$(get_step_name "$step")
  
  if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
    papers_count=$(jq -r '.papers | length // 0' "$REF_FILE" 2>/dev/null)
    cards_count=$(jq -r '.evidence_cards | length // 0' "$REF_FILE" 2>/dev/null)
    echo "$SESSION_NAME: $step_name ($status) - $papers_count papers, $cards_count cards"
  else
    echo "$SESSION_NAME: $step_name ($status)"
  fi
  exit 0
fi

# Next action mode
if [ "$SHOW_NEXT" = true ]; then
  step_status=$(detect_current_step "$SESSION_DIR")
  next_action=$(determine_next_action "$SESSION_DIR" "$step_status")
  action_title=$(echo "$next_action" | head -1)
  action_desc=$(echo "$next_action" | sed -n '2p')
  action_current=$(echo "$next_action" | sed -n '3p')
  action_refs=$(echo "$next_action" | sed -n '4p')
  
  echo "⏭️  Next Action: $action_title"
  echo ""
  echo "📋 To Do:"
  echo "   1. $action_desc"
  if [ -n "$action_current" ]; then
    echo "   2. $action_current"
  fi
  
  if [ -n "$action_refs" ] && [ "$action_refs" != "" ]; then
    echo ""
    echo "📖 Reference Files Needed:"
    echo "$action_refs" | tr ',' '\n' | while IFS= read -r ref; do
      if [ -n "$ref" ]; then
        echo "   - $ref"
      fi
    done
  fi
  
  echo ""
  echo "💡 Command:"
  if [ -n "$action_refs" ] && [ "$action_refs" != "" ]; then
    first_ref=$(echo "$action_refs" | cut -d',' -f1)
    echo "   ada::research:status --ref $first_ref"
  else
    echo "   Continue with: $action_desc"
  fi
  
  exit 0
fi

# Full status mode
  step_status=$(detect_current_step "$SESSION_DIR")
  step=$(echo "$step_status" | cut -d':' -f1)
  status=$(echo "$step_status" | cut -d':' -f2)
  step_name=$(get_step_name "$step")
  progress=$(calculate_progress "$SESSION_DIR")

echo "📊 Research Status: $SESSION_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Current Step: Step $step - $step_name"
echo "   Status: $status"
echo "   Progress: $progress% complete"
echo ""

# Completed steps
echo "✅ Completed:"
  step0_status=$(detect_current_step "$SESSION_DIR" | grep -q "^0:complete" && echo "complete" || echo "")
if [ -n "$step0_status" ]; then
  echo "   - Step 0: Codebase context gathered"
fi

  step1_status=$(detect_current_step "$SESSION_DIR" | grep -q "^1:complete\|^[2-9]" && echo "complete" || echo "")
if [ -n "$step1_status" ]; then
  echo "   - Step 1: Research question created"
fi

if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
  papers_count=$(jq -r '.papers | length // 0' "$REF_FILE" 2>/dev/null)
  academic_count=$(jq -r '[.papers[] | select(.source_type == "academic" or .source_type == null)] | length' "$REF_FILE" 2>/dev/null)
  non_academic_count=$((papers_count - academic_count))
  
  step2_status=$(detect_current_step "$SESSION_DIR" | grep -q "^2:complete\|^[3-9]" && echo "complete" || echo "")
  if [ -n "$step2_status" ] || [ "$papers_count" -gt 0 ]; then
    echo "   - Step 2: $papers_count sources found ($academic_count academic, $non_academic_count non-academic)"
  fi
  
  cards_count=$(jq -r '.evidence_cards | length // 0' "$REF_FILE" 2>/dev/null)
  step3_status=$(detect_current_step "$SESSION_DIR" | grep -q "^3:complete\|^3\.5\|^4" && echo "complete" || echo "")
  if [ -n "$step3_status" ] || [ "$cards_count" -gt 0 ]; then
    echo "   - Step 3: $cards_count evidence cards created"
  fi
fi

echo ""

# In progress
if [ "$status" = "in_progress" ]; then
  echo "🔄 In Progress:"
  case "$step" in
    "2")
      if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
        papers_count=$(jq -r '.papers | length // 0' "$REF_FILE" 2>/dev/null)
        needed=$((25 - papers_count))
        echo "   - Step 2: Searching for sources ($papers_count found, need $needed more)"
      fi
      ;;
    "3")
      if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
        cards_count=$(jq -r '.evidence_cards | length // 0' "$REF_FILE" 2>/dev/null)
        next_card=$((cards_count + 1))
        last_approach=$(jq -r '.approaches[-1]?.name // "unknown"' "$REF_FILE" 2>/dev/null)
        echo "   - Step 3: Creating evidence card $next_card ($last_approach)"
      fi
      ;;
    "4")
      echo "   - Step 4: Generating research report"
      ;;
  esac
  echo ""
fi

# Next actions
echo "⏭️  Next Actions:"
  next_action=$(determine_next_action "$SESSION_DIR" "$step_status")
  action_title=$(echo "$next_action" | head -1)
  action_desc=$(echo "$next_action" | sed -n '2p')
  action_current=$(echo "$next_action" | sed -n '3p')

echo "   1. $action_title: $action_desc"
if [ -n "$action_current" ] && [ "$action_current" != "" ]; then
  echo "   2. $action_current"
fi
if [ "$step" != "complete" ]; then
  echo "   3. Continue until step complete, then check status again"
fi
echo ""

# Files status
echo "📁 Files Status:"
  question_file="${SESSION_DIR}/research-question.md"
if [ -f "$question_file" ]; then
  echo "   ✅ research-question.md"
else
  echo "   ⏳ research-question.md (not started)"
fi

if [ -f "$REF_FILE" ]; then
  if command -v jq &> /dev/null; then
    papers_count=$(jq -r '.papers | length // 0' "$REF_FILE" 2>/dev/null)
    approaches_count=$(jq -r '.approaches | length // 0' "$REF_FILE" 2>/dev/null)
    echo "   ✅ references.json ($papers_count papers, $approaches_count approaches)"
  else
    echo "   ✅ references.json"
  fi
else
  echo "   ⏳ references.json (not started)"
fi

  card_files=$(find "$SESSION_DIR" -name "evidence-card-*.md" -type f 2>/dev/null)
if [ -n "$card_files" ]; then
  card_count=$(echo "$card_files" | wc -l | tr -d ' ')
  echo "   ✅ evidence-card-*.md ($card_count cards)"
else
  echo "   ⏳ evidence-card-*.md (not started)"
fi

  report_file="${SESSION_DIR}/research-report.md"
if [ -f "$report_file" ]; then
  echo "   ✅ research-report.md"
else
  echo "   ⏳ research-report.md (not started)"
fi
echo ""

# Metrics
if [ -f "$REF_FILE" ] && command -v jq &> /dev/null; then
  echo "📊 Metrics:"
  papers_total=$(jq -r '.papers | length // 0' "$REF_FILE" 2>/dev/null)
  papers_high=$(jq -r '[.papers[] | select(.quality_indicator == "high" or (.cited_by_count // 0) >= 50)] | length' "$REF_FILE" 2>/dev/null)
  papers_medium=$(jq -r '[.papers[] | select(.quality_indicator == "medium" or ((.cited_by_count // 0) >= 10 and (.cited_by_count // 0) < 50))] | length' "$REF_FILE" 2>/dev/null)
  papers_low=$(jq -r '[.papers[] | select(.quality_indicator == "low" or (.cited_by_count // 0) < 10)] | length' "$REF_FILE" 2>/dev/null)
  cards_count=$(jq -r '.evidence_cards | length // 0' "$REF_FILE" 2>/dev/null)
  coverage=$(jq -r '.research_metrics.coverage_assessment // "unknown"' "$REF_FILE" 2>/dev/null)
  synthesis=$(jq -r '.research_metrics.synthesis_completeness // "not_started"' "$REF_FILE" 2>/dev/null)
  
  echo "   - Papers: $papers_total ($papers_high high-weight, $papers_medium medium, $papers_low low)"
  echo "   - Evidence Cards: $cards_count / 5+ (target: 5+)"
  echo "   - Coverage: $coverage"
  echo "   - Synthesis: $synthesis"
  echo ""
fi

# Issues/Warnings
  issues=$(check_for_issues "$SESSION_DIR")
if [ -n "$issues" ]; then
  echo "⚠️  Issues/Warnings:"
  echo "$issues" | while IFS= read -r issue; do
    if [ -n "$issue" ]; then
      echo "   - $issue"
    fi
  done
  echo ""
fi

# Next command
echo "💡 Next Command:"
  next_action=$(determine_next_action "$SESSION_DIR" "$step_status")
  action_refs=$(echo "$next_action" | sed -n '4p')
if [ -n "$action_refs" ] && [ "$action_refs" != "" ]; then
  first_ref=$(echo "$action_refs" | cut -d',' -f1)
  echo "   ada::research:status --ref $first_ref"
else
  echo "   ada::research:status --next"
fi

