#!/bin/bash
# ============================================================================
# AI Dev Atelier Skills & MCP Installer
# ============================================================================
#
# Description:
#   Installs skills and MCP servers to both Codex and OpenCode agents.
#   Follows Anthropic Agent Skills standard and OpenCode specifications.
#
# Features:
#   - Installs skills to Codex (~/.codex/skills) and OpenCode (~/.opencode/skill)
#   - Configures MCPs for both agents with proper format conversion
#   - Preserves existing configurations (never overwrites)
#   - Smart diff-based confirmation for skill updates
#   - Agent-specific skill filtering via skills-config.json
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
#   ./install.sh [--yes] [--help]
#
# ============================================================================

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
SOURCE_SKILLS_DIR="${ATELIER_DIR}/skills"
SKILLS_CONFIG="${ATELIER_DIR}/skills-config.json"
MCP_CONFIG="${ATELIER_DIR}/mcp.json"
ENV_FILE="${ATELIER_DIR}/.env"
ENV_EXAMPLE="${ATELIER_DIR}/.env.example"

# ============================================================================
# CONFIGURATION & PATHS
# ============================================================================

# Codex paths (Anthropic Agent Skills standard)
# MCP config uses config.toml per OpenAI Codex docs: https://developers.openai.com/codex/mcp/
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  CODEX_SKILLS_DIR="${XDG_CONFIG_HOME}/codex/skills"
  CODEX_MCP_CONFIG="${XDG_CONFIG_HOME}/codex/config.toml"
else
  CODEX_SKILLS_DIR="${HOME}/.codex/skills"
  CODEX_MCP_CONFIG="${HOME}/.codex/config.toml"
fi

# OpenCode paths (OpenCode specification)
# Skills use "skill" (singular) per OpenCode docs: https://opencode.ai/docs/skills/
# Note: OPENCODE_SKILLS_DIR will be set by get_opencode_skills_path() function below
OPENCODE_CONFIG_DIR=""
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

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

SKIP_CONFIRM=false  # Skip confirmation prompts when true

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

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

# ----------------------------------------------------------------------------
# Load Environment Variables
# ----------------------------------------------------------------------------
# Loads API keys and configuration from .env file if it exists.
# Falls back to .env.example for reference if .env doesn't exist.
#
# Returns:
#   0 if .env loaded successfully, 1 if not found (non-fatal)
load_env_file() {
  if [ -f "$ENV_FILE" ]; then
    # Source .env file (export variables)
    set -a
    source "$ENV_FILE" 2>/dev/null || return 1
    set +a
    return 0
  fi
  return 1
}

# ----------------------------------------------------------------------------
# Get OpenCode Skills Path
# ----------------------------------------------------------------------------
# Determines the global OpenCode skills directory.
# Per OpenCode docs: https://opencode.ai/docs/skills/
# Always uses global config location (like Codex), not project-local.
# - Global config: ~/.opencode/skill/<name>/SKILL.md
#
# Returns: Path to global OpenCode skills directory
get_opencode_skills_path() {
  # Always use global config location (like Codex)
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    echo "${XDG_CONFIG_HOME}/opencode/skill"
    return
  fi

  if [ -n "${OPENCODE_CONFIG_DIR:-}" ]; then
    echo "${OPENCODE_CONFIG_DIR}/skill"
    return
  fi

  if [ -d "${HOME}/.config/opencode" ] || [ -f "${HOME}/.config/opencode/opencode.json" ]; then
    echo "${HOME}/.config/opencode/skill"
  else
    echo "${HOME}/.opencode/skill"
  fi
}

# Update OPENCODE_SKILLS_DIR to use the function result
OPENCODE_SKILLS_DIR=$(get_opencode_skills_path)

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
Install AI Dev Atelier Skills and MCPs to Codex and OpenCode

Usage: $0 [OPTIONS]

