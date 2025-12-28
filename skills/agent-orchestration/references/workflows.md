# Workflow Guide

## Orchestrator Flow (Required)

1. Get user prompt (requirements, constraints, success criteria)
2. Search (Researcher: codebase search, then web search if needed)
3. Plan (Orchestrator: phases + workstreams)
4. Implement (Implementer)
5. Test (Tester)
6. Document (Documenter)
7. Verify (Reviewer)

## Role Workflow

- Researcher: gather sources, produce `answer.md`, cite sources
- Implementer: scoped code changes, no tests unless asked
- Tester: run tests, fix failures, record commands + outcomes
- Documenter: update docs using docs-check + docs-write guidance
- Reviewer: verify requirements, tests, docs, and risks

## Context Passing

Downward (orchestrator -> specialist):
- Orchestrator brief (`references/orchestrator-brief.md`)
- Subagent task brief (`references/subagent-task-brief.md`)
- Minimal context pack (`--context-file`)
 - `prompt.md` is written automatically by wrappers and contains full role + task context (single source of truth)

Upward (specialist -> orchestrator):
- Result contract (`references/result-contract.md`)

## Single Context File Policy

All context passed to specialists is embedded into the prompt and written to `prompt.md` in the worktree and run directory. No other context file is used.

## Batch Responsibility

When spawning multiple agents:
- Orchestrator resolves merge conflicts
- Orchestrator confirms outputs match the original prompt
- A specialist who spawns helpers owns the same responsibilities for that subtask

## Helper Rules

- Specialists may spawn multiple helpers (Level 3)
- Helpers must not spawn further agents

## Runtime Selection

- Research: always `await`
- Work: `await` for risky changes, `ff` for low-risk tasks
- Auto-merge: use `agent-run.sh --merge` or `agent-run-batch.sh --merge`
- Wrappers override `runtime=ff` to `await` in research mode

## Rescue Follow-up

If a run fails to produce results after rescue attempts, check the run directory for:
- `rescue.md` (diagnostics + next steps)
- `rescue.sh` (re-run with the original prompt)
