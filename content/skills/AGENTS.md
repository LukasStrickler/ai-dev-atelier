# SKILLS CATALOG

**Generated:** 2026-01-14
**Reason:** Standard Agent Skills Catalog

## OVERVIEW
Detailed catalog of 10 specialized agent skills implementing the OpenCode Skill Interface for git, research, and QA.

## STRUCTURE
```
skills/
├── [skill-name]/      # e.g., git-commit, research
│   ├── SKILL.md       # YAML frontmatter + Prompt logic
│   ├── references/    # Static context documentation
│   └── scripts/       # (Optional) Bash/Python executables
└── README.md          # Full usage documentation
```

**Note**: Skills are installed to `~/.opencode/skills/` (OpenCode) and `~/.cursor/skills/` (Cursor, user-level) when using this repo's `install.sh`. When agents reference scripts, they use `skills/<name>/scripts/<script>.sh` (relative paths from the skill installation directory).

## WHERE TO LOOK
| Component | Path | Purpose |
|-----------|------|---------|
| **Definitions** | `*/SKILL.md` | Source of truth for agent behavior and triggers |
| **Context** | `*/references/*.md` | Static knowledge injected into agent context |
| **Executables** | `*/scripts/*` | Helper tools called by the skill logic |
| **Usage** | `README.md` | Human-readable catalog and instructions |

## CONVENTIONS
- **SKILL.md**: MUST start with YAML frontmatter (`name`, `description`) followed by prompt.
- **Scripts**: Must be executable (`chmod +x`) and use relative paths.
- **References**: Markdown files only; keep focused and modular.
- **Independence**: Skills must be self-contained; do not import from other skills.

## ANTI-PATTERNS
- **Inline Logic**: Putting complex logic in `SKILL.md` prompts (use `scripts/` instead).
- **Empty Directories**: Creating `references/` or `scripts/` without content.
- **Hardcoded Paths**: Using absolute paths or user-specific directories in scripts.
- **Mixed Languages**: Using non-Bash languages in `scripts/` without explicit justification.
