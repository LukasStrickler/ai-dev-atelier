# AI Dev Atelier

AI agent tools for code quality, documentation checking, code reviews, and PR comment management.

## Overview

AI Dev Atelier provides a collection of tools, skills, and documentation standards to help AI agents maintain code quality and automate common development workflows.

## Quick Start

```bash
# 1. Clone AI Dev Atelier
git clone https://github.com/LukasStrickler/ai-dev-atelier.git /ai-dev-atelier

# 2. Navigate to your project
cd /path/to/your/project

# 3. Run setup script
bash /ai-dev-atelier/setup.sh
```

See [SETUP.md](./SETUP.md) for detailed setup instructions.

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

See [skills/README.md](./skills/README.md) for complete overview.

### Scripts

Shell scripts are organized in `scripts/` directories within each skill:

- **code-quality**: `skills/code-quality/scripts/finalize.sh`
- **docs-check**: `skills/docs-check/scripts/check-docs.sh`
- **code-review**: `skills/code-review/scripts/review-*.sh`
- **pr-review**: `skills/pr-review/scripts/pr-comments-*.sh`
- **research**: `skills/research/scripts/research-*.sh`

All scripts are accessible via `ada::` prefixed npm commands. Scripts are documented in their respective skill directories.

### Documentation

Documentation standards and guides:

- **[Documentation Guide](./docs/DOCUMENTATION_GUIDE.md)** - Best practices for maintaining documentation
- **[docs/README.md](./docs/README.md)** - Documentation overview

## How It Works Together

```
┌─────────────┐
│   Skills    │  ← AI agent capabilities (SKILL.md + scripts)
└──────┬──────┘
       │ contains
       ▼
┌─────────────┐
│   Scripts   │  ← Executable tools (co-located with skills)
└──────┬──────┘
       │ uses
       ▼
┌─────────────┐
│    Docs     │  ← Standards and guides
└─────────────┘
```

1. **Skills** define AI agent capabilities and contain their scripts
2. **Scripts** provide executable tools accessible via npm commands
3. **Documentation** provides standards and best practices

## Usage

After setup, use npm commands with `ada::` prefix:

```bash
# Code quality
npm run ada::agent:finalize

# Documentation check
npm run ada::docs:check

# Code review (task mode)
npm run ada::review:task

# Code review (PR mode)
npm run ada::review:pr

# PR comments
npm run ada::pr:comments

# Research (list evidence cards)
npm run ada::research:list

# Research (show evidence card)
npm run ada::research:show <topic>

# Research (cleanup PDFs)
npm run ada::research:cleanup --all
```

## Resources

- [Setup Guide](./SETUP.md) - Installation and setup
- [Skills](./skills/README.md) - AI agent skills (includes scripts)
- [Documentation](./docs/README.md) - Documentation standards

## License

See [LICENSE](./LICENSE) file.
