#!/bin/bash
# Universal documentation check script
# Analyzes git diff to identify code changes that may require documentation updates
# Works in any directory and lets the agent determine what documentation needs updating

set -euo pipefail

# Default values
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-v|--verbose] [-h|--help]"
      echo "  -v, --verbose  Show detailed debugging output"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo "$@" >&2
  fi
}

# Load optional configuration file
load_config() {
  local config_file=".docs-check-config.json"
  if [ -f "$config_file" ]; then
    log_verbose "Loading configuration from $config_file..."
    # Note: This is a placeholder for future config support
    # For now, we use hardcoded patterns but this allows for extension
    log_verbose "Config file found (not yet implemented)"
  fi
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "❌ Error: Not in a git repository"
  echo "   This script requires a git repository to compare changes."
  exit 1
fi

echo "🔍 Checking for documentation updates needed..."
echo ""

# Load optional configuration
load_config

# Get the main branch name (could be main or master)
log_verbose "Detecting main branch..."
MAIN_BRANCH=$(git branch -r 2>/dev/null | grep -E 'origin/(main|master)' | head -1 | sed 's|origin/||' | xargs 2>/dev/null || echo "")
if [ -z "$MAIN_BRANCH" ]; then
  # Try local branches
  MAIN_BRANCH=$(git branch 2>/dev/null | grep -E '^\s*(main|master)' | head -1 | sed 's/^\s*\|\s*$//g' | xargs 2>/dev/null || echo "")
fi
if [ -z "$MAIN_BRANCH" ]; then
  MAIN_BRANCH="main"
fi
log_verbose "Using main branch: $MAIN_BRANCH"

# Fetch latest main branch (silently fail if not available)
log_verbose "Fetching latest changes from origin/$MAIN_BRANCH..."
git fetch origin "$MAIN_BRANCH" 2>/dev/null || log_verbose "Warning: Could not fetch from origin/$MAIN_BRANCH"

# Get all changed files (committed and uncommitted) compared to main
log_verbose "Getting changed files..."
CHANGED_FILES=$(git diff --name-only origin/"$MAIN_BRANCH" HEAD 2>/dev/null || git diff --name-only "$MAIN_BRANCH" HEAD 2>/dev/null || echo "")
UNCOMMITTED_FILES=$(git diff --name-only 2>/dev/null || echo "")
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")

# Combine all changed files
ALL_CHANGED=$(echo -e "$CHANGED_FILES\n$UNCOMMITTED_FILES\n$STAGED_FILES" | sort -u | grep -v '^$')

if [ -z "$ALL_CHANGED" ]; then
  echo "✅ No changes detected compared to $MAIN_BRANCH"
  exit 0
fi

log_verbose "Found $(echo "$ALL_CHANGED" | wc -l | xargs) changed files"

# Cache all documentation files once at initialization
log_verbose "Caching documentation files..."
ALL_DOC_FILES=$(find . -type f \( -name "*.md" -o -name "*.puml" \) \
  -not -path "./node_modules/*" \
  -not -path "./.next/*" \
  -not -path "./.git/*" \
  -not -path "./dist/*" \
  -not -path "./build/*" \
  2>/dev/null | sort || echo "")
log_verbose "Found $(echo "$ALL_DOC_FILES" | wc -l | xargs) documentation files"

# Separate documentation files from code files
DOC_FILES_CHANGED=$(echo "$ALL_CHANGED" | grep -iE "\.(md|puml)$|README|SETUP|IDEA|CONTRIBUTING|CHANGELOG|\.docs/" || echo "")
CODE_FILES_CHANGED=$(comm -23 <(echo "$ALL_CHANGED" | sort) <(echo "$DOC_FILES_CHANGED" | sort) | grep -v '^$' || echo "")

# Show documentation files that were already updated
if [ -n "$DOC_FILES_CHANGED" ]; then
  echo "📚 Documentation files already updated:"
  echo "$DOC_FILES_CHANGED" | sed 's/^/  - /'
  echo ""
fi

echo "🔎 Analyzing code changes for documentation impact..."
echo ""

# Function to find documentation files by pattern (uses cached ALL_DOC_FILES)
find_doc_files() {
  local pattern="$1"
  echo "$ALL_DOC_FILES" | grep -iE "$pattern" || echo ""
}

# Function to check a category of changes
check_category() {
  local category_name="$1"
  local pattern="$2"
  local doc_patterns="$3"
  local files=$(echo "$CODE_FILES_CHANGED" | grep -iE "$pattern" || echo "")
  
  if [ -z "$files" ]; then
    return 1
  fi
  
  echo "⚠️  $category_name changes detected:"
  echo "$files" | sed 's/^/  - /'
  echo ""
  echo "  📚 Check these documentation files:"
  
  # Find docs matching patterns (doc_patterns is a single pattern string)
  find_doc_files "$doc_patterns" | sed 's/^/    - /'
  
  # Check common root docs
  for doc in README.md AGENTS.md IDEA.md; do
    if [ -f "$doc" ]; then
      echo "    - $doc"
    fi
  done
  
  echo ""
  return 0
}

# Track categories found and store categorized files
CATEGORIES_FOUND=0
HAS_CHANGES=false
SCHEMA_CHANGES=""
API_CHANGES=""
COMPONENT_CHANGES=""
CONFIG_CHANGES=""
AUTH_CHANGES=""
HOOK_CHANGES=""
EMAIL_CHANGES=""
TEST_CHANGES=""
STYLE_CHANGES=""

# Database/Schema changes
SCHEMA_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(schema|db|database|migration|model)" || echo "")
if [ -n "$SCHEMA_CHANGES" ]; then
  if check_category "Database/Schema" "(schema|db|database|migration|model)" "(db|database|schema)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# API changes
API_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(api|router|route|endpoint|trpc|graphql|rest)" || echo "")
if [ -n "$API_CHANGES" ]; then
  if check_category "API" "(api|router|route|endpoint|trpc|graphql|rest)" "(api|workflow|endpoint|route)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# Component/UI changes
COMPONENT_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(component|ui|view|page|layout|template)" | grep -v -iE "(api|route)" || echo "")
if [ -n "$COMPONENT_CHANGES" ]; then
  echo "⚠️  Component/UI changes detected:"
  echo "$COMPONENT_CHANGES" | sed 's/^/  - /'
  echo ""
  echo "  📚 Check these documentation files:"
  find_doc_files "(component|ui|feature|guide)" | sed 's/^/    - /'
  if [ -f "README.md" ]; then
    echo "    - README.md (check features section)"
  fi
  if [ -f "IDEA.md" ]; then
    echo "    - IDEA.md (check features section)"
  fi
  echo ""
  HAS_CHANGES=true
  CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
fi

# Configuration changes (including env.js and .gitignore)
CONFIG_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(config|\.env|env\.js|\.gitignore|package\.json|package-lock|yarn\.lock|bun\.lock|tsconfig|eslint|prettier|tailwind|\.config\.)" || echo "")
if [ -n "$CONFIG_CHANGES" ]; then
  if check_category "Configuration" "(config|\.env|env\.js|\.gitignore|package\.json|package-lock|yarn\.lock|bun\.lock|tsconfig|eslint|prettier|tailwind|\.config\.)" "(config|setup|install|environment)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# Authentication/Security changes
AUTH_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(auth|login|session|security|permission|role)" || echo "")
if [ -n "$AUTH_CHANGES" ]; then
  if check_category "Authentication/Security" "(auth|login|session|security|permission|role)" "(auth|security|login|session)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# Hook/Utility changes
HOOK_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(hook|util|lib|helper|service)" || echo "")
if [ -n "$HOOK_CHANGES" ]; then
  if check_category "Hook/Utility" "(hook|util|lib|helper|service)" "(util|helper|api|guide)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# Email/Template changes
EMAIL_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(email|mail|template|notification)" || echo "")
if [ -n "$EMAIL_CHANGES" ]; then
  if check_category "Email/Template" "(email|mail|template|notification)" "(email|mail|notification|template)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# Test changes
TEST_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(test|spec|__tests__|\.test\.|\.spec\.)" || echo "")
if [ -n "$TEST_CHANGES" ]; then
  if check_category "Test" "(test|spec|__tests__|\.test\.|\.spec\.)" "(test|testing|spec)"; then
    HAS_CHANGES=true
    CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
  fi
fi

# Style/CSS changes
STYLE_CHANGES=$(echo "$CODE_FILES_CHANGED" | grep -iE "(\.css|\.scss|\.sass|\.less|style)" || echo "")
if [ -n "$STYLE_CHANGES" ]; then
  echo "⚠️  Style/CSS changes detected:"
  echo "$STYLE_CHANGES" | sed 's/^/  - /'
  echo ""
  echo "  📚 Check these documentation files:"
  find_doc_files "(style|css|theme|design)" | sed 's/^/    - /'
  if [ -f "README.md" ]; then
    echo "    - README.md (check if styling features changed)"
  fi
  echo ""
  HAS_CHANGES=true
  CATEGORIES_FOUND=$((CATEGORIES_FOUND + 1))
fi

# Other changes (files that don't fit into specific categories)
# Optimize: collect all categorized files in one pass
CATEGORIZED_FILES=$(echo -e "$SCHEMA_CHANGES\n$API_CHANGES\n$COMPONENT_CHANGES\n$CONFIG_CHANGES\n$AUTH_CHANGES\n$HOOK_CHANGES\n$EMAIL_CHANGES\n$TEST_CHANGES\n$STYLE_CHANGES\n$DOC_FILES_CHANGED" | sort -u | grep -v '^$')
OTHER_CHANGES=$(comm -23 <(echo "$ALL_CHANGED" | sort) <(echo "$CATEGORIZED_FILES" | sort) | grep -v '^$' || echo "")

if [ -n "$OTHER_CHANGES" ]; then
  echo "📄 Other changes detected:"
  echo "$OTHER_CHANGES" | sed 's/^/  - /'
  echo ""
  echo "  📚 Review these files and check relevant documentation:"
  # Deterministic: check common root documentation files
  for doc in README.md SETUP.md IDEA.md CONTRIBUTING.md CHANGELOG.md; do
    if [ -f "$doc" ]; then
      echo "    - $doc"
    fi
  done
  # Also check docs directory
  if [ -d ".docs" ]; then
    find .docs -type f \( -name "*.md" -o -name "*.puml" \) 2>/dev/null | head -5 | sed 's/^/    - /' || true
  fi
  echo ""
  HAS_CHANGES=true
fi

if [ "$HAS_CHANGES" = true ]; then
  # Summary statistics
  TOTAL_CHANGED=$(echo "$ALL_CHANGED" | wc -l | xargs)
  CODE_CHANGED=$(echo "$CODE_FILES_CHANGED" | wc -l | xargs)
  DOC_CHANGED=$(echo "$DOC_FILES_CHANGED" | wc -l | xargs)
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Summary:"
  echo "  • Total files changed: $TOTAL_CHANGED"
  echo "  • Code files changed: $CODE_CHANGED"
  echo "  • Documentation files changed: $DOC_CHANGED"
  echo "  • Categories affected: $CATEGORIES_FOUND"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📚 Documentation Review Required:"
  echo ""
  echo "  The documentation files listed above are suggestions based on file patterns."
  echo "  However, you should also:"
  echo ""
  echo "  🔍 Exploratory File Finding:"
  echo "  - Search the project for additional documentation files that may be relevant"
  echo "  - Look for documentation in subdirectories (.docs/, documentation/, etc.)"
  echo "  - Check for README files in subdirectories that might be affected"
  echo "  - Review any architecture or design documents"
  echo "  - Check for inline documentation in code comments that may need updates"
  echo ""
  echo "  📝 Review Process:"
  echo "  - Read the changed code files to understand what changed"
  echo "  - Read the suggested documentation files listed above"
  echo "  - Search for and read any additional relevant documentation you discover"
  echo "  - Determine what information needs to be added or modified"
  echo "  - Update visual diagrams (PlantUML, etc.) if schemas/workflows changed"
  echo "  - Update setup instructions if configuration changed"
  echo "  - Update API documentation if endpoints changed"
  echo "  - Update feature descriptions if functionality changed"
  echo ""
  echo "  💡 Universal Guidelines:"
  echo "  - Keep documentation focused, concise, and up-to-date with code changes"
  echo "  - Documentation structure varies by project - adapt to the project's conventions"
  echo "  - When in doubt, search for existing documentation patterns in the project"
  echo "  - Consider creating new documentation if none exists for significant changes"
  echo ""
  echo "✅ Documentation check complete. Please review and update documentation as needed."
  exit 0
else
  echo "✅ No obvious documentation updates needed"
  exit 0
fi
