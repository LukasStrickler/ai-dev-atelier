#!/bin/bash
# ============================================================================
# AI Dev Atelier Skills & MCP Installer
# ============================================================================
#
# Description:
#   Installs skills and MCP servers to OpenCode and Cursor.
#   Follows open Agent Skills standard and OpenCode specifications.
#
# Features:
#   - Installs skills to OpenCode (~/.opencode/skills) and Cursor (~/.cursor/skills)
#   - Configures MCPs for OpenCode and Cursor (~/.cursor/mcp.json)
#   - Preserves existing configurations (never overwrites)
#   - Smart diff-based confirmation for skill updates
#   - Agent-specific skill filtering via skills.json
#
# Dependencies:
#   - jq (for JSON manipulation and MCP configuration)
#   - bash 4.0+
#
# OpenCode Compliance:
#   - Skills: https://opencode.ai/docs/skills/
#   - MCPs: https://opencode.ai/docs/mcp-servers/
#
# Usage:
#   ./install.sh [--no] [--check] [--help]
#
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Platform & Configuration Constants
# ============================================================================

# Platform identifiers
PLATFORM_OPENCODE="opencode"
PLATFORM_CURSOR="cursor"

# Config file section keys
SECTION_MCP="mcp"                      # OpenCode uses "mcp"
SECTION_MCPSERVERS="mcpServers"         # Cursor uses "mcpServers"
SECTION_AGENT="agent"
SECTION_HOOKS="hooks"
SECTION_PLUGINS="plugins"

# API key environment variable names
ENV_TAVILY_API_KEY="TAVILY_API_KEY"
ENV_ZAI_API_KEY="Z_AI_API_KEY"
ENV_CONTEXT7_API_KEY="CONTEXT7_API_KEY"
ENV_OPENALEX_EMAIL="OPENALEX_EMAIL"

# API key placeholder strings for recognition
PLACEHOLDER_TAVILY="TAVILY_API_KEY"
PLACEHOLDER_ZAI="Z_AI_API_KEY"
PLACEHOLDER_CONTEXT7="CONTEXT7_API_KEY"

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1

