# AI Dev Atelier

AI agent tools for code quality, documentation checking, code reviews, and PR comment management.

## Overview

AI Dev Atelier provides a collection of tools, skills, and documentation standards to help AI agents maintain code quality and automate common development workflows.

## Quick Start

```bash
# 1. Clone AI Dev Atelier
git clone https://github.com/LukasStrickler/ai-dev-atelier.git /ai-dev-atelier

# 2. Verify skill structure
bash /ai-dev-atelier/setup.sh

# 3. Install skills to Codex
bash /ai-dev-atelier/install.sh

# 4. Verify skills are loaded in Codex
# Ask Codex: "What skills are available?"
```

See [SETUP.md](./SETUP.md) for detailed setup instructions.

## Testing and Validation

Verify the integrity and structure of all skills:

```bash
bash .test/scripts/validate-skills.sh
```

## Components

### Skills

AI agent skills following [Anthropic Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) format:

- **[code-quality](./skills/code-quality/SKILL.md)** - Code quality checks (typecheck, lint, format, markdown)
- **[docs-check](./skills/docs-check/SKILL.md)** - Documentation update detection
- **[docs-write](./skills/docs-write/SKILL.md)** - Documentation writing and updates
- **[code-review](./skills/code-review/SKILL.md)** - CodeRabbit reviews (task and pr modes)
- **[pr-review](./skills/pr-review/SKILL.md)** - GitHub PR comments management
- **[search](./skills/search/SKILL.md)** - Web and library documentation search (Tavily, Context7)
- **[research](./skills/research/SKILL.md)** - Academic research with evidence cards (OpenAlex, PDF extraction)
- **[agent-orchestration](./skills/agent-orchestration/SKILL.md)** - Spawn and manage hierarchical AI sub-agents

See [skills/README.md](./skills/README.md) for complete overview.

### Scripts

Shell scripts are embedded within each skill directory in `scripts/` subdirectories:

- **code-quality**: `skills/code-quality/scripts/finalize.sh`
- **docs-check**: `skills/docs-check/scripts/check-docs.sh`
- **code-review**: `skills/code-review/scripts/review-*.sh`
- **pr-review**: `skills/pr-review/scripts/pr-comments-*.sh`
- **research**: `skills/research/scripts/research-*.sh`
- **agent-orchestration**: `skills/agent-orchestration/scripts/agent-*.sh`

Scripts are executed by agents when they use the skill. Each skill's `SKILL.md` file contains instructions on when and how to execute these scripts.

### Documentation

Documentation standards and guides:

- **[Documentation Guide](./docs/DOCUMENTATION_GUIDE.md)** - Best practices for maintaining documentation
- **[docs/README.md](./docs/README.md)** - Documentation overview

## How It Works Together

```
┌─────────────┐
│   Skills    │  ← AI agent capabilities (SKILL.md + embedded scripts)
└──────┬──────┘
       │ contains
       ▼
┌─────────────┐
│   Scripts   │  ← Executable tools (embedded in skills/ subdirectories)
└──────┬──────┘
       │ uses
       ▼
┌─────────────┐
│    Docs     │  ← Standards and guides
└─────────────┘
```

1. **Skills** define AI agent capabilities with `SKILL.md` files and contain embedded scripts
2. **Scripts** are executed by agents when they use the skill (via bash, not npm)
3. **Documentation** provides standards and best practices

## How Agents Use Skills

Skills follow the [Anthropic Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) standard:

1. **Discovery**: Agents scan skill directories (like `~/.codex/skills`) for directories containing `SKILL.md` files
2. **Loading**: Agents read `SKILL.md` files which contain:
   - YAML frontmatter with `name` and `description`
   - Detailed instructions on when and how to use the skill
   - References to embedded scripts in `scripts/` subdirectories
3. **Execution**: When an agent decides to use a skill, it:
   - Reads the skill instructions from `SKILL.md`
   - Executes scripts via `bash skills/<skill-name>/scripts/<script-name>.sh`
   - Scripts are called directly, not through npm or package.json

## Usage

After installation, agents (like Codex) will automatically discover and use skills. You can trigger skills by asking the agent:

```bash
# Code quality
"Run code quality checks" → triggers code-quality skill

# Documentation check
"Check if documentation needs updates" → triggers docs-check skill

# Code review
"Review my code changes" → triggers code-review skill

# PR comments
"Fetch PR comments" → triggers pr-review skill

# Research
"List research sessions" → triggers research skill

# Search
"Search for React documentation" → triggers search skill
```

Each skill's `SKILL.md file contains detailed instructions on when and how agents should use it.

## Resources

- [Setup Guide](./SETUP.md) - Installation and setup
- [Installation Guide](./INSTALL.md) - Complete dependency installation
- [Skills](./skills/README.md) - AI agent skills documentation
- [Documentation](./docs/README.md) - Documentation standards

## License

See [LICENSE](./LICENSE) file.
