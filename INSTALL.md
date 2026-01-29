# Installation Guide

Complete installation guide for AI Dev Atelier, including all required and optional dependencies.

## System Requirements

- **Operating System**: macOS, Linux, or Windows (with WSL/Git Bash)
- **Shell**: Bash 4.0+ (included on macOS/Linux, Git Bash on Windows)

## Automatic Dependency Install

The installer checks dependencies and will prompt to install common packages with your system package manager when possible. If the automatic install fails, use the manual commands below.

## Required Dependencies

### 1. Git

Version control system (required for all tools). The installer will prompt to install Git via your system package manager if it's missing.

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

# Linux (Arch)
sudo pacman -S git

# Linux (openSUSE)
sudo zypper install git

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

### 3. OpenCode Agent

This skill pack is designed for OpenCode agent. Ensure you have it installed and configured.

**Installation:**
```bash
curl -fsSL https://opencode.ai/install | bash
```

**Verify:**
```bash
# Verify OpenCode config directory exists
ls -la ~/.opencode
```

## Optional Dependencies

### jq (JSON processor)

Required for automatic MCP configuration by `install.sh`. The installer will prompt to install jq when it's missing.

**Installation:**

```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq

# Linux (Fedora/RHEL)
sudo dnf install jq

# Linux (Arch)
sudo pacman -S jq

# Linux (openSUSE)
sudo zypper install jq

# Windows (using Chocolatey)
choco install jq

# Or download from: https://stedolan.github.io/jq/download/
```

**Verify:**
```bash
jq --version
```

### GitHub CLI (gh)

Required for PR review tools (used by the `resolve-pr-comments` skill).

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
curl -fsSL https://cli.coderabbit.ai/install.sh | sh

# OR with npm
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

### Graphite CLI (gt)

Required for stacked PR workflows (used by the `use-graphite` skill).

**Installation:**

```bash
# Homebrew
brew install withgraphite/tap/graphite

# npm
npm install -g @withgraphite/graphite-cli@stable
```

**Authentication:**

```bash
gt auth login
```

