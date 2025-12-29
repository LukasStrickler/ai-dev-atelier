# AGENTS.md

This file defines how AI agents and contributors should work in this repository.

## For AI agents

Read these first:
- `README.md` for capabilities and entry points
- `SETUP.md` for verification steps
- `INSTALL.md` for dependencies and MCP setup
- `WORKFLOW_EXAMPLE.md` for a personal OpenCode + Vibekanban usage example

Repository layout:
- Skills live in `skills/<name>/SKILL.md`
- Skill scripts live in `skills/<name>/scripts/`
- Output data is written under `.ada/`

Commands you can run:
- `bash setup.sh` (verify structure)
- `bash install.sh` (install skills and MCPs)
- `bash .test/scripts/validate-skills.sh` (validate skills)
- `bash skills/<skill>/scripts/<script>.sh` (skill scripts)

Install locations (see `install.sh`):
- Codex skills: `~/.codex/skills` (or `$XDG_CONFIG_HOME/codex/skills`)
- OpenCode skills: `~/.opencode/skill` (or `$XDG_CONFIG_HOME/opencode/skill`)
- Codex MCP config: `~/.codex/config.toml`
- OpenCode config: `~/.opencode/opencode.json` (or project `opencode.json`)

MCP keys:
- Provide API keys via `.env` (see `.env.example`) before running `install.sh`, or update the generated MCP config after install.

Guardrails:
- Do not commit unless explicitly requested.
- Do not modify global git config.
- Do not add or expose secrets in files.
- Keep changes scoped to the requested task.
- Use `skills-config.json` to disable skills per agent when needed.

## For human contributors

Before changes:
- Run `bash setup.sh`

After changes:
- Run `bash .test/scripts/validate-skills.sh`
- Ensure each skill keeps the `SKILL.md` format and embedded scripts

When adding or updating skills:
- Keep instructions and scripts inside the skill folder
- Update `skills/README.md` if the catalog changes
- Keep outputs under `.ada/`