# Script directory (where this script is located)
SCRIPT_SOURCE="${BASH_SOURCE[0]-${0}}"
if [ -n "$SCRIPT_SOURCE" ] && [ -f "$SCRIPT_SOURCE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
  SCRIPT_DIR="$(pwd)"
fi
ATELIER_DIR="$SCRIPT_DIR"

# Global dry-run flag
export DRY_RUN=${DRY_RUN:-false}

# Cleanup trap for temp files and backups
cleanup_on_exit() {
  local cleanup_needed=false
  
  for dir in "$ATELIER_STATE_DIR" "$OPENCODE_CONFIG_DIR" "${CURSOR_HOME:-}"; do
    [ -d "$dir" ] || continue
    for tmp_file in "$dir"/*.tmp "$dir"/*.tmp.*; do
      [ -f "$tmp_file" ] && dry_run_aware_rm -f "$tmp_file" && cleanup_needed=true
    done
  done
  
  for backup_dir in "$OPENCODE_CONFIG_DIR" "${CURSOR_HOME:-}"; do
    [ -d "$backup_dir" ] || continue
    while read -r old_backup; do
      [ -f "$old_backup" ] && dry_run_aware_rm -f "$old_backup" && cleanup_needed=true
    done < <(find "$backup_dir" -maxdepth 1 -name ".*.backup" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -n -10 | cut -d' ' -f2)
  done
  
  [ "$cleanup_needed" = true ] && log_info "Cleaned up temporary files and old backups"
}

# Register cleanup trap
trap cleanup_on_exit EXIT
REPO_URL="https://github.com/LukasStrickler/ai-dev-atelier.git"
REPO_REF="${AI_DEV_ATELIER_REF:-main}"
DEFAULT_INSTALL_DIR="${AI_DEV_ATELIER_DIR:-${HOME}/ai-dev-atelier}"  # Reserved for backward compatibility; not used in current implementation
# Content directories (where actual skill/hook/plugin/agent content lives)
CONTENT_DIR="${ATELIER_DIR}/content"
SOURCE_SKILLS_DIR="${CONTENT_DIR}/skills"
SOURCE_HOOKS_DIR="${CONTENT_DIR}/hooks"
SOURCE_PLUGINS_DIR="${CONTENT_DIR}/plugins"
SOURCE_AGENTS_DIR="${CONTENT_DIR}/agents"

# Config files (JSON configuration)
CONFIG_DIR="${ATELIER_DIR}/config"
SKILLS_CONFIG="${CONFIG_DIR}/skills.json"
LEGACY_SKILLS_CONFIG="${CONFIG_DIR}/skills-config.json"
MCP_CONFIG="${CONFIG_DIR}/mcps.json"
AGENTS_CONFIG="${CONFIG_DIR}/agents.json"
PLUGIN_CONFIG="${CONFIG_DIR}/plugins.json"
HOOKS_CONFIG="${CONFIG_DIR}/hooks.json"
ENV_FILE="${ATELIER_DIR}/.env"
ENV_EXAMPLE="${ATELIER_DIR}/.env.example"

# ============================================================================
# CONFIGURATION & PATHS
# ============================================================================

# OpenCode paths (OpenCode specification)
# OpenCode skills dir: ~/.opencode/skills (or $XDG_CONFIG_HOME/opencode/skills)
# Note: OPENCODE_SKILLS_DIR will be set by get_opencode_skills_path() function below
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME}/opencode"
else
  if [ -d "${HOME}/.config/opencode" ] || [ -f "${HOME}/.config/opencode/opencode.json" ]; then
    OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
  else
    OPENCODE_CONFIG_DIR="${HOME}/.opencode"
  fi
fi
OPENCODE_CONFIG="${OPENCODE_CONFIG_DIR}/opencode.json"

# Check project root for opencode.json (project-local config takes precedence)
if [ -f "${ATELIER_DIR}/opencode.json" ]; then
  OPENCODE_CONFIG="${ATELIER_DIR}/opencode.json"
fi

ATELIER_STATE_DIR="${OPENCODE_CONFIG_DIR}/atelier"
ATELIER_CACHE_DIR="${ATELIER_STATE_DIR}/cache"
ATELIER_REPO_DIR="${ATELIER_CACHE_DIR}/repo"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

SKIP_CONFIRM=true  # Skip confirmation prompts when true
CHECK_ONLY=false
MISSING_DEPS=()
MISSING_OPTIONAL=()

# Temporary hook file IDs (for cleanup when hooks.json is absent)
TEMP_HOOK_IDS=("graphite-block" "pr-comments-block" "release-block")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# ----------------------------------------------------------------------------
# Logging Functions
# ----------------------------------------------------------------------------

# Log an informational message
# Usage: log_info "message"
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

# ----------------------------------------------------------------------------
# Dry Run Aware Operations
# ----------------------------------------------------------------------------

# Dry-run aware copy
# Usage: dry_run_aware_cp [-r] source target
dry_run_aware_cp() {
  local args=()
  while [[ $# -gt 2 ]]; do
    args+=("$1")
    shift
  done
  local src="$1"
  local dest="$2"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would copy: ${src} -> ${dest} (args: ${args[*]})"
    return 0
  fi
  cp "${args[@]}" "$src" "$dest"
}

# Dry-run aware move
# Usage: dry_run_aware_mv source target
dry_run_aware_mv() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would move: $1 -> $2"
    return 0
  fi
  mv "$1" "$2"
}

# Dry-run aware remove
# Usage: dry_run_aware_rm [-rf] target
dry_run_aware_rm() {
  local args=()
  while [[ $# -gt 1 ]]; do
    args+=("$1")
    shift
  done
  local target="$1"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would remove: ${target} (args: ${args[*]})"
    return 0
  fi
  rm "${args[@]}" "$target"
}

# Dry-run aware mkdir
# Usage: dry_run_aware_mkdir [-p] target
dry_run_aware_mkdir() {
  local args=()
  while [[ $# -gt 1 ]]; do
    args+=("$1")
    shift
  done
  local target="$1"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would create directory: ${target} (args: ${args[*]})"
    return 0
  fi
  mkdir "${args[@]}" "$target"
}

# Dry-run aware file write (redirection)
# Usage: command | dry_run_aware_write target
dry_run_aware_write() {
  local target="$1"
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would write to: ${target}"
    cat > /dev/null
    return 0
  fi
  cat > "$target"
}

# ----------------------------------------------------------------------------
# Dry Run Aware Operations
# ----------------------------------------------------------------------------

# Dry-run aware copy
# Usage: dry_run_aware_cp [-r] source target
dry_run_aware_cp() {
  local args=()
  while [[ $# -gt 2 ]]; do
    args+=("$1")
    shift
  done
  local src="$1"
  local dest="$2"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would copy: ${src} -> ${dest} (args: ${args[*]})"
    return 0
  fi
  cp "${args[@]}" "$src" "$dest"
}

# Dry-run aware move
# Usage: dry_run_aware_mv source target
dry_run_aware_mv() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would move: $1 -> $2"
    return 0
  fi
  mv "$1" "$2"
}

# Dry-run aware remove
# Usage: dry_run_aware_rm [-rf] target
dry_run_aware_rm() {
  local args=()
  while [[ $# -gt 1 ]]; do
    args+=("$1")
    shift
  done
  local target="$1"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would remove: ${target} (args: ${args[*]})"
    return 0
  fi
  rm "${args[@]}" "$target"
}

# Dry-run aware mkdir
# Usage: dry_run_aware_mkdir [-p] target
dry_run_aware_mkdir() {
  local args=()
  while [[ $# -gt 1 ]]; do
    args+=("$1")
    shift
  done
  local target="$1"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would create directory: ${target} (args: ${args[*]})"
    return 0
  fi
  mkdir "${args[@]}" "$target"
}

# Dry-run aware file write (redirection)
# Usage: command | dry_run_aware_write target
dry_run_aware_write() {
  local target="$1"
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would write to: ${target}"
    cat > /dev/null
    return 0
  fi
  cat > "$target"
}

# ----------------------------------------------------------------------------
# Atomic Copy Skill
# ----------------------------------------------------------------------------
# Copies a skill directory to a target location atomically by using a temporary
# directory and mv. This prevents partial copies on interruption.
#
# Parameters:
#   $1 - Source directory path
#   $2 - Target directory path
#
# Returns:
#   0 on success, 1 on failure
atomic_copy_skill() {
  local source="$1"
  local target="$2"
  local temp_target="${target}.tmp.$$"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would copy skill atomically: ${source} -> ${target}"
    return 0
  fi

  # Copy to temp location
  if ! dry_run_aware_cp -r "$source" "$temp_target"; then
    log_error "Failed to copy skill to temp location"
    dry_run_aware_rm -rf "$temp_target" 2>/dev/null
    return 1
  fi

  # Atomic move
  if ! dry_run_aware_mv "$temp_target" "$target"; then
    log_error "Failed to move skill to final location"
    dry_run_aware_rm -rf "$temp_target" 2>/dev/null
    return 1
  fi

  return 0
}

git_with_retry() {
  local max_attempts=3
  local attempt=1
  local delay=2

  while [ $attempt -le $max_attempts ]; do
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY RUN] Would execute git: git $*"
      return 0
    fi
    if git "$@"; then
      return 0
    fi
    if git "$@"; then
      return 0
    fi

    if [ $attempt -lt $max_attempts ]; then
      log_warning "Git operation failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
      sleep $delay
      delay=$((delay * 2))
    fi

    attempt=$((attempt + 1))
  done

  log_error "Git operation failed after $max_attempts attempts"
  return 1
}

confirm_action() {
  local prompt="$1"

  if [ "$SKIP_CONFIRM" = true ]; then
    return 0
  fi

  echo -n "${prompt} [Y/n]: "
  read -r response
  case "$response" in
    [nN][oO]|[nN])
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

detect_package_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  else
    echo ""
  fi
}

package_for_command() {
  case "$1" in
    bash)
      echo "bash"
      ;;
    git)
      echo "git"
      ;;
    jq)
      echo "jq"
      ;;
    awk|gawk)
      echo "gawk"
      ;;
    sed)
      echo "sed"
      ;;
    diff)
      echo "diffutils"
      ;;
    *)
      echo ""
      ;;
  esac
}

install_missing_dependencies() {
  local has_required=${#MISSING_DEPS[@]}
  local packages=()
  local unmapped=()
  local cmd
  local pkg

  for cmd in "${MISSING_DEPS[@]}" "${MISSING_OPTIONAL[@]}"; do
    pkg=$(package_for_command "$cmd")
    if [ -n "$pkg" ]; then
      packages+=("$pkg")
    else
      unmapped+=("$cmd")
    fi
  done

  if [ ${#packages[@]} -eq 0 ]; then
    if [ ${#unmapped[@]} -gt 0 ]; then
      log_error "Missing dependencies require manual install: ${unmapped[*]}"
    fi
    if [ "$has_required" -gt 0 ]; then
      return 1
    fi
    return 0
  fi

  local manager
  manager=$(detect_package_manager)
  if [ -z "$manager" ]; then
    log_error "No supported package manager found."
    echo "Install missing dependencies manually: ${packages[*]}"
    if [ "$has_required" -gt 0 ]; then
      return 1
    fi
    return 0
  fi

  if ! confirm_action "Install missing dependencies: ${packages[*]}?"; then
    if [ "$has_required" -gt 0 ]; then
      log_error "Missing required dependencies: ${MISSING_DEPS[*]}"
      return 1
    fi
    return 0
  fi

  local sudo_cmd=""
  if [ "${EUID}" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo_cmd="sudo"
  fi

  case "$manager" in
    brew)
      brew install "${packages[@]}"
      ;;
    apt-get)
      ${sudo_cmd} apt-get update
      ${sudo_cmd} apt-get install -y "${packages[@]}"
      ;;
    dnf)
      ${sudo_cmd} dnf install -y "${packages[@]}"
      ;;
    yum)
      ${sudo_cmd} yum install -y "${packages[@]}"
      ;;
    pacman)
      ${sudo_cmd} pacman -S --noconfirm "${packages[@]}"
      ;;
    zypper)
      ${sudo_cmd} zypper install -y "${packages[@]}"
      ;;
  esac

  return 0
}

ensure_repo_checkout() {
  if [ -d "$SOURCE_SKILLS_DIR" ]; then
    return 0
  fi

  log_warning "Skills directory not found in ${ATELIER_DIR}."
  local target_dir="$ATELIER_REPO_DIR"

  if [ -d "${target_dir}/content/skills" ] && [ -f "${target_dir}/install.sh" ]; then
    log_info "Using cached checkout at ${target_dir}"
    if git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if ! git -C "$target_dir" diff --quiet || ! git -C "$target_dir" diff --cached --quiet; then
        log_warning "Local changes detected in cached checkout; resetting to ${REPO_REF}"
      fi
      if git_with_retry -C "$target_dir" fetch --depth=1 origin "$REPO_REF" >/dev/null 2>&1; then
        if ! git -C "$target_dir" checkout -B "$REPO_REF" FETCH_HEAD >/dev/null 2>&1; then
          log_warning "Failed to update cached checkout"
        fi
      else
        log_warning "Failed to fetch updates for cached checkout"
      fi
    fi
    exec bash "${target_dir}/install.sh" "$@"
  fi

  if ! confirm_action "Download AI Dev Atelier into ${target_dir}?"; then
    log_error "Cannot continue without a local checkout."
    exit 1
  fi

  if ! dry_run_aware_mkdir -p "$ATELIER_CACHE_DIR"; then
    log_error "Failed to create cache directory: ${ATELIER_CACHE_DIR}"
    exit 1
  fi

  if ! git_with_retry clone --depth=1 --branch "$REPO_REF" "$REPO_URL" "$target_dir"; then
    log_error "Failed to clone ${REPO_URL}"
    exit 1
  fi

  exec bash "${target_dir}/install.sh" "$@"
}

resolve_skills_config() {
  if [ -f "$SKILLS_CONFIG" ]; then
    return 0
  fi

  if [ -f "$LEGACY_SKILLS_CONFIG" ]; then
    log_warning "Found legacy skills-config.json. Copying to skills.json."
    dry_run_aware_cp "$LEGACY_SKILLS_CONFIG" "$SKILLS_CONFIG"
    dry_run_aware_rm -f "$LEGACY_SKILLS_CONFIG"
    return 0
  fi
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

# ----------------------------------------------------------------------------
# Load Environment Variables
# ----------------------------------------------------------------------------
# Loads API keys and configuration from .env file if it exists.
# Falls back to .env.example for reference if .env doesn't exist.
# This function is non-fatal: it always returns 0 (success) to allow
# installation to proceed even when .env is missing (users can configure
# MCP servers later via OpenCode settings).
#
# Arguments:
#   $1 - Optional path to env file (defaults to $ENV_FILE)
# Returns:
#   0 (always) - success whether or not .env file exists
load_env_file() {
  # shellcheck disable=SC2120
  local env_file="${1:-$ENV_FILE}"
  if [ -f "$env_file" ]; then
    while IFS='=' read -r key value || [ -n "$key" ]; do
      # Skip comments and empty lines
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue

      # Trim whitespace
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)

      # Security: Validate key is valid identifier
      if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        export "$key=$value"
      else
        log_warning "Skipping invalid env key: $key"
      fi
    done < "$env_file"
  fi
  return 0
}

# ----------------------------------------------------------------------------
# Get OpenCode Skills Path
# ----------------------------------------------------------------------------
# Determines the global OpenCode skills directory.
# Per OpenCode docs: https://opencode.ai/docs/skills/
# Always uses global config location, not project-local.
# - Global config: ~/.opencode/skills/<name>/SKILL.md
#
# Returns: Path to global OpenCode skills directory
get_opencode_skills_path() {
  echo "${OPENCODE_CONFIG_DIR}/skills"
}

# ----------------------------------------------------------------------------
# Cursor skills path (Cursor docs: https://cursor.com/docs/context/skills)
# User-level (global): ~/.cursor/skills/
# CURSOR_HOME overrides base when set.
get_cursor_skills_path() {
  echo "${CURSOR_HOME:-$HOME/.cursor}/skills"
}

# Cursor MCP config path (Cursor docs: https://cursor.com/docs/context/mcp)
# Global: ~/.cursor/mcp.json
get_cursor_mcp_config_path() {
  echo "${CURSOR_HOME:-$HOME/.cursor}/mcp.json"
}

# Update OPENCODE_SKILLS_DIR and CURSOR_SKILLS_DIR to use the function results
OPENCODE_SKILLS_DIR=$(get_opencode_skills_path)
CURSOR_SKILLS_DIR=$(get_cursor_skills_path)
CURSOR_MCP_CONFIG=$(get_cursor_mcp_config_path)

# ----------------------------------------------------------------------------
# Argument Parsing
# ----------------------------------------------------------------------------

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --yes|-y)
        SKIP_CONFIRM=true
        shift
        ;;
      --no)
        SKIP_CONFIRM=false
        shift
        ;;
      --check)
        CHECK_ONLY=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

show_help() {
  cat << EOF
Install AI Dev Atelier Skills and MCPs to OpenCode and Cursor

Usage: $0 [OPTIONS]

Options:
  -y, --yes    Skip confirmation prompts (auto-overwrite)
  --no         Require confirmation before overwriting skills
  --check      Run preflight checks only
  -h, --help   Show this help message

This script installs skills and MCPs:
  OpenCode:
    Skills: ${OPENCODE_SKILLS_DIR}
    MCPs: ${OPENCODE_CONFIG} (JSON format)
  Cursor (global):
    Skills: ${CURSOR_SKILLS_DIR}
    MCPs: ${CURSOR_MCP_CONFIG}

Skills are installed following the open Agent Skills standard.
Skills can be disabled per agent in skills.json.
EOF
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# ----------------------------------------------------------------------------
# Validate Skill Name
# ----------------------------------------------------------------------------
# Validates skill name per OpenCode specification.
# Per OpenCode docs: https://opencode.ai/docs/skills/
# Requirements:
#   - 1-64 characters
#   - Lowercase alphanumeric with single hyphen separators
#   - Not start or end with '-'
#   - Not contain consecutive '--'
#   - Regex: ^[a-z0-9]+(-[a-z0-9]+)*$
#
# Parameters:
#   $1 - Skill name to validate
#
# Returns:
#   0 if valid, 1 if invalid
validate_skill_name() {
  local name="$1"
  
  # Check length (1-64 characters)
  if [ ${#name} -lt 1 ] || [ ${#name} -gt 64 ]; then
    return 1
  fi
  
  # Check regex pattern: lowercase alphanumeric with single hyphens
  if ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    return 1
  fi
  
  # Additional checks (redundant but explicit)
  # Must not start or end with hyphen
  if [[ "$name" =~ ^- ]] || [[ "$name" =~ -$ ]]; then
    return 1
  fi
  
  # Must not contain consecutive hyphens
  if [[ "$name" =~ -- ]]; then
    return 1
  fi
  
  return 0
}

# ----------------------------------------------------------------------------
# Check Source Directory
# ----------------------------------------------------------------------------
# Validates that the source skills directory exists and contains valid skills.
#
# Exits with error if:
#   - Source directory doesn't exist
#   - No skills found in source directory
check_source_dir() {
  if [ ! -d "$SOURCE_SKILLS_DIR" ]; then
    log_error "Skills directory not found: ${SOURCE_SKILLS_DIR}"
    echo "Please run this script from the AI Dev Atelier root directory"
    exit 1
  fi

  local required_skills=("code-quality" "docs-check" "code-review" "resolve-pr-comments")
  local missing_skills=()

  for skill in "${required_skills[@]}"; do
    if [ ! -d "${SOURCE_SKILLS_DIR}/${skill}" ]; then
      missing_skills+=("$skill")
    elif [ ! -f "${SOURCE_SKILLS_DIR}/${skill}/SKILL.md" ]; then
      log_warning "SKILL.md not found in ${skill} directory"
    fi
  done

  if [ ${#missing_skills[@]} -gt 0 ]; then
    log_error "Required skill directories not found: ${missing_skills[*]}"
    exit 1
  fi

  local optional_skills=("research" "search" "docs-write" "git-commit" "ui-animation" "use-graphite")
  for skill in "${optional_skills[@]}"; do
    if [ ! -d "${SOURCE_SKILLS_DIR}/${skill}" ]; then
      log_warning "Optional skill '${skill}' not found"
    elif [ ! -f "${SOURCE_SKILLS_DIR}/${skill}/SKILL.md" ]; then
      log_warning "SKILL.md not found in optional skill '${skill}'"
    fi
  done

  log_success "Skills directory structure verified"
}

check_dependencies() {
  MISSING_DEPS=()
  MISSING_OPTIONAL=()

  local cmd
  local required_cmds=("bash" "git" "diff" "cp" "rm" "awk" "sed" "mkdir" "basename" "dirname")

  for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      MISSING_DEPS+=("$cmd")
    fi
  done

  if ! command -v jq > /dev/null 2>&1; then
    MISSING_OPTIONAL+=("jq")
  fi

  if ! command -v bun > /dev/null 2>&1; then
    MISSING_OPTIONAL+=("bun")
  fi

  if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_error "Missing required dependencies: ${MISSING_DEPS[*]}"
    return 1
  fi

  if [ ${#MISSING_OPTIONAL[@]} -gt 0 ]; then
    log_warning "Optional dependencies missing: ${MISSING_OPTIONAL[*]}"
  fi

  return 0
}

check_optional_tools() {
  log_info "Checking optional skill dependencies..."

  if command -v gt > /dev/null 2>&1; then
    local gt_version
    gt_version=$(gt --version 2>/dev/null | head -1 || echo "unknown")
    log_success "Graphite CLI found: ${gt_version}"
  else
    log_warning "Graphite CLI (gt) not found. use-graphite skill will not be functional."
    echo "         Install with: npm install -g @withgraphite/graphite-cli"
    echo "         Then run: gt auth login"
  fi

  if command -v coderabbit > /dev/null 2>&1; then
    log_success "CodeRabbit CLI found"
  else
    log_warning "CodeRabbit CLI not found. code-review skill will not be functional."
    echo "         Install with: npm install -g @coderabbitai/cli"
  fi

  if command -v gh > /dev/null 2>&1; then
    log_success "GitHub CLI (gh) found"
  else
    log_warning "GitHub CLI (gh) not found. resolve-pr-comments skill will not be functional."
    echo "         Install from: https://cli.github.com/"
    echo "         Then run: gh auth login"
  fi
}

verify_skill_structure() {
  local skills_dir="${SOURCE_SKILLS_DIR}"
  local skill_count=0
  local valid_skills=()

  for skill_dir in "${skills_dir}"/*; do
    if [ ! -d "$skill_dir" ]; then
      continue
    fi

    local skill_name
    skill_name=$(basename "$skill_dir")

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

check_write_access() {
  local target="$1"
  local probe="$target"

  while [ ! -d "$probe" ]; do
    probe=$(dirname "$probe")
    if [ "$probe" = "/" ]; then
      break
    fi
  done

  if [ ! -w "$probe" ]; then
    log_error "No write access to ${target} (closest existing dir: ${probe})"
    return 1
  fi

  return 0
}

preflight_checks() {
  local i
  for i in 1 2; do
    check_dependencies || true
    [ ${#MISSING_DEPS[@]} -eq 0 ] && [ ${#MISSING_OPTIONAL[@]} -eq 0 ] && break
    [ "$i" -eq 2 ] && break
    if [ ${#MISSING_DEPS[@]} -gt 0 ] || [ ${#MISSING_OPTIONAL[@]} -gt 0 ]; then
      install_missing_dependencies || break
    fi
  done

  if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    exit 1
  fi

  check_optional_tools

  # Create ATELIER_STATE_DIR before checking write access
  if ! dry_run_aware_mkdir -p "$ATELIER_STATE_DIR"; then
    log_error "Failed to create state directory: ${ATELIER_STATE_DIR}"
    exit 1
  fi

  local failed=0
  check_write_access "$OPENCODE_SKILLS_DIR" || failed=$((failed + 1))
  check_write_access "$CURSOR_SKILLS_DIR" || failed=$((failed + 1))
  check_write_access "$(dirname "$OPENCODE_CONFIG")" || failed=$((failed + 1))
  check_write_access "$(dirname "$CURSOR_MCP_CONFIG")" || failed=$((failed + 1))
  check_write_access "$ATELIER_STATE_DIR" || failed=$((failed + 1))

  if [ "$failed" -gt 0 ]; then
    log_error "Preflight checks failed. Fix permissions and re-run."
    exit 1
  fi
}

# ============================================================================
# SKILL INSTALLATION
# ============================================================================

# ----------------------------------------------------------------------------
# Calculate Directory Diff
# ----------------------------------------------------------------------------
# Calculates a smart diff summary between source and target skill directories.
# Uses git diff if available, falls back to unified diff.
#
# Parameters:
#   $1 - Source directory path
#   $2 - Target directory path
#   $3 - Skill name (for context)
#
# Returns:
#   Diff summary string: "new", "identical", or "X files, +Y -Z lines"
calculate_diff() {
  local source_dir="$1"
  local target_dir="$2"
  local skill_name="$3"
  
  if [ ! -d "$target_dir" ]; then
    echo "new"
    return
  fi
  
  # Try git diff first if both are in git repos
  if command -v git &> /dev/null; then
    local source_git=$(cd "$source_dir" && git rev-parse --git-dir 2>/dev/null || echo "")
    local target_git=$(cd "$target_dir" && git rev-parse --git-dir 2>/dev/null || echo "")
    
    if [ -n "$source_git" ] && [ -n "$target_git" ]; then
      # Both are in git, use git diff
      local diff_output=$(cd "$(dirname "$source_dir")" && git diff --shortstat "$(basename "$source_dir")" "$target_dir" 2>/dev/null || echo "")
      if [ -n "$diff_output" ]; then
        echo "$diff_output"
        return
      fi
    fi
  fi
  
  # Fall back to unified diff for meaningful change calculation
  local diff_output=$(diff -rq "$source_dir" "$target_dir" 2>/dev/null | wc -l || echo "0")
  local file_count=$(echo "$diff_output" | head -1)
  
  if [ "$file_count" -eq 0 ]; then
    echo "identical"
    return
  fi
  
  # Calculate line changes using unified diff
  local line_changes=0
  local added=0
  local removed=0
  
  # Get unified diff and count actual line changes
  while IFS= read -r line; do
    if [[ "$line" =~ ^\+[^+] ]]; then
      added=$((added + 1))
    elif [[ "$line" =~ ^-[^-] ]]; then
      removed=$((removed + 1))
    fi
  done < <(diff -u "$source_dir" "$target_dir" 2>/dev/null || true)
  
  line_changes=$((added + removed))
  
  if [ $line_changes -eq 0 ]; then
    echo "identical"
  else
    echo "${file_count} files, +${added} -${removed} lines"
  fi
}

# ----------------------------------------------------------------------------
# Show Diff Preview
# ----------------------------------------------------------------------------
# Displays a preview of changes between source and target directories.
#
# Parameters:
#   $1 - Source directory path
#   $2 - Target directory path
#   $3 - Skill name (for context)
show_diff_preview() {
  local source_dir="$1"
  local target_dir="$2"
  local skill_name="$3"
  
  if [ ! -d "$target_dir" ]; then
    return
  fi
  
  log_info "Preview of changes for '${skill_name}':"
  echo ""
  
  # Show first few lines of unified diff
  local preview=$(diff -u "$target_dir" "$source_dir" 2>/dev/null | head -30 || echo "")
  if [ -n "$preview" ]; then
    echo "$preview" | head -20
    local total_lines=$(echo "$preview" | wc -l)
    if [ "$total_lines" -gt 20 ]; then
      echo "... (${total_lines} more lines)"
    fi
  fi
  echo ""
}

# ============================================================================
# MCP CONFIGURATION
# ============================================================================

# ----------------------------------------------------------------------------
# Get MCP Server Type from Config
# ----------------------------------------------------------------------------
# Gets the MCP server type (remote/local) by detecting from server config.
# Remote = has "url" field, Local = has "command" field
#
# Parameters:
#   $1 - Server config (JSON string)
#
# Returns:
#   "remote" or "local" via stdout, or empty string if unknown
get_mcp_server_type() {
  local server_config="$1"
  
  if echo "$server_config" | jq -e '.url' > /dev/null 2>&1; then
    echo "remote"
    return 0
  fi
  
  if echo "$server_config" | jq -e '.command' > /dev/null 2>&1; then
    echo "local"
    return 0
  fi
  
  echo ""
  return 0
}

# ----------------------------------------------------------------------------
# Substitute API Keys in Server Config
# ----------------------------------------------------------------------------
# Replaces placeholder API keys in server config with values from .env
#
# Parameters:
#   $1 - Server config (JSON string)
#   $2 - Server name
#
# Returns:
#   Modified JSON string via stdout
substitute_api_keys() {
  local server_config="$1"

  # Load environment values (or empty if not set)
  local tavily_val="${TAVILY_API_KEY:-}"
  local context7_val="${CONTEXT7_API_KEY:-}"
  local zai_val="${Z_AI_API_KEY:-}"
  local openalex_val="${OPENALEX_EMAIL:-}"

  # Optimized: Single jq call with all --arg parameters for safety and performance
  echo "$server_config" | jq \
    --arg tavily "$tavily_val" \
    --arg context7 "$context7_val" \
    --arg zai "$zai_val" \
    --arg openalex "$openalex_val" \
    --arg env_context7 '${env:CONTEXT7_API_KEY}' \
    --arg env_zai '${env:Z_AI_API_KEY}' \
    --arg env_openalex '${env:OPENALEX_EMAIL}' \
    '
    if (.headers.Authorization // "" | test("TAVILY_API_KEY|Z_AI_API_KEY")) and $tavily != "" then
      .headers.Authorization = "Bearer " + $tavily
    elif (.headers.AUTHORIZATION // "" | test("TAVILY_API_KEY|Z_AI_API_KEY")) and $zai != "" then
      .headers.AUTHORIZATION = "Bearer " + $zai
    else .
    end
    | if (.headers.CONTEXT7_API_KEY // null) and $context7 != "" then .headers.CONTEXT7_API_KEY = $env_context7 else . end
    | if (.env.Z_AI_API_KEY // null) and $zai != "" then .env.Z_AI_API_KEY = $env_zai else . end
    | if (.env.OPENALEX_EMAIL // null) and $openalex != "" then .env.OPENALEX_EMAIL = $env_openalex else . end
  '
}

# ----------------------------------------------------------------------------
# Convert MCP to OpenCode Format
# ----------------------------------------------------------------------------
# Converts standard MCP server configuration to OpenCode format.
# Per OpenCode docs: https://opencode.ai/docs/mcp-servers/
#
# Parameters:
#   $1 - Server name
#   $2 - Server config (JSON string from config/mcps.json)
#
# Returns:
#   OpenCode-formatted JSON config via stdout
#   Returns 1 on error
#
# Format Conversion:
#   - Detects type from config (url = remote, command = local)
#   - env field → environment field
#   - Always adds enabled: true
convert_mcp_to_opencode() {
  local server_name="$1"
  local server_config="$2"
  
  # Substitute API keys from .env before conversion
  server_config=$(substitute_api_keys "$server_config" "$server_name")
  
  # Get server type by detecting from config (url = remote, command = local)
  local server_type=$(get_mcp_server_type "$server_config")
  
  # Handle remote MCPs (detected by type or URL field)
  if [ "$server_type" = "remote" ] || { [ -z "$server_type" ] && echo "$server_config" | jq -e '.url' > /dev/null 2>&1; }; then
    local url=""
    local headers="{}"
    
    # Extract URL from config
    if echo "$server_config" | jq -e '.url' > /dev/null 2>&1; then
      url=$(echo "$server_config" | jq -r '.url')
      headers=$(echo "$server_config" | jq -c '.headers // {}')
    else
      log_error "Remote MCP ${server_name} requires URL but none found in config"
      return 1
    fi
    
    # Build OpenCode remote MCP format
    jq -n \
      --arg url "$url" \
      --argjson headers "$headers" \
      '{
        type: "remote",
        url: $url,
        headers: $headers,
        enabled: true
      }'
    return $?
  fi
  
  # Check if it's a local MCP (has "command" field or metadata says local)
  if [ "$server_type" = "local" ] || echo "$server_config" | jq -e '.command' > /dev/null 2>&1; then
    local command=$(echo "$server_config" | jq -r '.command')
    local cmd_args=$(echo "$server_config" | jq -c '.args // []')
    local env=$(echo "$server_config" | jq -c '.env // {}')
    
    # Build command array: [command, ...args] using jq
    local cmd_array=$(echo "$cmd_args" | jq -c --arg cmd "$command" '[$cmd] + .')
    
    # Build OpenCode local MCP format
    jq -n \
      --argjson cmd "$cmd_array" \
      --argjson env "$env" \
      '{
        type: "local",
        command: $cmd,
        environment: $env,
        enabled: true
      }'
    return $?
  fi
  
  # Unknown format
  log_error "Unknown MCP server format for ${server_name} (must have 'url' or 'command' field, or type in config/mcps.json)"
  return 1
}

# ----------------------------------------------------------------------------
# Get MCP server names from config (shared prelude for OpenCode/Cursor)
# ----------------------------------------------------------------------------
# Validates jq, MCP_CONFIG file, JSON; loads .env; outputs server name list.
# Call: server_names=$(get_mcp_server_names "OpenCode") || return 1
get_mcp_server_names() {
  local label="${1:-MCP}"
  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping ${label} MCP configuration."
    log_info "Install jq to enable automatic MCP configuration:"
    log_info "  macOS: brew install jq"
    log_info "  Linux: sudo apt-get install jq"
    return 1
  fi
  if [ ! -f "$MCP_CONFIG" ]; then
    log_warning "config/mcps.json not found at ${MCP_CONFIG}"
    log_info "Skipping ${label} MCP configuration"
    return 1
  fi
  if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
    log_error "config/mcps.json is not valid JSON"
    return 1
  fi
  load_env_file || true
  local server_names
  server_names=$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG")
  if [ -z "$server_names" ]; then
    log_error "No mcpServers found in config/mcps.json"
    return 1
  fi
  echo "$server_names"
  return 0
}

# ----------------------------------------------------------------------------
# Apply Cursor env interpolation (${env:VAR})
# ----------------------------------------------------------------------------
# Replaces placeholder API key values with ${env:VAR} so Cursor resolves them
# at runtime. Cursor docs: https://cursor.com/docs/context/mcp (Config interpolation)
#
# Parameters:
#   $1 - Server config (JSON string, already stripped of _ keys)
#
# Returns:
#   JSON with placeholder values replaced by ${env:VAR}
apply_cursor_env_interpolation() {
  local config="$1"
  local rep placeholder
  # Authorization header: placeholder -> ${env:VAR} (loop over known placeholders)
  for placeholder in TAVILY_API_KEY Z_AI_API_KEY; do
    if echo "$config" | jq -e ".headers.Authorization | strings | test(\"$placeholder\")" > /dev/null 2>&1; then
      rep='${env:'"$placeholder"'}'
      config=$(echo "$config" | jq --arg r "$rep" '.headers.Authorization |= gsub("'"$placeholder"'"; $r)')
    fi
  done
  # Direct key = ${env:VAR} (single jq for all optional keys)
  config=$(echo "$config" | jq \
    --arg env_context7 '${env:CONTEXT7_API_KEY}' \
    --arg env_zai '${env:Z_AI_API_KEY}' \
    --arg env_openalex '${env:OPENALEX_EMAIL}' \
    '
    if (.headers.CONTEXT7_API_KEY // null) then .headers.CONTEXT7_API_KEY = $env_context7 else . end
    | if (.env.Z_AI_API_KEY // null) then .env.Z_AI_API_KEY = $env_zai else . end
    | if (.env.OPENALEX_EMAIL // null) then .env.OPENALEX_EMAIL = $env_openalex else . end
  ')
  echo "$config"
}

# ----------------------------------------------------------------------------
# Check if Cursor Config Has Literal Placeholders
# ----------------------------------------------------------------------------
# Checks if a Cursor MCP configuration contains literal placeholder values that
# should be replaced with ${env:VAR} format so Cursor resolves them at runtime.
#
# Parameters:
#   $1 - Cursor config as string (from jq tostring)
#
# Returns:
#   0 (true) if config has literal placeholders that need updating
#   1 (false) if config already uses ${env:VAR} format
cursor_has_literal_placeholders() {
  local config_str="$1"
  
  # Check if Authorization header contains literal placeholder strings (not ${env:VAR})
  # The placeholders TAVILY_API_KEY and Z_AI_API_KEY should be ${env:TAVILY_API_KEY} etc.
  if echo "$config_str" | jq -e '.headers.Authorization | strings | test("TAVILY_API_KEY|Z_AI_API_KEY")' > /dev/null 2>&1; then
    return 0  # Has literal placeholders
  fi
  
  # Check if any of these keys exist and are NOT already in ${env:VAR} format
  # Test if string values start with "${env:" pattern
  if echo "$config_str" | jq -e '
    (.headers.CONTEXT7_API_KEY // false | type == "string") and
    (.headers.CONTEXT7_API_KEY | test("^\\$\\{env:") == false)
  ' > /dev/null 2>&1; then
    return 0
  fi
  
  if echo "$config_str" | jq -e '
    (.env.Z_AI_API_KEY // false | type == "string") and
    (.env.Z_AI_API_KEY | test("^\\$\\{env:") == false)
  ' > /dev/null 2>&1; then
    return 0
  fi
  
  if echo "$config_str" | jq -e '
    (.env.OPENALEX_EMAIL // false | type == "string") and
    (.env.OPENALEX_EMAIL | test("^\\$\\{env:") == false)
  ' > /dev/null 2>&1; then
    return 0
  fi
  
  # No literal placeholders found
  return 1
}

# ----------------------------------------------------------------------------
# Convert MCP to Cursor Format
# ----------------------------------------------------------------------------
# Produces Cursor-native mcpServers entry: strip _-prefixed keys, then apply
# ${env:VAR} interpolation so Cursor resolves API keys at runtime (no secrets
# written to disk). Cursor docs: https://cursor.com/docs/context/mcp
#
# Parameters:
#   $1 - Server name
#   $2 - Server config (JSON string from config/mcps.json)
#
# Returns:
#   Clean JSON config via stdout (no _* keys, ${env:VAR} for API keys)
convert_mcp_to_cursor() {
  local server_name="$1"
  local server_config="$2"
  # Strip keys starting with _
  local clean=$(echo "$server_config" | jq -c 'with_entries(select(.key | startswith("_") | not))')
  apply_cursor_env_interpolation "$clean"
}

# ----------------------------------------------------------------------------
# Safe JSON Update with Backup and Rollback
# ----------------------------------------------------------------------------
# Performs atomic JSON file updates with automatic backup creation.
# If update fails, automatically restores from backup.
#
# Parameters:
#   $1 - Target file path
#   $2 - jq filter/expression to apply
#   $3 - Description/label for logging (optional)
#
# Returns:
#   0 on success, 1 on failure (with backup restored)
safe_json_update() {
  local file="$1"
  local jq_filter="$2"
  local label="${3:-JSON update}"
  local backup="${file}.backup"
  
  # Create backup before modification
  dry_run_aware_cp "$file" "$backup"
  
  # Atomic update: write to temp file, then move
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would update $label in $file"
    return 0
  fi

  if jq "$jq_filter" "$file" > "${file}.tmp" && dry_run_aware_mv "${file}.tmp" "$file"; then
    log_success "Updated $label"
    return 0
  else
    log_error "Failed to update $label, restoring from backup"
    dry_run_aware_mv "$backup" "$file"
    return 1
  fi
}

# ----------------------------------------------------------------------------
# Configure MCP Servers for Generic Platform
# ----------------------------------------------------------------------------
# Configures MCP servers for any platform (OpenCode or Cursor).
# Reads from config/mcps.json, converts to platform format, and updates config file.
#
# IMPORTANT: Preserves existing MCP configurations and only adds missing ones.
# It will NEVER overwrite an existing MCP server configuration.
#
# Parameters:
#   $1 - Platform: $PLATFORM_OPENCODE or $PLATFORM_CURSOR
#   $2 - Config file path (OPENCODE_CONFIG or CURSOR_MCP_CONFIG)
#   $3 - Section key: $SECTION_MCP (OpenCode) or $SECTION_MCPSERVERS (Cursor)
#   $4 - Format conversion function name (e.g., "convert_mcp_to_opencode")
#
# Returns:
#   0 on success, 1 on failure
configure_mcp_platform() {
  local platform="$1"
  local config_path="$2"
  local section_key="$3"
  local format_converter="$4"
  
  log_info "━━━ ${platform^} MCP Configuration ━━━"
  log_info "Checking MCP configuration for $platform..."  
  # Common preflight checks
  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping $platform MCP configuration."
    return 0
  fi
  
  if [ ! -f "$MCP_CONFIG" ]; then
    log_warning "config/mcps.json not found at ${MCP_CONFIG}. Skipping $platform MCP configuration."
    return 0
  fi
  
  if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
    log_error "config/mcps.json is not valid JSON"
    return 1
  fi
  
  load_env_file || true
  
  local server_names=$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG")
  if [ -z "$server_names" ]; then
    log_error "No mcpServers found in config/mcps.json"
    return 1
  fi
  
  local config_dir=$(dirname "$config_path")
  dry_run_aware_mkdir -p "$config_dir"
  
  # Handle existing or new config
  if [ -f "$config_path" ]; then
    # Existing config: validate and backup
    if ! jq empty "$config_path" 2>/dev/null; then
      log_error "Existing $platform config is not valid JSON. Creating backup and starting fresh..."
      dry_run_aware_mv "$config_path" "${config_path}.invalid.$(date +%s).backup"
      jq -n "{\"$section_key\": {}}" | dry_run_aware_write "$config_path"
    fi
    
    # Ensure section exists
    if ! jq -e ".$section_key" "$config_path" > /dev/null 2>&1; then
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would ensure section $section_key exists in $config_path"
      else
        jq ".$section_key = {}" "$config_path" > "${config_path}.tmp" && \
          dry_run_aware_mv "${config_path}.tmp" "$config_path"
      fi
    fi
    
    dry_run_aware_cp "$config_path" "${config_path}.backup"
    log_info "Backup created: ${config_path}.backup"
    
    # Process servers using unified logic
    local added_count=0
    local skipped_count=0
    local updated_count=0
    
    while IFS= read -r server_name; do
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        continue
      fi
      
      # Use: provided format converter (function passed as argument)
      local platform_config=$($format_converter "$server_name" "$server_config")
      
      if jq -e ".${section_key}.\"${server_name}\"" "$config_path" > /dev/null 2>&1; then
        # Server exists: check if needs update
        if [ "$platform" = $PLATFORM_CURSOR ] && command -v cursor_has_literal_placeholders 2>/dev/null; then
          local current=$(jq -c ".${section_key}.\"${server_name}\"" "$config_path")
          local current_str=$(jq -r ".${section_key}.\"${server_name}\" | tostring" "$config_path")
          if cursor_has_literal_placeholders "$current_str"; then
            if safe_json_update "$config_path" ".${section_key}.\"${server_name}\" = \$platform_config" "$server_name"; then
              updated_count=$((updated_count + 1))
            fi
          else
            log_info "  ${server_name}: already configured, preserving existing configuration"
            skipped_count=$((skipped_count + 1))
          fi
        else
          log_info "  ${server_name}: already configured, preserving existing configuration"
          skipped_count=$((skipped_count + 1))
        fi
      else
        # Server doesn't exist: add it
        if safe_json_update "$config_path" ".${section_key}.\"${server_name}\" = \$platform_config" "$server_name"; then
          log_success "  ${server_name}: added"
          added_count=$((added_count + 1))
        else
          log_error "  ${server_name}: failed to add; restoring backup"
          return 1
        fi
      fi
    done <<< "$server_names"
    
    # Summary output
    if [ $added_count -gt 0 ]; then
      log_success "Added ${added_count} MCP server(s) to ${config_path}"
    fi
    if [ "$platform" = $PLATFORM_CURSOR ] && [ $updated_count -gt 0 ]; then
      log_success "Updated ${updated_count} server(s) to use \${env:VAR} (set Z_AI_API_KEY etc. in your environment or Cursor settings)"
    fi
    if [ $skipped_count -gt 0 ]; then
      log_info "Preserved ${skipped_count} already configured server(s)"
    fi
    if [ $added_count -eq 0 ] && [ $skipped_count -eq 0 ]; then
      log_info "No changes needed - all MCPs from config are already configured"
    fi
  
  else
    # New config: create from scratch
    log_info "Creating new $platform MCP configuration from config/mcps.json..."
    local mcp_section='{}'
    
    while IFS= read -r server_name; do
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        continue
      fi
      
      local platform_config=$($format_converter "$server_name" "$server_config")
      mcp_section=$(echo "$mcp_section" | jq --arg name "$server_name" --argjson config "$platform_config" '.[$name] = $config')
    done <<< "$server_names"
    
    local new_config=$(jq -n --argjson mcp "$mcp_section" "{\"$section_key\": \$mcp}")
    echo "$new_config" | dry_run_aware_write "$config_path"
    log_success "Created $platform MCP configuration at ${config_path}"
    log_info "Configured $(echo "$mcp_section" | jq 'length') MCP server(s)"
  fi
}

# ----------------------------------------------------------------------------
# Validate JSON File
# ----------------------------------------------------------------------------
# Checks if a file exists and contains valid JSON.
#
# Parameters:
#   $1 - File path to validate
#   $2 - Label/description for error message (optional)
#
# Returns:
#   0 if valid, 1 if invalid or missing
validate_json_file() {
  local file="$1"
  local label="${2:-config file}"
  
  if [[ ! -f "$file" ]]; then
    log_error "$label not found: $file"
    return 1
  fi
  
  if ! jq empty "$file" 2>/dev/null; then
    log_error "$label ($file) is not valid JSON"
    return 1
  fi
  
  return 0
}

# ----------------------------------------------------------------------------
# Configure MCP Servers for OpenCode
# ----------------------------------------------------------------------------
# Configures MCP servers for OpenCode agent using OpenCode format.
# Reads from config/mcps.json, converts to OpenCode format, and updates opencode.json.
#
# IMPORTANT: Preserves existing MCP configurations and only adds missing ones.
# It will NEVER overwrite an existing MCP server configuration.
#
# Format: opencode.json with mcp section
#   {
#     "$schema": "https://opencode.ai/config.json",
#     $SECTION_MCP: {
#       "server-name": {
#         "type": "local" | "remote",
#         "command": [...] | "url": "...",
#         "environment": {} | "headers": {},
#         "enabled": true
#       }
#     }
#   }
#
# References:
#   - OpenCode MCP docs: https://opencode.ai/docs/mcp-servers/
configure_mcp_opencode() {
  # Call unified MCP platform configuration (preserves backward compatibility)
  configure_mcp_platform "$PLATFORM_OPENCODE" "$OPENCODE_CONFIG" "$SECTION_MCP" "convert_mcp_to_opencode"
}

# ----------------------------------------------------------------------------
# Configure MCP Servers for Cursor
# ----------------------------------------------------------------------------
# Configures MCP servers for Cursor (global ~/.cursor/mcp.json).
# Reads from config/mcps.json, strips _-prefixed keys, substitutes API keys,
# and merges into Cursor config. Only adds missing servers; never overwrites.
#
# Format: ~/.cursor/mcp.json with mcpServers (Cursor native)
#   { $SECTION_MCPSERVERS: { "server-name": { "url" | "command", ... } } }
#
# References: https://cursor.com/docs/context/mcp
configure_mcp_cursor() {
  log_info "Checking MCP configuration for Cursor..."
  
  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping Cursor MCP configuration."
    log_info "Install jq to enable automatic MCP configuration (see OpenCode MCP section above)."
    return 0
  fi

  if [ ! -f "$MCP_CONFIG" ]; then
    log_warning "config/mcps.json not found at ${MCP_CONFIG}. Skipping Cursor MCP configuration"
    return
  fi

  local cursor_config_dir=$(dirname "$CURSOR_MCP_CONFIG")
  dry_run_aware_mkdir -p "$cursor_config_dir"

  if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
    log_error "config/mcps.json is not valid JSON"
    return 1
  fi

  load_env_file || true

  local server_names=$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG")
  if [ -z "$server_names" ]; then
    log_error "No mcpServers found in config/mcps.json"
    return 1
  fi

  if [ -f "$CURSOR_MCP_CONFIG" ]; then
    if ! jq empty "$CURSOR_MCP_CONFIG" 2>/dev/null; then
      log_error "Existing Cursor MCP config is not valid JSON. Creating backup and starting fresh..."
      dry_run_aware_mv "$CURSOR_MCP_CONFIG" "${CURSOR_MCP_CONFIG}.invalid.$(date +%s).backup"
      echo '{$SECTION_MCPSERVERS: {}}' | dry_run_aware_write "$CURSOR_MCP_CONFIG"
    fi

    if ! jq -e '.mcpServers' "$CURSOR_MCP_CONFIG" > /dev/null 2>&1; then
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would ensure mcpServers section exists in $CURSOR_MCP_CONFIG"
      else
        jq '.mcpServers = {}' "$CURSOR_MCP_CONFIG" > "${CURSOR_MCP_CONFIG}.tmp" && \
          dry_run_aware_mv "${CURSOR_MCP_CONFIG}.tmp" "$CURSOR_MCP_CONFIG"
      fi
    fi

    dry_run_aware_cp "$CURSOR_MCP_CONFIG" "${CURSOR_MCP_CONFIG}.backup"
    local added_count=0
    local skipped_count=0
    local updated_count=0

    while IFS= read -r server_name; do
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        continue
      fi

      local cursor_config=$(convert_mcp_to_cursor "$server_name" "$server_config")

      if jq -e ".mcpServers.\"${server_name}\"" "$CURSOR_MCP_CONFIG" > /dev/null 2>&1; then
        # Server already exists: update if it has literal placeholders (so Cursor resolves ${env:VAR} at runtime)
        local current=$(jq -c ".mcpServers.\"${server_name}\"" "$CURSOR_MCP_CONFIG")
        local current_str=$(echo "$current" | jq -r 'tostring')
        if cursor_has_literal_placeholders "$current_str"; then
          if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would update ${server_name} in $CURSOR_MCP_CONFIG"
            updated_count=$((updated_count + 1))
          elif jq --arg name "$server_name" --argjson config "$cursor_config" \
             '.mcpServers[$name] = $config' "$CURSOR_MCP_CONFIG" > "${CURSOR_MCP_CONFIG}.tmp" && \
             dry_run_aware_mv "${CURSOR_MCP_CONFIG}.tmp" "$CURSOR_MCP_CONFIG"; then
            log_success "  ${server_name}: updated to use \${env:VAR} (Cursor resolves at runtime)"
            updated_count=$((updated_count + 1))
          fi
        else
          log_info "  ${server_name}: already configured, preserving existing configuration"
          skipped_count=$((skipped_count + 1))
        fi
        continue
      fi

      # Server doesn't exist, add it
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would add ${server_name} to $CURSOR_MCP_CONFIG"
        added_count=$((added_count + 1))
      elif jq --arg name "$server_name" --argjson config "$cursor_config" \
         '.mcpServers[$name] = $config' "$CURSOR_MCP_CONFIG" > "${CURSOR_MCP_CONFIG}.tmp" && \
         dry_run_aware_mv "${CURSOR_MCP_CONFIG}.tmp" "$CURSOR_MCP_CONFIG"; then
        log_success "  ${server_name}: added"
        added_count=$((added_count + 1))
      else
        dry_run_aware_mv "${CURSOR_MCP_CONFIG}.backup" "$CURSOR_MCP_CONFIG"
        log_error "  ${server_name}: failed to add; restored backup"
        return 1
      fi
    done <<< "$server_names"

    if [ $added_count -gt 0 ]; then
      log_success "Added ${added_count} MCP server(s) to ${CURSOR_MCP_CONFIG}"
    fi
    if [ $updated_count -gt 0 ]; then
      log_success "Updated ${updated_count} server(s) to use \${env:VAR} (set Z_AI_API_KEY etc. in your environment or Cursor settings)"
    fi
    if [ $skipped_count -gt 0 ]; then
      log_info "Preserved ${skipped_count} already configured server(s)"
    fi
    if [ $added_count -eq 0 ] && [ $skipped_count -eq 0 ]; then
      log_info "No changes needed - all MCPs from config are already configured"
    fi
  else
    log_info "Creating new Cursor MCP configuration from config/mcps.json..."
    local mcp_section='{}'
    while IFS= read -r server_name; do
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        continue
      fi
      local cursor_config=$(convert_mcp_to_cursor "$server_name" "$server_config")
      mcp_section=$(echo "$mcp_section" | jq --arg name "$server_name" --argjson config "$cursor_config" '.[$name] = $config')
    done <<< "$server_names"

    local new_config=$(jq -n --argjson mcp "$mcp_section" '{mcpServers: $mcp}')
    echo "$new_config" | dry_run_aware_write "$CURSOR_MCP_CONFIG"
    log_success "Created Cursor MCP configuration at ${CURSOR_MCP_CONFIG}"
    log_info "Configured $(echo "$mcp_section" | jq 'length') MCP server(s)"
  fi
}

# ----------------------------------------------------------------------------
# Configure OpenCode Tool Filtering
# ----------------------------------------------------------------------------
# Reads _disabledTools from config/mcps.json and adds them to the tools section
# of opencode.json. Format: "server-name_tool-name": false
#
# OpenCode uses a top-level tools section for filtering, not per-server.
configure_opencode_tool_filtering() {
  local tools_config='{}'
  
  while IFS= read -r server_name; do
    local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
    if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
      continue
    fi
    
    local disabled_tools=$(echo "$server_config" | jq -r '._disabledTools // {} | keys[] | select(startswith("_") | not)')
    if [ -n "$disabled_tools" ]; then
      while IFS= read -r tool_name; do
        local full_tool_name="${server_name}_${tool_name}"
        tools_config=$(echo "$tools_config" | jq --arg name "$full_tool_name" '.[$name] = false')
      done <<< "$disabled_tools"
    fi
  done <<< "$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG")"
  
  if [ "$tools_config" != "{}" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY RUN] Would configure tool filtering in $OPENCODE_CONFIG"
    else
      if jq -e '.tools' "$OPENCODE_CONFIG" > /dev/null 2>&1; then
        jq --argjson new_tools "$tools_config" '.tools = (.tools + $new_tools)' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
          dry_run_aware_mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"
      else
        jq --argjson new_tools "$tools_config" '.tools = $new_tools' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
          dry_run_aware_mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"
      fi
    fi
    local disabled_count=$(echo "$tools_config" | jq 'length')
    log_info "Configured ${disabled_count} disabled tool(s) in OpenCode"
  fi
}

configure_opencode_plugins() {
  local plugin_source_dir="${CONTENT_DIR}/plugins"
  local plugin_config_source="${PLUGIN_CONFIG}"

  if [ ! -d "${CONTENT_DIR}/plugins" ]; then
    log_info "No local ${CONTENT_DIR} plugins found, skipping plugin installation"
    return 0
  fi

  if [ ! -d "$plugin_source_dir" ]; then
    log_info "No local OpenCode plugins found, skipping plugin installation"
    return 0
  fi

  local opencode_config_dir
  opencode_config_dir=$(dirname "$OPENCODE_CONFIG")
  local opencode_plugin_dir="${opencode_config_dir}/plugin"
  dry_run_aware_mkdir -p "$opencode_plugin_dir"

  local installed=0
  local updated=0
  local skipped=0

  for plugin_file in "$plugin_source_dir"/*; do
    [ -f "$plugin_file" ] || continue
    local plugin_name
    plugin_name=$(basename "$plugin_file")
    local target_file="${opencode_plugin_dir}/${plugin_name}"

    if [ -f "$target_file" ]; then
      if diff -q "$plugin_file" "$target_file" >/dev/null 2>&1; then
        skipped=$((skipped + 1))
        continue
      fi
      if confirm_action "Overwrite OpenCode plugin ${plugin_name}?"; then
        dry_run_aware_cp "$plugin_file" "$target_file"
        updated=$((updated + 1))
      else
        skipped=$((skipped + 1))
      fi
    else
      dry_run_aware_cp "$plugin_file" "$target_file"
      installed=$((installed + 1))
    fi
  done

  log_success "OpenCode plugins: ${installed} installed, ${updated} updated, ${skipped} skipped"

  if [ ! -f "$plugin_config_source" ]; then
    log_info "plugin.json not found, skipping plugin config merge"
    return 0
  fi

  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping plugin.json merge."
    if [ ! -f "${opencode_config_dir}/plugin.json" ]; then
      dry_run_aware_cp "$plugin_config_source" "${opencode_config_dir}/plugin.json"
      log_success "Copied plugin.json to ${opencode_config_dir}/plugin.json"
    fi
    return 0
  fi

  if ! jq empty "$plugin_config_source" 2>/dev/null; then
    log_error "plugin.json is not valid JSON, skipping plugin config merge"
    return 1
  fi

  local target_plugin_config="${opencode_config_dir}/plugin.json"
  if [ -f "$target_plugin_config" ]; then
    if ! jq empty "$target_plugin_config" 2>/dev/null; then
      log_error "Existing plugin.json is not valid JSON. Creating backup and replacing."
      dry_run_aware_mv "$target_plugin_config" "${target_plugin_config}.invalid.$(date +%s).backup"
      dry_run_aware_cp "$plugin_config_source" "$target_plugin_config"
      return 0
    fi

    dry_run_aware_cp "$target_plugin_config" "${target_plugin_config}.backup"
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY RUN] Would merge plugin.json into ${target_plugin_config}"
    elif jq -s '.[0] * .[1]' "$plugin_config_source" "$target_plugin_config" > "${target_plugin_config}.tmp" && \
      dry_run_aware_mv "${target_plugin_config}.tmp" "$target_plugin_config"; then
      log_success "Merged plugin.json into ${target_plugin_config} (source values override existing)"
    else
      dry_run_aware_mv "$target_plugin_config" "${target_plugin_config}.backup"
      log_error "Failed to merge plugin.json, restored backup"
      return 1
    fi
  else
    dry_run_aware_cp "$plugin_config_source" "$target_plugin_config"
    log_success "Installed plugin.json to ${target_plugin_config}"
  fi
}

# ----------------------------------------------------------------------------
# Configure OpenCode Custom Agents
# ----------------------------------------------------------------------------
# Reads agents.json and injects agent definitions into opencode.json.
# Agents are merged into the "agent" section of the config.
#
# OpenCode agent format: https://opencode.ai/docs/agents/
configure_opencode_agents() {
  if [ ! -f "$AGENTS_CONFIG" ]; then
    log_info "No agents.json found, skipping agent configuration"
    return 0
  fi
  
  if [ ! -f "$OPENCODE_CONFIG" ]; then
    log_warning "OpenCode config not found, skipping agent configuration"
    return 0
  fi
  
  log_info "Configuring custom agents from agents.json..."
  
  # Read agents from agents.json
  local agents_data
  agents_data=$(jq -c '.agents // {}' "$AGENTS_CONFIG" 2>/dev/null)
  
  if [ -z "$agents_data" ] || [ "$agents_data" = "{}" ] || [ "$agents_data" = "null" ]; then
    log_info "No agents defined in agents.json"
    return 0
  fi
  
  # Resolve {file:path} syntax in agent prompts
  # This reads the file content and replaces the placeholder
  local agent_names
  agent_names=$(echo "$agents_data" | jq -r 'keys[]')
  
  while IFS= read -r agent_name; do
    local prompt_value
    prompt_value=$(echo "$agents_data" | jq -r ".\"$agent_name\".prompt // empty")
    
    # Check if prompt uses {file:path} syntax
    if [[ "$prompt_value" =~ ^\{file:(.+)\}$ ]]; then
      local file_path="${BASH_REMATCH[1]}"

      # Security: Prevent path traversal attacks
      # Get canonical ATELIER_DIR to handle any symlinks
      local canonical_atelier_dir
      if command -v realpath >/dev/null 2>&1; then
        canonical_atelier_dir=$(realpath "$ATELIER_DIR" 2>/dev/null) || canonical_atelier_dir="$ATELIER_DIR"
      else
        canonical_atelier_dir="$ATELIER_DIR"
      fi

      # Build full path and resolve it to canonical form
      local full_path="${ATELIER_DIR}/${file_path}"

      # Resolve to canonical absolute path to normalize symlinks
      # Use cd+pwd-P approach for macOS compatibility (realpath -m is GNU-specific)
      local resolved_path
      local resolved_dir
      if ! resolved_dir=$(cd "$(dirname "$full_path")" 2>/dev/null && pwd -P); then
        log_error "  ${agent_name}: directory for prompt file not found or is invalid: $(dirname "$full_path")"
        continue
      fi
      resolved_path="${resolved_dir}/$(basename "$full_path")"

      # Verify the resolved path is under ATELIER_DIR using canonical paths
      # This prevents both path traversal (via symlinks) and sibling directory attacks
      # Use trailing slashes to prevent sibling directory attacks (e.g., /home/user/repo-malicious)
      case "$resolved_path/" in
        "${canonical_atelier_dir}/"*)
          # OK: resolved_path is within ATELIER_DIR
          ;;
        *)
          log_error "  ${agent_name}: path traversal detected: ${file_path} resolves to ${resolved_path} which is outside ${canonical_atelier_dir}"
          continue
          ;;
      esac

      if [ -f "$resolved_path" ]; then
        # Read file content and escape for JSON
        local file_content
        file_content=$(cat "$resolved_path")
        
        # Update the agent's prompt with file content using jq
        agents_data=$(echo "$agents_data" | jq --arg name "$agent_name" --arg content "$file_content" \
          '.[$name].prompt = $content')
        
        log_info "  ${agent_name}: resolved prompt from ${file_path}"
      else
        log_warning "  ${agent_name}: file not found: ${full_path}"
      fi
    fi
  done <<< "$agent_names"
  
  # Merge agents into opencode.json
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would merge custom agents into $OPENCODE_CONFIG"
  else
    if jq -e '.agent' "$OPENCODE_CONFIG" > /dev/null 2>&1; then
      # Merge with existing agents
      jq --argjson new_agents "$agents_data" '.agent = (.agent + $new_agents)' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
        dry_run_aware_mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"
    else
      # Create agent section
      jq --argjson new_agents "$agents_data" '.agent = $new_agents' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
        dry_run_aware_mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"
    fi
  fi
  
  local agent_count
  agent_count=$(echo "$agents_data" | jq 'length')
  log_success "Configured ${agent_count} custom agent(s) in OpenCode"
}

# ============================================================================
# CLAUDE HOOKS CONFIGURATION
# ============================================================================
#
# oh-my-opencode provides Agent Skills compatibility, including hooks.
# Hooks are loaded from these locations and MERGED (not overwritten):
#   1. ~/.claude/settings.json (global - we install here)
#   2. ./.claude/settings.json (project-level)
#   3. ./.claude/settings.local.json (local override)
#
# Hook definitions are read from hooks.json for extensibility.
#
# Source: https://github.com/code-yeongyu/oh-my-opencode
#         src/hooks/claude-code-hooks/config.ts

AGENT_CONFIG_DIR="${HOME}/.claude"
AGENT_CONFIG="${AGENT_CONFIG_DIR}/settings.json"
HOOKS_SOURCE="$HOOKS_CONFIG"

add_or_update_hook() {
  local hook_script="$1"
  local hook_type="$2"     # e.g., PreToolUse
  local tool_matcher="$3"  # e.g., Bash
  local full_command="bash ${hook_script}"

  hook_exists=$(jq -r --arg cmd "$full_command" ".hooks.${hook_type}[] | select(.matcher == \"${tool_matcher}\") | .hooks[]? | select(.command == \$cmd) | .command" "$AGENT_CONFIG" 2>/dev/null | wc -l || echo "0")
  if [ "$hook_exists" -gt 0 ]; then
    return 1
  else
    matcher_exists=$(jq -r ".hooks.${hook_type}[] | select(.matcher == \"${tool_matcher}\") | .matcher" "$AGENT_CONFIG" 2>/dev/null || true)
    if [ -n "$matcher_exists" ]; then
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would update hook matcher '${tool_matcher}' in $AGENT_CONFIG"
      else
        jq --arg hook_script "$full_command" \
          --arg hook_type "$hook_type" \
          --arg tool_matcher "$tool_matcher" \
          '(.hooks[$hook_type][] | select(.matcher == $tool_matcher)).hooks += [{ type: "command", command: $hook_script }]' \
          "$AGENT_CONFIG" > "${AGENT_CONFIG}.tmp" && \
          dry_run_aware_mv "${AGENT_CONFIG}.tmp" "$AGENT_CONFIG"
      fi
    else
      new_hook=$(jq -n --arg hook_script "$full_command" --arg tool_matcher "$tool_matcher" '{
        matcher: $tool_matcher,
        hooks: [{ type: "command", command: $hook_script }]
      }')
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would add new hook matcher '${tool_matcher}' to $AGENT_CONFIG"
      else
        jq --argjson new_hook "$new_hook" --arg hook_type "$hook_type" \
          '.hooks[$hook_type] += [$new_hook]' \
          "$AGENT_CONFIG" > "${AGENT_CONFIG}.tmp" && \
          dry_run_aware_mv "${AGENT_CONFIG}.tmp" "$AGENT_CONFIG"
      fi
    fi
    return 0
  fi
}

ensure_hook_array() {
  local hook_type="$1"
  
  if ! jq -e ".hooks.${hook_type}" "$AGENT_CONFIG" > /dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY RUN] Would ensure hook array for ${hook_type} in $AGENT_CONFIG"
    else
      if jq -e '.hooks' "$AGENT_CONFIG" > /dev/null 2>&1; then
        jq --arg hook_type "$hook_type" '.hooks[$hook_type] = []' "$AGENT_CONFIG" > "${AGENT_CONFIG}.tmp" && \
          dry_run_aware_mv "${AGENT_CONFIG}.tmp" "$AGENT_CONFIG"
      else
        jq --arg hook_type "$hook_type" '.hooks = { ($hook_type): [] }' "$AGENT_CONFIG" > "${AGENT_CONFIG}.tmp" && \
          dry_run_aware_mv "${AGENT_CONFIG}.tmp" "$AGENT_CONFIG"
      fi
    fi
  fi
}

configure_agent_hooks() {
  log_info "Configuring oh-my-opencode hooks (Agent Skills compatible)..."
  
  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping agent hooks configuration."
    return 0
  fi
  
  if [ ! -f "$HOOKS_SOURCE" ]; then
    log_info "No hooks.json found, skipping agent hooks configuration"
    return 0
  fi

  log_info "Using hooks configuration from config/hooks.json"
  
  if ! jq empty "$HOOKS_SOURCE" 2>/dev/null; then
    log_error "hooks.json is not valid JSON. Skipping hook configuration."
    return 1
  fi
  
  dry_run_aware_mkdir -p "$AGENT_CONFIG_DIR"
  
  if [ -f "$AGENT_CONFIG" ]; then
    if ! jq empty "$AGENT_CONFIG" 2>/dev/null; then
      log_error "Existing agent config is not valid JSON. Creating backup and starting fresh..."
      dry_run_aware_mv "$AGENT_CONFIG" "${AGENT_CONFIG}.invalid.$(date +%s).backup"
      echo '{}' | dry_run_aware_write "$AGENT_CONFIG"
    else
      dry_run_aware_cp "$AGENT_CONFIG" "${AGENT_CONFIG}.backup"
      log_info "Backup created: ${AGENT_CONFIG}.backup"
    fi
  else
    echo '{}' | dry_run_aware_write "$AGENT_CONFIG"
  fi
  
  local added=0
  local updated=0
  local skipped=0
  
  local hook_types
  hook_types=$(jq -r '.hooks | keys[]' "$HOOKS_SOURCE" 2>/dev/null)
  
  for hook_type in $hook_types; do
    ensure_hook_array "$hook_type"
    
    local hook_count
    hook_count=$(jq -r ".hooks.${hook_type} | length" "$HOOKS_SOURCE")
    
    for ((i=0; i<hook_count; i++)); do
      local hook_id hook_desc hook_matcher hook_script hook_enabled
      hook_id=$(jq -r ".hooks.${hook_type}[$i].id" "$HOOKS_SOURCE")
      hook_desc=$(jq -r ".hooks.${hook_type}[$i].description" "$HOOKS_SOURCE")
      hook_matcher=$(jq -r ".hooks.${hook_type}[$i].matcher" "$HOOKS_SOURCE")
      hook_script=$(jq -r ".hooks.${hook_type}[$i].script" "$HOOKS_SOURCE")
      hook_enabled=$(jq -r ".hooks.${hook_type}[$i].enabled" "$HOOKS_SOURCE")
      
      if [ "$hook_enabled" != "true" ]; then
        log_info "Skipped disabled hook: ${hook_id}"
        skipped=$((skipped + 1))
        continue
      fi
      
      # Hook scripts can be project-root-relative (content/...) or directory-relative
      local full_path=""
      local candidate
      
      # Local install: use project-root-relative paths
      if [[ "$hook_script" == content/* ]]; then
        candidate="${ATELIER_DIR}/${hook_script}"
        if [ -f "$candidate" ]; then
          # Canonicalize to prevent symlink tricks and path traversal
          local resolved_dir
          if resolved_dir=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P); then
            local resolved_path="${resolved_dir}/$(basename "$candidate")"
            local canonical_atelier_dir
            canonical_atelier_dir=$(cd "$ATELIER_DIR" 2>/dev/null && pwd -P)
            if [ -n "$canonical_atelier_dir" ] && [[ "$resolved_path/" == "${canonical_atelier_dir}/"* ]]; then
              full_path="$resolved_path"
            else
              log_warning "Hook '${hook_id}': path traversal detected for script '${hook_script}'. Skipping."
            fi
          else
            log_warning "Hook '${hook_id}': directory for script not found or is invalid: $(dirname "$candidate")"
          fi
        fi
      fi
      
      # If not found, try directory-relative paths for backward compatibility
      if [ -z "$full_path" ]; then
        for candidate in "${SOURCE_HOOKS_DIR}/${hook_script}" "${SOURCE_SKILLS_DIR}/${hook_script}" "${CONTENT_DIR}/${hook_script}"; do
          if [ -f "$candidate" ]; then
            # Canonicalize to prevent ../ escaping and symlink tricks
            local resolved_dir resolved_path
            if ! resolved_dir=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P); then
              continue
            fi
            resolved_path="${resolved_dir}/$(basename "$candidate")"

            local canonical_skills_dir canonical_hooks_dir canonical_content_dir
            canonical_skills_dir=$(cd "$SOURCE_SKILLS_DIR" 2>/dev/null && pwd -P)
            canonical_hooks_dir=$(cd "$SOURCE_HOOKS_DIR" 2>/dev/null && pwd -P)
            canonical_content_dir=$(cd "$CONTENT_DIR" 2>/dev/null && pwd -P)

            if [ -z "$canonical_skills_dir" ] && [ -z "$canonical_hooks_dir" ] && [ -z "$canonical_content_dir" ]; then
              continue
            fi

            if [ -n "$canonical_hooks_dir" ] && [[ "$resolved_path/" == "$canonical_hooks_dir/"* ]]; then
              full_path="$resolved_path"
              break
            elif [ -n "$canonical_skills_dir" ] && [[ "$resolved_path/" == "$canonical_skills_dir/"* ]]; then
              full_path="$resolved_path"
              break
            elif [ -n "$canonical_content_dir" ] && [[ "$resolved_path/" == "$canonical_content_dir/"* ]]; then
              full_path="$resolved_path"
              break
            fi
          fi
        done
      fi
      
      if [ ! -f "$full_path" ]; then
        log_warning "Hook script not found: ${hook_script}"
        skipped=$((skipped + 1))
        continue
      fi
      
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would clean up existing hook script references for ${full_path}"
      else
        jq --arg hook_type "$hook_type" --arg hook_script "${full_path}" \
          '.hooks[$hook_type] |= map(.hooks |= map(select((.command // "") | endswith($hook_script) | not)))' \
          "$AGENT_CONFIG" > "${AGENT_CONFIG}.tmp" && \
          dry_run_aware_mv "${AGENT_CONFIG}.tmp" "$AGENT_CONFIG"
      fi
      
      if add_or_update_hook "$full_path" "$hook_type" "$hook_matcher"; then
        log_success "Added hook: ${hook_desc}"
        added=$((added + 1))
      else
        log_info "Updated hook: ${hook_desc}"
        updated=$((updated + 1))
      fi
    done
  done
  
  if [ $added -gt 0 ] || [ $updated -gt 0 ]; then
    log_success "agent hooks configured: ${added} added, ${updated} updated, ${skipped} skipped"
  fi
}

# ============================================================================
# DEPRECATED SKILL CLEANUP
# ============================================================================

# Mapping of old skill names to new names (for migration)
# Format: "old-name:new-name"
DEPRECATED_SKILLS=(
  "pr-comment-resolver:resolve-pr-comments"
)

# ----------------------------------------------------------------------------
# Cleanup Deprecated Skills
# ----------------------------------------------------------------------------
# Checks for deprecated/renamed skills in agent directories and offers to
# remove them. In --yes mode, removes automatically.
#
# Parameters:
#   $1 - Agent type (codex, opencode)
#   $2 - Target skills directory path
cleanup_deprecated_skills() {
  local agent_type="$1"
  local target_skills_dir="$2"
  
  if [ ! -d "$target_skills_dir" ]; then
    return 0
  fi
  
  local cleaned=0
  
  for mapping in "${DEPRECATED_SKILLS[@]}"; do
    local old_name="${mapping%%:*}"
    local new_name="${mapping##*:}"
    local old_skill_path="${target_skills_dir}/${old_name}"
    
    if [ -d "$old_skill_path" ]; then
      log_warning "Found deprecated skill '${old_name}' (renamed to '${new_name}')"
      log_info "The new skill '${new_name}' will be installed next."
      
      if [ "$SKIP_CONFIRM" = true ]; then
        # Auto-remove in --yes mode
        dry_run_aware_rm -rf "$old_skill_path"
        log_success "Removed deprecated skill '${old_name}'"
        cleaned=$((cleaned + 1))
      else
        echo -n "Remove deprecated skill '${old_name}'? [Y/n]: "
        read -r response
        case "$response" in
          [nN][oO]|[nN])
            log_info "Kept deprecated skill '${old_name}'"
            ;;
          *)
            dry_run_aware_rm -rf "$old_skill_path"
            log_success "Removed deprecated skill '${old_name}'"
            cleaned=$((cleaned + 1))
            ;;
        esac
      fi
    fi
  done
  
  if [ $cleaned -gt 0 ]; then
    log_info "Cleaned up ${cleaned} deprecated skill(s) from ${agent_type}"
  fi
}

# ============================================================================
# SKILL FILTERING & INSTALLATION
# ============================================================================

# ----------------------------------------------------------------------------
# Check if Skill Should Be Installed
# ----------------------------------------------------------------------------
# Checks skills.json to determine if a skill should be installed
# for a specific agent type.
#
# Parameters:
#   $1 - Skill name
#   $2 - Agent type (opencode)
#
# Returns:
#   0 if should install, 1 if should skip
should_install_skill() {
  local skill_name="$1"
  local agent_type="$2"
  
  # Skip .system directory
  if [ "$skill_name" = ".system" ]; then
    return 1
  fi
  
  # If skills.json doesn't exist, install all skills
  if [ ! -f "$SKILLS_CONFIG" ]; then
    return 0
  fi
  
  # Check if jq is available
  if ! command -v jq &> /dev/null; then
    # If jq not available, install all skills (fallback)
    return 0
  fi
  
  # Check agent-specific configuration
  # jq's // operator treats false as falsy, so we check for explicit false string instead
  local install_value=$(jq -r ".agents.\"${agent_type}\".skills.\"${skill_name}\".install" "$SKILLS_CONFIG" 2>/dev/null)
  
  if [ "$install_value" = "false" ]; then
    return 1
  fi
  
  return 0
}

# ----------------------------------------------------------------------------
# Install Single Skill to Agent
# ----------------------------------------------------------------------------
# Installs a single skill to a specific agent's skills directory.
# Handles validation, diff calculation, and user confirmation.
#
# Parameters:
#   $1 - Skill name
#   $2 - Agent type (opencode)
#   $3 - Target skills directory path
#
# Behavior:
#   - Validates skill name per OpenCode spec (for OpenCode)
#   - Checks if skill should be installed (skills.json)
#   - Calculates diff if skill exists
#   - Prompts for confirmation unless --yes flag
#   - Preserves existing skills if identical
install_skill_to_agent() {
  local skill_name="$1"
  local agent_type="$2"
  local target_skills_dir="$3"
  local source_skill="${SOURCE_SKILLS_DIR}/${skill_name}"
  local target_skill="${target_skills_dir}/${skill_name}"
  
  # Validate skill name for OpenCode and Cursor (same pattern per OpenCode/Cursor specs)
  if [ "$agent_type" = $PLATFORM_OPENCODE ] || [ "$agent_type" = $PLATFORM_CURSOR ]; then
    if ! validate_skill_name "$skill_name"; then
      log_error "Skill '${skill_name}' has invalid name for ${agent_type} (must match: ^[a-z0-9]+(-[a-z0-9]+)*$)"
      return 1
    fi
  fi
  
  # Check if skill should be installed for this agent
  if ! should_install_skill "$skill_name" "$agent_type"; then
    log_info "Skill '${skill_name}' is disabled for agent '${agent_type}', skipping"
    return
  fi
  
  # Validate source skill exists
  if [ ! -d "$source_skill" ]; then
    log_warning "Source skill directory not found: ${source_skill}"
    return 1
  fi
  
  # Validate SKILL.md exists (required per open Agent Skills standard)
  if [ ! -f "${source_skill}/SKILL.md" ]; then
    log_warning "SKILL.md not found in ${source_skill}, skipping"
    return 1
  fi
  
  local exists=false
  if [ -d "$target_skill" ]; then
    exists=true
  fi
  
  if [ "$exists" = true ]; then
    # Calculate diff
    local diff_summary=$(calculate_diff "$source_skill" "$target_skill" "$skill_name")
    
    if [ "$diff_summary" = "identical" ]; then
      log_info "Skill '${skill_name}' is identical, skipping"
      return 0  # Return 0 but set a flag to indicate it was skipped
    fi
    
    log_warning "Skill '${skill_name}' already exists"
    echo "  Changes: ${diff_summary}"
    
    # Show preview of changes
    show_diff_preview "$source_skill" "$target_skill" "$skill_name"
    
    # Ask for confirmation unless --yes flag
    if [ "$SKIP_CONFIRM" = false ]; then
      echo -n "Overwrite existing skill? [y/N]: "
      read -r response
      case "$response" in
        [yY][eE][sS]|[yY])
          # User confirmed, proceed with overwrite
          ;;
        *)
          log_info "Skipped '${skill_name}' (user declined)"
          return 1  # Return 1 to indicate skipped (user declined)
          ;;
      esac
    fi
    
    # Remove existing skill before installing new version
    dry_run_aware_rm -rf "$target_skill"
    log_info "Removed existing skill '${skill_name}'"
  fi
  
  # Copy skill to target directory atomically
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would copy skill '${skill_name}' to ${target_skills_dir}"
    return 0
  fi

  if atomic_copy_skill "$source_skill" "$target_skill"; then
    if [ "$exists" = true ]; then
      log_success "Updated skill '${skill_name}'"
    else
      log_success "Installed skill '${skill_name}'"
    fi
    return 0
  else
    log_error "Failed to copy skill '${skill_name}' to ${target_skills_dir}"
    return 1
  fi
}

# ----------------------------------------------------------------------------
# Install All Skills to Agent
# ----------------------------------------------------------------------------
# Installs all available skills to a specific agent's skills directory.
# Respects skills.json for agent-specific filtering.
#
# Parameters:
#   $1 - Agent type (opencode)
#   $2 - Target skills directory path
#
# Returns:
#   Prints summary: "Installed X, Updated Y, Skipped Z"
install_skills_to_agent() {
  local agent_type="$1"
  local target_skills_dir="$2"
  
  log_info "Installing skills to ${agent_type}..."
  echo ""
  
  local installed=0
  local updated=0
  local skipped=0
  
  for skill_dir in "${SOURCE_SKILLS_DIR}"/*; do
    if [ ! -d "$skill_dir" ]; then
      continue
    fi
    
    local skill_name=$(basename "$skill_dir")
    
    # Skip .system directory
    if [ "$skill_name" = ".system" ]; then
      continue
    fi
    
    # Check if it's a valid skill (has SKILL.md)
    if [ ! -f "${skill_dir}/SKILL.md" ]; then
      continue
    fi
    
    # Check if skill should be installed (before checking if it exists)
    if ! should_install_skill "$skill_name" "$agent_type"; then
      skipped=$((skipped + 1))
      continue
    fi
    
    local existed=false
    if [ -d "${target_skills_dir}/${skill_name}" ]; then
      existed=true
    fi
    
    # Store state before installation
    local before_exists=$existed
    
    # Check if skill exists before installation to detect if it was skipped (identical)
    local skill_was_identical=false
    if [ -d "${target_skills_dir}/${skill_name}" ]; then
      local diff_check=$(calculate_diff "${SOURCE_SKILLS_DIR}/${skill_name}" "${target_skills_dir}/${skill_name}" "$skill_name" 2>/dev/null || echo "")
      if [ "$diff_check" = "identical" ]; then
        skill_was_identical=true
      fi
    fi
    
    install_skill_to_agent "$skill_name" "$agent_type" "$target_skills_dir"
    local install_result=$?
    
    # Check result: 0 = success (installed/updated/skipped identical), 1 = error/skipped
    if [ "$skill_was_identical" = true ]; then
      # Skill was skipped because it's identical
      skipped=$((skipped + 1))
    elif [ "$install_result" -eq 0 ] && [ -d "${target_skills_dir}/${skill_name}" ]; then
      # Skill was successfully installed or updated
      if [ "$before_exists" = true ]; then
        updated=$((updated + 1))
      else
        installed=$((installed + 1))
      fi
    else
      # Skill installation failed or was skipped (user declined, invalid, etc.)
      skipped=$((skipped + 1))
    fi
  done
  
  # Report summary for this agent
  echo "  ${agent_type}: Installed ${installed}, Updated ${updated}, Skipped ${skipped}"
  echo ""
}

post_install_check() {
  local agent_type="$1"
  local target_dir="$2"
  local missing=()
  local skill_dir

  for skill_dir in "${SOURCE_SKILLS_DIR}"/*; do
    if [ ! -d "$skill_dir" ] || [ ! -f "${skill_dir}/SKILL.md" ]; then
      continue
    fi

    local skill_name
    skill_name=$(basename "$skill_dir")

    if [ "$skill_name" = ".system" ]; then
      continue
    fi

    if ! should_install_skill "$skill_name" "$agent_type"; then
      continue
    fi

    if [ ! -f "${target_dir}/${skill_name}/SKILL.md" ]; then
      missing+=("$skill_name")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log_warning "Post-install check (${agent_type}) missing skills: ${missing[*]}"
  else
    log_success "Post-install check (${agent_type}) verified skills present"
  fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# ----------------------------------------------------------------------------
# Main Function
# ----------------------------------------------------------------------------
# Orchestrates the complete installation process:
#   1. Validates prerequisites and source directory
#   2. Configures MCPs for OpenCode
#   3. Installs skills to both agents
#   4. Reports installation summary
#
# Exit Codes:
#   0 - Success
#   1 - Error (invalid source, missing dependencies, etc.)
main() {
  # Check Bash version (4.0+ required for modern features)
  if [[ "${BASH_VERSINFO:-0}" -lt 4 ]]; then
    log_error "Bash 4.0+ is required. You are running: $BASH_VERSION"
    log_info "Please upgrade Bash or use a compatible shell."
    exit 1
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "AI Dev Atelier Skills & MCP Installer"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Parse arguments
  parse_args "$@"

  if [ "$DRY_RUN" = true ]; then
    log_info "DRY RUN MODE ENABLED. No changes will be made to the filesystem."
    echo ""
  fi

  if [ "$CHECK_ONLY" = true ]; then
    preflight_checks
    log_success "Dependency checks complete."
    exit 0
  fi

  log_info "Running preflight checks..."
  preflight_checks
  echo ""

  ensure_repo_checkout "$@"
  resolve_skills_config

  if [ -f "$SKILLS_CONFIG" ]; then
    log_info "Using skills configuration: ${SKILLS_CONFIG}"
  fi
  echo ""

  log_info "Checking source skills directory..."
  check_source_dir
  verify_skill_structure
  echo ""
  
  # Ensure target directories exist
  log_info "Preparing installation directories..."
  dry_run_aware_mkdir -p "$OPENCODE_SKILLS_DIR"
  dry_run_aware_mkdir -p "$CURSOR_SKILLS_DIR"
  log_success "Directories ready"
  echo ""
  log_info "OpenCode skills: ${OPENCODE_SKILLS_DIR} (global)"
  log_info "Cursor skills: ${CURSOR_SKILLS_DIR} (global)"
  echo ""
  
  # Configure MCP servers for OpenCode
  log_info "Configuring MCP servers..."
  echo ""
  
  log_info "━━━ OpenCode MCP Configuration ━━━"
  if ! configure_mcp_opencode; then
    log_warning "OpenCode MCP configuration failed"
  fi
  echo ""

  log_info "━━━ Cursor MCP Configuration ━━━"
  if ! configure_mcp_cursor; then
    log_warning "Cursor MCP configuration failed"
  fi
  echo ""
  
  log_info "━━━ OpenCode Custom Agents ━━━"
  configure_opencode_agents
  echo ""

  log_info "━━━ OpenCode Plugins ━━━"
  configure_opencode_plugins
  echo ""
  
  # Install skills to each agent (OpenCode, Cursor)
  # Skills may be filtered per agent via skills.json
  local agents=(opencode cursor)
  local skills_dirs=("$OPENCODE_SKILLS_DIR" "$CURSOR_SKILLS_DIR")
  local agent_label
  log_info "━━━ Cleaning Up Deprecated Skills ━━━"
  for i in "${!agents[@]}"; do
    cleanup_deprecated_skills "${agents[i]}" "${skills_dirs[i]}"
  done
  echo ""
  for i in "${!agents[@]}"; do
    case "${agents[i]}" in
      opencode) agent_label="OpenCode" ;;
      cursor)   agent_label="Cursor" ;;
      *)        agent_label="${agents[i]}" ;;
    esac
    log_info "━━━ Installing Skills to ${agent_label} ━━━"
    install_skills_to_agent "${agents[i]}" "${skills_dirs[i]}"
    post_install_check "${agents[i]}" "${skills_dirs[i]}"
    echo ""
  done
  log_info "━━━ Configuring Agent Skills Hooks (oh-my-opencode) ━━━"
  configure_agent_hooks
  
  # Clean up temporary hook files downloaded from GitHub
  # These files are only created when HOOKS_CONFIG is missing during initial
  # curl-based installation (not local installs). When hooks.json exists in
  # the repo, hooks are installed from local paths instead of temp downloads.
  if [ ! -f "$HOOKS_CONFIG" ]; then
    for hook_id in "${TEMP_HOOK_IDS[@]}"; do
      dry_run_aware_rm -f "${AGENT_CONFIG_DIR}/hook-${hook_id}.sh" 2>/dev/null || true
    done
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_success "Installation complete!"
  echo ""
  echo "OpenCode:"
  echo "  Skills: ${OPENCODE_SKILLS_DIR}"
  echo "  MCPs: ${OPENCODE_CONFIG}"
  echo "  Plugins: ${OPENCODE_CONFIG_DIR}/plugin"
  echo "  Agent Hooks: ${AGENT_CONFIG} (for oh-my-opencode)"
  echo ""
  echo "Cursor (global):"
  echo "  Skills: ${CURSOR_SKILLS_DIR}"
  echo "  MCPs: ${CURSOR_MCP_CONFIG}"
  echo ""
  echo "To verify, ask your agent: 'What skills are available?' or check Cursor Settings → Rules."
  echo ""
  
  # Credential configuration guidance
  local env_file_display=""
  if [ -f "${ATELIER_DIR}/.env" ] && [ "${ATELIER_DIR}" != "${ATELIER_STATE_DIR}/repo" ]; then
    # Local development (make install) - using repo .env
    env_file_display="${ATELIER_DIR}/.env"
  else
    # Remote install (curl | bash) - using state dir .env
    env_file_display="${ATELIER_STATE_DIR}/.env"
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Next Steps: Configure API Keys"
  echo ""
  echo "Some skills require API keys. Configure them in:"
  echo "  ${env_file_display}"
  echo ""
  echo "Required for full functionality:"
  echo "  - TAVILY_API_KEY     (for web search skill)"
  echo "  - Z_AI_API_KEY       (for Z.AI vision features)"
  echo "  - CONTEXT7_API_KEY   (for documentation lookup)"
  echo "  - OPENALEX_EMAIL     (for academic research)"
  echo ""
  echo "Copy from example file:"
  echo "  cp ${ATELIER_DIR}/.env.example ${env_file_display}"
  echo ""
  echo "Then edit ${env_file_display} with your credentials."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "References:"
  echo "  - OpenCode Skills: https://opencode.ai/docs/skills/"
  echo "  - OpenCode MCPs: https://opencode.ai/docs/mcp-servers/"
  echo "  - Cursor Skills: https://cursor.com/docs/context/skills"
  echo "  - Cursor MCPs: https://cursor.com/docs/context/mcp"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Run main function with all arguments
main "$@"
