# Installation Guide

Complete installation guide for AI Dev Atelier, including all required and optional dependencies.

## System Requirements

- **Operating System**: macOS, Linux, or Windows (with WSL/Git Bash)
- **Shell**: Bash 4.0+ (included on macOS/Linux, Git Bash on Windows)

## Required Dependencies

### 1. Git

Version control system (required for all tools).

**Installation:**

```bash
# macOS (usually pre-installed)
git --version

# If not installed, use Homebrew
brew install git

# Linux (Ubuntu/Debian)
sudo apt-get install git

# Linux (Fedora/RHEL)
sudo dnf install git

# Windows
# Download from: https://git-scm.com/download/win
```

**Verify:**
```bash
git --version  # Should show version 2.0+
```

### 2. Node.js or Bun

JavaScript runtime (required for code quality tools and optional dependencies).

**Option A: Node.js 18+**

```bash
# macOS (using Homebrew)
brew install node

# Linux (using NodeSource)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Or download from: https://nodejs.org/
```

**Option B: Bun (recommended for faster execution)**

```bash
# macOS/Linux
curl -fsSL https://bun.sh/install | bash

# Or using Homebrew
brew install bun
```

**Verify:**
```bash
node --version  # Should show v18.0.0 or higher
# OR
bun --version   # Should show latest Bun version
```

### 3. Codex

AI agent that supports skills installation. Skills are installed to `~/.codex/skills`.

**Note:** Only Codex is currently supported for skills installation. Gemini does not support skills.

**Installation:**

```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq

# Linux (Fedora/RHEL)
sudo dnf install jq

# Windows (using Chocolatey)
choco install jq

# Or download from: https://stedolan.github.io/jq/download/
```

**Verify:**
```bash
# Verify Codex is installed and skills directory exists
ls -la ~/.codex/skills
```

## Optional Dependencies

### GitHub CLI (gh)

Required for PR review tools (used by the `pr-review` skill).

**Installation:**

```bash
# macOS
brew install gh

# Linux (Ubuntu/Debian)
sudo apt-get install gh

# Linux (Fedora/RHEL)
sudo dnf install gh

# Windows
# Download from: https://cli.github.com/
```

**Authentication:**

```bash
gh auth login
```

**Verify:**
```bash
gh --version
gh auth status
```

### CodeRabbit CLI

Required for code review tools (used by the `code-review` skill).

**Installation:**

```bash
npm install -g @coderabbitai/cli

# OR with Bun
bun install -g @coderabbitai/cli
```

**Authentication:**

```bash
coderabbit auth login
```

**Verify:**
```bash
coderabbit --version
```

## Project-Specific Dependencies

These are required for the `code-quality` skill to work properly in your project.

### TypeScript (for type checking)

**Installation:**

```bash
# As dev dependency
npm install --save-dev typescript

# OR with Bun
bun add -d typescript
```

**Configuration:**

Create `tsconfig.json` in your project root (or ensure it exists).

**Verify:**
```bash
npx tsc --version
```

### ESLint (for linting)

**Installation:**

```bash
# As dev dependency
npm install --save-dev eslint

# OR with Bun
bun add -d eslint
```

**Configuration:**

Create `.eslintrc` or `eslint.config.js` in your project root.

**Verify:**
```bash
npx eslint --version
```

### Prettier (for formatting)

**Installation:**

```bash
# As dev dependency
npm install --save-dev prettier

# OR with Bun
bun add -d prettier
```

**Configuration:**

Create `.prettierrc` or `prettier.config.js` in your project root.

**Verify:**
```bash
npx prettier --version
```

### Project Scripts (for code-quality skill)

Your project should have these commands available for the code-quality skill to use:

- `typecheck` - TypeScript type checking (e.g., `tsc --noEmit`)
- `lint` - ESLint linting (e.g., `eslint .`)
- `format:check` - Prettier format checking (e.g., `prettier --check .`)
- `format:write` - Prettier format writing (e.g., `prettier --write .`)

**Note:** These can be in `package.json` scripts or available as direct commands. The code-quality skill will use them when executing quality checks.

## Installation Steps

> **⚡ Quick setup:** For a quick start guide, see [SETUP.md](./SETUP.md).

### 1. Clone AI Dev Atelier

```bash
git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/ai-dev-atelier
```

**Alternative locations:**

You can clone to any location. The install script will automatically detect the correct path.

```bash
git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/projects/ai-dev-atelier
# Or any other path
```

### 2. Verify Skill Structure

```bash
bash ~/ai-dev-atelier/setup.sh
```

