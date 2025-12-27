# AI Dev Atelier Skills

Skills provide specialized capabilities for AI agents working with code quality, documentation, code reviews, and PR management.

## Overview

Skills are organized directories containing `SKILL.md` files that follow the [Anthropic Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) format. Each skill has YAML frontmatter with `name` and `description`, followed by detailed instructions.

## Available Skills

| Skill | Description | Tools |
|-------|-------------|-------|
| [`code-quality`](./code-quality/SKILL.md) | Run comprehensive code quality checks including typecheck, lint, format, and markdown validation | `ada::agent:finalize`, `ada::ci:finalize` |
| [`docs-check`](./docs-check/SKILL.md) | Analyze git diff to identify code changes requiring documentation updates | `ada::docs:check` |
| [`docs-write`](./docs-write/SKILL.md) | Write or update documentation with clear style, structure, visuals, API/ADR/runbook patterns | N/A (workflow skill) |
| [`code-review`](./code-review/SKILL.md) | Review code changes using CodeRabbit - uncommitted files (task mode) or all PR files vs main (pr mode) | `ada::review:task`, `ada::review:pr`, `ada::review:read`, `ada::review:cleanup` |
| [`pr-review`](./pr-review/SKILL.md) | Manage GitHub PR comments - fetch, resolve, dismiss, and interact with review comments | `ada::pr:comments:*` |
| [`search`](./search/SKILL.md) | Search the web and library documentation using Tavily and Context7 MCPs | N/A (MCP-based skill) |
| [`research`](./research/SKILL.md) | Conduct academic research using OpenAlex, PDF extraction, and paper search MCPs with evidence cards | `ada::research:list`, `ada::research:show`, `ada::research:cleanup` |
| [`agent-orchestrator`](./agent-orchestrator/SKILL.md) | Design hierarchical multi-agent workflows with structured plans, role prompts, context packages, and verification checklists | N/A (workflow skill) |

## Quick Reference

### Code Quality
- **When to use**: Before committing, in CI pipelines, after making changes
- **Command**: `npm run ada::agent:finalize` (auto-fixes) or `npm run ada::ci:finalize` (read-only)

### Documentation Check
- **When to use**: After making code changes, before committing
- **Command**: `npm run ada::docs:check`
- **References**: See [Documentation Guide](docs/DOCUMENTATION_GUIDE.md) for what to document

### Documentation Write
- **When to use**: Creating or updating documentation after code changes, during PR preparation
- **Workflow**: Follow the skill instructions in [docs-write/SKILL.md](./docs-write/SKILL.md)
- **References**: See [Documentation Guide](docs/DOCUMENTATION_GUIDE.md) for documentation standards

### Code Review
- **When to use**: 
  - Task mode: For subtasks, uncommitted files, before committing
  - PR mode: For complete PR review, all changed files vs main branch
- **Commands**: `npm run ada::review:task` or `npm run ada::review:pr`

### PR Review
- **When to use**: When working on PRs with comments, need to resolve/dismiss feedback
- **Commands**: `ada::pr:comments:*` (fetch, detect, get, resolve, dismiss, cleanup)

### Search
- **When to use**: Looking up documentation, code examples, API references, troubleshooting guides, best practices
- **MCPs**: Tavily (web search), Context7 (library documentation)
- **Setup**: Configure MCP servers in `mcp.json` (see `mcp.json.example`)

### Research
- **When to use**: Researching software architecture patterns, finding academic papers, conducting literature reviews, building evidence cards
- **MCPs**: OpenAlex (paper discovery), PDF extractor (text extraction), Paper-search (optional, multi-platform download)
- **Commands**: `ada::research:list`, `ada::research:show <topic>`, `ada::research:cleanup`
- **Setup**: Configure MCP servers in `mcp.json` (see `mcp.json.example`)

## Tools and Scripts

Scripts are organized in `scripts/` directories within each skill. Each skill contains its executable scripts and utilities in the `scripts/` subdirectory, following the Agent Skills standard structure.

## Documentation

Skills that check or update documentation reference the [Documentation Guide](docs/DOCUMENTATION_GUIDE.md) for standards and best practices.

## Skill Format

Each skill follows the Anthropic/Codex standard:

```yaml
---
name: skill-name
description: What it does and when to use it (max 500 chars, one line)
---
```

The body contains detailed instructions, workflows, examples, and references.

## Output Locations

- Code reviews: `.ada/data/reviews/`
- PR comments: `.ada/data/pr-comments/`
- Research evidence cards: `.ada/data/research/{topic}/`
- Research PDFs (temporary): `.ada/temp/research/downloads/`

## See Also

- [Documentation Guide](docs/DOCUMENTATION_GUIDE.md) - Documentation standards
- [Setup Guide](SETUP.md) - Installation and setup



