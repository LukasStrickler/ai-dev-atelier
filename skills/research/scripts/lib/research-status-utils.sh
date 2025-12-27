#!/bin/bash
# Research status utilities for detecting current step, determining next actions, and loading reference files

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/research-utils.sh"

# Reference file mapping
# Use a function to get reference path instead of associative array to avoid unbound variable issues
get_reference_path() {
  local ref_name="$1"
  case "$ref_name" in
    "workflow") echo "references/guides/guide-workflow.md" ;;
    "evidence-cards") echo "references/guides/guide-evidence-cards.md" ;;
    "reports") echo "references/guides/guide-reports.md" ;;
    "weighting") echo "references/guides/guide-weighting.md" ;;
    "critical-evaluation") echo "references/guides/guide-critical-evaluation.md" ;;
    "decision-making") echo "references/guides/guide-decision-making.md" ;;
    "adaptive-strategies") echo "references/guides/guide-adaptive-strategies.md" ;;
    "template-question") echo "references/templates/template-research-question.md" ;;
    "template-card") echo "references/templates/template-evidence-card.md" ;;
    "template-report") echo "references/templates/template-research-report.md" ;;
    "template-json") echo "references/templates/template-references.json" ;;
    "example-question") echo "references/examples/example-research-question.md" ;;
    "example-card") echo "references/examples/example-evidence-card.md" ;;
    "example-report") echo "references/examples/example-research-report.md" ;;
    "example-workflows") echo "references/examples/example-workflows.md" ;;
    "tools") echo "references/reference/reference-tools.md" ;;
    *) echo "" ;;
  esac
}

# List all available reference names
list_reference_names() {
  echo "workflow evidence-cards reports weighting critical-evaluation decision-making adaptive-strategies template-question template-card template-report template-json example-question example-card example-report example-workflows tools"
}

# Detect current step from references.json and filesystem
# Usage: detect_current_step "path/to/research/dir"
detect_current_step() {
  local research_dir="$1"
  local ref_file="${research_dir}/references.json"
  local question_file="${research_dir}/research-question.md"
  local report_file="${research_dir}/research-report.md"
  
  if [ ! -f "$ref_file" ]; then
    echo "not_started"
    return
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "unknown"
    return
  fi
  
  # Step 0: Codebase Context
  local step0_status="not_started"
  if [ -f "$question_file" ]; then
    if grep -q "## Codebase Context" "$question_file" 2>/dev/null; then
      if grep -A 20 "## Codebase Context" "$question_file" | grep -q -v "^## " | grep -q "[A-Za-z0-9]"; then
        step0_status="complete"
      else
        step0_status="in_progress"
      fi
    fi
  fi
  
  # Step 1: Research Question
  local step1_status="not_started"
  local has_question_file=false
  local has_question_json=false
  
  if [ -f "$question_file" ]; then
    if grep -q "## Research Question" "$question_file" 2>/dev/null; then
      if grep -A 5 "## Research Question" "$question_file" | grep -q -v "^## " | grep -q "[A-Za-z0-9]"; then
        has_question_file=true
      fi
    fi
  fi
  
  local research_question=$(jq -r '.research_question // ""' "$ref_file" 2>/dev/null)
  if [ -n "$research_question" ] && [ "$research_question" != "null" ] && [ "$research_question" != "" ]; then
    has_question_json=true
  fi
  
  if [ "$has_question_file" = true ] && [ "$has_question_json" = true ]; then
    step1_status="complete"
  elif [ "$has_question_file" = true ] || [ "$has_question_json" = true ]; then
    step1_status="in_progress"
  fi
  
  # Step 2: Discovery
  local step2_status="not_started"
  local papers_count=$(jq -r '.papers | length // 0' "$ref_file" 2>/dev/null)
  if [ "$papers_count" -ge 25 ]; then
    step2_status="complete"
  elif [ "$papers_count" -gt 0 ]; then
    step2_status="in_progress"
  fi
  
  # Step 3: Evidence Cards
  local step3_status="not_started"
  local cards_count=$(jq -r '.evidence_cards | length // 0' "$ref_file" 2>/dev/null)
  if [ "$cards_count" -ge 5 ]; then
    step3_status="complete"
  elif [ "$cards_count" -gt 0 ]; then
    step3_status="in_progress"
  fi
  
  # Step 3.5: Critical Evaluation
  local step35_status="not_started"
  # Check if evaluation notes exist or if report exists (implies evaluation done)
  if [ -f "${research_dir}/evaluation-notes.md" ] || [ -f "$report_file" ]; then
    step35_status="complete"
  elif [ "$step3_status" = "complete" ]; then
    step35_status="not_started"  # Ready but not done
  fi
  
  # Step 4: Report
  local step4_status="not_started"
  local has_report_file=false
  local has_report_json=false
  
  if [ -f "$report_file" ]; then
    has_report_file=true
  fi
  
  local research_report=$(jq -r '.research_report // ""' "$ref_file" 2>/dev/null)
  if [ -n "$research_report" ] && [ "$research_report" != "null" ] && [ "$research_report" != "" ]; then
    has_report_json=true
  fi
  
  if [ "$has_report_file" = true ] && [ "$has_report_json" = true ]; then
    step4_status="complete"
  elif [ "$has_report_file" = true ] || [ "$has_report_json" = true ]; then
    step4_status="in_progress"
  fi
  
  # Determine current step (first incomplete step)
  if [ "$step0_status" != "complete" ]; then
    echo "0:$step0_status"
  elif [ "$step1_status" != "complete" ]; then
    echo "1:$step1_status"
  elif [ "$step2_status" != "complete" ]; then
    echo "2:$step2_status"
  elif [ "$step3_status" != "complete" ]; then
    echo "3:$step3_status"
  elif [ "$step35_status" = "not_started" ]; then
    echo "3.5:$step35_status"
  elif [ "$step4_status" != "complete" ]; then
    echo "4:$step4_status"
  else
    echo "complete:complete"
  fi
}

