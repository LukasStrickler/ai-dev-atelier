#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-skills.sh"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

SKILLS_DIR="${TMP_DIR}/skills"
mkdir -p "$SKILLS_DIR"

expect_fail() {
  local skill_name="$1"
  if SKILLS_DIR_OVERRIDE="$SKILLS_DIR" bash "$VALIDATOR" "$skill_name" > /dev/null 2>&1; then
    echo "FAIL: ${skill_name} should have failed"
    exit 1
  fi
  echo "PASS: ${skill_name} failed as expected"
}

expect_pass() {
  local skill_name="$1"
  if ! SKILLS_DIR_OVERRIDE="$SKILLS_DIR" bash "$VALIDATOR" "$skill_name" > /dev/null 2>&1; then
    echo "FAIL: ${skill_name} should have passed"
    exit 1
  fi
  echo "PASS: ${skill_name} passed"
}

mkdir -p "$SKILLS_DIR/good-skill"
cat > "$SKILLS_DIR/good-skill/SKILL.md" <<'EOF'
---
name: good-skill
description: "Short description."
---
# Good
EOF

mkdir -p "$SKILLS_DIR/bad-no-close"
cat > "$SKILLS_DIR/bad-no-close/SKILL.md" <<'EOF'
---
name: bad-no-close
description: "Missing closing frontmatter."
# Missing closing delimiter
EOF

mkdir -p "$SKILLS_DIR/bad-name"
cat > "$SKILLS_DIR/bad-name/SKILL.md" <<'EOF'
---
name: Bad Name
description: "Invalid name format."
---
# Bad Name
EOF

long_desc=$(printf 'a%.0s' {1..1025})
mkdir -p "$SKILLS_DIR/bad-desc-length"
cat > "$SKILLS_DIR/bad-desc-length/SKILL.md" <<EOF
---
name: bad-desc-length
description: "${long_desc}"
---
# Bad Desc Length
EOF

mkdir -p "$SKILLS_DIR/bad-desc-block"
cat > "$SKILLS_DIR/bad-desc-block/SKILL.md" <<'EOF'
---
name: bad-desc-block
description: |
  Multi-line description not allowed.
---
# Bad Desc Block
EOF

expect_pass "good-skill"
expect_fail "bad-no-close"
expect_fail "bad-name"
expect_fail "bad-desc-length"
expect_fail "bad-desc-block"

rm -rf "$SKILLS_DIR"
mkdir -p "$SKILLS_DIR/dup-one" "$SKILLS_DIR/dup-two"
cat > "$SKILLS_DIR/dup-one/SKILL.md" <<'EOF'
---
name: dup-skill
description: "Duplicate name test."
---
# Dup One
EOF
cat > "$SKILLS_DIR/dup-two/SKILL.md" <<'EOF'
---
name: dup-skill
description: "Duplicate name test."
---
# Dup Two
EOF

if SKILLS_DIR_OVERRIDE="$SKILLS_DIR" bash "$VALIDATOR" > /dev/null 2>&1; then
  echo "FAIL: duplicate names should have failed"
  exit 1
fi

echo "PASS: duplicate name check failed as expected"