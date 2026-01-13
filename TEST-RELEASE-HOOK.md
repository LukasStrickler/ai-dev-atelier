# Test: Release Hook Allows Read-Only Operations

## Purpose
Verify that the fixed `release-block-hook.sh` properly allows read-only operations to GitHub releases endpoint while blocking write operations.

## Tests Performed

### ✅ Read-Only Operations (ALLOWED)
```bash
# Test 1: curl GET to releases endpoint (no write indicators)
curl -s https://api.github.com/repos/knowsuchagency/vibora/releases/latest | grep -E '"tag_name"|"published_at"|"name"'

# Result: Returns release metadata
# Expected: Hook should ALLOW this (no -X, --data, -F, etc.)
```

### ❌ Write Operations (BLOCKED)
```bash
# Test 2: curl POST to releases endpoint
curl -X POST -H "Content-Type: application/json" https://api.github.com/repos/test/releases -d '{"tag_name":"test"}'

# Expected: Hook should BLOCK this (has -X POST)
# Error message: "🚫 BLOCKED: Releases require human approval."
```

## Fix Applied

Modified `/home/lukas/projects/ai-dev-atelier/.hooks/release-block-hook.sh` to check for write indicators before blocking curl/wget requests to GitHub releases endpoint:

**What changed:**
- **Before**: Blocked ALL `curl|wget|http|https .*api\.github\.com.*/releases`
- **After**: Checks for write indicators (`-X POST/PUT/PATCH/DELETE`, `--data`, `-d`, `-F`, etc.) and only blocks those

**Write indicators now detected:**
- `-X POST|PUT|PATCH|DELETE`
- `--method POST|PUT|PATCH|DELETE`
- `--data`, `-d`
- `--data-binary`
- `--post-data`
- `--form`, `-F`
- `--upload-file`, `-T`

**Allowed (read-only):**
- Default GET requests (no write indicators)

## Documentation Alignment

Fix aligns with `docs/RELEASING.md` which states:
> "gh api /repos/.../releases (GET requests for reading release info)"
> "gh release list, gh release view (read-only operations)"

## Test Results

✅ All 259 existing tests in `.test/tests/test-release-block.sh` pass
✅ 4 new tests added for read-only curl/wget to releases endpoint
✅ Manual verification: `curl -s https://api.github.com/repos/knowsuchagency/vibora/releases/latest` works

## Commit

`ef89576` - "fix(hook): allow read-only curl/wget to api.github.com releases endpoint"