The setup script will:
- ✅ Verify skills directory exists
- ✅ Check for required skills (code-quality, docs-check, code-review, pr-review)
- ✅ Validate SKILL.md files are present
- ✅ Report any missing or invalid skills

### 3. Install Skills to Codex

```bash
bash ~/ai-dev-atelier/install.sh
```

The install script will:
- ✅ Copy skills to `~/.codex/skills`
- ✅ Preserve existing `.system` directory in Codex
- ✅ Show smart diff before overwriting existing skills
- ✅ Ask for confirmation before overwriting (use `--yes` to skip)

**Options:**
- `--yes` or `-y` - Skip confirmation prompts (auto-overwrite)
- `--help` or `-h` - Show help message

### 4. Verify Installation

```bash
# Check skills are installed
ls -la ~/.codex/skills

# Ask Codex: "What skills are available?"
# Should list: code-quality, docs-check, docs-write, code-review, pr-review, search, research, agent-orchestration
```

> **📖 Next steps:** See [SETUP.md](./SETUP.md) for configuring skills in your AI agent and usage examples.

## Feature-Specific Requirements

### Code Quality Tools

**Required:**
- TypeScript installed in project
- ESLint installed in project
- Prettier installed in project
- Commands available: `typecheck`, `lint`, `format:check`, `format:write`

**Usage:**
- Ask Codex: "Run code quality checks" (triggers `code-quality` skill)
- The skill will execute scripts embedded in `skills/code-quality/scripts/finalize.sh`

### Documentation Check

**Required:**
- Git repository initialized
- Git remote configured (optional, for better branch detection)

**Usage:**
- Ask Codex: "Check if documentation needs updates" (triggers `docs-check` skill)
- The skill will execute scripts embedded in `skills/docs-check/scripts/check-docs.sh`

### Code Review (CodeRabbit)

**Required:**
- CodeRabbit CLI installed and authenticated
- Git repository initialized

**Usage:**
- Ask Codex: "Review my code changes" (triggers `code-review` skill)
- The skill will execute scripts embedded in `skills/code-review/scripts/review-run.sh`

### PR Review Tools

**Required:**
- GitHub CLI installed and authenticated
- Git repository with GitHub remote configured
- jq installed

**Usage:**
- Ask Codex: "Fetch PR comments" (triggers `pr-review` skill)
- The skill will execute scripts embedded in `skills/pr-review/scripts/pr-comments-*.sh`

### MCP Dependencies (for Search and Research Skills)

**Required for Search Skill:**

- **Tavily MCP** - Web search for general information, tutorials, and current content
  - **Installation:** `npm install -g @tavily/mcp-server-tavily` or use `npx -y @tavily/mcp-server-tavily`
  - **API Key Required:** Get from https://tavily.com
  - **Configuration:** Add to `mcp.json` with `TAVILY_API_KEY` environment variable
  - **Usage:** General web searches, tutorials, error messages, best practices

- **Context7 MCP** - Library documentation and API references
  - **Installation:** `npm install -g @context7/mcp-server` or use `npx -y @context7/mcp-server`
  - **API Key Required:** No
  - **Usage:** Library/framework documentation, API references, installation instructions

- **Grep MCP** - Search across a million public GitHub repositories for code examples and patterns
  - **Installation:** Automatically configured by `install.sh` (no manual installation needed)
  - **API Key Required:** No
  - **Configuration:** Automatically added to Codex MCP config (`~/.codex/mcp.json` or `$XDG_CONFIG_HOME/codex/mcp.json`)
  - **Usage:** Finding real-world code examples, implementation patterns, API usage, error handling patterns
  - **Note:** All MCPs from `mcp.json` are automatically configured by the installer. Update API keys after installation.

**Required for Research Skill:**

- **OpenAlex MCP** - Academic paper discovery and citation analysis
  - **Installation:** `npx -y openalex-research-mcp`
  - **API Key Required:** No (uses OpenAlex free API)
  - **Usage:** Finding academic papers, related works, citations, references

- **PDF Reader MCP** - PDF text extraction
  - **Installation:** `npx -y @sylphx/pdf-reader-mcp`
  - **API Key Required:** No
  - **Usage:** Extracting text, images, and metadata from PDF files

**Optional for Research Skill:**

- **Paper-search MCP** - Multi-platform academic paper search and download
  - **Installation:** `npx -y paper-search-mcp-nodejs`
  - **API Key Required:** Optional (arXiv API key, Wiley TDM API key)
  - **Usage:** Automated paper search and download from arXiv, bioRxiv, medRxiv, IACR, Wiley TDM
  - **Note:** Includes Google Scholar + Sci-Hub integration (check Terms of Service and legal considerations)

