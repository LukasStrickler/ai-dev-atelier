# PLUGIN ARCHITECTURE

**Generated:** 2026-01-14
**Context:** OpenCode Runtime Plugins (TypeScript)

## OVERVIEW
TypeScript plugins for the OpenCode runtime, extending agent capabilities via lifecycle hooks (e.g., telemetry).

## WHERE TO LOOK
| File | Description |
|------|-------------|
| `skill-telemetry.ts` | Captures `tool.execute.before` events to log skill usage to `~/.ada/skill-events.jsonl`. |

## CONVENTIONS
- **Runtime**: Node.js environment within OpenCode.
- **Dependencies**: **Zero external dependencies** preferred; use Node.js standard library (`fs`, `path`, `os`).
- **IO Strategy**: Non-blocking `fs/promises` for file operations; ensure directories exist before writing.
- **Error Handling**: Silent failure preferred over crashing; catch and log internal errors safely.
- **Output**: Write structured logs (JSONL) to user home `.ada` directory, not console.

## ANTI-PATTERNS
- **Blocking I/O**: NEVER use `fs.readFileSync` in high-frequency event loops (except initial config load).
- **Console Spam**: NEVER leave `console.log` in production plugins; use proper logging channels.
- **Hardcoded Paths**: NEVER assume paths; use `os.homedir()` or environment variables.
- **Complex Logic**: NEVER put heavy business logic in plugins; delegate to Skills/Scripts.
