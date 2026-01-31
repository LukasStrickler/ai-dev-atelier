# AI Dev Atelier Skills

Skills provide specialized capabilities for AI agents working with code quality, documentation, code reviews, and PR management.

## Overview

Skills are organized directories containing `SKILL.md` files that follow the open [Agent Skills standard](https://agentskills.io/specification). Each skill has YAML frontmatter with `name` and `description`, followed by detailed instructions.

## Available Skills

| Skill | Description | Scripts |
|-------|-------------|---------|
| [`code-quality`](./code-quality/SKILL.md) | Run comprehensive code quality checks including typecheck, lint, format, and markdown validation | `scripts/finalize.sh` (agent/ci modes) |
| [`docs-check`](./docs-check/SKILL.md) | Analyze git diff to identify code changes requiring documentation updates | `scripts/check-docs.sh` |
| [`docs-write`](./docs-write/SKILL.md) | Write or update documentation with clear style, structure, visuals, API/ADR/runbook patterns | N/A (workflow skill) |
| [`git-commit`](./git-commit/SKILL.md) | Write clear git commits with Conventional Commits format, detect project conventions | N/A (workflow skill) |
| [`image-generation`](./image-generation/SKILL.md) | Generate, edit, and upscale AI images with quality tiers (FREE Cloudflare + Fal.ai) | `scripts/gen.ts`, `scripts/edit.ts`, `scripts/upscale.ts`, `scripts/rembg.ts` |
| [`use-graphite`](./use-graphite/SKILL.md) | Manage stacked PRs with Graphite CLI, auto-detect Graphite repos, block conflicting git commands | `scripts/graphite*.sh` |
| [`code-review`](./code-review/SKILL.md) | Review code changes using CodeRabbit - uncommitted files (task mode) or all PR files vs main (pr mode) | `scripts/review-run.sh` |
| [`resolve-pr-comments`](./resolve-pr-comments/SKILL.md) | Multi-agent PR comment resolution for bot reviews (CodeRabbit, Copilot, Gemini) | `scripts/pr-resolver*.sh` |
| [`search`](./search/SKILL.md) | Search the web and library documentation using Tavily and Context7 MCPs | N/A (MCP-based skill) |
| [`research`](./research/SKILL.md) | Conduct academic research using OpenAlex, PDF extraction, and paper search MCPs with evidence cards | `scripts/research-*.sh` |
| [`ui-animation`](./ui-animation/SKILL.md) | Guide tasteful UI animation implementation with easing, springs, timing, and accessibility | N/A (workflow skill) |
| [`tdd`](./tdd/SKILL.md) | Implement Test-Driven Development with red-green-refactor workflow, hermetic testing, and test pyramid standards | N/A (workflow skill) |

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

### Use Graphite
- **When to use**: Creating branches, pushing changes, or creating PRs in Graphite-enabled repos
- **How agents use it**: Auto-detection via PreToolUse hook; agents use `gt` commands instead of `git`/`gh`
- **Scripts**: `scripts/graphite-detect.sh` (detection), `scripts/graphite-block-hook.sh` (hook)
- **MCP**: Graphite MCP (`gt mcp`) for stacked PR management
- **References**: See `use-graphite/references/graphite-workflow.md` for detailed examples

### Code Review
- **When to use**:
  - Task mode: For subtasks, uncommitted files, before committing
  - PR mode: For complete PR review, all changed files vs main branch
- **How agents use it**: Agents read `SKILL.md` and execute `scripts/review-run.sh` with `task` or `pr` mode
- **Scripts**: Embedded in `skills/code-review/scripts/review-*.sh`

### PR Comment Resolver
- **When to use**: When PRs have bot review comments to triage, need batch resolution, want to see what's fixed vs pending
- **How agents use it**: Agents read `SKILL.md` and execute `scripts/pr-resolver.sh` to fetch/cluster comments, then spawn subagents per cluster
- **Scripts**: Embedded in `skills/resolve-pr-comments/scripts/pr-resolver*.sh`
- **Subagent**: `@pr-comment-reviewer` processes individual clusters with 6-phase workflow

### Search
- **When to use**: Looking up documentation, code examples, API references, troubleshooting guides, best practices
- **How agents use it**: Agents read `SKILL.md` and use MCP tools (Tavily, Context7)
- **MCPs**: Tavily (web search), Context7 (library documentation)
- **Setup**: Configure MCP servers in `config/mcps.json`

### Research
- **When to use**: Researching software architecture patterns, finding academic papers, conducting literature reviews, building evidence cards
- **How agents use it**: Agents read `SKILL.md` and execute scripts in `scripts/research-*.sh` or use MCP tools
- **Scripts**: Embedded in `skills/research/scripts/research-*.sh`
- **MCPs**: OpenAlex (paper discovery), PDF extractor (text extraction), Paper-search (optional, multi-platform download)
- **Setup**: Configure MCP servers in `config/mcps.json`

### UI Animation
- **When to use**: Implementing enter/exit animations, choosing easing curves, configuring springs, setting durations, ensuring accessibility
- **How agents use it**: Agents follow instructions in `SKILL.md` (workflow skill, no scripts)
- **Patterns**: CSS and Tailwind code examples for modals, buttons, accordions, tooltips, and more

### TDD (Test-Driven Development)
- **When to use**: Implementing new features test-first, fixing bugs with reproduction tests, refactoring with safety net, adding tests to legacy code
- **How agents use it**: Agents follow instructions in `SKILL.md` (workflow skill, no scripts)
- **References**: See `tdd/references/examples.md` for code examples (modes, test doubles, PBT, mutation testing)

## How Agents Call Skills

Skills follow the open [Agent Skills standard](https://agentskills.io/specification):

1. **Discovery**: Agents scan skill directories (e.g. `~/.opencode/skills/` for OpenCode, `~/.cursor/skills/` for Cursor) for directories containing `SKILL.md` files
2. **Loading**: Agents read `SKILL.md` files which contain:
   - YAML frontmatter with `name` and `description`
   - Detailed instructions on when and how to use the skill
   - References to embedded scripts in `scripts/` subdirectories
3. **Execution**: When an agent decides to use a skill, it:
   - Reads the skill instructions from `SKILL.md`
   - Executes scripts via `bash skills/<skill-name>/scripts/<script-name>.sh`
   - Scripts are called directly, not through npm or package.json

**Install locations**: Running `install.sh` installs skills to **OpenCode** (`~/.opencode/skills/`) and **Cursor** (`~/.cursor/skills/`, user-level per [Cursor docs](https://cursor.com/docs/context/skills)). Use `CURSOR_HOME` to override the Cursor base path.

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
make validate
```

## Skill Format

Each skill follows the open [Agent Skills standard](https://agentskills.io/specification):

```yaml
---
name: skill-name
description: What it does and when to use it (max 1024 chars, one line)
---
```

The body contains detailed instructions, workflows, examples, and references.

## Output Locations

- Code reviews: `.ada/data/reviews/`
- PR comment resolver: `.ada/data/pr-resolver/`
- Research evidence cards: `.ada/data/research/{topic}/`
- Research PDFs (temporary): `.ada/temp/research/downloads/`

## See Also

- `docs-write/references/documentation-guide.md` - Documentation standards
- `../INSTALL.md` - Dependencies and MCP setup
