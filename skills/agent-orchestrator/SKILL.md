---
name: agent-orchestrator
description: Design and run hierarchical multi-agent workflows (orchestrator -> specialist -> helper) with structured plans, role prompts, context packages, and verification checklists. Use when delegating complex tasks to subagents, coordinating research/implementation/testing/documentation, or enforcing strict task scopes and requirement coverage.
---

# Agent Orchestrator

Design and run hierarchical orchestration using structured task briefs, role templates, and verification steps. This skill provides the planning and prompt scaffolding; use the `agent-orchestration` skill/scripts to spawn and collect agents.

## Quick Start

1. Create an **Orchestrator Brief** using `references/orchestrator-brief.md`.
2. Split work into **workstreams** with unique IDs (R1, I1, T1, D1).
3. Create a **Subagent Task Brief** for each workstream using `references/subagent-task-brief.md`.
4. Spawn specialists with `agent-spawn.sh` and pass the brief content as the prompt.
5. Collect results and run the **verification checklist** (`references/verification-checklist.md`).

## Workflow

### Step 0: Decide if orchestration is needed
Use orchestration only when the task has multiple distinct workstreams (research + implementation + tests + docs) or requires strict verification.

### Step 1: Build the Orchestrator Brief
Use `references/orchestrator-brief.md` to define:
- Requirements and constraints
- Plan by phase (research -> plan -> implement -> test -> docs -> verify)
- Workstreams with owners
- Definition of done

### Step 2: Define roles and context packages
Use `references/role-templates.md` for baseline roles (researcher, implementer, tester, doc-writer, reviewer). For each subagent:
- Provide **scope** (what to do, what not to do)
- Provide **inputs** (files, directories, relevant context)
- Provide **outputs** (expected files or summaries)
- Provide **success criteria**

### Step 3: Spawn specialists (Level 2)
Use `agent-spawn.sh` with `--parent-run-id` and `--max-depth 3` for strict hierarchy. Keep specialists **stateless** with a minimal context pack.

Example:
```bash
PROMPT="$(cat /path/to/subagent-brief.md)"
RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode work \
  --runtime await \
  --prompt "$PROMPT" \
  --parent-run-id "$ORCH_RUN_ID" \
  --max-depth 3 \
  --model auto)
```

### Step 4: Optional helpers (Level 3)
Level-2 specialists may spawn a **single-level helper** for tightly scoped tasks (e.g., bugfix, micro-research). Helpers must be scoped to the specialist's workstream and return results to the specialist only.

### Step 5: Collect and verify
Collect outputs with `agent-collect.sh`. Run `references/verification-checklist.md` to confirm:
- Implementation matches requirements
- Tests executed and failures resolved
- Documentation updated
- Requirements coverage confirmed

## Hierarchy Rules

- **Level 1 (Orchestrator):** Owns plan, task allocation, verification, merge decisions.
- **Level 2 (Specialists):** Execute assigned scope; may spawn Level 3 helpers.
- **Level 3 (Helpers):** Tightly scoped tasks only; no further spawning.
- **No lateral communication** between specialists. All handoffs go through the parent.

## Context Packaging Rules

- **Minimal context**: only the files and decisions needed to complete the task
- **Include:** task brief, relevant file paths, expected output format, constraints
- **Avoid:** full repo dumps, unrelated notes, or overlapping workstreams

## Result Contract

Ask each specialist to return a short summary using `references/result-contract.md` so the orchestrator can quickly aggregate results.

## References

- `references/orchestrator-brief.md` - Template for orchestration plan
- `references/subagent-task-brief.md` - Template for specialist tasks
- `references/role-templates.md` - Baseline role prompts
- `references/result-contract.md` - Standard result summary format
- `references/verification-checklist.md` - Verification checklist
