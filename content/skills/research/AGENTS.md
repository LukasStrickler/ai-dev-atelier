# RESEARCH SKILL

**Context:** Academic Research & Evidence Synthesis

## OVERVIEW
Conducts deep academic research using OpenAlex, Paper-search, and PDF extraction. Produces weighted "Evidence Cards" to ground technical decisions in peer-reviewed science and SOTA industry practices.

## STRUCTURE
```
research/
├── SKILL.md                 # Core prompt & triggers
├── scripts/                 # Automation (status, cleanup)
└── references/
    ├── templates/           # Artifact templates (cards, reports)
    ├── guides/              # Workflow & weighting guides
    └── examples/            # Reference outputs
```

## WHERE TO LOOK
| Component | Location | Purpose |
|-----------|----------|---------|
| **Templates** | `references/templates/` | Standard formats for cards/reports |
| **Workflows** | `references/guides/` | Step-by-step research protocols |
| **Logic** | `scripts/` | `ada::research` cli commands |
| **MCP Tools** | `SKILL.md` (Table) | Tool usage reference (OpenAlex, etc) |

## CONVENTIONS
- **Write-First**: MUST write an evidence card after reading 1-2 papers. Never stack contexts.
- **Evidence Cards**: Atomic units of research. 1 card = 1 cluster of similar findings.
- **Minimums**: Always 5+ cards + 1 "Conflicting View" card before reporting.
- **Weighting**: Academic citations > Industry Blogs > Random Tutorials.
- **Step 0**: Always starts with `codebase context` to frame the research question.

## ANTI-PATTERNS
- **Context Stacking**: Reading 3+ PDFs before writing anything (causes context loss).
- **Confirmation Bias**: Skipping the "Conflict-Seeking" phase.
- **Ghosting**: Stopping research without a final `research-report.md`.
- **Orphan Files**: Creating markdown files without updating `references.json`.
- **Raw Dumps**: Pasting raw PDF text into reports instead of synthesizing.
