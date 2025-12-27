#!/bin/bash
# Setup script for AI Dev Atelier
# Checks and adds required npm scripts to package.json

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

# Required scripts to add
declare -A REQUIRED_SCRIPTS=(
  ["ada::agent:finalize"]="bash /ai-dev-atelier/skills/code-quality/scripts/finalize.sh agent"
  ["ada::ci:finalize"]="bash /ai-dev-atelier/skills/code-quality/scripts/finalize.sh ci"
  ["ada::docs:check"]="bash /ai-dev-atelier/skills/docs-check/scripts/check-docs.sh"
  ["ada::review:task"]="bash /ai-dev-atelier/skills/code-review/scripts/review-run.sh task"
  ["ada::review:pr"]="bash /ai-dev-atelier/skills/code-review/scripts/review-run.sh pr"
  ["ada::review:read"]="bash /ai-dev-atelier/skills/code-review/scripts/review-read.sh"
  ["ada::review:cleanup"]="bash /ai-dev-atelier/skills/code-review/scripts/review-cleanup.sh"
  ["ada::pr:comments"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-fetch.sh read"
  ["ada::pr:comments:detect"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-detect.sh"
  ["ada::pr:comments:get"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-get.sh"
  ["ada::pr:comments:resolve"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-resolve.sh"
  ["ada::pr:comments:resolve:interactive"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-fetch.sh resolve"
  ["ada::pr:comments:dismiss"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-dismiss.sh"
  ["ada::pr:comments:cleanup"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-cleanup.sh --all"
  ["ada::pr:list"]="bash /ai-dev-atelier/skills/pr-review/scripts/pr-comments-fetch.sh list"
  ["ada::research:list"]="bash /ai-dev-atelier/skills/research/scripts/research-list.sh"
  ["ada::research:show"]="bash /ai-dev-atelier/skills/research/scripts/research-show.sh"
  ["ada::research:status"]="bash /ai-dev-atelier/skills/research/scripts/research-status.sh"
  ["ada::research:cleanup"]="bash /ai-dev-atelier/skills/research/scripts/research-cleanup.sh"
)

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

# Check if jq is installed
check_jq() {
  if ! command -v jq &> /dev/null; then
    log_error "jq is required for this script"
    echo "Install it with:"
    echo "  macOS: brew install jq"
    echo "  Linux: See https://stedolan.github.io/jq/download/"
    exit 1
  fi
}

# Check if package.json exists
check_package_json() {
  if [ ! -f "package.json" ]; then
    log_error "package.json not found in current directory"
    echo "Please run this script from your project root directory"
    exit 1
  fi
}

# Check if skills directory exists
check_scripts_dir() {
  if [ ! -d "/ai-dev-atelier/skills" ]; then
    log_error "AI Dev Atelier skills not found at /ai-dev-atelier/skills"
    echo ""
    echo "Please ensure AI Dev Atelier is available at /ai-dev-atelier"
    echo "You can:"
    echo "  1. Clone the repository: git clone <repo-url> /ai-dev-atelier"
    echo "  2. Copy the directory: cp -r /path/to/ai-dev-atelier /ai-dev-atelier"
    exit 1
  fi
  
  # Verify key skill directories exist
  if [ ! -d "/ai-dev-atelier/skills/code-quality" ] || \
     [ ! -d "/ai-dev-atelier/skills/docs-check" ] || \
     [ ! -d "/ai-dev-atelier/skills/code-review" ] || \
     [ ! -d "/ai-dev-atelier/skills/pr-review" ]; then
    log_error "Required skill directories not found"
    echo "Expected: code-quality, docs-check, code-review, pr-review"
    exit 1
  fi
  
  # Optional skill directories (research, search)
  if [ ! -d "/ai-dev-atelier/skills/research" ]; then
    log_warning "Research skill directory not found (optional)"
  fi
  if [ ! -d "/ai-dev-atelier/skills/search" ]; then
    log_warning "Search skill directory not found (optional)"
  fi
}

# Get existing scripts from package.json
get_existing_scripts() {
  if [ ! -f "package.json" ]; then
    echo "{}"
    return
  fi
  
  if jq -e '.scripts' package.json > /dev/null 2>&1; then
    jq -c '.scripts // {}' package.json 2>/dev/null || echo "{}"
  else
    echo "{}"
  fi
}

# Check if a script exists
script_exists() {
  local script_name="$1"
  local existing_scripts="$2"
  
  if echo "$existing_scripts" | jq -e --arg name "$script_name" 'has($name)' > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Add scripts to package.json
add_scripts() {
  local package_file="package.json"
  local temp_file=$(mktemp)
  local scripts_added=0
  local scripts_skipped=0
  
  # Read existing package.json
  if [ ! -f "$package_file" ]; then
    log_error "package.json not found"
    exit 1
  fi
  
  # Create backup
  cp "$package_file" "${package_file}.backup"
  log_info "Created backup: ${package_file}.backup"
  
  # Get existing scripts
  local existing_scripts
  existing_scripts=$(get_existing_scripts)
  
  # Start building new scripts object
  local new_scripts="$existing_scripts"
  
  # Add missing scripts
  for script_name in "${!REQUIRED_SCRIPTS[@]}"; do
    local script_command="${REQUIRED_SCRIPTS[$script_name]}"
    
    if script_exists "$script_name" "$existing_scripts"; then
      log_warning "Script '$script_name' already exists, skipping"
      scripts_skipped=$((scripts_skipped + 1))
    else
      log_info "Adding script: $script_name"
      new_scripts=$(echo "$new_scripts" | jq --arg name "$script_name" --arg cmd "$script_command" '. + {($name): $cmd}')
      scripts_added=$((scripts_added + 1))
    fi
  done
  
  # Update package.json with new scripts
  if [ "$scripts_added" -gt 0 ] || [ "$scripts_skipped" -lt "${#REQUIRED_SCRIPTS[@]}" ]; then
    # Use jq to merge scripts into package.json
    jq --argjson scripts "$new_scripts" '.scripts = $scripts' "$package_file" > "$temp_file"
    mv "$temp_file" "$package_file"
    
    log_success "Updated package.json"
    echo ""
    echo "  Added: $scripts_added script(s)"
    echo "  Skipped: $scripts_skipped script(s) (already exist)"
  else
    log_info "All scripts already present, no changes needed"
  fi
}

# Main function
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "AI Dev Atelier Setup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Check prerequisites
  log_info "Checking prerequisites..."
  check_jq
  check_package_json
  check_scripts_dir
  log_success "Prerequisites check passed"
  echo ""
  
  # Add scripts
  log_info "Checking package.json for required scripts..."
  add_scripts
  echo ""
  
  # Summary
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_success "Setup complete!"
  echo ""
  log_warning "IMPORTANT: Configure skills in your AI agent"
  echo ""
  echo "The npm scripts have been added, but you must configure the skills in your"
  echo "AI agent (Claude Code, Codex, etc.) for the agent to discover and use them."
  echo ""
  echo "Skills directory: ${ATELIER_DIR}/skills/"
  echo ""
  echo "Next steps:"
  echo "  1. Configure skills in your AI agent:"
  echo "     - Add ${ATELIER_DIR}/skills/ to your agent's skill directories"
  echo "     - See SETUP.md for detailed instructions"
  echo ""
  echo "  2. Verify skills are loaded:"
  echo "     - Ask your agent: 'What skills are available?'"
  echo "     - Should list: code-quality, docs-check, docs-write, code-review, pr-review, search, research"
  echo ""
  echo "  3. Test npm scripts (works independently):"
  echo "     - npm run ada::docs:check"
  echo "     - npm run ada::agent:finalize"
  echo ""
  echo "  4. Read the skills documentation:"
  echo "     - cat ${ATELIER_DIR}/skills/README.md"
  echo ""
  echo "If you need to restore the backup:"
  echo "  mv package.json.backup package.json"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Run main function
main

