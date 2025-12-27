#!/bin/bash
# Research utilities for managing evidence cards, papers, and PDFs

# Get the project root directory (assuming script is in skills/research/scripts/lib/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
ADA_DIR="${PROJECT_ROOT}/.ada"
DATA_DIR="${ADA_DIR}/data/research"
TEMP_DIR="${ADA_DIR}/temp/research"
# Simplified: removed evidence-cards/ from path
EVIDENCE_CARDS_DIR="${DATA_DIR}"
DOWNLOADS_DIR="${TEMP_DIR}/downloads"

# Ensure all research directories exist
ensure_research_dirs() {
  mkdir -p "${EVIDENCE_CARDS_DIR}"
  mkdir -p "${DOWNLOADS_DIR}"
}

# Generate timestamp for research session (YYYYMMDD-HHMMSS)
get_research_timestamp() {
  date +"%Y%m%d-%H%M%S"
}

# Get path for evidence card directory
# Usage: get_evidence_card_dir "microservices" "20250115-103000"
get_evidence_card_dir() {
  local topic="$1"
  local timestamp="${2:-$(get_research_timestamp)}"
  # Sanitize topic to create valid directory name
  local topic_slug=$(echo "$topic" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
  echo "${EVIDENCE_CARDS_DIR}/${topic_slug}-${timestamp}"
}

# Get path for evidence card file (approach-based)
# Usage: get_evidence_card_path "path/to/dir" "approach-1" or "raft-consensus"
get_evidence_card_path() {
  local card_dir="$1"
  local approach_id="$2"
  # Sanitize approach ID for filename
  local filename=$(echo "$approach_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
  # Use descriptive name if provided, otherwise use numbered approach
  if [[ "$filename" =~ ^approach-[0-9]+$ ]]; then
    echo "${card_dir}/evidence-card-${filename}.md"
  else
    echo "${card_dir}/evidence-card-${filename}.md"
  fi
}

# Get path for temporary PDF download
# Usage: get_temp_pdf_path "10.1234/example.doi" or "paper-id"
get_temp_pdf_path() {
  local paper_id="$1"
  # Sanitize paper ID for filename
  local filename=$(echo "$paper_id" | sed 's/[^a-zA-Z0-9._-]/_/g')
  echo "${DOWNLOADS_DIR}/${filename}.pdf"
}

# Create evidence card directory and initialize files
# Usage: create_evidence_card_dir "microservices" "20250115-103000"
create_evidence_card_dir() {
  local topic="$1"
  local timestamp="${2:-$(get_research_timestamp)}"
  local card_dir=$(get_evidence_card_dir "$topic" "$timestamp")
  
  mkdir -p "$card_dir"
  
  # Create research question file from template if it doesn't exist
  local research_question_path="${card_dir}/research-question.md"
  if [ ! -f "$research_question_path" ]; then
    create_research_question_file "$research_question_path" "$topic"
  fi
  
  echo "$card_dir"
}

# Create research question file from template
# Usage: create_research_question_file "path/to/research-question.md" "topic"
create_research_question_file() {
  local question_path="$1"
  local topic="$2"
  
  local template_path="${PROJECT_ROOT}/skills/research/references/research-question-template.md"
  local created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  if [ -f "$template_path" ]; then
    cp "$template_path" "$question_path"
    # Replace template placeholders
    sed -i.bak "s/{Topic}/$topic/g" "$question_path"
    sed -i.bak "s/{Date}/$created/g" "$question_path"
    rm -f "${question_path}.bak"
  else
    # Create basic structure if template doesn't exist
    cat > "$question_path" <<EOF
# Research Question: $topic

**Created:** $created

## Research Question / Problem Statement

{What is the research question or problem you're trying to solve?}

## Context / Background

{What is the context or background for this research?}

## Desired Outcome

{What do you want to achieve with this research?}

## Constraints / Requirements

{What are the constraints or requirements?}

## Initial Understanding (Optional)

{Any initial understanding or assumptions?}

EOF
  fi
}

# Get path to research question file
# Usage: get_research_question_path "path/to/research/dir"
get_research_question_path() {
  local research_dir="$1"
  echo "${research_dir}/research-question.md"
}

# Read research question from file
# Usage: read_research_question "path/to/research/dir"
read_research_question() {
  local research_dir="$1"
  local question_path=$(get_research_question_path "$research_dir")
  
  if [ -f "$question_path" ]; then
    cat "$question_path"
  else
    echo "Research question file not found: $question_path"
    return 1
  fi
}

# Check existing evidence cards for alignment
# Usage: check_existing_evidence_cards "path/to/research/dir"
check_existing_evidence_cards() {
  local research_dir="$1"
  
  if [ ! -d "$research_dir" ]; then
    echo "Research directory not found: $research_dir"
    return 1
  fi
  
  # Find all evidence card files
  find "$research_dir" -name "evidence-card-*.md" -type f | sort
}

# Update existing evidence card with new paper
# Usage: update_evidence_card "path/to/evidence-card.md" "paper-id" "paper-title" "path/to/references.json" "approach-id" "approach-name"
update_evidence_card() {
  local card_path="$1"
  local paper_id="$2"
  local paper_title="$3"
  local ref_path="${4:-}"
  local approach_id="${5:-}"
  local approach_name="${6:-}"
  
  if [ ! -f "$card_path" ]; then
    echo "Evidence card not found: $card_path"
    return 1
  fi
  
  # Update the "Updated" timestamp in metadata
  local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  sed -i.bak "s/- \*\*Updated:\*\* .*/- **Updated:** $updated/g" "$card_path"
  rm -f "${card_path}.bak"
  
  # Update references.json if provided
  if [ -n "$ref_path" ] && [ -f "$ref_path" ] && [ -n "$approach_id" ]; then
    local card_file=$(basename "$card_path")
    if command -v jq &> /dev/null; then
      local papers_count=$(jq --arg approach "$approach_id" '[.papers[] | select(.approach == $approach)] | length' "$ref_path")
      update_evidence_card_in_references "$ref_path" "$approach_id" "$card_file" "$approach_name" "$papers_count"
      # Update research metrics
      update_research_metrics "$ref_path"
    fi
  fi
  
  echo "Updated evidence card: $card_path"
}

# Create new evidence card for new approach
# Usage: create_new_evidence_card "path/to/research/dir" "approach-name" "topic" "path/to/references.json" "approach-id"
create_new_evidence_card() {
  local research_dir="$1"
  local approach_name="$2"
  local topic="$3"
  local ref_path="${4:-}"
  local approach_id="${5:-}"
  
  # Sanitize approach name for filename
  local approach_slug=$(echo "$approach_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
  local card_path="${research_dir}/evidence-card-${approach_slug}.md"
  
  create_evidence_card "$card_path" "$approach_name" "$topic"
  
  # Update references.json if provided
  if [ -n "$ref_path" ] && [ -f "$ref_path" ] && [ -n "$approach_id" ]; then
    local card_file=$(basename "$card_path")
    add_approach_to_references "$ref_path" "$approach_id" "$approach_name" "$card_file"
    update_evidence_card_in_references "$ref_path" "$approach_id" "$card_file" "$approach_name" "0"
    # Update research metrics
    update_research_metrics "$ref_path"
  fi
  
  echo "$card_path"
}

# Create evidence card from template (approach-based)
# Usage: create_evidence_card "path/to/evidence-card.md" "Approach Name" "topic"
create_evidence_card() {
  local card_path="$1"
  local approach_name="$2"
  local topic="$3"
  
  local template_path="${PROJECT_ROOT}/skills/research/references/evidence-card-template.md"
  local created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  if [ -f "$template_path" ]; then
    cp "$template_path" "$card_path"
    # Replace template placeholders (basic implementation)
    sed -i.bak "s/{Approach Name}/$approach_name/g" "$card_path"
    sed -i.bak "s/{Topic this approach relates to}/$topic/g" "$card_path"
    sed -i.bak "s/{Timestamp}/$created/g" "$card_path"
    sed -i.bak "s/{Number}/0/g" "$card_path"  # Papers count starts at 0
    rm -f "${card_path}.bak"
  else
    # Create basic structure if template doesn't exist
    cat > "$card_path" <<EOF
# Evidence Card: $approach_name

## Metadata
- **Approach Name:** $approach_name
- **Research Topic:** $topic
- **Papers Included:** 0 papers
- **Created:** $created
- **Updated:** $created

## Approach Overview
{2-3 paragraph overview of what this approach is}

## Papers Supporting This Approach
{List papers here}

## Key Claims
{3-5 synthesized claims}

## Supporting Evidence
{Quotes organized by claim}

## Assumptions/Conditions
{When this approach applies}

## Tradeoffs / Limitations
{Consolidated limitations}

## Failure Modes
{When this approach fails}

## Related Approaches
{Connections to other evidence cards}

## Notes
{Additional observations}
EOF
  fi
}

# Create or update references.json file
# Usage: create_references_file "path/to/references.json" "topic" "research_question" "problem" "desired_outcome" "constraints"
create_references_file() {
  local ref_path="$1"
  local topic="$2"
  local research_question="${3:-}"
  local problem="${4:-}"
  local desired_outcome="${5:-}"
  local constraints="${6:-}"
  
  local created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local updated="$created"
  
  if [ -f "$ref_path" ]; then
    # Update existing file
    updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # Use jq to update if available, otherwise create new structure
    if command -v jq &> /dev/null; then
      jq --arg updated "$updated" '.updated = $updated' "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
    fi
  else
    # Create new references file
    local template_path="${PROJECT_ROOT}/skills/research/references/references-template.json"
    if [ -f "$template_path" ]; then
      cp "$template_path" "$ref_path"
      # Update basic fields including research_question and original_intent
      if command -v jq &> /dev/null; then
        jq --arg topic "$topic" \
           --arg question "$research_question" \
           --arg problem "$problem" \
           --arg outcome "$desired_outcome" \
           --arg constraints "$constraints" \
           --arg created "$created" \
           --arg updated "$updated" \
          '.topic = $topic | 
           .created = $created | 
           .updated = $updated |
           .research_question = $question |
           .original_intent.problem = $problem |
           .original_intent.desired_outcome = $outcome |
           .original_intent.constraints = $constraints' \
          "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
      fi
    else
      # Create basic structure with new fields
      cat > "$ref_path" <<EOF
{
  "topic": "$topic",
  "created": "$created",
  "updated": "$updated",
  "research_question": "$research_question",
  "original_intent": {
    "problem": "$problem",
    "desired_outcome": "$desired_outcome",
    "constraints": "$constraints"
  },
  "approaches": [],
  "papers": [],
  "evidence_cards": [],
  "search_queries": [],
  "research_report": null
}
EOF
    fi
  fi
}

# List all evidence cards with metadata (approach-based)
list_evidence_cards() {
  if [ ! -d "$EVIDENCE_CARDS_DIR" ]; then
    echo "No evidence cards directory found."
    return 1
  fi
  
  for card_dir in "$EVIDENCE_CARDS_DIR"/*; do
    if [ -d "$card_dir" ]; then
      local card_name=$(basename "$card_dir")
      local ref_file="${card_dir}/references.json"
      
      echo "=== $card_name ==="
      
      if [ -f "$ref_file" ] && command -v jq &> /dev/null; then
        local topic=$(jq -r '.topic // "Unknown"' "$ref_file" 2>/dev/null)
        local papers_count=$(jq -r '.papers | length' "$ref_file" 2>/dev/null)
        local approaches_count=$(jq -r '.approaches | length // 0' "$ref_file" 2>/dev/null)
        local evidence_cards_count=$(jq -r '.evidence_cards | length // 0' "$ref_file" 2>/dev/null)
        
        echo "Topic: $topic"
        echo "Papers: $papers_count"
        echo "Approaches: $approaches_count"
        echo "Evidence Cards: $evidence_cards_count"
        
        # List approaches if available
        if [ "$approaches_count" -gt 0 ]; then
          echo "Approaches:"
          jq -r '.approaches[] | "  - \(.name) (\(.evidence_card))"' "$ref_file" 2>/dev/null
        fi
        
        # Check for research report
        if jq -e '.research_report' "$ref_file" > /dev/null 2>&1; then
          local report=$(jq -r '.research_report' "$ref_file")
          echo "Report: $report"
        fi
      fi
      echo ""
    fi
  done
}

# Get references for a specific paper
# Usage: get_paper_references "path/to/references.json" "paper-id"
get_paper_references() {
  local ref_path="$1"
  local paper_id="$2"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if command -v jq &> /dev/null; then
    jq --arg id "$paper_id" '.papers[] | select(.id == $id)' "$ref_path"
  else
    echo "jq is required for this function"
    return 1
  fi
}

# Check if PDF exists in temp/downloads
# Usage: check_pdf_exists "paper-id"
check_pdf_exists() {
  local paper_id="$1"
  local pdf_path=$(get_temp_pdf_path "$paper_id")
  
  if [ -f "$pdf_path" ]; then
    echo "true"
    return 0
  else
    echo "false"
    return 1
  fi
}

# Mark PDF as cleared in references.json
# Usage: mark_pdf_cleared "path/to/references.json" "paper-id"
mark_pdf_cleared() {
  local ref_path="$1"
  local paper_id="$2"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if command -v jq &> /dev/null; then
    jq --arg id "$paper_id" \
      '(.papers[] | select(.id == $id) | .pdf_cleared) = true' \
      "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
  else
    echo "jq is required for this function"
    return 1
  fi
}

# Get all PDF paths from references.json
# Usage: get_all_pdf_paths "path/to/references.json"
get_all_pdf_paths() {
  local ref_path="$1"
  
  if [ ! -f "$ref_path" ]; then
    return 1
  fi
  
  if command -v jq &> /dev/null; then
    jq -r '.papers[] | select(.pdf_path != null) | .pdf_path' "$ref_path"
  else
    echo "jq is required for this function"
    return 1
  fi
}

# Add single paper to references.json immediately (incremental update)
# Usage: add_paper_to_references "path/to/references.json" "paper-id" "paper-title" "authors-json-array" "year" "doi" "urls-json-object" "approach-id" "download-date"
add_paper_to_references() {
  local ref_path="$1"
  local paper_id="$2"
  local paper_title="$3"
  local authors_json="$4"
  local year="$5"
  local doi="$6"
  local urls_json="$7"
  local approach_id="$8"
  local download_date="${9:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "jq is required for this function"
    return 1
  fi
  
  # Check if paper already exists
  local paper_exists=$(jq --arg id "$paper_id" '.papers[] | select(.id == $id) | .id' "$ref_path")
  
  if [ -z "$paper_exists" ]; then
    # Add new paper
    local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg id "$paper_id" \
       --arg title "$paper_title" \
       --argjson authors "$authors_json" \
       --arg year "$year" \
       --arg doi "$doi" \
       --argjson urls "$urls_json" \
       --arg approach "$approach_id" \
       --arg download "$download_date" \
       --arg updated "$updated" \
      '.papers += [{
        "id": $id,
        "title": $title,
        "authors": $authors,
        "year": ($year | tonumber),
        "doi": $doi,
        "urls": $urls,
        "approach": $approach,
        "download_date": $download,
        "pdf_path": null,
        "pdf_cleared": false
      }] | .updated = $updated' \
      "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
    echo "Added paper to references.json: $paper_id"
  else
    # Update existing paper (e.g., add approach if missing)
    local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg id "$paper_id" \
       --arg approach "$approach_id" \
       --arg updated "$updated" \
      '(.papers[] | select(.id == $id) | .approach) = $approach | .updated = $updated' \
      "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
    echo "Updated paper in references.json: $paper_id"
  fi
}

# Add approach to references.json when creating new evidence card
# Usage: add_approach_to_references "path/to/references.json" "approach-id" "approach-name" "evidence-card-filename"
add_approach_to_references() {
  local ref_path="$1"
  local approach_id="$2"
  local approach_name="$3"
  local evidence_card_file="$4"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "jq is required for this function"
    return 1
  fi
  
  # Check if approach already exists
  local approach_exists=$(jq --arg id "$approach_id" '.approaches[] | select(.id == $id) | .id' "$ref_path")
  
  if [ -z "$approach_exists" ]; then
    # Add new approach
    local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg id "$approach_id" \
       --arg name "$approach_name" \
       --arg card "$evidence_card_file" \
       --arg updated "$updated" \
      '.approaches += [{
        "id": $id,
        "name": $name,
        "evidence_card": $card,
        "papers": []
      }] | .updated = $updated' \
      "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
    echo "Added approach to references.json: $approach_id"
  else
    echo "Approach already exists in references.json: $approach_id"
  fi
}

# Update evidence card metadata in references.json
# Usage: update_evidence_card_in_references "path/to/references.json" "evidence-card-id" "evidence-card-filename" "approach-name" "papers-count"
update_evidence_card_in_references() {
  local ref_path="$1"
  local card_id="$2"
  local card_file="$3"
  local approach_name="$4"
  local papers_count="${5:-0}"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "jq is required for this function"
    return 1
  fi
  
  # Check if evidence card already exists
  local card_exists=$(jq --arg id "$card_id" '.evidence_cards[] | select(.id == $id) | .id' "$ref_path")
  
  local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  if [ -z "$card_exists" ]; then
    # Add new evidence card
    jq --arg id "$card_id" \
       --arg file "$card_file" \
       --arg name "$approach_name" \
       --arg count "$papers_count" \
       --arg created "$updated" \
       --arg updated "$updated" \
      '.evidence_cards += [{
        "id": $id,
        "file": $file,
        "approach_name": $name,
        "papers_count": ($count | tonumber),
        "created": $created
      }] | .updated = $updated' \
      "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
    echo "Added evidence card to references.json: $card_id"
  else
    # Update existing evidence card
    jq --arg id "$card_id" \
       --arg name "$approach_name" \
       --arg count "$papers_count" \
       --arg updated "$updated" \
      '(.evidence_cards[] | select(.id == $id) | .approach_name) = $name |
       (.evidence_cards[] | select(.id == $id) | .papers_count) = ($count | tonumber) |
       .updated = $updated' \
      "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
    echo "Updated evidence card in references.json: $card_id"
  fi
}

# Link paper to approach in references.json
# Usage: link_paper_to_approach "path/to/references.json" "approach-id" "paper-id"
link_paper_to_approach() {
  local ref_path="$1"
  local approach_id="$2"
  local paper_id="$3"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "jq is required for this function"
    return 1
  fi
  
  local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Add paper ID to approach's papers array if not already present
  jq --arg approach "$approach_id" \
     --arg paper "$paper_id" \
     --arg updated "$updated" \
    '(.approaches[] | select(.id == $approach) | .papers) |= (
      if (. | index($paper)) then . else . + [$paper] end
    ) | .updated = $updated' \
    "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
  
  echo "Linked paper $paper_id to approach $approach_id in references.json"
}

# Incremental update wrapper: Update references.json after each paper/evidence card
# Usage: incremental_update_references "path/to/references.json" "paper-id" "paper-title" "authors-json" "year" "doi" "urls-json" "approach-id" "approach-name" "evidence-card-filename"
incremental_update_references() {
  local ref_path="$1"
  local paper_id="$2"
  local paper_title="$3"
  local authors_json="$4"
  local year="$5"
  local doi="$6"
  local urls_json="$7"
  local approach_id="$8"
  local approach_name="$9"
  local evidence_card_file="${10}"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  # Add paper
  add_paper_to_references "$ref_path" "$paper_id" "$paper_title" "$authors_json" "$year" "$doi" "$urls_json" "$approach_id"
  
  # Add/update approach
  add_approach_to_references "$ref_path" "$approach_id" "$approach_name" "$evidence_card_file"
  
  # Link paper to approach
  link_paper_to_approach "$ref_path" "$approach_id" "$paper_id"
  
  # Count papers for this approach
  if command -v jq &> /dev/null; then
    local papers_count=$(jq --arg approach "$approach_id" '[.papers[] | select(.approach == $approach)] | length' "$ref_path")
    
    # Update evidence card metadata
    update_evidence_card_in_references "$ref_path" "$approach_id" "$evidence_card_file" "$approach_name" "$papers_count"
  fi
  
  # Update research metrics
  update_research_metrics "$ref_path"
  
  echo "Incremental update complete for paper $paper_id, approach $approach_id"
}

# Update research metrics in references.json (incremental - call after each evidence card write)
# Usage: update_research_metrics "path/to/references.json"
update_research_metrics() {
  local ref_path="$1"
  
  if [ ! -f "$ref_path" ]; then
    echo "References file not found: $ref_path"
    return 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "jq is required for this function"
    return 1
  fi
  
  local updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Calculate metrics from current references.json
  local papers_total=$(jq '.papers | length' "$ref_path")
  local papers_high_quality=$(jq '[.papers[] | select(.quality_indicator == "high")] | length' "$ref_path")
  local papers_medium_quality=$(jq '[.papers[] | select(.quality_indicator == "medium")] | length' "$ref_path")
  local papers_low_quality=$(jq '[.papers[] | select(.quality_indicator == "low")] | length' "$ref_path")
  
  # Count recent papers (published in last 5 years)
  local current_year=$(date +%Y)
  local cutoff_year=$((current_year - 5))
  local papers_recent=$(jq --arg year "$cutoff_year" '[.papers[] | select(.year >= ($year | tonumber))] | length' "$ref_path")
  
  local approaches_identified=$(jq '.approaches | length' "$ref_path")
  local evidence_cards_created=$(jq '.evidence_cards | length' "$ref_path")
  
  # Determine synthesis completeness
  local synthesis_completeness="in_progress"
  if [ "$evidence_cards_created" -gt 0 ] && [ -n "$(jq -r '.research_report // empty' "$ref_path")" ]; then
    synthesis_completeness="complete"
  fi
  
  # Determine coverage assessment
  local coverage_assessment="limited"
  if [ "$papers_total" -ge 15 ]; then
    coverage_assessment="comprehensive"
  elif [ "$papers_total" -ge 8 ]; then
    coverage_assessment="moderate"
  fi
  
  # Update or create research_metrics object
  jq --arg total "$papers_total" \
     --arg high "$papers_high_quality" \
     --arg medium "$papers_medium_quality" \
     --arg low "$papers_low_quality" \
     --arg recent "$papers_recent" \
     --arg approaches "$approaches_identified" \
     --arg cards "$evidence_cards_created" \
     --arg completeness "$synthesis_completeness" \
     --arg coverage "$coverage_assessment" \
     --arg updated "$updated" \
    '.research_metrics = {
      "papers_total": ($total | tonumber),
      "papers_high_quality": ($high | tonumber),
      "papers_medium_quality": ($medium | tonumber),
      "papers_low_quality": ($low | tonumber),
      "papers_recent": ($recent | tonumber),
      "approaches_identified": ($approaches | tonumber),
      "evidence_cards_created": ($cards | tonumber),
      "synthesis_completeness": $completeness,
      "coverage_assessment": $coverage
    } | .updated = $updated' \
    "$ref_path" > "${ref_path}.tmp" && mv "${ref_path}.tmp" "$ref_path"
  
  echo "Updated research metrics in references.json"
}

# Initialize research directories on script load
ensure_research_dirs

