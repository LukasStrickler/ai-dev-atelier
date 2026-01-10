# My Agentic Development Setup

> Personal reference, not required for AI Dev Atelier.

---

## Why This Exists

AI coding tools have gotten good. Cursor, Windsurf, Claude Code: they understand your codebase, they write real code, they're genuinely useful. But they still assume you're sitting there, watching, iterating in real-time.

I wanted something I could hand work to and walk away. Multiple tasks running in parallel while I sleep. Quality gates that run automatically. An agent that updates its own Linear tickets and pings me when there's a PR to review.

The goal: queue a task from my phone, go to bed, wake up to a reviewed PR.

---

## The Stack

| Layer | Tool | Does |
|-------|------|------|
| Orchestration | [Vibora](https://github.com/knowsuchagency/vibora) | Kanban for agents. Tasks, worktrees, Linear sync. |
| Agent | [OpenCode](https://github.com/sst/opencode) + [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) | AI that writes code. Multi-model routing, LSP tools, specialist delegation. |
| Network | [Tailscale](https://tailscale.com) | Mesh VPN. SSH from anywhere. |
| Skills | [AI Dev Atelier](https://github.com/LukasStrickler/ai-dev-atelier) | Quality, docs, review, research capabilities. |

---

## Why These

### Vibora

Git worktrees are the unlock. Every task gets its own isolated checkout, so agents can't step on each other. Three tasks running in parallel means three separate folders. No merge conflicts, no coordination headaches.

Linear integration gives you proper lifecycle: backlog through in progress, review, done. The agent updates its own status as it works.

### OpenCode + oh-my-opencode

OpenCode is the runtime. oh-my-opencode is what makes it actually good.

Multi-model routing means fast models handle exploration while reasoning models tackle architecture. LSP tools like `lsp_goto_definition` replace grep with semantic navigation. And instead of one agent doing everything, the main agent delegates to specialists: a librarian for docs, an explorer for codebase navigation, a UI engineer for frontend.

Not a chat. A small team that coordinates internally.

### Tailscale

Server runs 24/7. Tailscale meshes my devices together (laptop, phone, whatever) without port forwarding or public exposure. SSH just works from anywhere.

### AI Dev Atelier

Skills fill gaps that agents don't have out of the box. Code-quality runs typecheck, lint, format before marking done. Code-review sends changes through CodeRabbit before you see them. Docs-check flags when code changes need doc updates. Search pulls from library docs, GitHub, the web. Research finds academic papers for architecture decisions.

Without skills you review raw output. With skills, output has already passed gates.

---

## Workflow

1. Queue a task from anywhere (phone, laptop, wherever)
2. Vibora creates a worktree and starts an agent
3. Agent works, skills trigger as needed
4. Task completes, notification sent
5. Review the PR when convenient

I usually queue two or three tasks before bed. By morning there are PRs ready, already linted and type-checked and reviewed.

---

## Setup

About thirty minutes:

```bash
# Tailscale (on your server)
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up

# Vibora
npx vibora@latest up

# OpenCode
curl -fsSL https://opencode.ai/install | bash

# AI Dev Atelier
git clone https://github.com/LukasStrickler/ai-dev-atelier.git ~/ai-dev-atelier
cp ~/ai-dev-atelier/.env.example ~/ai-dev-atelier/.env  # add API keys
bash ~/ai-dev-atelier/setup.sh && bash ~/ai-dev-atelier/install.sh

# oh-my-opencode
bunx oh-my-opencode install
```

Open Vibora, create a task, watch it work.

---

## Links

- [Vibora](https://github.com/knowsuchagency/vibora)
- [OpenCode](https://github.com/sst/opencode)
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- [Tailscale](https://tailscale.com)
- [AI Dev Atelier](https://github.com/LukasStrickler/ai-dev-atelier)

---

*January 2026*
