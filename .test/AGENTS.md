# TEST SUITE KNOWLEDGE BASE

**Generated:** 2026-01-14
**Context:** Custom Bash Testing & Analysis Framework

## OVERVIEW
Lightweight, dependency-free Bash testing suite for validating skills, analyzing telemetry, and ensuring configuration integrity.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Integration Tests** | `tests/` | Executable `test-*.sh` scripts. Run directly or via make. |
| **Telemetry Analysis** | `analysis/` | Scripts to crunch session data (`analyze-*.sh`). |
| **Test Fixtures** | `analysis/fixtures/` | Sample JSONL datasets for analysis logic. |
| **Skill Validation** | `scripts/` | `validate-skills.sh` checks structure compliance. |
| **Linting** | `scripts/lint-shell.sh` | ShellCheck wrapper for project consistency. |

## CONVENTIONS
- **Framework**: Pure Bash. No `jest`, `mocha`, or Python deps allowed.
- **Execution**: All `tests/*.sh` must be executable (`chmod +x`).
- **Assertions**: Use simple exit codes (`exit 1` on fail). Define `pass`/`fail` helpers locally.
- **Mocking**: Mock external tools (gh, git) by prepending temp scripts to `$PATH`.
- **Safety**: Strict mode `set -euo pipefail` is mandatory in all scripts.
- **Cleanup**: Use `trap` to ensure temp directories are removed on exit.

## ANTI-PATTERNS
- **Heavy Dependencies**: NEVER introduce node_modules or pip requirements.
- **Hardcoded Paths**: NEVER use absolute paths like `/home/user`. Use `$(pwd)`.
- **Production Data**: NEVER commit real telemetry. Use `fixtures/` synthetic data.
- **Global State**: DO NOT rely on user's ~/.gitconfig. Mock git config locally.
- **Silent Failures**: NEVER swallow errors in pipes; always use `pipefail`.
