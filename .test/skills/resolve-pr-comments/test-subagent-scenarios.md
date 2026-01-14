# PR Comment Reviewer Subagent - Test Scenarios

Test scenarios for validating the `@pr-comment-reviewer` subagent behavior.

## Prerequisites

1. A PR with bot review comments (CodeRabbit, Gemini Code Assist, Copilot)
2. Run `bash content/skills/resolve-pr-comments/scripts/pr-resolver.sh {PR}` to generate clusters
3. Have at least one cluster with `actionable: true` (unresolved comments)

## How to Test

```bash
# In OpenCode, spawn the subagent with a cluster file:
@pr-comment-reviewer @.ada/data/pr-resolver/pr-{N}/clusters/{cluster}.md
```

---

## Scenario 1: False Positive Detection (Unused Import)

**Setup**: Bot claims an import is unused when it's actually used in JSX or dynamically.

**Expected Behavior**:
1. Subagent reads the file and line mentioned
2. Uses `grep` to search for actual usage of the import
3. Finds usage at line N
4. Classifies as `FALSE_POSITIVE` with confidence 85+
5. Dismisses with reason: "False positive: {import} is used at line {N} in {context}"
6. Does NOT make any code changes

**Verification**:
- [ ] No file edits made
- [ ] Dismiss reason includes line number and usage context
- [ ] JSON output shows `classification: "FALSE_POSITIVE"`
- [ ] Thread is dismissed, not resolved

---

## Scenario 2: Valid Fix (Import Path Error)

**Setup**: Bot correctly identifies an incorrect import path.

**Expected Behavior**:
1. Subagent reads the file and confirms import exists
2. Checks if the suggested path is correct
3. Classifies as `VALID_FIX` with confidence 85+
4. Applies minimal edit to fix the import path
5. Runs verification:
   - `lsp_diagnostics` - must pass
   - Tests (if exist) - must pass
   - Lint (if available) - must pass
6. Resolves the thread

**Verification**:
- [ ] Only the import line was changed
- [ ] No other modifications
- [ ] Diagnostics pass
- [ ] JSON output shows `verification.diagnostics: "pass"`
- [ ] Thread is resolved

---

## Scenario 3: Security Deferral

**Setup**: Bot flags a potential SQL injection or security vulnerability.

**Expected Behavior**:
1. Subagent reads the code and understands the issue
2. Analyzes whether the concern is valid
3. Regardless of confidence, classifies as `VALID_DEFER`
4. Does NOT make any code changes
5. Does NOT resolve or dismiss the thread
6. Documents full context in deferred_items

**Verification**:
- [ ] No file edits made
- [ ] Thread remains open
- [ ] JSON output shows `classification: "VALID_DEFER"`
- [ ] `deferred_items` array contains full context

---

## Scenario 4: Style vs Bug (const vs let)

**Setup**: Bot suggests using `const` instead of `let` for a variable.

**Expected Behavior**:
1. Subagent reads the file
2. Uses `grep` to check if the variable is reassigned
3. If reassigned: `FALSE_POSITIVE` - dismiss with evidence
4. If not reassigned: `VALID_FIX` - apply change and verify

**Verification**:
- [ ] Correctly identifies whether variable is reassigned
- [ ] If dismissed, reason includes reassignment location
- [ ] If fixed, diagnostics pass before resolving

---

## Scenario 5: Verification Failure Recovery

**Setup**: Bot suggests a fix that would break tests or diagnostics.

**Expected Behavior**:
1. Subagent applies the suggested fix
2. Runs verification suite
3. Verification fails (diagnostics error or test failure)
4. Immediately reverts the change
5. Classifies as `VALID_DEFER`
6. Does NOT resolve the thread
7. Documents what went wrong

**Verification**:
- [ ] Original file content restored after revert
- [ ] Thread remains open
- [ ] JSON output shows what verification step failed
- [ ] `deferred_items` explains the failure

---

## Scenario 6: Multiple Comments in Cluster

**Setup**: Cluster has 3+ unresolved comments about different issues in the same file.

**Expected Behavior**:
1. Phase 0: Creates mental plan for all comments
2. Processes each comment sequentially
3. Each comment gets independent classification
4. Verification runs after each fix
5. Output includes all actions in order

**Verification**:
- [ ] All unresolved comments addressed
- [ ] Each has classification and confidence
- [ ] Summary statistics are accurate
- [ ] JSON `actions` array has entry for each comment

---

## Output Format Validation

The subagent MUST produce both:

### 1. Markdown Summary (Human-Readable)

```markdown
## Results: {file} - {concern}

### Thinking Process
{Brief description}

### Actions Taken
| Comment ID | Classification | Confidence | Action | Reason |
|------------|----------------|------------|--------|--------|
| ... | ... | ... | ... | ... |

### Verification Summary
- **Diagnostics**: PASS/FAIL
- **Tests Run**: {details}
- **Lint**: PASS/FAIL/SKIPPED

### Statistics
- Fixed: N
- Dismissed: N
- Deferred: N
```

### 2. JSON Output (Machine-Readable)

```json
{
  "cluster_id": "...",
  "file": "...",
  "concern": "...",
  "summary": { "fixed": 0, "dismissed": 0, "deferred": 0, "total": 0 },
  "actions": [...],
  "verification_summary": {...},
  "deferred_items": [...]
}
```

---

## Anti-Pattern Detection

Watch for these failures:

| Anti-Pattern | What to Check |
|--------------|---------------|
| Resolving without verification | `verification.diagnostics` should be "pass" |
| Type suppressions added | No `as any`, `@ts-ignore`, `@ts-expect-error` |
| Scope creep in fixes | Only mentioned lines should change |
| Missing evidence for dismissals | All dismissals have specific file:line references |
| Resolving security comments | Security concerns should always DEFER |
| Continuing after verification failure | Should revert and DEFER |
| **Script not executed** | `script_executed` must not be null for resolved/dismissed |
| **Planning vs doing** | Check actual `bash` output, not just stated intent |
| **Missing script log** | `SCRIPTS EXECUTED` section must list actual commands run |

---

## Running the Test

1. Find or create a PR with bot comments
2. Run `bash content/skills/resolve-pr-comments/scripts/pr-resolver.sh {PR}`
3. Identify an actionable cluster
4. Spawn the subagent:

   ```bash
   @pr-comment-reviewer @.ada/data/pr-resolver/pr-{N}/clusters/{cluster}.md
   ```

5. Validate against the scenarios above
6. Check that output matches both Markdown and JSON formats

## Success Criteria

The subagent passes validation if:

- [ ] All scenarios handled correctly
- [ ] No files left in broken state
- [ ] All resolved threads have passing verification
- [ ] All dismissals have evidence
- [ ] All security items deferred
- [ ] JSON output parseable by jq
- [ ] Statistics match actual actions
- [ ] **Every resolved/dismissed thread has corresponding `script execution`**
- [ ] **`scripts_executed` array in JSON matches actual `bash` commands run**
- [ ] **"SCRIPTS EXECUTED" log shows actual output, not just planned commands**
