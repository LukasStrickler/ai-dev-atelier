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

JavaScript runtime (required for npm scripts and code quality tools).

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

### 3. jq

JSON processor (required for setup script and PR tools).

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
jq --version  # Should show version 1.6+
```

### 4. package.json

Your project must have a `package.json` file. If you don't have one:

```bash
# Initialize npm project
npm init -y

# OR initialize with Bun
bun init -y
```

## Optional Dependencies

### GitHub CLI (gh)

Required for PR review tools (`ada::pr:*` commands).

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

Required for code review tools (`ada::review:*` commands).

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

### Package.json Scripts

Your `package.json` should include these scripts for the code-quality skill:

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "format:check": "prettier --check .",
    "format:write": "prettier --write ."
  }
}
```

**Note:** The exact commands may vary based on your project setup. Adjust as needed.

## Installation Steps

> **⚡ Quick setup:** For a quick start guide, see [SETUP.md](./SETUP.md).

### 1. Clone AI Dev Atelier

```bash
git clone https://github.com/LukasStrickler/ai-dev-atelier.git /ai-dev-atelier
```

**Alternative locations:**

If you prefer a different location, update the paths in `package.json` after setup:

```bash
git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/ai-dev-atelier
# Or any other path
```

### 2. Navigate to Your Project

```bash
cd /path/to/your/project
```

**Important:** Run the setup script from your project root directory (where `package.json` is located).

### 3. Run Setup Script

```bash
bash /ai-dev-atelier/setup.sh
```

The setup script will:
- ✅ Check prerequisites (jq, package.json)
- ✅ Add npm scripts to your `package.json`
- ✅ Create a backup of your `package.json`
- ✅ Show a summary of what was added

### 4. Verify Installation

```bash
# Check scripts were added
npm run | grep "ada::"

# Test a script
npm run ada::docs:check
```

> **📖 Next steps:** See [SETUP.md](./SETUP.md) for configuring skills in your AI agent and usage examples.

## Feature-Specific Requirements

### Code Quality Tools

**Required:**
- TypeScript installed in project
- ESLint installed in project
- Prettier installed in project
- `package.json` scripts: `typecheck`, `lint`, `format:check`, `format:write`

**Commands:**
- `npm run ada::agent:finalize` - Auto-fixes formatting
- `npm run ada::ci:finalize` - Read-only checks

### Documentation Check

**Required:**
- Git repository initialized
- Git remote configured (optional, for better branch detection)

**Commands:**
- `npm run ada::docs:check` - Check for documentation updates

### Code Review (CodeRabbit)

**Required:**
- CodeRabbit CLI installed and authenticated
- Git repository initialized

**Commands:**
- `npm run ada::review:task` - Review uncommitted changes
- `npm run ada::review:pr` - Review PR changes
- `npm run ada::review:read` - Read review results
- `npm run ada::review:cleanup` - Clean up old reviews

### PR Review Tools

**Required:**
- GitHub CLI installed and authenticated
- Git repository with GitHub remote configured
- jq installed

**Commands:**
- `npm run ada::pr:comments` - Fetch PR comments
- `npm run ada::pr:comments:detect` - Auto-detect PR number
- `npm run ada::pr:comments:get` - Get single comment
- `npm run ada::pr:comments:resolve` - Resolve comments
- `npm run ada::pr:comments:dismiss` - Dismiss comments
- `npm run ada::pr:list` - List open PRs

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

1. Copy `mcp.json.example` to your MCP configuration location (typically `~/.config/claude/mcp.json` for Claude Desktop)
2. Update API keys in the configuration file
3. Restart your AI agent to load MCP servers

See `mcp.json.example` for complete configuration format.

## Configure Skills in Your AI Agent

**IMPORTANT:** After running the setup script, you must configure the skills in your AI agent for automatic discovery and use.

> **📖 Detailed configuration:** See [SETUP.md](./SETUP.md) for complete agent configuration instructions.

### Quick Summary

1. **Add skills directory to agent configuration:**
   - Skills are located at: `/ai-dev-atelier/skills/`
   - Configure your agent to load skills from this directory

2. **Verify skills are loaded:**
   - Ask your agent: "What skills are available?"
   - The agent should list: `code-quality`, `docs-check`, `docs-write`, `code-review`, `pr-review`

3. **Test skill triggering:**
   - Try: "Run code quality checks" (should trigger `code-quality` skill)
   - Try: "Check if documentation needs updates" (should trigger `docs-check` skill)

**Note:** The npm scripts (`ada::*`) work independently of agent skills. You can use them via command line even if skills aren't configured in your agent.

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `jq: command not found` | Install jq: `brew install jq` (macOS) or see installation instructions above |
| `package.json not found` | Run setup from project root directory where `package.json` is located |
| `bash: command not found` | Install Git Bash (Windows) or use WSL |
| Scripts not found at `/ai-dev-atelier/skills/` | Verify clone location or update paths in `package.json` |
| Permission denied | `chmod +x /ai-dev-atelier/skills/*/scripts/*.sh` |
| `gh: command not found` | Install GitHub CLI: `brew install gh && gh auth login` |
| `coderabbit: command not found` | Install CodeRabbit CLI: `npm install -g @coderabbitai/cli && coderabbit auth login` |
| TypeScript errors | Install TypeScript: `npm install --save-dev typescript` |
| ESLint errors | Install ESLint: `npm install --save-dev eslint` |
| Prettier errors | Install Prettier: `npm install --save-dev prettier` |
| `bun: command not found` | Install Bun or use Node.js instead |

### Verification Checklist

Run these commands to verify your installation:

```bash
# Check required tools
git --version
node --version  # OR bun --version
jq --version

# Check optional tools (if using PR/review features)
gh --version
gh auth status
coderabbit --version

# Check project dependencies (if using code-quality)
npx tsc --version
npx eslint --version
npx prettier --version

# Check npm scripts
npm run | grep "ada::"

# Test a script
npm run ada::docs:check
```

## Next Steps

After installation, see [SETUP.md](./SETUP.md) for:
- Configuring skills in your AI agent
- Usage examples
- Integration into your workflow
- Customization options

## Support

- **Setup Guide:** [SETUP.md](./SETUP.md) - Quick setup and configuration
- **Documentation:** `/ai-dev-atelier/skills/README.md`
- **Script help:** See individual skill documentation in `skills/*/SKILL.md`
- **Repository:** https://github.com/LukasStrickler/ai-dev-atelier

