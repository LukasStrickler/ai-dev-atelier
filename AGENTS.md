# AGENTS.md

This file defines how AI agents and contributors should work in this repository.

## Overview

AI Dev Atelier: Production-grade skill pack for AI-assisted development. 10 skills following the open Agent Skills standard, with MCP integrations for search/research.

## For AI agents

Read these first:
- `README.md` for capabilities and entry points
- `INSTALL.md` for dependencies and MCP setup
- `MY_AGENTIC_DEV_SETUP.md` for a personal Vibora + oh-my-opencode usage example

## Structure

```text
ai-dev-atelier/
├── skills/                    # 10 skill directories
│   ├── <name>/SKILL.md        # YAML frontmatter + instructions
│   ├── <name>/scripts/        # Executable bash scripts
│   └── <name>/references/     # Guides, templates, examples
├── .hooks/                    # Standalone hook scripts
├── .test/                     # Validation and integration tests
├── .ada/                      # Runtime outputs (gitignored)
├── hooks.json                 # PreToolUse hook definitions
├── install.sh                 # Deploy skills + MCPs + hooks
├── mcp.json                   # MCP server definitions
└── skills.json                # Per-agent skill filtering
```

## Skills Quick Reference

| Skill | Purpose | Entry Script |
|-------|---------|--------------| 
| `code-quality` | Typecheck, lint, format, Markdown | `scripts/finalize.sh` |
| `docs-check` | Detect docs needing updates from git diff | `scripts/check-docs.sh` |
| `docs-write` | Write/update docs with standards | Workflow (no script) |
| `git-commit` | Write clear commits with Conventional Commits | Workflow (no script) |
| `code-review` | CodeRabbit reviews (task/pr modes) | `scripts/review-run.sh` |
| `resolve-pr-comments` | Multi-agent PR comment resolution | `scripts/pr-resolver*.sh` |
| `search` | Web + library docs + GitHub code search | MCP-based |
| `research` | Academic research with evidence cards | `scripts/research-*.sh` |
| `ui-animation` | Tasteful UI animation & accessibility | Workflow (no script) |

## Commands

```bash
bash install.sh                            # Install skills + MCPs
make validate                              # Validate skill structure
bash skills/<skill>/scripts/<script>.sh    # Run skill script
```

> **Tip**: You can also use `make setup`, `make install`, `make validate` for shorter commands.

## This Repository

**This repository uses Graphite.** Use `gt` commands instead of `git push`/`gh pr create`. See the `use-graphite` skill.

## Install Locations

| Agent | Skills Path | MCP Config |
|-------|-------------|------------|
| OpenCode | `~/.opencode/skill` | `~/.opencode/opencode.json` |

Respects `$XDG_CONFIG_HOME` if set.

## PreToolUse Hooks

Hooks in `hooks.json` enforce workflow guardrails by intercepting tool calls before execution:

| Hook ID | Matcher | Purpose |
|---------|---------|---------|
| `graphite-block` | Bash | Blocks `git push`, `git checkout -b`, `gh pr create` in Graphite-enabled repos |
| `pr-comments-block` | Bash | Blocks `gh api` calls fetching PR comments on current repo's open PRs |
| `release-block` | Bash | Blocks `gh workflow run release.yml` and `gh release create` (requires human approval) |

Hooks are installed to `~/.opencode/hook/` by `install.sh`. They help prevent:
- Accidental git operations that conflict with Graphite stacked PR workflow
- Wasteful API calls that can be replaced by the `resolve-pr-comments` skill
- AI agents from triggering releases without human approval

## MCP Servers

| Server | Purpose | Required Key |
|--------|---------|--------------|
| `tavily-remote-mcp` | Web search | `TAVILY_API_KEY` |
| `context7` | Library docs | Optional |
| `grep` | GitHub code search | None |
| `openalex-research` | Academic papers | `OPENALEX_EMAIL` |
| `pdf-reader` | PDF extraction | None |
| `paper-search` | Multi-platform papers | Optional |
| `zai-zread` | GitHub repo semantic search (issues, PRs, docs) | `Z_AI_API_KEY` |
| `zai-vision` | Image/video analysis, UI code gen, diagrams | `Z_AI_API_KEY` |
| `graphite` | Stacked PR management | None |

### Z.AI MCP Tool Filtering (OpenCode)

Some Z.AI MCP tools should be disabled to save quota or avoid redundancy.
Add to your `~/.opencode/opencode.json` under `"tools"`:

```json
{
  "tools": {
    "zai-zread_read_file": false,
    "zai-zread_get_repo_structure": false,
    "zai-vision_image_analysis": false,
    "zai-vision_extract_text_from_screenshot": false
  }
}
```

**Why disable these:**
- `zai-zread_read_file`: Use `webfetch("https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}")` instead (free)
- `zai-zread_get_repo_structure`: Use `gh api repos/{owner}/{repo}/git/trees/{branch}` instead (free)
- `zai-vision_image_analysis`: Use native `look_at` tool instead
- `zai-vision_extract_text_from_screenshot`: Use native `look_at` tool for OCR

Set keys in `.env` before `install.sh`, or update MCP config after.

## Data Outputs

All runtime data under `.ada/` (gitignored):
- `.ada/data/reviews/` - Code review results
- `.ada/data/pr-resolver/` - PR comment resolution data
- `.ada/data/research/{topic}/` - Evidence cards, reports
- `.ada/temp/` - Temporary files (downloads, etc.)

## Anti-Patterns (THIS PROJECT)

**Documentation skills:**
- Never assume docs format - ALWAYS load `references/documentation-guide.md` first
- Never proceed without reading the guide

**Research skill:**
- Never skip Step 0 (codebase context) - ALWAYS gather context first
- Never stop at 1-2 evidence cards - ALWAYS produce 5+ cards
- Never batch tool calls without writing - write after 1-2 calls

**PR comment resolver:**
- Never auto-fix security issues - always defer to orchestrator
- Validate bot comments with evidence before dismissing

## Skill Format

Each skill follows the open [Agent Skills standard](https://agentskills.io/specification):

```yaml
---
name: skill-name
description: "Purpose and triggers (max 1024 chars)"
---
```

Body contains: instructions, workflows, examples, script references.

## Releases

**CRITICAL: AI agents must NEVER trigger releases without explicit user permission.**

Releases are manual. See [docs/RELEASING.md](./docs/RELEASING.md) for the full guide.

| Command | Description |
|---------|-------------|
| `gh workflow run release.yml -f version=X.Y.Z` | Create release |
| `gh workflow run release.yml -f version=X.Y.Z -f dry_run=true` | Dry run |
| `gh workflow run release.yml -f version=X.Y.Z -f prerelease=true` | Prerelease |

Agent behavior:
- Help prepare releases (summarize changes, suggest version)
- Show the command to run
- **ALWAYS wait for explicit user confirmation** before executing
- Never assume a release should happen after merging PRs

## Guardrails

- Do not commit unless explicitly requested
- Do not modify global git config
- Do not add or expose secrets in files
- Keep changes scoped to the requested task
- Use `skills.json` to disable skills per agent
- **Do not trigger releases** without explicit user permission

## Testing

```bash
make validate                              # Validate skill structure
bash .test/tests/validate-skills-tests.sh # Test the validator itself
```

## For human contributors

Before changes:
- Run `bash install.sh` to install skills and check dependencies

After changes:
- Run `make validate`
- Ensure each skill keeps the `SKILL.md` format and embedded scripts

When adding or updating skills:
- Keep instructions and scripts inside the skill folder
- Update `skills/README.md` if the catalog changes
- Keep outputs under `.ada/`