Options:
  -y, --yes    Skip confirmation prompts (auto-overwrite)
  -h, --help   Show this help message

This script installs skills and MCPs to both Codex and OpenCode:
  - Skills: ${CODEX_SKILLS_DIR} and ${OPENCODE_SKILLS_DIR}
  - MCPs: ${CODEX_MCP_CONFIG} (TOML format) and ${OPENCODE_CONFIG} (JSON format)

Skills are installed following the Anthropic Agent Skills standard.
Skills can be disabled per agent in skills-config.json.
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
  
  # Check for at least one skill with SKILL.md
  local skill_count=0
  for skill_dir in "${SOURCE_SKILLS_DIR}"/*; do
    if [ -d "$skill_dir" ] && [ -f "${skill_dir}/SKILL.md" ]; then
      skill_count=$((skill_count + 1))
    fi
  done
  
  if [ $skill_count -eq 0 ]; then
    log_error "No skills found in ${SOURCE_SKILLS_DIR}"
    echo "Expected to find directories with SKILL.md files"
    exit 1
  fi
  
  log_success "Found ${skill_count} skill(s) in source directory"
}

check_dependencies() {
  local missing=0
  local cmd
  local required_cmds=("git" "diff" "cp" "rm" "awk" "sed" "mkdir" "basename" "dirname")

  for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      log_error "Missing required command: ${cmd}"
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -gt 0 ]; then
    log_error "Missing required commands. Install them and re-run."
    exit 1
  fi

  if ! command -v jq > /dev/null 2>&1; then
    log_warning "jq not found. MCP configuration will be skipped."
  fi


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
  check_dependencies

  local failed=0
  check_write_access "$CODEX_SKILLS_DIR" || failed=$((failed + 1))
  check_write_access "$OPENCODE_SKILLS_DIR" || failed=$((failed + 1))
  check_write_access "$(dirname "$CODEX_MCP_CONFIG")" || failed=$((failed + 1))
  check_write_access "$(dirname "$OPENCODE_CONFIG")" || failed=$((failed + 1))

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
# Convert JSON MCP Config to TOML Format
# ----------------------------------------------------------------------------
# Converts a single MCP server from JSON format (mcp.json) to TOML format
# for Codex config.toml.
#
# Parameters:
#   $1 - Server name
#   $2 - Server config (JSON string from mcp.json)
#
# Returns:
#   TOML-formatted config block via stdout
#   Returns 1 on error
#
# References:
#   - Codex MCP docs: https://developers.openai.com/codex/mcp/
convert_mcp_to_toml() {
  local server_name="$1"
  local server_config="$2"
  
  # Escape server name for TOML (handle special characters)
  local toml_name="$server_name"
  
  # Check if it's a remote MCP (has "url" field)
  if echo "$server_config" | jq -e '.url' > /dev/null 2>&1; then
    local url=$(echo "$server_config" | jq -r '.url')
    local headers=$(echo "$server_config" | jq -c '.headers // {}')
    
    # Build TOML for remote MCP
    echo "[mcp_servers.${toml_name}]"
    echo "url = \"${url}\""
    
    # Add headers if present
    local header_count=$(echo "$headers" | jq 'length')
    if [ "$header_count" -gt 0 ]; then
      echo "http_headers = {"
      echo "$headers" | jq -r 'to_entries[] | "  \"\(.key)\" = \"\(.value)\","' | sed '$ s/,$//'
      echo "}"
    fi
    
    return 0
  fi
  
  # Check if it's a local MCP (has "command" field)
  if echo "$server_config" | jq -e '.command' > /dev/null 2>&1; then
    local command=$(echo "$server_config" | jq -r '.command')
    local args=$(echo "$server_config" | jq -c '.args // []')
    local env=$(echo "$server_config" | jq -c '.env // {}')
    
    # Build TOML for local MCP
    echo "[mcp_servers.${toml_name}]"
    echo "command = \"${command}\""
    
    # Add args if present
    local args_count=$(echo "$args" | jq 'length')
    if [ "$args_count" -gt 0 ]; then
      echo "args = ["
      echo "$args" | jq -r '.[] | "  \"\(.)\","' | sed '$ s/,$//'
      echo "]"
    fi
    
    # Add env if present
    local env_count=$(echo "$env" | jq 'length')
    if [ "$env_count" -gt 0 ]; then
      echo "env = {"
      echo "$env" | jq -r 'to_entries[] | "  \"\(.key)\" = \"\(.value)\","' | sed '$ s/,$//'
      echo "}"
    fi
    
    return 0
  fi
  
  # Unknown format
  log_error "Unknown MCP server format for ${server_name} (must have 'url' or 'command' field)"
  return 1
}

# ----------------------------------------------------------------------------
# Configure MCP Servers for Codex
# ----------------------------------------------------------------------------
# Configures MCP servers for Codex agent using TOML format (config.toml).
# Reads from mcp.json and adds missing servers to Codex config.
#
# IMPORTANT: Preserves existing MCP configurations and only adds missing ones.
# It will NEVER overwrite an existing MCP server configuration.
#
# Format: config.toml with [mcp_servers.server-name] sections
#   [mcp_servers.server-name]
#   command = "npx"
#   args = ["-y", "@package/mcp"]
#   env = { "VAR" = "VALUE" }
#
# References:
#   - Codex MCP docs: https://developers.openai.com/codex/mcp/
configure_mcp() {
  log_info "Checking MCP configuration for Codex..."
  
  # Check if jq is available (required for JSON manipulation)
  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping Codex MCP configuration."
    log_info "Install jq to enable automatic MCP configuration:"
    log_info "  macOS: brew install jq"
    log_info "  Linux: sudo apt-get install jq"
    log_info "  Or manually configure MCPs using mcp.json"
    return
  fi
  
  # Check if mcp.json exists
  if [ ! -f "$MCP_CONFIG" ]; then
    log_warning "mcp.json not found at ${MCP_CONFIG}"
    log_info "Skipping Codex MCP configuration"
    return
  fi
  
  # Ensure Codex config directory exists
  local codex_config_dir=$(dirname "$CODEX_MCP_CONFIG")
  mkdir -p "$codex_config_dir"
  
  # Validate config is valid JSON
  if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
    log_error "mcp.json is not valid JSON"
    return 1
  fi
  
  # Load .env file for API keys
  load_env_file
  
  # Extract MCP servers from config
  local mcp_servers=$(jq -c '.mcpServers' "$MCP_CONFIG")
  if [ -z "$mcp_servers" ] || [ "$mcp_servers" = "null" ]; then
    log_error "No mcpServers found in mcp.json"
    return 1
  fi
  
  # Get list of server names from config
  local server_names=$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG")
  
  if [ -f "$CODEX_MCP_CONFIG" ]; then
    # Config exists, check and add missing servers (preserve existing configs)
    log_info "Updating existing Codex MCP configuration (preserving existing servers)..."
    
    # Create backup before any modifications (safety measure)
    cp "$CODEX_MCP_CONFIG" "${CODEX_MCP_CONFIG}.backup"
    log_info "Backup created: ${CODEX_MCP_CONFIG}.backup"
    
    local added_count=0
    local skipped_count=0
    
    # Process each server from example
    while IFS= read -r server_name; do
      # IMPORTANT: Check if server already exists - if so, preserve it and skip
      # Check for [mcp_servers.server-name] section in TOML
      if grep -q "^\[mcp_servers\.${server_name}\]" "$CODEX_MCP_CONFIG" 2>/dev/null; then
        log_info "  ${server_name}: already configured, preserving existing configuration"
        skipped_count=$((skipped_count + 1))
        continue
      fi
      
      # Server doesn't exist, safe to add from config
      # Get server config from mcp.json
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        log_warning "  ${server_name}: not found in mcp.json, skipping"
        continue
      fi
      
      # Substitute API keys from .env
      server_config=$(substitute_api_keys "$server_config" "$server_name")
      
      # Convert to TOML format
      # Note: API keys are already substituted in JSON before conversion
      local toml_config=$(convert_mcp_to_toml "$server_name" "$server_config")
      if [ $? -ne 0 ]; then
        log_error "  ${server_name}: failed to convert format"
        continue
      fi
      
      # Append to config file
      echo "" >> "$CODEX_MCP_CONFIG"
      echo "# Added by AI Dev Atelier installer" >> "$CODEX_MCP_CONFIG"
      echo "$toml_config" >> "$CODEX_MCP_CONFIG"
      
      log_success "  ${server_name}: added"
      added_count=$((added_count + 1))
    done <<< "$server_names"
    
    if [ $added_count -gt 0 ]; then
      log_success "Added ${added_count} MCP server(s) to ${CODEX_MCP_CONFIG}"
    fi
    if [ $skipped_count -gt 0 ]; then
      log_info "Preserved ${skipped_count} already configured server(s) (not overwritten)"
    fi
    if [ $added_count -eq 0 ] && [ $skipped_count -eq 0 ]; then
      log_info "No changes needed - all MCPs from example are already configured"
    fi
    
    # Warn about API keys that need to be set (check for placeholder values in TOML)
    if grep -q "TAVILY_API_KEY" "$CODEX_MCP_CONFIG" 2>/dev/null || grep -q "X-Tavily-Api-Key.*TAVILY_API_KEY" "$CODEX_MCP_CONFIG" 2>/dev/null; then
      log_warning "⚠️  Tavily MCP requires TAVILY_API_KEY - update in ${CODEX_MCP_CONFIG} (set as X-Tavily-Api-Key header)"
    fi
    if grep -q "CONTEXT7_API_KEY.*CONTEXT7_API_KEY" "$CODEX_MCP_CONFIG" 2>/dev/null; then
      log_warning "⚠️  Context7 MCP requires CONTEXT7_API_KEY - update in ${CODEX_MCP_CONFIG} (optional)"
    fi
    if grep -q "you@example.com" "$CODEX_MCP_CONFIG" 2>/dev/null; then
      log_warning "⚠️  OpenAlex MCP requires OPENALEX_EMAIL - update in ${CODEX_MCP_CONFIG}"
    fi
    
  else
    # Config doesn't exist, create new one from mcp.json
    log_info "Creating new Codex MCP configuration from mcp.json..."
    
    # Create TOML config file with header comment
    {
      echo "# MCP (Model Context Protocol) Configuration"
      echo "# Auto-generated by AI Dev Atelier installer from mcp.json"
      echo "# API keys loaded from .env file if available"
      echo "#"
      echo "# Reference: https://developers.openai.com/codex/mcp/"
      echo ""
    } > "$CODEX_MCP_CONFIG"
    
    local server_count=0
    
    # Process each server and convert to TOML
    while IFS= read -r server_name; do
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        continue
      fi
      
      # Substitute API keys from .env
      server_config=$(substitute_api_keys "$server_config" "$server_name")
      
      local toml_config=$(convert_mcp_to_toml "$server_name" "$server_config")
      if [ $? -eq 0 ]; then
        echo "$toml_config" >> "$CODEX_MCP_CONFIG"
        echo "" >> "$CODEX_MCP_CONFIG"
        server_count=$((server_count + 1))
      fi
    done <<< "$server_names"
    
    log_success "Created Codex MCP configuration at ${CODEX_MCP_CONFIG}"
    log_info "Configured ${server_count} MCP server(s)"
    
    # Warn about API keys that need to be updated
    log_warning "⚠️  Remember to update API keys in ${CODEX_MCP_CONFIG}:"
    if grep -q "tavily-remote-mcp" "$CODEX_MCP_CONFIG" 2>/dev/null; then
      log_info "  - TAVILY_API_KEY for Tavily MCP (set as X-Tavily-Api-Key header)"
    fi
    if grep -q "\[mcp_servers\.context7\]" "$CODEX_MCP_CONFIG" 2>/dev/null; then
      log_info "  - CONTEXT7_API_KEY for Context7 MCP (optional)"
    fi
    if grep -q "openalex-research" "$CODEX_MCP_CONFIG" 2>/dev/null; then
      log_info "  - OPENALEX_EMAIL for OpenAlex MCP"
    fi
  fi
}

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
  local server_name="$2"
  local result="$server_config"
  
  # Load .env if available
  load_env_file
  
  # Replace TAVILY_API_KEY in headers
  if echo "$result" | jq -e '.headers."X-Tavily-Api-Key" // .headers.TAVILY_API_KEY' > /dev/null 2>&1; then
    if [ -n "${TAVILY_API_KEY:-}" ] && [ "$TAVILY_API_KEY" != "your_tavily_api_key_here" ]; then
      result=$(echo "$result" | jq --arg key "$TAVILY_API_KEY" \
        'if .headers."X-Tavily-Api-Key" then .headers."X-Tavily-Api-Key" = $key
         elif .headers.TAVILY_API_KEY then .headers.TAVILY_API_KEY = $key
         else . end')
    fi
  fi
  
  # Replace CONTEXT7_API_KEY in headers
  if echo "$result" | jq -e '.headers.CONTEXT7_API_KEY' > /dev/null 2>&1; then
    if [ -n "${CONTEXT7_API_KEY:-}" ] && [ "$CONTEXT7_API_KEY" != "your_context7_api_key_here" ]; then
      result=$(echo "$result" | jq --arg key "$CONTEXT7_API_KEY" \
        '.headers.CONTEXT7_API_KEY = $key')
    fi
  fi
  
  # Replace OPENALEX_EMAIL in env
  if echo "$result" | jq -e '.env.OPENALEX_EMAIL' > /dev/null 2>&1; then
    if [ -n "${OPENALEX_EMAIL:-}" ] && [ "$OPENALEX_EMAIL" != "your_email@example.com" ]; then
      result=$(echo "$result" | jq --arg email "$OPENALEX_EMAIL" \
        '.env.OPENALEX_EMAIL = $email')
    fi
  fi
  
  echo "$result"
}

# ----------------------------------------------------------------------------
# Convert MCP to OpenCode Format
# ----------------------------------------------------------------------------
# Converts standard MCP server configuration to OpenCode format.
# Per OpenCode docs: https://opencode.ai/docs/mcp-servers/
#
# Parameters:
#   $1 - Server name
#   $2 - Server config (JSON string from mcp.json)
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
  
  # Handle remote MCPs
  if [ "$server_type" = "remote" ]; then
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
  
  # Check if it's a remote MCP (has "url" field in config)
  if [ -z "$server_type" ] && echo "$server_config" | jq -e '.url' > /dev/null 2>&1; then
    local url=$(echo "$server_config" | jq -r '.url')
    local headers=$(echo "$server_config" | jq -c '.headers // {}')
    
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
    local args=$(echo "$server_config" | jq -c '.args // []')
    local env=$(echo "$server_config" | jq -c '.env // {}')
    
    # Build command array: [command, ...args] using jq
    local cmd_array=$(echo "$args" | jq -c --arg cmd "$command" '[$cmd] + .')
    
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
  log_error "Unknown MCP server format for ${server_name} (must have 'url' or 'command' field, or type in mcp.json)"
  return 1
}

# ----------------------------------------------------------------------------
# Configure MCP Servers for OpenCode
# ----------------------------------------------------------------------------
# Configures MCP servers for OpenCode agent using OpenCode format.
# Reads from mcp.json, converts to OpenCode format, and updates opencode.json.
#
# IMPORTANT: Preserves existing MCP configurations and only adds missing ones.
# It will NEVER overwrite an existing MCP server configuration.
#
# Format: opencode.json with mcp section
#   {
#     "$schema": "https://opencode.ai/config.json",
#     "mcp": {
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
  log_info "Checking MCP configuration for OpenCode..."
  
  # Check if jq is available (required for JSON manipulation)
  if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Skipping OpenCode MCP configuration."
    log_info "Install jq to enable automatic MCP configuration:"
    log_info "  macOS: brew install jq"
    log_info "  Linux: sudo apt-get install jq"
    log_info "  Or manually configure MCPs using mcp.json"
    return
  fi
  
  # Check if mcp.json exists
  if [ ! -f "$MCP_CONFIG" ]; then
    log_warning "mcp.json not found at ${MCP_CONFIG}"
    log_info "Skipping OpenCode MCP configuration"
    return
  fi
  
  # Ensure OpenCode config directory exists
  local opencode_config_dir=$(dirname "$OPENCODE_CONFIG")
  mkdir -p "$opencode_config_dir"
  
  # Validate config is valid JSON
  if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
    log_error "mcp.json is not valid JSON"
    return 1
  fi
  
  # Load .env file for API keys
  load_env_file
  
  # Extract MCP servers from config
  local mcp_servers=$(jq -c '.mcpServers' "$MCP_CONFIG")
  if [ -z "$mcp_servers" ] || [ "$mcp_servers" = "null" ]; then
    log_error "No mcpServers found in mcp.json"
    return 1
  fi
  
  # Get list of server names from config
  local server_names=$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG")
  
  if [ -f "$OPENCODE_CONFIG" ]; then
    # Config exists, check and add missing servers (preserve existing configs)
    log_info "Updating existing OpenCode configuration (preserving existing MCPs)..."
    
    # Validate existing config
    if ! jq empty "$OPENCODE_CONFIG" 2>/dev/null; then
      log_error "Existing OpenCode config is not valid JSON. Creating backup and starting fresh..."
      mv "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.invalid.$(date +%s).backup"
      # Create empty config structure with schema
      echo '{"$schema": "https://opencode.ai/config.json", "mcp": {}}' > "$OPENCODE_CONFIG"
    fi
    
    # Ensure mcp section exists
    if ! jq -e '.mcp' "$OPENCODE_CONFIG" > /dev/null 2>&1; then
      log_info "Adding mcp section to OpenCode config..."
      # Preserve schema if it exists
      if jq -e '."$schema"' "$OPENCODE_CONFIG" > /dev/null 2>&1; then
        jq '.mcp = {}' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
          mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"
      else
        jq '{"$schema": "https://opencode.ai/config.json", mcp: {}} + . | .mcp = (if .mcp then .mcp else {} end)' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
          mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"
      fi
    fi
    
    # Create backup before any modifications
    cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.backup"
    log_info "Backup created: ${OPENCODE_CONFIG}.backup"
    
    local added_count=0
    local skipped_count=0
    
    # Process each server from example
    while IFS= read -r server_name; do
      # IMPORTANT: Check if server already exists - if so, preserve it and skip
      if jq -e ".mcp.\"${server_name}\"" "$OPENCODE_CONFIG" > /dev/null 2>&1; then
        log_info "  ${server_name}: already configured, preserving existing configuration"
        skipped_count=$((skipped_count + 1))
        continue
      fi
      
      # Server doesn't exist, safe to add from config
      # Get server config from mcp.json
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        log_warning "  ${server_name}: not found in mcp.json, skipping"
        continue
      fi
      
      # Convert to OpenCode format (substitutes API keys from .env internally)
      local opencode_config=$(convert_mcp_to_opencode "$server_name" "$server_config")
      if [ $? -ne 0 ]; then
        log_error "  ${server_name}: failed to convert format"
        continue
      fi
      
      # Add server to config (only adds if it doesn't exist - already verified above)
      if jq --arg name "$server_name" --argjson config "$opencode_config" \
         '.mcp[$name] = $config' "$OPENCODE_CONFIG" > "${OPENCODE_CONFIG}.tmp" && \
         mv "${OPENCODE_CONFIG}.tmp" "$OPENCODE_CONFIG"; then
        log_success "  ${server_name}: added"
        added_count=$((added_count + 1))
      else
        log_error "  ${server_name}: failed to add"
        # Restore backup on failure
        mv "${OPENCODE_CONFIG}.backup" "$OPENCODE_CONFIG"
        log_error "Restored backup due to failure"
        return 1
      fi
    done <<< "$server_names"
    
    if [ $added_count -gt 0 ]; then
      log_success "Added ${added_count} MCP server(s) to ${OPENCODE_CONFIG}"
    fi
    if [ $skipped_count -gt 0 ]; then
      log_info "Preserved ${skipped_count} already configured server(s) (not overwritten)"
    fi
    if [ $added_count -eq 0 ] && [ $skipped_count -eq 0 ]; then
      log_info "No changes needed - all MCPs from example are already configured"
    fi
    
  else
    # Config doesn't exist, create new one from mcp.json
    log_info "Creating new OpenCode configuration from mcp.json..."
    
    # Initialize OpenCode config structure with schema
    local opencode_base='{
      "$schema": "https://opencode.ai/config.json",
      "mcp": {}
    }'
    
    # Process each server and convert to OpenCode format
    local mcp_section='{}'
    while IFS= read -r server_name; do
      local server_config=$(jq -c ".mcpServers.\"${server_name}\"" "$MCP_CONFIG")
      if [ -z "$server_config" ] || [ "$server_config" = "null" ]; then
        continue
      fi
      
      # Convert to OpenCode format (substitutes API keys from .env internally)
      local opencode_config=$(convert_mcp_to_opencode "$server_name" "$server_config")
      if [ $? -eq 0 ]; then
        mcp_section=$(echo "$mcp_section" | jq --arg name "$server_name" --argjson config "$opencode_config" '.[$name] = $config')
      fi
    done <<< "$server_names"
    
    # Create final config
    local new_config=$(echo "$opencode_base" | jq --argjson mcp "$mcp_section" '.mcp = $mcp')
    
    echo "$new_config" > "$OPENCODE_CONFIG"
    log_success "Created OpenCode configuration at ${OPENCODE_CONFIG}"
    
    # Count servers added
    local server_count=$(jq '.mcp | length' "$OPENCODE_CONFIG")
    log_info "Configured ${server_count} MCP server(s)"
  fi
}

# ============================================================================
# SKILL FILTERING & INSTALLATION
# ============================================================================

# ----------------------------------------------------------------------------
# Check if Skill Should Be Installed
# ----------------------------------------------------------------------------
# Checks skills-config.json to determine if a skill should be installed
# for a specific agent type.
#
# Parameters:
#   $1 - Skill name
#   $2 - Agent type (codex, opencode)
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
  
  # If skills-config.json doesn't exist, install all skills
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
#   $2 - Agent type (codex, opencode)
#   $3 - Target skills directory path
#
# Behavior:
#   - Validates skill name per OpenCode spec (for OpenCode)
#   - Checks if skill should be installed (skills-config.json)
#   - Calculates diff if skill exists
#   - Prompts for confirmation unless --yes flag
#   - Preserves existing skills if identical
install_skill_to_agent() {
  local skill_name="$1"
  local agent_type="$2"
  local target_skills_dir="$3"
  local source_skill="${SOURCE_SKILLS_DIR}/${skill_name}"
  local target_skill="${target_skills_dir}/${skill_name}"
  
  # Validate skill name for OpenCode (per OpenCode spec)
  if [ "$agent_type" = "opencode" ]; then
    if ! validate_skill_name "$skill_name"; then
      log_error "Skill '${skill_name}' has invalid name for OpenCode (must match: ^[a-z0-9]+(-[a-z0-9]+)*$)"
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
  
  # Validate SKILL.md exists (required per Anthropic Agent Skills standard)
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
    rm -rf "$target_skill"
    log_info "Removed existing skill '${skill_name}'"
  fi
  
  # Copy skill to target directory
  # Use cp -r to preserve directory structure and permissions
  if cp -r "$source_skill" "$target_skill" 2>/dev/null; then
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
# Respects skills-config.json for agent-specific filtering.
#
# Parameters:
#   $1 - Agent type (codex, opencode)
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
#   2. Configures MCPs for both Codex and OpenCode
#   3. Installs skills to both agents
#   4. Reports installation summary
#
# Exit Codes:
#   0 - Success
#   1 - Error (invalid source, missing dependencies, etc.)
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "AI Dev Atelier Skills & MCP Installer"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Parse arguments
  parse_args "$@"

  log_info "Running preflight checks..."
  preflight_checks
  echo ""

  if [ -f "$SKILLS_CONFIG" ]; then
    log_info "Using skills configuration: ${SKILLS_CONFIG}"
  fi
  echo ""
  
  # Check source directory
  log_info "Checking source skills directory..."
  check_source_dir
  echo ""
  
  # Ensure target directories exist
  log_info "Preparing installation directories..."
  mkdir -p "$CODEX_SKILLS_DIR"
  mkdir -p "$OPENCODE_SKILLS_DIR"
  log_success "Directories ready"
  echo ""
  log_info "Codex skills: ${CODEX_SKILLS_DIR}"
  log_info "OpenCode skills: ${OPENCODE_SKILLS_DIR} (global, per OpenCode spec: skill/singular)"
  echo ""
  
  # Configure MCP servers for both agents
  # MCPs are configured separately because they use different formats
  log_info "Configuring MCP servers for both agents..."
  echo ""
  
  log_info "━━━ Codex MCP Configuration ━━━"
  configure_mcp
  if [ $? -ne 0 ]; then
    log_warning "Codex MCP configuration had issues (check errors above)"
  fi
  echo ""
  
  log_info "━━━ OpenCode MCP Configuration ━━━"
  configure_mcp_opencode
  if [ $? -ne 0 ]; then
    log_warning "OpenCode MCP configuration had issues (check errors above)"
  fi
  echo ""
  
  # Install skills to both agents
  # Skills use the same format but may be filtered per agent via skills-config.json
  log_info "Installing skills to both agents..."
  echo ""
  
  log_info "━━━ Installing Skills to Codex ━━━"
  install_skills_to_agent "codex" "$CODEX_SKILLS_DIR"
  post_install_check "codex" "$CODEX_SKILLS_DIR"
  
  log_info "━━━ Installing Skills to OpenCode ━━━"
  install_skills_to_agent "opencode" "$OPENCODE_SKILLS_DIR"
  post_install_check "opencode" "$OPENCODE_SKILLS_DIR"
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_success "Installation complete!"
  echo ""
  echo "Codex:"
  echo "  Skills: ${CODEX_SKILLS_DIR}"
  echo "  MCPs: ${CODEX_MCP_CONFIG}"
  echo ""
  echo "OpenCode:"
  echo "  Skills: ${OPENCODE_SKILLS_DIR} (global, per OpenCode spec)"
  echo "  MCPs: ${OPENCODE_CONFIG}"
  echo ""
  echo "To verify, ask your agent: 'What skills are available?'"
  echo ""
  echo "References:"
  echo "  - OpenCode Skills: https://opencode.ai/docs/skills/"
  echo "  - OpenCode MCPs: https://opencode.ai/docs/mcp-servers/"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Run main function with all arguments
main "$@"


