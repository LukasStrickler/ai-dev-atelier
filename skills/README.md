# AI Dev Atelier Skills

Skills provide specialized capabilities for AI agents working with code quality, documentation, code reviews, and PR management.

## Overview

Skills are organized directories containing `SKILL.md` files that follow the [Anthropic Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) format. Each skill has YAML frontmatter with `name` and `description`, followed by detailed instructions.

## Available Skills

| Skill | Description | Scripts |
|-------|-------------|---------|
| [`code-quality`](./code-quality/SKILL.md) | Run comprehensive code quality checks including typecheck, lint, format, and markdown validation | `scripts/finalize.sh` (agent/ci modes) |
| [`docs-check`](./docs-check/SKILL.md) | Analyze git diff to identify code changes requiring documentation updates | `scripts/check-docs.sh` |
| [`docs-write`](./docs-write/SKILL.md) | Write or update documentation with clear style, structure, visuals, API/ADR/runbook patterns | N/A (workflow skill) |
| [`git-commit`](./git-commit/SKILL.md) | Write clear git commits with Conventional Commits format, detect project conventions | N/A (workflow skill) |
| [`code-review`](./code-review/SKILL.md) | Review code changes using CodeRabbit - uncommitted files (task mode) or all PR files vs main (pr mode) | `scripts/review-*.sh` |
| [`pr-review`](./pr-review/SKILL.md) | Manage GitHub PR comments - fetch, resolve, dismiss, and interact with review comments | `scripts/pr-comments-*.sh` |
| [`search`](./search/SKILL.md) | Search the web and library documentation using Tavily and Context7 MCPs | N/A (MCP-based skill) |
| [`research`](./research/SKILL.md) | Conduct academic research using OpenAlex, PDF extraction, and paper search MCPs with evidence cards | `scripts/research-*.sh` |
| [`agent-orchestration`](./agent-orchestration/SKILL.md) | Spawn and manage hierarchical AI sub-agents with role-aware wrappers and verification templates | `scripts/agent-*.sh`, `scripts/orchestrator-*.sh` |

## Quick Reference

### Code Quality
- **When to use**: Before committing, in CI pipelines, after making changes
- **How agents use it**: Agents read `SKILL.md` and execute `scripts/finalize.sh` with `agent` or `ci` mode
- **Scripts**: Embedded in `skills/code-quality/scripts/finalize.sh`

### Documentation Check
- **When to use**: After making code changes, before committing
- **How agents use it**: Agents read `SKILL.md` and execute `scripts/check-docs.sh`
- **Scripts**: Embedded in `skills/docs-check/scripts/check-docs.sh`
- **References**: See `docs-check/references/documentation-guide.md` for what to document

### Documentation Write
- **When to use**: Creating or updating documentation after code changes, during PR preparation
- **How agents use it**: Agents follow instructions in `SKILL.md` (workflow skill, no scripts)
- **References**: See `docs-write/references/documentation-guide.md` for documentation standards

### Git Commit
- **When to use**: After completing working code, before pushing, when code builds and tests pass
- **How agents use it**: Agents follow instructions in `SKILL.md` (workflow skill, no scripts)
- **References**: See `git-commit/references/examples.md` for extended commit examples

### Code Review
- **When to use**:
  - Task mode: For subtasks, uncommitted files, before committing
  - PR mode: For complete PR review, all changed files vs main branch
- **How agents use it**: Agents read `SKILL.md` and execute `scripts/review-run.sh` with `task` or `pr` mode
- **Scripts**: Embedded in `skills/code-review/scripts/review-*.sh`

### PR Review
- **When to use**: When working on PRs with comments, need to resolve/dismiss feedback
- **How agents use it**: Agents read `SKILL.md` and execute scripts in `scripts/pr-comments-*.sh`
- **Scripts**: Embedded in `skills/pr-review/scripts/pr-comments-*.sh`

### Search
- **When to use**: Looking up documentation, code examples, API references, troubleshooting guides, best practices
- **How agents use it**: Agents read `SKILL.md` and use MCP tools (Tavily, Context7)
- **MCPs**: Tavily (web search), Context7 (library documentation)
- **Setup**: Configure MCP servers in `mcp.json`

### Research
- **When to use**: Researching software architecture patterns, finding academic papers, conducting literature reviews, building evidence cards
- **How agents use it**: Agents read `SKILL.md` and execute scripts in `scripts/research-*.sh` or use MCP tools
- **Scripts**: Embedded in `skills/research/scripts/research-*.sh`
- **MCPs**: OpenAlex (paper discovery), PDF extractor (text extraction), Paper-search (optional, multi-platform download)
- **Setup**: Configure MCP servers in `mcp.json`

### Agent Orchestration
- **When to use**: Delegating work to subagents, parallel research/implementation/testing, hierarchical orchestration
- **How agents use it**: Agents read `SKILL.md` and execute scripts in `scripts/agent-*.sh` and `scripts/orchestrator-*.sh`
- **Scripts**: Embedded in `skills/agent-orchestration/scripts/agent-*.sh`

## How Agents Call Skills

Skills follow the Anthropic Agent Skills standard:

1. **Discovery**: Agents scan skill directories (like `~/.codex/skills`) for directories containing `SKILL.md` files
2. **Loading**: Agents read `SKILL.md` files which contain:
   - YAML frontmatter with `name` and `description`
   - Detailed instructions on when and how to use the skill
   - References to embedded scripts in `scripts/` subdirectories
3. **Execution**: When an agent decides to use a skill, it:
   - Reads the skill instructions from `SKILL.md`
   - Executes scripts via `bash skills/<skill-name>/scripts/<script-name>.sh`
   - Scripts are called directly, not through npm or package.json

**Key Points:**
- Scripts are embedded within skill directories (`scripts/` subdirectory)
- Agents read `SKILL.md` to understand how to use each skill
- Scripts are executed via bash, with paths relative to the skill directory
- No package.json or npm scripts required

## Tools and Scripts

Scripts are organized in `scripts/` directories within each skill. Each skill contains its executable scripts and utilities in the `scripts/` subdirectory, following the Agent Skills standard structure.

Scripts are executed by agents when they use the skill. Each skill's `SKILL.md` file contains instructions on when and how to execute these scripts.

## Documentation

Skills that check or update documentation reference `docs-write/references/documentation-guide.md` for standards and best practices.

## Testing and Validation

Verify the integrity and structure of all skills:

```bash
bash .test/scripts/validate-skills.sh
```

## Skill Format

Each skill follows the Anthropic/Codex standard:

```yaml
---
name: skill-name
description: What it does and when to use it (max 1024 chars, one line)
---
```

The body contains detailed instructions, workflows, examples, and references.

## Output Locations

- Code reviews: `.ada/data/reviews/`
- PR comments: `.ada/data/pr-comments/`
- Research evidence cards: `.ada/data/research/{topic}/`
- Research PDFs (temporary): `.ada/temp/research/downloads/`

## See Also

- `docs-write/references/documentation-guide.md` - Documentation standards
- [Setup Guide](../SETUP.md) - Installation and setup
