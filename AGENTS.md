# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-14
**Context:** AI Dev Atelier - Agent Skills & MCP Pack

## OVERVIEW
Production-grade skill pack for OpenCode agents. 10 skills (Agent Skills standard), 9 MCP servers, hooks, and telemetry. Pure Bash implementation + JSON config.

## STRUCTURE
```
.
├── config/            # [AGENTS.md] Configuration (skills, hooks, MCPs, agents)
├── content/
│   ├── skills/        # [AGENTS.md] 10 skills (SKILL.md + scripts + refs)
│   ├── plugins/       # [AGENTS.md] OpenCode plugins (TypeScript)
│   ├── hooks/         # Standalone hook scripts
│   └── agents/        # Custom agent definitions
├── .test/             # [AGENTS.md] Custom bash testing framework
├── .ada/              # Runtime outputs (gitignored)
└── install.sh         # Main deployment script
```

## SKILL CATALOG
| Skill | Purpose | Entry Point |
|-------|---------|-------------|
| `code-quality` | Typecheck, lint, format, Markdown | `scripts/finalize.sh` |
| `docs-check` | Detect docs needing updates from git diff | `scripts/check-docs.sh` |
| `docs-write` | Write/update docs with standards | Workflow (no script) |
| `git-commit` | Write clear commits with Conventional Commits | Workflow (no script) |
| `code-review` | CodeRabbit reviews (task/pr modes) | `scripts/review-run.sh` |
| `resolve-pr-comments` | Multi-agent PR comment resolution | `scripts/pr-resolver*.sh` |
| `search` | Web + library docs + GitHub code search | MCP-based |
| `research` | Academic research with evidence cards | `scripts/research-*.sh` |
| `ui-animation` | Tasteful UI animation & accessibility | Workflow (no script) |
| `use-graphite` | Manage stacked PRs with Graphite CLI | `scripts/graphite*.sh` |

## CRITICAL WORKFLOWS
**1. Releases (MANUAL ONLY)**
AI agents must **NEVER** trigger releases. Human approval required.
```bash
gh workflow run release.yml -f version=X.Y.Z -f dry_run=true  # Dry run
gh workflow run release.yml -f version=X.Y.Z                  # Real release
```

**2. Z.AI Optimization**
Disable redundant Z.AI tools in `~/.opencode/opencode.json` to save quota:
- `zai-zread_read_file` (Use `webfetch`)
- `zai-zread_get_repo_structure` (Use `gh api`)
- `zai-vision_image_analysis` (Use `look_at`)

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add New Skill** | `content/skills/` | See `content/skills/AGENTS.md` |
| **Configure Tools** | `config/mcps.json` | See `config/AGENTS.md`. Installer writes MCPs to OpenCode (`~/.opencode/opencode.json`) and Cursor (`~/.cursor/mcp.json`). |
| **Edit Guardrails** | `config/hooks.json` | See `config/AGENTS.md` |
| **Run Tests** | `.test/` | See `.test/AGENTS.md` |
| **Plugin Logic** | `content/plugins/` | See `content/plugins/AGENTS.md` |
| **Data Outputs** | `.ada/data/` | Reviews, research cards, PR data |

## SKILL UPDATE CHECKLIST
- Update `config/skills.json` and `content/skills/README.md` for the catalog.
- Update `content/skills/AGENTS.md` and any skill-specific `SKILL.md` references.
- Update `.github/ISSUE_TEMPLATE/bug_report.yml` and `.github/ISSUE_TEMPLATE/feature_request.yml` dropdowns.
- Verify any docs listing skills (README/INSTALL) remain accurate.

## CONVENTIONS
- **Language**: Bash for logic, JSON for config, TypeScript for plugins.
- **Runtime**: `bun` required for TypeScript-based skills (e.g., `image-generation`).
- **No Build**: `install.sh` deploys skills to `~/.opencode/skills/` (OpenCode) and `~/.cursor/skills/` (Cursor).
- **Formatting**: `shfmt` (2 spaces), `prettier` (Markdown/JSON).
- **Skill Standard**: Must have `SKILL.md` (YAML frontmatter) + `references/`.

## SKILL INVOCATION GUIDELINES (IMPORTANT)

**Installation Paths**: Skills are installed to `~/.opencode/skills/<name>/` (OpenCode) and `~/.cursor/skills/<name>/` (Cursor, user-level per [Cursor docs](https://cursor.com/docs/context/skills)). Set `CURSOR_HOME` to override Cursor's base path.

**Agent-Facing Paths**: When referencing skills in agent prompts, SKILL.md files, or custom agents:
- ✅ Use: `skills/<name>/scripts/<script>.sh` (relative from skill directory)
- ✅ Use: `scripts/<script>.sh` (relative from within the skill)
- ❌ Avoid: `content/skills/<name>/...` (repo structure, not installed path)

**Developer Paths**: In documentation for humans (README, INSTALL.md):
- ✅ Use: `content/skills/<name>/...` (matches repo layout)

**Examples**:
```bash
# Agent executing skill script (installed context)
bash skills/resolve-pr-comments/scripts/pr-resolver.sh 26

# Within a SKILL.md referencing its own scripts
bash scripts/finalize.sh agent

# Developer referring to source files
See `content/skills/code-quality/SKILL.md` for details
```

## ANTI-PATTERNS (THIS PROJECT)
- **Releases**: NEVER trigger `gh release` or `release.yml` without explicit user permission.
- **Secrets**: NEVER commit secrets. Use placeholders in `config/mcps.json`.
- **Format**: NEVER assume docs format. Read `references/` guides first.
- **Telemetry**: NEVER break `skill-telemetry.ts` (essential for analytics).
- **Logic**: NEVER put complex logic in `SKILL.md` (call scripts instead).

## COMMANDS
```bash
bash install.sh         # Deploy skills + MCPs + hooks
make validate           # Check skill structure & config validity
make test               # Run integration tests (.test/tests/*.sh)
make lint               # Run shellcheck
make setup              # Check dependencies
```