**Verify:**
```bash
gt --version
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

Follow [README.md](./README.md) for quick start and install commands. See [AGENTS.md](./AGENTS.md) and [content/skills/README.md](./content/skills/README.md) for workflow guidance and usage examples. Local development uses `make install` to install changes from your checkout.

## Feature-Specific Requirements

### Code Quality Tools

**Required:**
- TypeScript installed in project
- ESLint installed in project
- Prettier installed in project
- Commands available: `typecheck`, `lint`, `format:check`, `format:write`

**Usage:**
- Ask OpenCode: "Run code quality checks" (triggers `code-quality` skill)
- The skill will execute scripts embedded in `content/skills/code-quality/scripts/finalize.sh`

### Documentation Check

**Required:**
- Git repository initialized
- Git remote configured (optional, for better branch detection)

**Usage:**
- Ask OpenCode: "Check if documentation needs updates" (triggers `docs-check` skill)
- The skill will execute scripts embedded in `content/skills/docs-check/scripts/check-docs.sh`

### Code Review (CodeRabbit)

**Required:**
- CodeRabbit CLI installed and authenticated
- Git repository initialized

**Usage:**
- Ask OpenCode: "Review my code changes" (triggers `code-review` skill)
- The skill will execute scripts embedded in `content/skills/code-review/scripts/review-run.sh`

### PR Review Tools

**Required:**
- GitHub CLI installed and authenticated
- Git repository with GitHub remote configured
- jq installed

**Usage:**
- Ask OpenCode: "Fetch PR comments" (triggers `resolve-pr-comments` skill)
- The skill will execute scripts embedded in `content/skills/resolve-pr-comments/scripts/pr-resolver*.sh`

### MCP Dependencies (for Search and Research Skills)

**Required for Search Skill:**

- **Tavily MCP** - Web search for general information, tutorials, and current content
  - **Installation:** `npm install -g @tavily/mcp-server-tavily` or use `npx -y @tavily/mcp-server-tavily`
  - **API Key Required:** Get from https://tavily.com
  - **Configuration:** Add to `config/mcps.json` with `TAVILY_API_KEY` environment variable
  - **Usage:** General web searches, tutorials, error messages, best practices

- **Context7 MCP** - Library documentation and API references
  - **Installation:** `npm install -g @context7/mcp-server` or use `npx -y @context7/mcp-server`
  - **API Key Required:** No
  - **Usage:** Library/framework documentation, API references, installation instructions

- **Grep MCP** - Search across a million public GitHub repositories for code examples and patterns
  - **Installation:** Automatically configured by `install.sh` (no manual installation needed)
  - **API Key Required:** No
  - **Configuration:** Automatically added to OpenCode MCP config
  - **Usage:** Finding real-world code examples, implementation patterns, API usage, error handling patterns
  - **Note:** All MCPs from `config/mcps.json` are automatically configured by the installer. Update API keys after installation.

**Optional for Search/Research:**

- **Z.AI MCP (zai-zread + zai-vision)** - Repo semantic search and vision tools
  - **Installation:** `npx -y @z_ai/mcp-server`
  - **API Key Required:** `Z_AI_API_KEY`
  - **Usage:** Semantic GitHub search and image/video analysis

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

**For OpenCode (Automatic):**
- The `install.sh` script automatically configures all MCPs from `config/mcps.json` for OpenCode and installs skills to both OpenCode and Cursor (global).
- **OpenCode**: MCP configuration is created/updated at `~/.opencode/opencode.json` (or `$XDG_CONFIG_HOME/opencode/opencode.json`). Skills go to `~/.opencode/skills/`.
- **Cursor**: Skills are installed to `~/.cursor/skills/` (user-level per [Cursor docs](https://cursor.com/docs/context/skills)). Set `CURSOR_HOME` to override the Cursor base path.
- Existing MCP configurations are preserved; only missing MCPs are added.
- All MCPs from the example file are configured: Tavily, Context7, OpenAlex, PDF Reader, Paper-search, Grep, Z.AI, and Graphite.
- Requires `jq` to be installed for automatic configuration.
- **Important:** After installation, update API keys in the `.env` file or directly in the config.

**For Other Agents (Manual):**
1. Copy `config/mcps.json` to your MCP configuration location (typically `~/.opencode/opencode.json` or your agent's MCP config)
2. Update API keys in the configuration file
3. Restart your AI agent to load MCP servers

See `config/mcps.json` for complete configuration format.

## How Agents Use Skills

See [content/skills/README.md](./content/skills/README.md) for the skill loading model, scripts, and usage details.

### Test skill triggering:
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
| Skills not appearing in OpenCode | Verify skills are installed to `~/.opencode/skills/` and restart OpenCode |
| Skills not appearing in Cursor | Verify skills in `~/.cursor/skills/`; restart Cursor if needed |
| OpenCode doesn't recognize skills | Restart OpenCode after installation |
| `gh: command not found` | Install GitHub CLI: `brew install gh && gh auth login` |
| `coderabbit: command not found` | Install CodeRabbit CLI: `npm install -g @coderabbitai/cli && coderabbit auth login` |
| TypeScript errors | Install TypeScript: `npm install --save-dev typescript` |
| ESLint errors | Install ESLint: `npm install --save-dev eslint` |
| Prettier errors | Install Prettier: `npm install --save-dev prettier` |
| `bun: command not found` | Install Bun or use Node.js instead |
| MCP configuration failed | Install jq: `brew install jq` (macOS) or `sudo apt-get install jq` (Linux) |
| Grep MCP not working | Verify MCP config exists at `~/.opencode/opencode.json` and restart OpenCode |

### Verification Checklist

Run these commands to verify your installation:

```bash
# Check required tools
git --version
node --version  # OR bun --version

# Check OpenCode skills directory
ls -la ~/.opencode/skills

# Check Cursor skills directory (user-level, global)
ls -la ~/.cursor/skills

# Check optional tools (if using PR/review features)
gh --version
gh auth status
coderabbit --version

# Check project dependencies (if using code-quality)
npx tsc --version
npx eslint --version
npx prettier --version

# Validate skill structure and integrity
make validate
```

## Next Steps

After installation, see:
- [AGENTS.md](./AGENTS.md) for workflow guidance and MCP references
- [content/skills/README.md](./content/skills/README.md) for usage examples and scripts

## Support

- **Documentation:** `~/ai-dev-atelier/content/skills/README.md`
- **Workflow:** `~/ai-dev-atelier/AGENTS.md`
- **Script help:** See individual skill documentation in `content/skills/*/SKILL.md`
