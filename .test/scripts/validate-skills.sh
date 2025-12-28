#!/bin/bash
# Skill Validation Script
# Validates all skills against the Claude Skills specification
#
# Usage: bash .test/scripts/validate-skills.sh [skill-name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../../skills" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_SKILLS=0
PASSED_SKILLS=0
FAILED_SKILLS=0
WARNINGS=0

validate_skill() {
  local skill_dir="$1"
  local skill_name=$(basename "$skill_dir")
  local skill_md="${skill_dir}/SKILL.md"
  local errors=0
  local warns=0
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Validating: $skill_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Check SKILL.md exists
  if [ ! -f "$skill_md" ]; then
    echo -e "${RED}❌ Missing SKILL.md${NC}"
    return 1
  fi
  echo -e "${GREEN}✓${NC} SKILL.md exists"
  
  # Check YAML frontmatter exists
  if ! head -1 "$skill_md" | grep -q "^---$"; then
    echo -e "${RED}❌ Missing YAML frontmatter (must start with ---)${NC}"
    ((errors++))
  else
    echo -e "${GREEN}✓${NC} YAML frontmatter present"
  fi
  
  # Check name field
  if ! grep -q "^name:" "$skill_md"; then
    echo -e "${RED}❌ Missing 'name' field in frontmatter${NC}"
    ((errors++))
  else
    local name_value=$(grep "^name:" "$skill_md" | sed 's/name: *//' | tr -d '"')
    echo -e "${GREEN}✓${NC} name: $name_value"
  fi
  
  # Check description field
  if ! grep -q "^description:" "$skill_md"; then
    echo -e "${RED}❌ Missing 'description' field in frontmatter${NC}"
    ((errors++))
  else
    echo -e "${GREEN}✓${NC} description field present"
  fi
  
  local desc_line=$(grep "^description:" "$skill_md")
  if echo "$desc_line" | grep -Eqi "use when|should be used when|when Claude|when users|when the user"; then
    echo -e "${GREEN}✓${NC} Description includes a WHEN clause"
  else
    echo -e "${YELLOW}⚠${NC}  Description may be missing a WHEN clause (e.g., \"Use when\")"
    ((warns++))
  fi
  
  # Check for triggers
  if echo "$desc_line" | grep -qi "Triggers:"; then
    echo -e "${GREEN}✓${NC} Triggers list present"
  else
    echo -e "${YELLOW}⚠${NC}  No triggers list found in description"
    ((warns++))
  fi
  
  # Check word count (<5000 recommended, <2000 ideal)
  local word_count=$(wc -w < "$skill_md" | tr -d ' ')
  if [ "$word_count" -gt 5000 ]; then
    echo -e "${RED}❌ SKILL.md too long: $word_count words (max 5000)${NC}"
    ((errors++))
  elif [ "$word_count" -gt 2000 ]; then
    echo -e "${YELLOW}⚠${NC}  SKILL.md is $word_count words (ideal <2000)"
    ((warns++))
  else
    echo -e "${GREEN}✓${NC} Word count: $word_count (good)"
  fi
  
  # Check line count
  local line_count=$(wc -l < "$skill_md" | tr -d ' ')
  if [ "$line_count" -gt 300 ]; then
    echo -e "${YELLOW}⚠${NC}  SKILL.md is $line_count lines (consider moving content to references/)"
    ((warns++))
  else
    echo -e "${GREEN}✓${NC} Line count: $line_count"
  fi
  
  # Check for references directory usage
  if [ -d "${skill_dir}/references" ]; then
    local ref_count=$(find "${skill_dir}/references" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} References directory: $ref_count .md files"
  else
    if [ "$line_count" -gt 150 ]; then
      echo -e "${YELLOW}⚠${NC}  No references/ directory - consider progressive disclosure"
      ((warns++))
    fi
  fi
  
  # Check for scripts directory
  if [ -d "${skill_dir}/scripts" ]; then
    local script_count=$(find "${skill_dir}/scripts" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} Scripts directory: $script_count .sh files"
  fi
  
  # Verify referenced files exist
  local missing_refs=0
  while IFS= read -r ref; do
    if [ -n "$ref" ]; then
      local ref_path="${skill_dir}/${ref}"
      if [ ! -f "$ref_path" ]; then
        echo -e "${RED}❌ Referenced file missing: $ref${NC}"
        ((missing_refs++))
      fi
    fi
  done < <(grep -oE 'references/[a-zA-Z0-9_/-]+\.md' "$skill_md" 2>/dev/null || true)
  
  if [ "$missing_refs" -gt 0 ]; then
    ((errors++))
  elif [ "$missing_refs" -eq 0 ]; then
    local ref_mentions
    ref_mentions=$(grep -c 'references/' "$skill_md" 2>/dev/null) || ref_mentions=0
    if [ "$ref_mentions" -gt 0 ]; then
      echo -e "${GREEN}✓${NC} All referenced files exist"
    fi
  fi
  
  # Summary for this skill
  echo ""
  if [ $errors -eq 0 ]; then
    if [ $warns -eq 0 ]; then
      echo -e "${GREEN}✅ $skill_name: PASSED${NC}"
    else
      echo -e "${GREEN}✅ $skill_name: PASSED with $warns warning(s)${NC}"
    fi
    return 0
  else
    echo -e "${RED}❌ $skill_name: FAILED ($errors error(s), $warns warning(s))${NC}"
    return 1
  fi
}

# Main execution
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║          SKILL VALIDATION REPORT           ║"
echo "╚════════════════════════════════════════════╝"

# Check if specific skill requested
if [ $# -gt 0 ]; then
  skill_path="${SKILLS_DIR}/$1"
  if [ -d "$skill_path" ]; then
    TOTAL_SKILLS=1
    if validate_skill "$skill_path"; then
      PASSED_SKILLS=1
    else
      FAILED_SKILLS=1
    fi
  else
    echo -e "${RED}Error: Skill '$1' not found at $skill_path${NC}"
    exit 1
  fi
else
  # Validate all skills
  for skill_dir in "$SKILLS_DIR"/*/; do
    # Skip non-skill directories
    skill_name=$(basename "$skill_dir")
    if [ "$skill_name" = "scripts" ] || [ "$skill_name" = ".backups-"* ]; then
      continue
    fi
    
    if [ -f "${skill_dir}SKILL.md" ]; then
      ((TOTAL_SKILLS++))
      if validate_skill "$skill_dir"; then
        ((PASSED_SKILLS++))
      else
        ((FAILED_SKILLS++))
      fi
    fi
  done
fi

# Final summary
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║                 SUMMARY                    ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "Total skills validated: $TOTAL_SKILLS"
echo -e "Passed: ${GREEN}$PASSED_SKILLS${NC}"
if [ $FAILED_SKILLS -gt 0 ]; then
  echo -e "Failed: ${RED}$FAILED_SKILLS${NC}"
else
  echo "Failed: 0"
fi
echo ""

if [ $FAILED_SKILLS -eq 0 ]; then
  echo -e "${GREEN}✅ All skills passed validation!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some skills failed validation. See details above.${NC}"
  exit 1
fi
