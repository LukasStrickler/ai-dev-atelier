# AI Dev Atelier

```text
                 █████╗ ████████╗███████╗██╗     ██╗███████╗██████╗                     
                ██╔══██╗╚══██╔══╝██╔════╝██║     ██║██╔════╝██╔══██╗                   
                ███████║   ██║   █████╗  ██║     ██║█████╗  ██████╔╝                   
                ██╔══██║   ██║   ██╔══╝  ██║     ██║██╔══╝  ██╔══██╗                    
                ██║  ██║   ██║   ███████╗███████╗██║███████╗██║  ██║                    
                ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝╚═╝╚══════╝╚═╝  ╚═╝                    

                        🎨 A I   D E V   A T E L I E R 🎨                     
                                                                                        
                        🖌️ Where AI Agents Craft Quality Code                              
                🔍      📝     ✍️     🔬     💬      🔎       📚
                quality  docs   docs   code    pr     search  research
                check    check  write  review  review 
```


![License](https://img.shields.io/badge/license-BSL%201.1-blue) ![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Anthropic-orange) ![OpenCode](https://img.shields.io/badge/OpenCode-supported-1f6feb) ![Codex](https://img.shields.io/badge/Codex-supported-6f42c1) ![MCP](https://img.shields.io/badge/MCP-enabled-2ea043)

Production-grade skill pack for AI-assisted development: code quality, documentation, code review, research, and orchestration via Agent Skills and MCP.

Quick links: [WORKFLOW_EXAMPLE.md](./WORKFLOW_EXAMPLE.md) | [SETUP.md](./SETUP.md) | [INSTALL.md](./INSTALL.md)

## Quick Start

Before install, copy `.env.example` to `.env` and set MCP API keys you plan to use.

```bash
git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/ai-dev-atelier
bash ~/ai-dev-atelier/setup.sh
bash ~/ai-dev-atelier/install.sh
```

`install.sh` installs skills and MCPs for both Codex and OpenCode, preserves existing configs, and supports agent-specific filtering via `skills-config.json`.

Verify in your agent:
- Ask: "What skills are available?"
- Or check: `~/.codex/skills` and `~/.opencode/skill`

## Agent Compatibility

- Agent Skills are primarily aimed at raw Codex.
- OpenCode supports skills, but relies on native subagents for orchestration.

## What You Get

| Skill | Purpose | Entry Point |
| --- | --- | --- |
| `code-quality` | Typecheck, lint, format, markdown validation | `skills/code-quality/scripts/finalize.sh` |
| `docs-check` | Detect documentation impact from git diffs | `skills/docs-check/scripts/check-docs.sh` |
| `docs-write` | Write/update docs using standards | Workflow skill (no script) |
| `code-review` | CodeRabbit reviews (task/pr modes) | `skills/code-review/scripts/review-run.sh` |
| `pr-review` | Fetch/resolve/dismiss PR comments | `skills/pr-review/scripts/pr-comments-*.sh` |
| `search` | Web and library documentation search | MCP-based (no script) |
| `research` | Academic research with evidence cards | `skills/research/scripts/research-*.sh` |
| `agent-orchestration` | Spawn and manage sub-agents | `skills/agent-orchestration/scripts/agent-*.sh` |

## MCP Integration

| MCP Server | Purpose | API Key / Env |
| --- | --- | --- |
| `tavily-remote-mcp` | Web search and research | `TAVILY_API_KEY` required |
| `context7` | Library documentation | `CONTEXT7_API_KEY` (if used) |
| `openalex-research` | Academic papers and citations | `OPENALEX_EMAIL` required |
| `pdf-reader` | PDF extraction | None |
| `paper-search` | Multi-platform paper search | Optional keys |
| `grep` | GitHub code search | None |

## Data and Outputs

| Output Type | Location |
| --- | --- |
| Code reviews | `.ada/data/reviews/` |
| PR comments | `.ada/data/pr-comments/` |
| Research evidence cards | `.ada/data/research/{topic}/` |
| Research downloads (temp) | `.ada/temp/research/downloads/` |

## Safety and Guardrails

- Skills are driven by `SKILL.md` instructions and execute scripts via bash.
- The installer preserves existing Codex/OpenCode configurations.
- Outputs are written to `.ada/` directories; no hidden state.
- Use `skills-config.json` to disable skills per agent.

## Docs and Setup

- [SETUP.md](./SETUP.md): Verify the repository and skill structure before installing.
- [INSTALL.md](./INSTALL.md): Full dependency and MCP setup across platforms.
- [WORKFLOW_EXAMPLE.md](./WORKFLOW_EXAMPLE.md): Personal OpenCode (oh-my-opencode) and Vibekanban setup example.

## License

Business Source License 1.1. Change License: Apache 2.0. See [LICENSE](./LICENSE).
