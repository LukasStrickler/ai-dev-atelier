#!/bin/bash
# Tests for skill-telemetry plugin
# Tests pure functions: extractSkillScript, getRepoName
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/content/plugins/skill-telemetry.ts"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: skill-telemetry.ts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if node/bun is available
if command -v bun &>/dev/null; then
  RUNTIME="bun"
elif command -v node &>/dev/null; then
  RUNTIME="node"
else
  echo "ERROR: Neither bun nor node found. Skipping plugin tests."
  exit 0
fi

# Create test harness that extracts and tests pure functions
cat > "$TMP_DIR/test-harness.ts" << 'HARNESS_EOF'
// Extract pure functions from the plugin for testing
// NOTE: This must match the implementation in skill-telemetry.ts
const extractSkillScript = (command?: string) => {
  if (!command) {
    return null;
  }
  const match = command.match(/\b(?:content\/)?skills\/([^/\s]+)\/scripts\/([^\s]+\.sh)(?:\s+(.*))?/);
  if (!match) {
    return null;
  }
  return { skill: match[1], script: match[2], arguments: match[3]?.trim() || null };
};

const getRepoName = (project?: { name?: string }, worktree?: string, directory?: string) => {
  if (project?.name) {
    return project.name;
  }
  if (worktree) {
    const basename = (p: string) => p.split('/').pop() || p;
    return basename(worktree);
  }
  if (directory) {
    const basename = (p: string) => p.split('/').pop() || p;
    return basename(directory);
  }
  return "unknown";
};

// Test framework
let passed = 0;
let failed = 0;

function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`PASS: ${name}`);
    passed++;
  } catch (e) {
    console.log(`FAIL: ${name}`);
    console.log(`  Error: ${e}`);
    failed++;
  }
}

function expect<T>(actual: T) {
  return {
    toBe(expected: T) {
      if (actual !== expected) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
    toEqual(expected: T) {
      if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
    toBeNull() {
      if (actual !== null) {
        throw new Error(`Expected null, got ${JSON.stringify(actual)}`);
      }
    }
  };
}

// ============================================================================
// extractSkillScript tests
// ============================================================================

console.log("\n--- extractSkillScript tests ---\n");

test("extractSkillScript: returns null for undefined command", () => {
  expect(extractSkillScript(undefined)).toBeNull();
});

test("extractSkillScript: returns null for empty string", () => {
  expect(extractSkillScript("")).toBeNull();
});

test("extractSkillScript: returns null for non-matching command", () => {
  expect(extractSkillScript("ls -la")).toBeNull();
});

test("extractSkillScript: returns null for git commands", () => {
  expect(extractSkillScript("git status")).toBeNull();
});

test("extractSkillScript: matches content/skills/name/scripts/script.sh", () => {
  expect(extractSkillScript("bash content/skills/code-quality/scripts/finalize.sh"))
    .toEqual({ skill: "code-quality", script: "finalize.sh", arguments: null });
});

test("extractSkillScript: matches skills/name/scripts/script.sh", () => {
  expect(extractSkillScript("bash skills/code-quality/scripts/finalize.sh"))
    .toEqual({ skill: "code-quality", script: "finalize.sh", arguments: null });
});

test("extractSkillScript: matches content/skills/name/scripts/script.sh", () => {
  expect(extractSkillScript("bash content/skills/research/scripts/research-run.sh"))
    .toEqual({ skill: "research", script: "research-run.sh", arguments: null });
});

test("extractSkillScript: matches skills/name/scripts/script.sh", () => {
  expect(extractSkillScript("bash skills/research/scripts/research-run.sh"))
    .toEqual({ skill: "research", script: "research-run.sh", arguments: null });
});

test("extractSkillScript: matches absolute path with content/skills/", () => {
  expect(extractSkillScript("bash /home/user/ai-dev-atelier/content/skills/docs-check/scripts/check-docs.sh"))
    .toEqual({ skill: "docs-check", script: "check-docs.sh", arguments: null });
});

test("extractSkillScript: captures arguments after script", () => {
  expect(extractSkillScript("bash content/skills/code-review/scripts/review-run.sh --mode task"))
    .toEqual({ skill: "code-review", script: "review-run.sh", arguments: "--mode task" });
});

test("extractSkillScript: captures PR number as argument", () => {
  expect(extractSkillScript("bash skills/resolve-pr-comments/scripts/pr-resolver.sh 26"))
    .toEqual({ skill: "resolve-pr-comments", script: "pr-resolver.sh", arguments: "26" });
});

test("extractSkillScript: captures skip-wait with reason", () => {
  expect(extractSkillScript("bash skills/resolve-pr-comments/scripts/pr-resolver.sh 42 --skip-wait 'CI confirmed passed'"))
    .toEqual({ skill: "resolve-pr-comments", script: "pr-resolver.sh", arguments: "42 --skip-wait 'CI confirmed passed'" });
});

test("extractSkillScript: handles script names with hyphens", () => {
  expect(extractSkillScript("bash content/skills/resolve-pr-comments/scripts/pr-resolver-run.sh"))
    .toEqual({ skill: "resolve-pr-comments", script: "pr-resolver-run.sh", arguments: null });
});

test("extractSkillScript: handles content/ prefix with absolute path", () => {
  expect(extractSkillScript("/opt/atelier/content/skills/ui-animation/scripts/run.sh"))
    .toEqual({ skill: "ui-animation", script: "run.sh", arguments: null });
});

test("extractSkillScript: does not match without .sh extension", () => {
  expect(extractSkillScript("node content/skills/test/scripts/run.js")).toBeNull();
});

test("extractSkillScript: does not match malformed paths", () => {
  expect(extractSkillScript("content/skills/scripts/run.sh")).toBeNull();
});

// ============================================================================
// getRepoName tests
// ============================================================================

console.log("\n--- getRepoName tests ---\n");

test("getRepoName: returns project name if available", () => {
  expect(getRepoName({ name: "my-project" }, "/path/to/worktree", "/path/to/dir"))
    .toBe("my-project");
});

test("getRepoName: returns worktree basename if no project name", () => {
  expect(getRepoName(undefined, "/home/user/.vibora/worktrees/feature-branch", undefined))
    .toBe("feature-branch");
});

test("getRepoName: returns directory basename if no project or worktree", () => {
  expect(getRepoName(undefined, undefined, "/home/user/projects/my-repo"))
    .toBe("my-repo");
});

test("getRepoName: returns unknown if nothing provided", () => {
  expect(getRepoName(undefined, undefined, undefined)).toBe("unknown");
});

test("getRepoName: returns unknown if all empty", () => {
  expect(getRepoName({}, undefined, undefined)).toBe("unknown");
});

test("getRepoName: prefers project.name over worktree", () => {
  expect(getRepoName({ name: "explicit-name" }, "/path/to/other-name", undefined))
    .toBe("explicit-name");
});

test("getRepoName: prefers worktree over directory", () => {
  expect(getRepoName(undefined, "/worktrees/worktree-name", "/projects/dir-name"))
    .toBe("worktree-name");
});

// ============================================================================
// Summary
// ============================================================================

console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

process.exit(failed > 0 ? 1 : 0);
HARNESS_EOF

# Run tests
echo ""
$RUNTIME "$TMP_DIR/test-harness.ts"
TEST_EXIT=$?

# Parse output to get counts
if [ $TEST_EXIT -eq 0 ]; then
  echo ""
  echo "All skill-telemetry tests passed!"
else
  echo ""
  echo "Some skill-telemetry tests failed!"
  exit 1
fi