# Determine next action based on current state
# Usage: determine_next_action "path/to/research/dir" "step:status"
determine_next_action() {
  local research_dir="$1"
  local step_status="$2"
  local ref_file="${research_dir}/references.json"
  
  local step=$(echo "$step_status" | cut -d':' -f1)
  local status=$(echo "$step_status" | cut -d':' -f2)
  
  case "$step" in
    "0")
      echo "Gather codebase context"
      echo "Search codebase for relevant patterns using codebase_search"
      echo ""
      ;;
    "1")
      echo "Create research question"
      echo "Use template-research-question.md to create research-question.md"
      echo "template-question,example-question"
      ;;
    "2")
      local papers_count=$(jq -r '.papers | length // 0' "$ref_file" 2>/dev/null)
      local needed=$((25 - papers_count))
      echo "Continue discovery"
      echo "Search for more sources (target: 25+ total)"
      echo "Current: $papers_count sources found, need $needed more"
      echo "workflow"
      ;;
    "3")
      local cards_count=$(jq -r '.evidence_cards | length // 0' "$ref_file" 2>/dev/null)
      local next_card=$((cards_count + 1))
      local needed=$((5 - cards_count))
      echo "Create evidence card $next_card"
      echo "Read 1-2 papers, create/update evidence card"
      echo "Current: $cards_count cards created, need $needed more"
      echo "evidence-cards,template-card"
      ;;
    "3.5")
      echo "Perform critical evaluation"
      echo "Evaluate all approaches against codebase context"
      echo "critical-evaluation,decision-making"
      ;;
    "4")
      echo "Generate research report"
      echo "Re-read evidence cards, synthesize into report"
      echo "reports,template-report"
      ;;
    "complete")
      echo "Research complete"
      echo "All steps completed. Review report and finalize."
      echo ""
      ;;
    *)
      echo "Unknown step"
      echo "Check research state"
      echo ""
      ;;
  esac
}

# Calculate progress percentage
# Usage: calculate_progress "path/to/research/dir"
calculate_progress() {
  local research_dir="$1"
  local step_status=$(detect_current_step "$research_dir")
  local step=$(echo "$step_status" | cut -d':' -f1)
  local status=$(echo "$step_status" | cut -d':' -f2)
  
  case "$step" in
    "0")
      if [ "$status" = "complete" ]; then
        echo "20"
      else
        echo "0"
      fi
      ;;
    "1")
      if [ "$status" = "complete" ]; then
        echo "40"
      else
        echo "20"
      fi
      ;;
    "2")
      local ref_file="${research_dir}/references.json"
      if [ -f "$ref_file" ] && command -v jq &> /dev/null; then
        local papers_count=$(jq -r '.papers | length // 0' "$ref_file" 2>/dev/null)
        local progress=$((40 + (papers_count * 20 / 25)))
        if [ "$progress" -gt 60 ]; then
          progress=60
        fi
        echo "$progress"
      else
        echo "40"
      fi
      ;;
    "3")
      local ref_file="${research_dir}/references.json"
      if [ -f "$ref_file" ] && command -v jq &> /dev/null; then
        local cards_count=$(jq -r '.evidence_cards | length // 0' "$ref_file" 2>/dev/null)
        local progress=$((60 + (cards_count * 20 / 5)))
        if [ "$progress" -gt 80 ]; then
          progress=80
        fi
        echo "$progress"
      else
        echo "60"
      fi
      ;;
    "3.5")
      echo "80"
      ;;
    "4")
      if [ "$status" = "complete" ]; then
        echo "100"
      else
        echo "80"
      fi
      ;;
    "complete")
      echo "100"
      ;;
    *)
      echo "0"
      ;;
  esac
}

