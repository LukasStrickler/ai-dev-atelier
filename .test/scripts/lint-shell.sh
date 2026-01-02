#!/bin/bash
# Shell script linting with shellcheck
# Usage: bash .test/scripts/lint-shell.sh
#
# Lints all shell scripts in the repository using shellcheck.
# Exits with code 0 if all scripts pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║         SHELL SCRIPT LINT REPORT           ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    echo -e "${RED}❌ shellcheck not found${NC}"
    echo "Install with:"
    echo "  macOS: brew install shellcheck"
    echo "  Linux: sudo apt-get install shellcheck"
    exit 1
fi

SHELLCHECK_VERSION=$(shellcheck --version | grep "^version:" | cut -d' ' -f2)
echo -e "${GREEN}✓${NC} shellcheck version: ${SHELLCHECK_VERSION}"
echo ""

# Build exclusion list
FIND_EXCLUDES=(
    -not -path "*/.ada/*"
    -not -path "*/node_modules/*"
    -not -path "*/.git/*"
)

# Only exclude worktrees if we're NOT running from inside one
# (worktrees have a .git file, not a .git directory)
if [[ ! -f "$ROOT_DIR/.git" ]]; then
    FIND_EXCLUDES+=(-not -path "*-worktree/*")
fi

# Find all shell scripts
TOTAL=0
PASSED=0
FAILED=0
FAILED_FILES=()

while IFS= read -r -d '' script; do
    TOTAL=$((TOTAL + 1))
    relative_path="${script#$ROOT_DIR/}"

    # Run shellcheck with external sources enabled (reads .shellcheckrc)
    if shellcheck -x "$script"; then
        echo -e "${GREEN}✓${NC} $relative_path"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌${NC} $relative_path"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$relative_path")
    fi
done < <(find "$ROOT_DIR" -name "*.sh" -type f \
    "${FIND_EXCLUDES[@]}" \
    -print0 2>/dev/null | sort -z)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Failed scripts:${NC}"
    for f in "${FAILED_FILES[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo "Run 'shellcheck -x <script>' for detailed errors"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All shell scripts passed linting!${NC}"
exit 0
