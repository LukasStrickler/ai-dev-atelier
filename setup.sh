#!/bin/bash
# Setup script for AI Dev Atelier
# Verifies skill structure and provides installation guidance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATELIER_DIR="$SCRIPT_DIR"

log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠️${NC} $1"
}

log_error() {
  echo -e "${RED}❌${NC} $1" >&2
}

check_dependencies() {
  local missing=0
  local cmd
  local required_cmds=("bash" "git")

  for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      log_error "Missing required command: ${cmd}"
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -gt 0 ]; then
    exit 1
  fi

  if ! command -v jq > /dev/null 2>&1; then
    log_warning "jq not found. MCP configuration will be skipped during install."
  fi


}

# Check if skills directory exists
check_skills_dir() {
  local skills_dir="${ATELIER_DIR}/skills"
  
  if [ ! -d "$skills_dir" ]; then
    log_error "Skills directory not found: ${skills_dir}"
    echo "Please ensure AI Dev Atelier is properly cloned or installed"
    exit 1
  fi
  
  # Verify key skill directories exist
  local required_skills=("code-quality" "docs-check" "code-review" "resolve-pr-comments")
  local missing_skills=()
  
  for skill in "${required_skills[@]}"; do
    if [ ! -d "${skills_dir}/${skill}" ]; then
      missing_skills+=("$skill")
    elif [ ! -f "${skills_dir}/${skill}/SKILL.md" ]; then
      log_warning "SKILL.md not found in ${skill} directory"
    fi
  done
  
  if [ ${#missing_skills[@]} -gt 0 ]; then
    log_error "Required skill directories not found: ${missing_skills[*]}"
    exit 1
  fi
  
  # Optional skill directories
  local optional_skills=("research" "search" "docs-write" "agent-orchestration")
  for skill in "${optional_skills[@]}"; do
    if [ ! -d "${skills_dir}/${skill}" ]; then
      log_warning "Optional skill '${skill}' not found"
    elif [ ! -f "${skills_dir}/${skill}/SKILL.md" ]; then
      log_warning "SKILL.md not found in optional skill '${skill}'"
  fi
  done
  
  log_success "Skills directory structure verified"
}

# Verify skill structure
verify_skill_structure() {
  local skills_dir="${ATELIER_DIR}/skills"
  local skill_count=0
  local valid_skills=()
  
  for skill_dir in "${skills_dir}"/*; do
    if [ ! -d "$skill_dir" ]; then
      continue
    fi
    
    local skill_name=$(basename "$skill_dir")
  
    # Skip hidden directories
    if [[ "$skill_name" =~ ^\. ]]; then
      continue
    fi
    
    if [ -f "${skill_dir}/SKILL.md" ]; then
      skill_count=$((skill_count + 1))
      valid_skills+=("$skill_name")
    else
      log_warning "SKILL.md not found in ${skill_name} directory"
    fi
  done
  
  if [ $skill_count -eq 0 ]; then
    log_error "No valid skills found (no SKILL.md files)"
    exit 1
  fi
  
  log_success "Found ${skill_count} valid skill(s): ${valid_skills[*]}"
}

# Main function
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "AI Dev Atelier Setup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  log_info "Running preflight checks..."
  check_dependencies
  echo ""
  
  # Check skills directory
  log_info "Verifying skills directory structure..."
  check_skills_dir
  echo ""
  
  # Verify skill structure
  log_info "Verifying skill structure..."
  verify_skill_structure
  echo ""
  
  # Summary
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_success "Setup verification complete!"
  echo ""
  log_info "Next steps:"
  echo ""
  echo "  1. Install skills to Codex:"
  echo "     bash ${ATELIER_DIR}/install.sh"
  echo ""
  echo "  2. Verify skills are loaded in Codex:"
  echo "     - Ask Codex: 'What skills are available?'"
  echo "     - Should list: code-quality, docs-check, docs-write, code-review, resolve-pr-comments, search, research, agent-orchestration"
  echo ""
  echo "  3. Read the skills documentation:"
  echo "     cat ${ATELIER_DIR}/skills/README.md"
  echo ""
  echo "  4. Learn how agents use skills:"
  echo "     - Skills follow Anthropic Agent Skills standard"
  echo "     - Each skill has SKILL.md with instructions"
  echo "     - Scripts are embedded in skills/ subdirectories"
  echo "     - Agents read SKILL.md and execute scripts as needed"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Run main function
main
