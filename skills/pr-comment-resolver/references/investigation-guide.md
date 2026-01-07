# Deferred Item Investigation Guide

When subagents defer items, the orchestrator should attempt self-investigation before escalating to humans.

## Triage Classification

| Defer Reason | Self-Investigable? | Action |
|--------------|-------------------|--------|
| **Low confidence (50-69)** | YES | Investigate with more context |
| **Conflicting evidence** | YES | Gather more evidence, break tie |
| **Complex refactor** | MAYBE | Assess scope first |
| **Unclear requirement** | NO | Escalate to human |
| **Security concern** | **NEVER** | Escalate immediately |

**Security Rule (ABSOLUTE)**: Never self-investigate security concerns. Always escalate.

## Investigation Workflow

For each investigable deferred item:

```
1. READ the deferred_item context from subagent output
   │
   ├── What did the subagent check?
   ├── Why was confidence low?
   └── What investigation did subagent suggest?

2. READ the file at the mentioned location (±30 lines context)
   │
   └── Understand the full function/component, not just the line

3. GATHER additional evidence
   │
   ├── grep: Search for patterns the subagent might have missed
   ├── lsp_find_references: Check how the code is used
   ├── lsp_hover: Understand types and signatures
   └── read: Check related files (imports, callers)

4. CHECK resolved comments in same cluster
   │
   └── What patterns were already validated/dismissed?

5. SEARCH codebase for similar patterns
   │
   └── How is this pattern handled elsewhere?
```

## Post-Investigation Decision

| New Confidence | Action |
|----------------|--------|
| **≥70** | Apply fix or dismiss with evidence |
| **50-69** | Document findings, escalate with notes |
| **<50** | Escalate immediately |

**If you resolved it yourself, execute the scripts:**

```bash
# After fixing
bash skills/pr-comment-resolver/scripts/pr-resolver-resolve.sh <PR> <COMMENT_ID>

# After dismissing with evidence
bash skills/pr-comment-resolver/scripts/pr-resolver-dismiss.sh <PR> <COMMENT_ID> "reason with evidence"
```

## Investigation Examples

### Example A: Low Confidence Import Fix

**Deferred**: "Import path might be wrong" (confidence: 55)

**Your Investigation**:
```
1. Read the import statement and surrounding code
2. Check if the import target exists: glob("**/utils/index.ts")
3. Check if there's an alias: read tsconfig.json paths
4. Check how other files import from utils: grep "from.*utils"
5. Check if module resolution is configured specially

Result: Found tsconfig path alias "@/utils" → import is correct
Action: Dismiss with evidence
```

### Example B: Conflicting Evidence

**Deferred**: "Function might be unused" (subagent found 0 direct calls, but unsure)

**Your Investigation**:
```
1. lsp_find_references on the function
2. grep for the function name in string form (dynamic calls)
3. Check if exported and used by external consumers
4. Check if called via reflection/eval patterns

Result: Found dynamic import in plugin loader
Action: Dismiss - "Function loaded dynamically at runtime via plugin system"
```

### Example C: Complex Refactor Assessment

**Deferred**: "Needs refactor but scope unclear"

**Your Investigation**:
```
1. Understand what refactor is suggested
2. Count affected files: grep for pattern
3. Check if isolated or cross-cutting
4. Estimate effort: 1 file = in-scope, 5+ files = out-of-scope

Result: 12 files would need changes
Action: Escalate - "Refactor touches 12 files, recommend separate PR"
```

## Escalation Decision Tree

```
Deferred Item
    │
    ├── Security related?
    │   └── YES → ESCALATE (no investigation)
    │
    └── NO → Investigate
            │
            ├── Can gather more evidence?
            │   └── NO → ESCALATE
            │
            └── YES → Investigate
                    │
                    ├── Confidence now ≥70?
                    │   └── YES → RESOLVE (fix or dismiss)
                    │
                    └── NO → ESCALATE with investigation notes
```

## Documentation Template

Whether resolved or escalated, document what you checked:

```markdown
### Deferred Item Investigation: Comment {ID}

**Original Defer Reason**: {subagent's reason}
**Subagent Confidence**: {N}%

**Investigation Performed**:
- Read {file}:{lines}
- Searched for {patterns}
- Checked {N} references to {symbol}
- Reviewed {N} similar patterns in codebase

**Findings**:
{what you discovered}

**Determination**: 
- [ ] RESOLVED - Applied fix / Dismissed with evidence
- [ ] ESCALATE - Still uncertain because {reason}

**New Confidence**: {M}%
```

## Escalation Format

When escalating to human, provide full context:

```markdown
## Deferred Items Requiring Human Review

### 1. Comment {ID} - {file}:{line}

**Original Comment**: {bot's comment}
**Subagent Reason**: {why deferred}
**Subagent Confidence**: {N}%

**My Investigation**:
{what you checked and found}

**Why I'm Escalating**:
{specific uncertainty}

**Options I See**:
1. {option A} - {implications}
2. {option B} - {implications}

**My Recommendation**: {if you have one}
```

## When to Escalate (Mandatory)

| Scenario | Escalation Required |
|----------|---------------------|
| Any security-related comment | YES - Always |
| Breaking API changes | YES |
| Performance implications unclear | YES |
| Multiple valid interpretations | YES (ask for preference) |
| Subagent failed 2+ times on same item | YES |