# Check for issues/warnings
# Usage: check_for_issues "path/to/research/dir"
check_for_issues() {
  local research_dir="$1"
  local ref_file="${research_dir}/references.json"
  local issues=()
  
  if [ ! -f "$ref_file" ]; then
    issues+=("references.json not found")
    echo "$(IFS=$'\n'; echo "${issues[*]}")"
    return
  fi
  
  if ! command -v jq &> /dev/null; then
    issues+=("jq not installed - cannot parse JSON")
    echo "$(IFS=$'\n'; echo "${issues[*]}")"
    return
  fi
  
  # Check JSON validity
  if ! jq empty "$ref_file" 2>/dev/null; then
    issues+=("references.json is invalid JSON")
  fi
  
  # Check for evidence cards that don't exist
  local cards=$(jq -r '.evidence_cards[]?.file // empty' "$ref_file" 2>/dev/null)
  while IFS= read -r card_file; do
    if [ -n "$card_file" ] && [ ! -f "${research_dir}/${card_file}" ]; then
      issues+=("Evidence card referenced but not found: $card_file")
    fi
  done <<< "$cards"
  
  # Check for papers without approach
  local papers_without_approach=$(jq -r '[.papers[] | select(.approach == null or .approach == "")] | length' "$ref_file" 2>/dev/null)
  if [ "$papers_without_approach" -gt 0 ]; then
    issues+=("$papers_without_approach paper(s) without approach assignment")
  fi
  
  # Check for approaches without papers
  local approaches=$(jq -r '.approaches[]?.id // empty' "$ref_file" 2>/dev/null)
  while IFS= read -r approach_id; do
    if [ -n "$approach_id" ]; then
      local papers_count=$(jq --arg approach "$approach_id" '[.papers[] | select(.approach == $approach)] | length' "$ref_file" 2>/dev/null)
      if [ "$papers_count" -eq 0 ]; then
        issues+=("Approach $approach_id has no papers assigned")
      fi
    fi
  done <<< "$approaches"
  
  # Check if evidence cards count matches approaches count
  local cards_count=$(jq -r '.evidence_cards | length // 0' "$ref_file" 2>/dev/null)
  local approaches_count=$(jq -r '.approaches | length // 0' "$ref_file" 2>/dev/null)
  if [ "$cards_count" -ne "$approaches_count" ]; then
    issues+=("Evidence cards count ($cards_count) doesn't match approaches count ($approaches_count)")
  fi
  
  if [ ${#issues[@]} -eq 0 ]; then
    echo ""
  else
    echo "$(IFS=$'\n'; echo "${issues[*]}")"
  fi
}

# Load reference file by name
# Usage: load_reference_file "reference-name"
load_reference_file() {
  local ref_name="$1"
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local project_root="$(cd "$script_dir/../../../../" && pwd)"
  
  # Get reference path
  local ref_value=$(get_reference_path "$ref_name")
  if [ -z "$ref_value" ]; then
    echo "Error: Unknown reference '$ref_name'" >&2
    echo "Available references:" >&2
    for key in $(list_reference_names); do
      echo "  - $key" >&2
    done
    return 1
  fi
  
  local ref_path="${project_root}/skills/research/${ref_value}"
  
  if [ ! -f "$ref_path" ]; then
    echo "Error: Reference file not found: $ref_path" >&2
    return 1
  fi
  
  cat "$ref_path"
}

# Get step name from step number
# Usage: get_step_name "step-number"
get_step_name() {
  local step="$1"
  case "$step" in
    "0") echo "Gather Codebase Context" ;;
    "1") echo "Formulate Research Question" ;;
    "2") echo "Comprehensive Discovery" ;;
    "3") echo "Create Evidence Cards" ;;
    "3.5") echo "Critical Evaluation" ;;
    "4") echo "Generate Research Report" ;;
    "complete") echo "Research Complete" ;;
    *) echo "Unknown Step" ;;
  esac
}

