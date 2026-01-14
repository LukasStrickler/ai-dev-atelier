# CONFIGURATION KNOWLEDGE BASE

**Generated:** 2026-01-14
**Context:** config/
**Reason:** High complexity (Configuration interactions)

## OVERVIEW
Central registry defining active skills, MCP server endpoints, lifecycle guardrails, and agent capability permissions.

## WHERE TO LOOK
| File | Purpose | Key Fields |
|------|---------|------------|
| `agents.json` | Agent definitions & tool access | `capabilities`, `access` |
| `hooks.json` | Pre/Post-execution guardrails | `matcher`, `script` |
| `mcps.json` | MCP server registry & env vars | `mcpServers`, `args`, `env` |
| `plugins.json` | OpenCode plugin configuration | `enabled`, `settings` |
| `skills.json` | Skill pack selection & sources | `enabled`, `path` |

## CONVENTIONS
- **Format**: Pure JSON (RFC 8259). No comments allowed in strict parsers (use `_comment` keys if needed).
- **Secrets**: NEVER hardcode. Use `${VAR_NAME}` syntax for `install.sh` expansion or standard env var references.
- **Paths**: Relative paths in `hooks.json` start from project root.
- **Schema**:
  - `mcps.json`: Follows Model Context Protocol server definition.
  - `hooks.json`: Maps `id` to `script` executable.

## ANTI-PATTERNS
- **Hardcoding**: Creating `config/secrets.json` or committing real API keys.
- **Formatting**: Using trailing commas (breaks `jq`).
- **Logic**: Putting shell scripts inside JSON values (use reference paths to `content/hooks/` instead).
- **Redundancy**: Redefining standard MCPs defined in the parent runtime config.
