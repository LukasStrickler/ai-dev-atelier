# AI Dev Atelier Setup Guide

Quick setup guide for integrating AI Dev Atelier tools into your project.

> **📦 Need to install dependencies first?** See [INSTALL.md](./INSTALL.md) for complete installation instructions including all required and optional dependencies.

## Quick Start

```bash
# 1. Clone AI Dev Atelier
git clone https://github.com/LukasStrickler/ai-dev-atelier.git /ai-dev-atelier

# 2. Navigate to your project
cd /path/to/your/project

# 3. Run setup script
bash /ai-dev-atelier/setup.sh

# 4. Configure skills in your AI agent (REQUIRED)
# See "Configure Skills in Your AI Agent" section below
```

The setup script automatically adds all required npm scripts to your `package.json`. It will:
- ✅ Check prerequisites (jq, package.json)
- ✅ Add missing scripts (preserves existing ones)
- ✅ Create a backup of your package.json
- ✅ Show a summary of what was added

**Important**: After setup, you must configure the skills in your AI agent for the agent to discover and use them. See the "Configure Skills in Your AI Agent" section below.

## Prerequisites

Before running the setup script, ensure you have:

- **Git** - Version control
- **Node.js 18+** or **Bun** - JavaScript runtime
- **jq** - JSON processor
- **package.json** - In your project root

> **📖 Detailed installation instructions:** See [INSTALL.md](./INSTALL.md) for platform-specific installation commands and optional dependencies (GitHub CLI, CodeRabbit CLI, TypeScript, ESLint, Prettier).

## What Gets Added

The setup script adds 15 npm scripts with the `ada::` prefix to your `package.json`. These scripts work independently via command line.

**Note**: The npm scripts are separate from the agent skills. To use the skills in your AI agent (for automatic triggering), you must configure them separately (see "Configure Skills in Your AI Agent" section).

### Available Scripts

### Code Quality
- `ada::agent:finalize` - Run all quality checks (typecheck, lint, format, markdown)
- `ada::ci:finalize` - CI mode (read-only checks)

### Documentation
- `ada::docs:check` - Check for documentation updates needed

### Code Review (CodeRabbit)
- `ada::review:task` - Review uncommitted changes
- `ada::review:pr` - Review PR changes vs main
- `ada::review:read` - Read latest review results
- `ada::review:cleanup` - Clean up old reviews

### PR Comments
- `ada::pr:comments [PR_NUMBER]` - Fetch PR comments
- `ada::pr:comments:detect` - Detect PR number
- `ada::pr:comments:get [PR_NUMBER] [INDEX_OR_ID]` - Get single comment
- `ada::pr:comments:resolve [PR_NUMBER] <ID>...` - Resolve comments
- `ada::pr:comments:resolve:interactive` - Interactive resolve
- `ada::pr:comments:dismiss [PR_NUMBER] <ID> <REASON>` - Dismiss comment
- `ada::pr:comments:cleanup [--all] [PR_NUMBER]` - Clean up files
- `ada::pr:list` - List open PRs

## Verify Installation

```bash
# Check scripts were added
npm run | grep "ada::"

# Test a script
npm run ada::docs:check
```

## Customization

### Different Installation Path

If AI Dev Atelier is not at `/ai-dev-atelier`, update the paths in your `package.json` scripts:

```json
{
  "scripts": {
    "ada::agent:finalize": "bash /custom/path/skills/code-quality/scripts/finalize.sh agent"
  }
}
```

### Existing Scripts

The setup script **never modifies or removes** existing scripts. Your project scripts remain untouched.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `jq: command not found` | See [INSTALL.md](./INSTALL.md) for installation instructions |
| `package.json not found` | Run setup from project root directory |
| Scripts not found at `/ai-dev-atelier/skills/` | Verify clone location or update paths in package.json |
| Permission denied | `chmod +x /ai-dev-atelier/skills/*/scripts/*.sh` |

> **📖 More troubleshooting:** See [INSTALL.md](./INSTALL.md) for comprehensive troubleshooting guide and verification checklist.

## Configure Skills in Your AI Agent

**IMPORTANT**: After running the setup script, you must configure the skills in your AI agent (Claude Code, Codex, etc.) for the agent to discover and use them.

### For Claude Code / Codex

1. **Add skills directory to agent configuration:**
   - Skills are located at: `/ai-dev-atelier/skills/`
   - Configure your agent to load skills from this directory
   - See your agent's documentation for how to add skill directories

2. **Verify skills are loaded:**
   - Ask your agent: "What skills are available?"
   - The agent should list: `code-quality`, `docs-check`, `docs-write`, `code-review`, `pr-review`

3. **Test skill triggering:**
   - Try: "Run code quality checks" (should trigger `code-quality` skill)
   - Try: "Check if documentation needs updates" (should trigger `docs-check` skill)

### For Other Agents

- **Cursor**: Add skills directory in Cursor settings
- **VS Code Copilot**: Configure skills path in settings
- **Other agents**: Refer to your agent's documentation for skill configuration

**Note**: The npm scripts (`ada::*`) work independently of agent skills. You can use them via command line even if skills aren't configured in your agent.

## Next Steps

1. **Configure skills in your AI agent** (see above)

2. **Read the documentation:**
   ```bash
   cat /ai-dev-atelier/skills/README.md
   ```

3. **Test the tools:**
   ```bash
   npm run ada::docs:check
   npm run ada::agent:finalize
   ```

4. **Integrate into workflow:**
   - Add `ada::agent:finalize` to pre-commit hooks
   - Use `ada::review:task` before committing
   - Use PR comment tools when working on pull requests

## Re-running Setup

Safe to run multiple times. The script only adds missing scripts:

```bash
bash /ai-dev-atelier/setup.sh
```

## Support

- **Installation Guide:** [INSTALL.md](./INSTALL.md) - Complete dependency installation instructions
- **Documentation:** `/ai-dev-atelier/skills/README.md`
- **Script help:** See individual skill documentation in `skills/*/SKILL.md`
- **Repository:** https://github.com/LukasStrickler/ai-dev-atelier
