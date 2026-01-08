# My Personal Workflow

Note: This is a personal setup example for the author's environment. It is not required to use AI Dev Atelier and may not match your setup.

This document walks through the AI-assisted coding setup that powers my day-to-day development work. The stack combines Vibekanban for task orchestration, oh-my-opencode as the agent runtime, cloudflared for remote access, and AI Dev Atelier to inject specialized skills into the mix. Each component plays a distinct role, and together they create a workflow where tasks can be scheduled, refined, and executed from anywhere, backed by capabilities that make the agents meaningfully better at the work that matters.

## Why This Stack?

### Vibekanban — Task Orchestration

At the top of the stack sits Vibekanban, a kanban-style board designed to manage multiple AI coding agents in parallel. Rather than babysitting individual agent sessions, the board lets tasks queue up, run independently, and return results when they are ready. The worktree isolation is solid, so each task runs in its own environment without stepping on other work.

The instance runs on a 24/7 server. That enables long-running jobs to start before bed and finish overnight. Combined with cloudflared, the setup becomes fully accessible from any device, anywhere, which turns async work into the default instead of the exception.

### Cloudflared — Remote Access

A Cloudflare Tunnel exposes Vibekanban to the internet. One command (`cloudflared tunnel --url http://localhost:PORT`) generates a public URL with no port forwarding or VPN setup. The result is that scheduling and monitoring can happen from a train, a cafe, or a phone screen during downtime.

Official docs:
- Quick Tunnels: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/
- Get started: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/

### oh-my-opencode — The Agent Runtime

Inside Vibekanban, most tasks run on OpenCode-based agents. oh-my-opencode is the flavor of choice: async subagents, curated tools (LSP, AST-grep), and a Claude Code compatibility layer.

The typical flow is two-phase. First, Planner-Sisyphus refines the task and breaks it into steps. Once the plan is tight, Sisyphus implements it. Splitting planning and execution keeps quality high and prevents runaway implementation.

### AI Dev Atelier — The Skills Layer

The agents are already capable out of the box, but AI Dev Atelier injects skills that make them better at my specific work. The focus is on tasks that benefit from deeper context: code quality gates, documentation hygiene, review tooling, and research-heavy prompts.

| Skill | What It Adds |
| --- | --- |
| `code-quality` | Automated linting, typechecking, and formatting that catches issues early. |
| `docs-check` / `docs-write` | Detection of documentation drift plus structured writing. |
| `code-review` | CodeRabbit-powered reviews on uncommitted changes or PRs. |
| `pr-review` | Fetches, resolves, and dismisses GitHub PR comments. |
| `search` | Enhanced web and library doc search via Tavily and Context7. |
| `research` | Academic paper discovery with evidence cards. |

The difference is practical: without skills, an agent writes code. With skills, it writes code that is reviewed, documented, and backed by research when needed.

### How it all comes together

Vibekanban handles orchestration, cloudflared handles access, oh-my-opencode handles the agent runtime, and AI Dev Atelier supplies the specialized capabilities. The result is a system that can plan, execute, and validate work asynchronously, while staying reachable from anywhere.

## One-time setup

1. Clone the repo:
   - `git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/ai-dev-atelier`

2. Configure MCP keys before install:
   - Copy `.env.example` to `.env` and set the API keys you will use.

3. Verify the repository:
   - `bash ~/ai-dev-atelier/setup.sh`

4. Install skills and MCPs (OpenCode):
   - `bash ~/ai-dev-atelier/install.sh`
   - This installs to `~/.opencode/skill` and updates MCP configs.

5. Restart oh-my-opencode so skills and MCPs reload.

## Day-to-day flow

1. Vibekanban runs 24/7 on the server.
2. Cloudflared exposes it via a stable tunnel URL.
3. From any device, the URL opens and tasks queue up.
4. Planner-Sisyphus refines, Sisyphus implements.
5. Skills kick in automatically (quality gates, search, research, reviews).
6. Results arrive asynchronously.

After skill updates, re-running `install.sh` is safe and non-destructive.

## Links

- oh-my-opencode: https://github.com/code-yeongyu/oh-my-opencode
- Vibekanban: https://github.com/BloopAI/vibe-kanban
- [README.md](./README.md)
- [INSTALL.md](./INSTALL.md)
- [SETUP.md](./SETUP.md)
