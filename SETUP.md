# AI Dev Atelier Setup Guide

Quick setup guide for installing AI Dev Atelier skills into Codex.

> **📦 Need to install dependencies first?** See [INSTALL.md](./INSTALL.md) for complete installation instructions including all required and optional dependencies.

## Quick Start

```bash
# 1. Clone AI Dev Atelier
git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/ai-dev-atelier

# 2. Verify skill structure
bash ~/ai-dev-atelier/setup.sh

# 3. Install skills to Codex
bash ~/ai-dev-atelier/install.sh

# 4. Verify skills are loaded in Codex
# Ask Codex: "What skills are available?"
```

The setup script verifies that all skills are properly structured. The install script copies skills to Codex's skills directory (`~/.codex/skills`).

**Important**: Skills follow the [Anthropic Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) standard. Scripts are embedded within each skill directory and are executed by agents when they use the skill.

## Prerequisites

Before running the setup and install scripts, ensure you have:

- **Git** - Version control
- **Bash** - Shell (included on macOS/Linux, Git Bash on Windows)
- **Codex** - AI agent that supports skills (skills are installed to `~/.codex/skills`)

> **📖 Detailed installation instructions:** See [INSTALL.md](./INSTALL.md) for platform-specific installation commands and optional dependencies (GitHub CLI, CodeRabbit CLI, TypeScript, ESLint, Prettier).

## What Gets Installed

The install script copies skills from the local repository to `~/.codex/skills`. Each skill includes:

- **SKILL.md** - Skill definition with YAML frontmatter and instructions
- **scripts/** - Executable scripts embedded within the skill
- **references/** - Additional documentation and templates (if applicable)

### Available Skills

- **code-quality** - Code quality checks (typecheck, lint, format, markdown)
- **docs-check** - Documentation update detection
- **docs-write** - Documentation writing and updates
- **code-review** - CodeRabbit reviews (task and pr modes)
- **pr-review** - GitHub PR comments management
- **search** - Web and library documentation search (Tavily, Context7)
- **research** - Academic research with evidence cards (OpenAlex, PDF extraction)
- **agent-orchestration** - Spawn and manage hierarchical AI sub-agents

## Installation Process

### Step 1: Verify Skill Structure

```bash
bash ~/ai-dev-atelier/setup.sh
```

This script:
- ✅ Verifies skills directory exists
- ✅ Checks for required skills (code-quality, docs-check, code-review, pr-review)
- ✅ Validates SKILL.md files are present
- ✅ Reports any missing or invalid skills

### Step 2: Install Skills to Codex

```bash
bash ~/ai-dev-atelier/install.sh
```

This script:
- ✅ Copies skills to `~/.codex/skills`
- ✅ Preserves existing `.system` directory in Codex
- ✅ Shows smart diff before overwriting existing skills
- ✅ Asks for confirmation before overwriting (use `--yes` to skip)

**Options:**
- `--yes` or `-y` - Skip confirmation prompts (auto-overwrite)
- `--help` or `-h` - Show help message

### Step 3: Verify Installation

Ask Codex: "What skills are available?"

Codex should list: `code-quality`, `docs-check`, `docs-write`, `code-review`, `pr-review`, `search`, `research`, `agent-orchestration`

## Testing and Validation

Verify the integrity and structure of all skills using the validation script:

```bash
bash .test/scripts/validate-skills.sh
```

## How Agents Use Skills

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
- Scripts are embedded within skill directories
- Agents read `SKILL.md` to understand how to use each skill
- Scripts are executed via bash, with paths relative to the skill directory
- No package.json or npm scripts required

## Customization

### Different Installation Path

If AI Dev Atelier is not at `~/ai-dev-atelier`, the install script automatically detects the correct path based on where it's located.

### Updating Skills

To update skills after making changes to the local repository:

```bash
# Re-run install script
bash ~/ai-dev-atelier/install.sh

# Or use --yes to auto-overwrite
bash ~/ai-dev-atelier/install.sh --yes
```

The script will show a diff of changes before overwriting (unless `--yes` is used).

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Skills directory not found | Verify AI Dev Atelier is cloned correctly |
| SKILL.md not found | Ensure you're running from the AI Dev Atelier root directory |
| Permission denied | `chmod +x ~/ai-dev-atelier/install.sh` |
| Skills not appearing in Codex | Verify skills are installed to `~/.codex/skills` |
| Codex doesn't recognize skills | Restart Codex after installation |

> **📖 More troubleshooting:** See [INSTALL.md](./INSTALL.md) for comprehensive troubleshooting guide and verification checklist.

## Next Steps

1. **Verify skills are loaded in Codex:**
   - Ask Codex: "What skills are available?"
   - Should list all installed skills

2. **Read the skills documentation:**
   ```bash
   cat ~/ai-dev-atelier/skills/README.md
   ```

3. **Test a skill:**
   - Ask Codex: "Run code quality checks" (triggers `code-quality` skill)
   - Ask Codex: "Check if documentation needs updates" (triggers `docs-check` skill)

4. **Learn about individual skills:**
   - Read `skills/<skill-name>/SKILL.md` for detailed instructions
   - Each skill documents its scripts and usage patterns

## Re-running Setup

Safe to run multiple times:

```bash
# Verify structure
bash ~/ai-dev-atelier/setup.sh

# Re-install skills (with confirmation)
bash ~/ai-dev-atelier/install.sh

# Re-install skills (auto-overwrite)
bash ~/ai-dev-atelier/install.sh --yes
```

## Support

- **Installation Guide:** [INSTALL.md](./INSTALL.md) - Complete dependency installation instructions
- **Skills Documentation:** `~/ai-dev-atelier/skills/README.md`
- **Individual Skills:** See `skills/*/SKILL.md` for detailed skill documentation