**Configuration:**

**For Codex (Automatic):**
- The `install.sh` script automatically configures all MCPs from `mcp.json` for Codex
- MCP configuration is created/updated at `~/.codex/mcp.json` (or `$XDG_CONFIG_HOME/codex/mcp.json`)
- Existing MCP configurations are preserved; only missing MCPs are added
- All MCPs from the example file are configured: Tavily, Context7, OpenAlex, PDF Reader, Paper-search, and Grep
- Requires `jq` to be installed for automatic configuration
- **Important:** After installation, update API keys in the MCP config file (TAVILY_API_KEY, CONTEXT7_API_KEY, OPENALEX_EMAIL)

**For Other Agents (Manual):**
1. Copy `mcp.json` to your MCP configuration location (typically `~/.config/claude/mcp.json` for Claude Desktop)
2. Update API keys in the configuration file
3. Restart your AI agent to load MCP servers

See `mcp.json` for complete configuration format.

## How Agents Use Skills

**IMPORTANT:** After installing skills, Codex will automatically discover them from `~/.codex/skills`.

> **📖 Detailed information:** See [SETUP.md](./SETUP.md) for complete setup instructions.

### How It Works

1. **Skills are installed to `~/.codex/skills`:**
   - Each skill is a directory with `SKILL.md` and `scripts/` subdirectory
   - Codex automatically scans this directory for skills

2. **Agents discover skills:**
   - Codex reads `SKILL.md` files which contain YAML frontmatter and instructions
   - Skills are triggered based on their descriptions and trigger keywords

3. **Agents execute scripts:**
   - When a skill is triggered, Codex reads the instructions in `SKILL.md`
   - Scripts are executed via `bash skills/<skill-name>/scripts/<script-name>.sh`
   - Scripts are embedded within skill directories, not in package.json

4. **Verify skills are loaded:**
   - Ask Codex: "What skills are available?"
   - Should list: `code-quality`, `docs-check`, `docs-write`, `code-review`, `pr-review`, `search`, `research`, `agent-orchestration`

5. **Test skill triggering:**
   - Try: "Run code quality checks" (should trigger `code-quality` skill)
   - Try: "Check if documentation needs updates" (should trigger `docs-check` skill)

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Skills directory not found | Verify AI Dev Atelier is cloned correctly |
| SKILL.md not found | Ensure you're running setup from the AI Dev Atelier root directory |
| `bash: command not found` | Install Git Bash (Windows) or use WSL |
| Permission denied | `chmod +x ~/ai-dev-atelier/install.sh` |
| Skills not appearing in Codex | Verify skills are installed to `~/.codex/skills` and restart Codex |
| Codex doesn't recognize skills | Restart Codex after installation |
| `gh: command not found` | Install GitHub CLI: `brew install gh && gh auth login` |
| `coderabbit: command not found` | Install CodeRabbit CLI: `npm install -g @coderabbitai/cli && coderabbit auth login` |
| TypeScript errors | Install TypeScript: `npm install --save-dev typescript` |
| ESLint errors | Install ESLint: `npm install --save-dev eslint` |
| Prettier errors | Install Prettier: `npm install --save-dev prettier` |
| `bun: command not found` | Install Bun or use Node.js instead |
| MCP configuration failed | Install jq: `brew install jq` (macOS) or `sudo apt-get install jq` (Linux) |
| Grep MCP not working | Verify MCP config exists at `~/.codex/mcp.json` and restart Codex |

### Verification Checklist

Run these commands to verify your installation:

```bash
# Check required tools
git --version
node --version  # OR bun --version

# Check Codex skills directory
ls -la ~/.codex/skills

# Check optional tools (if using PR/review features)
gh --version
gh auth status
coderabbit --version

# Check project dependencies (if using code-quality)
npx tsc --version
npx eslint --version
npx prettier --version

# Verify skills are installed
bash ~/ai-dev-atelier/setup.sh

# Validate skill structure and integrity
bash .test/scripts/validate-skills.sh
```

## Next Steps

After installation, see [SETUP.md](./SETUP.md) for:
- Configuring skills in your AI agent
- Usage examples
- Integration into your workflow
- Customization options

## Support

- **Setup Guide:** [SETUP.md](./SETUP.md) - Quick setup and configuration
- **Documentation:** `~/ai-dev-atelier/skills/README.md`
- **Script help:** See individual skill documentation in `skills/*/SKILL.md`

