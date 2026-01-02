#!/bin/bash
# Skill Validation Script
# Validates all skills against the Claude Skills specification
#
# Usage: bash .test/scripts/validate-skills.sh [skill-name]

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SKILLS_DIR="$(cd "$SCRIPT_DIR/../../skills" && pwd)"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-$DEFAULT_SKILLS_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handler with improved debugging information
error_handler() {
  local exit_code=$?
  local line="${BASH_LINENO[0]:-unknown}"
  local cmd="${BASH_COMMAND:-unknown}"
  echo -e "${RED}❌ Error (exit code ${exit_code}) on line ${line}: ${cmd}${NC}" >&2
}

trap 'error_handler' ERR

if [ ! -d "$SKILLS_DIR" ]; then
  echo -e "${RED}❌ Skills directory not found: $SKILLS_DIR${NC}"
  exit 1
fi

# Counters
TOTAL_SKILLS=0
PASSED_SKILLS=0
FAILED_SKILLS=0
WARNINGS=0
SKILL_NAMES=""

name_exists() {
  local needle="$1"
  if [ -z "$SKILL_NAMES" ]; then
    return 1
  fi

  case "|$SKILL_NAMES|" in
    *"|$needle|"*) return 0 ;;
  esac
  return 1
}

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
    ((++errors))
  else
    echo -e "${GREEN}✓${NC} YAML frontmatter present"
  fi

  local fm_end=""
  fm_end=$(awk 'NR>1 && $0=="---" {print NR; exit}' "$skill_md")
  if [ -z "$fm_end" ]; then
    echo -e "${RED}❌ Missing closing YAML frontmatter delimiter (---)${NC}"
    ((++errors))
  fi

  local frontmatter=""
  if [ -n "$fm_end" ]; then
    frontmatter=$(awk "NR>1 && NR<${fm_end}" "$skill_md")
  fi

  local name_line=""
  name_line=$(printf "%s\n" "$frontmatter" | grep -m1 "^name:" || true)
  if [ -z "$name_line" ]; then
    echo -e "${RED}❌ Missing 'name' field in frontmatter${NC}"
    ((++errors))
  else
    local name_value
    name_value=$(printf "%s" "$name_line" | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'")
    local name_length=${#name_value}
    local name_valid=true

    if [ -z "$name_value" ]; then
      echo -e "${RED}❌ 'name' field is empty${NC}"
      ((++errors))
      name_valid=false
    fi

    if [ "$name_length" -gt 64 ]; then
      echo -e "${RED}❌ 'name' too long: ${name_length} chars (max 64)${NC}"
      ((++errors))
      name_valid=false
    fi

    if [ "$name_valid" = true ] && ! echo "$name_value" | grep -Eq '^[a-z0-9-]+$'; then
      echo -e "${RED}❌ 'name' must match ^[a-z0-9-]+$${NC}"
      ((++errors))
      name_valid=false
    fi

    if [ "$name_valid" = true ] && name_exists "$name_value"; then
      echo -e "${RED}❌ Duplicate skill name detected: ${name_value}${NC}"
      ((++errors))
      name_valid=false
    fi

    if [ "$name_valid" = true ]; then
      if [ -z "$SKILL_NAMES" ]; then
        SKILL_NAMES="$name_value"
      else
        SKILL_NAMES="${SKILL_NAMES}|$name_value"
      fi
      echo -e "${GREEN}✓${NC} name: $name_value"
    fi
  fi

  local desc_line=""
  desc_line=$(printf "%s\n" "$frontmatter" | grep -m1 "^description:" || true)
  if [ -z "$desc_line" ]; then
    echo -e "${RED}❌ Missing 'description' field in frontmatter${NC}"
    ((++errors))
  else
    if echo "$desc_line" | grep -Eq "description:[[:space:]]*[>|]$"; then
      echo -e "${RED}❌ 'description' must be a single line (no block scalars)${NC}"
      ((++errors))
    fi

    local desc_value
    desc_value=$(printf "%s" "$desc_line" | sed 's/^description:[[:space:]]*//')
    desc_value=$(printf "%s" "$desc_value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    desc_value=${desc_value#\"}
    desc_value=${desc_value%\"}
    desc_value=${desc_value#\'}
    desc_value=${desc_value%\'}

    if [ -z "$desc_value" ]; then
      echo -e "${RED}❌ 'description' field is empty${NC}"
      ((++errors))
    else
      local desc_length=${#desc_value}
      if [ "$desc_length" -gt 1024 ]; then
        echo -e "${RED}❌ 'description' too long: ${desc_length} chars (max 1024)${NC}"
        ((++errors))
      else
        echo -e "${GREEN}✓${NC} description field present"
      fi
    fi
  fi

  if [ -n "$desc_line" ]; then
    if echo "$desc_line" | grep -Eqi "use when|should be used when|when Claude|when users|when the user"; then
      echo -e "${GREEN}✓${NC} Description includes a WHEN clause"
    else
      echo -e "${YELLOW}⚠${NC}  Description may be missing a WHEN clause (e.g., \"Use when\")"
      ((++warns))
    fi

    # Check for triggers
    if echo "$desc_line" | grep -qi "Triggers:"; then
      echo -e "${GREEN}✓${NC} Triggers list present"
    else
      echo -e "${YELLOW}⚠${NC}  No triggers list found in description"
      ((++warns))
    fi
  fi
  
  # Check word count (<5000 recommended, <2000 ideal)
  local word_count=$(wc -w < "$skill_md" | tr -d ' ')
  if [ "$word_count" -gt 5000 ]; then
    echo -e "${RED}❌ SKILL.md too long: $word_count words (max 5000)${NC}"
    ((++errors))
  elif [ "$word_count" -gt 2000 ]; then
    echo -e "${YELLOW}⚠${NC}  SKILL.md is $word_count words (ideal <2000)"
    ((++warns))
  else
    echo -e "${GREEN}✓${NC} Word count: $word_count (good)"
  fi
  
  # Check line count
  local line_count=$(wc -l < "$skill_md" | tr -d ' ')
  if [ "$line_count" -gt 300 ]; then
    echo -e "${YELLOW}⚠${NC}  SKILL.md is $line_count lines (consider moving content to references/)"
    ((++warns))
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
      ((++warns))
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
        ((++missing_refs))
      fi
    fi
  done < <(grep -oE 'references/[a-zA-Z0-9_/-]+\.md' "$skill_md" 2>/dev/null || true)
  
  if [ "$missing_refs" -gt 0 ]; then
    ((++errors))
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

shopt -s nullglob
SKILL_DIRS=("$SKILLS_DIR"/*/)
shopt -u nullglob

if [ ${#SKILL_DIRS[@]} -eq 0 ]; then
  echo -e "${RED}❌ No skill directories found in $SKILLS_DIR${NC}"
  exit 1
fi

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
  for skill_dir in "${SKILL_DIRS[@]}"; do
    # Skip non-skill directories
    skill_name=$(basename "$skill_dir")
    if [ "$skill_name" = "scripts" ] || [[ "$skill_name" == ".backups-"* ]]; then
      continue
    fi
    
    if [ -f "${skill_dir}SKILL.md" ]; then
      ((++TOTAL_SKILLS))
      if validate_skill "$skill_dir"; then
        ((++PASSED_SKILLS))
      else
        ((++FAILED_SKILLS))
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

# Check documentation-guide.md consistency across skills
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking documentation-guide.md consistency"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DOC_GUIDE_FILES=()
for skill_dir in "${SKILL_DIRS[@]}"; do
  doc_guide="${skill_dir}references/documentation-guide.md"
  if [ -f "$doc_guide" ]; then
    DOC_GUIDE_FILES+=("$doc_guide")
  fi
done

if [ ${#DOC_GUIDE_FILES[@]} -eq 0 ]; then
  echo -e "${YELLOW}⚠${NC}  No documentation-guide.md files found in skill references/"
elif [ ${#DOC_GUIDE_FILES[@]} -eq 1 ]; then
  echo -e "${GREEN}✓${NC} Only one documentation-guide.md found: ${DOC_GUIDE_FILES[0]}"
else
  # Compare all files against the first one
  REFERENCE_FILE="${DOC_GUIDE_FILES[0]}"
  REFERENCE_HASH=$(md5 -q "$REFERENCE_FILE" 2>/dev/null || md5sum "$REFERENCE_FILE" | cut -d' ' -f1)
  DOC_GUIDE_CONSISTENT=true
  INCONSISTENT_FILES=()
  
  for doc_file in "${DOC_GUIDE_FILES[@]:1}"; do
    FILE_HASH=$(md5 -q "$doc_file" 2>/dev/null || md5sum "$doc_file" | cut -d' ' -f1)
    if [ "$FILE_HASH" != "$REFERENCE_HASH" ]; then
      DOC_GUIDE_CONSISTENT=false
      INCONSISTENT_FILES+=("$doc_file")
    fi
  done
  
  if [ "$DOC_GUIDE_CONSISTENT" = true ]; then
    echo -e "${GREEN}✓${NC} All ${#DOC_GUIDE_FILES[@]} documentation-guide.md files are identical"
  else
    echo -e "${RED}❌ documentation-guide.md files are NOT identical!${NC}"
    echo "   Reference: $REFERENCE_FILE"
    echo "   Inconsistent files:"
    for f in "${INCONSISTENT_FILES[@]}"; do
      echo "     - $f"
    done
    FAILED_SKILLS=$((FAILED_SKILLS + 1))
  fi
fi
echo ""

if [ $FAILED_SKILLS -eq 0 ]; then
  echo -e "${GREEN}✅ All skills passed validation!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some skills failed validation. See details above.${NC}"
  exit 1
fi
