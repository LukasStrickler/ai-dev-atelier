# AGENTS.md

This file defines how AI agents and contributors should work in this repository.

## Overview

AI Dev Atelier: Production-grade skill pack for AI-assisted development. 9 skills following Anthropic Agent Skills standard, with MCP integrations for search/research.

## For AI agents

Read these first:
- `README.md` for capabilities and entry points
- `SETUP.md` for verification steps
- `INSTALL.md` for dependencies and MCP setup
- `WORKFLOW_EXAMPLE.md` for a personal OpenCode + Vibekanban usage example

## Structure

```text
ai-dev-atelier/
├── skills/                    # 9 skill directories
│   ├── <name>/SKILL.md        # YAML frontmatter + instructions
│   ├── <name>/scripts/        # Executable bash scripts
│   └── <name>/references/     # Guides, templates, examples
├── .test/                     # Validation and integration tests
├── .ada/                      # Runtime outputs (gitignored)
├── install.sh                 # Deploy skills + MCPs
├── setup.sh                   # Verify structure
├── mcp.json                   # MCP server definitions
└── skills-config.json         # Per-agent skill filtering
```

## Skills Quick Reference

| Skill | Purpose | Entry Script |
|-------|---------|--------------| 
| `code-quality` | Typecheck, lint, format, Markdown | `scripts/finalize.sh` |
| `docs-check` | Detect docs needing updates from git diff | `scripts/check-docs.sh` |
| `docs-write` | Write/update docs with standards | Workflow (no script) |
| `git-commit` | Write clear commits with Conventional Commits | Workflow (no script) |
| `code-review` | CodeRabbit reviews (task/pr modes) | `scripts/review-run.sh` |
| `pr-review` | Fetch/resolve/dismiss PR comments | `scripts/pr-comments-*.sh` |
| `search` | Web + library docs + GitHub code search | MCP-based |
| `research` | Academic research with evidence cards | `scripts/research-*.sh` |
| `agent-orchestration` | Spawn/manage hierarchical subagents | `scripts/agent-*.sh` |

## Commands

```bash
bash setup.sh                              # Verify structure
bash install.sh                            # Install skills + MCPs
bash .test/scripts/validate-skills.sh      # Validate all skills
bash skills/<skill>/scripts/<script>.sh    # Run skill script
```

> **Tip**: You can also use `make setup`, `make install`, `make validate` for shorter commands.

## Install Locations

| Agent | Skills Path | MCP Config |
|-------|-------------|------------|
| Codex | `~/.codex/skills` | `~/.codex/config.toml` |
| OpenCode | `~/.opencode/skill` | `~/.opencode/opencode.json` |

Respects `$XDG_CONFIG_HOME` if set.

## MCP Servers

| Server | Purpose | Required Key |
|--------|---------|--------------|
| `tavily-remote-mcp` | Web search | `TAVILY_API_KEY` |
| `context7` | Library docs | Optional |
| `grep` | GitHub code search | None |
| `openalex-research` | Academic papers | `OPENALEX_EMAIL` |
| `pdf-reader` | PDF extraction | None |
| `paper-search` | Multi-platform papers | Optional |

Set keys in `.env` before `install.sh`, or update MCP config after.

## Data Outputs

All runtime data under `.ada/` (gitignored):
- `.ada/data/reviews/` - Code review results
- `.ada/data/pr-comments/` - PR comment snapshots
- `.ada/data/research/{topic}/` - Evidence cards, reports
- `.ada/data/agents/runs/` - Agent orchestration runs
- `.ada/data/agents/worktrees/` - Agent git worktrees
- `.ada/temp/` - Temporary files (downloads, etc.)

## Anti-Patterns (THIS PROJECT)

**Documentation skills:**
- Never assume docs format - ALWAYS load `references/documentation-guide.md` first
- Never proceed without reading the guide

**Research skill:**
- Never skip Step 0 (codebase context) - ALWAYS gather context first
- Never stop at 1-2 evidence cards - ALWAYS produce 5+ cards
- Never batch tool calls without writing - write after 1-2 calls

**Agent orchestration:**
- Helpers (Level 3) must NOT spawn further agents
- No lateral communication between specialists - report only to parent
- Stay within scope - do not change unrelated files

**PR review:**
- Never use detected PR number without validation - check workspace state first

## Skill Format

Each skill follows Anthropic Agent Skills standard:

```yaml
---
name: skill-name
description: "Purpose and triggers (max 1024 chars)"
---
```

Body contains: instructions, workflows, examples, script references.

## Guardrails

- Do not commit unless explicitly requested
- Do not modify global git config
- Do not add or expose secrets in files
- Keep changes scoped to the requested task
- Use `skills-config.json` to disable skills per agent

## Testing

```bash
bash .test/scripts/validate-skills.sh       # Validate skill structure
bash .test/scripts/validate-skills-tests.sh # Test the validator itself
```

Agent orchestration has integration tests in `.test/skills/agent-orchestration/`.

## For human contributors

Before changes:
- Run `bash setup.sh`

After changes:
- Run `bash .test/scripts/validate-skills.sh`
- Ensure each skill keeps the `SKILL.md` format and embedded scripts

When adding or updating skills:
- Keep instructions and scripts inside the skill folder
- Update `skills/README.md` if the catalog changes
- Keep outputs under `.ada/`
