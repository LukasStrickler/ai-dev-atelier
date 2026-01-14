---
name: research
description: "Conduct comprehensive academic research using OpenAlex, PDF extraction, paper search MCPs, and web search. Always produces comprehensive reports with 5+ evidence cards covering conflicting ideas and best approaches. Integrates academic papers (high weight) and non-academic sources (blogs, docs - lower weight but valuable for SOTA). Use when: (1) Researching software architecture patterns, (2) Finding academic papers on technical topics, (3) Conducting literature reviews, (4) Analyzing research papers for evidence-based decisions, (5) Building evidence cards from papers, (6) Finding related works and citations, or (7) When you need grounded, paper-backed technical recommendations. Triggers: research, find papers, literature review, evidence-based, academic research, compare approaches, what does research say, find studies on, search for papers about."
metadata:
  author: ai-dev-atelier
  version: "1.0"
---

# Research

Comprehensive academic research using OpenAlex, Paper-search, PDF extraction, and web search (Tavily). Always produces 5+ evidence cards covering conflicting ideas with weighted evidence synthesis.

## Quick Start

**Decision Tree:**
- **Need evidence-based decision?** → Use this skill
- **Quick lookup only?** → Use `search` skill instead
- **Already researched topic?** → Run `ada::research:list`

**Core Workflow:**
```
Step 0: Gather codebase context (ALWAYS FIRST)
Step 1: Formulate research question
Step 2: Comprehensive discovery (25+ sources)
Step 3: Create 5+ evidence cards incrementally
Critical Evaluation: Assess for codebase context
Step 4: Generate comprehensive report
```

**Mandatory Requirements:**
- ✅ Always 5+ evidence cards (broad coverage)
- ✅ Explicitly seek conflicting ideas
- ✅ Weight evidence (academic + real-world sources)
- ✅ Codebase context informs research question

## CRITICAL: Write-First Pattern

**MANDATORY:** After 1-2 tool calls:
1. Write/update evidence card immediately
2. Update `references.json` immediately
3. SAVE files before next tool calls
4. **CONTINUE** research (writing ≠ stopping)

**Why:** Context windows are limited. Writing preserves knowledge even if context resets.

**Failure Modes:**
- ❌ 3+ tool calls before writing → context overload
- ❌ Stopping after one card → must continue until complete
- ❌ Not updating `references.json` → loses tracking

## Workflow Summary

### Step 0: Codebase Context (ALWAYS FIRST)
Search codebase for: architecture, patterns, technologies, existing implementations.
Use context to inform research question.

### Step 1: Research Question
1. Create `.ada/data/research/{topic}/`
2. Create `research-question.md` using template
3. Create `references.json` with intent

### Step 2: Discovery (Target: 25+ Sources)

**Academic (OpenAlex, Paper-search):**
- Foundational: `get_top_cited_works` (min_citations: 50+)
- Recent SOTA: `search_works` (from_year: 2020+)
- Citation networks: `get_citation_network`

**Non-Academic (Tavily via search skill):**
- Blogs, docs, case studies in parallel
- Target: 5-10 relevant sources

**Conflict-Seeking:**
- "{approach A} vs {approach B}"
- "{approach} limitations"
- "alternative to {approach}"

### Step 3: Evidence Cards (5+ Required)
1. Read 1-2 papers/sources
2. Create/update evidence card
3. Update `references.json`
4. SAVE files
5. **REPEAT** until 5+ cards

**Grouping:** Same approach → same card. Different approach → new card.

### Critical Evaluation
After 5+ cards, before report:
1. Assess strengths/weaknesses
2. Evaluate for codebase context
3. Compare tradeoffs systematically
4. Identify best fit

### Step 4: Research Report
1. Re-read all evidence cards: `ada::research:show`
2. Re-read `research-question.md`
3. Create `research-report.md` using template
4. Include "Answer to Original Question" section

## Tools Quick Reference

| Tool | Purpose | When |
|------|---------|------|
| OpenAlex `get_top_cited_works` | Foundational papers | Discovery |
| OpenAlex `search_works` | Recent SOTA | Discovery |
| OpenAlex `get_citation_network` | Related work | Deep dive |
| Paper-search `search_arxiv` | Preprints | Recent work |
| PDF `read_pdf` | Extract content | Reading papers |
| Tavily (search skill) | Non-academic | Parallel discovery |
| zai-zread `search_doc` | Semantic issues/PRs/docs | Real-world implementations |
| `webfetch` | Direct URL reads | Lightweight docs/files |
| `look_at` | Interpret diagrams/images | PDFs/screenshots |

## Research Management Commands

```bash
ada::research:status              # Full status + next action
ada::research:status --next       # Just next action
ada::research:status --checkpoint # Verify state
ada::research:status --ref <name> # Load reference file

ada::research:list                # List all sessions
ada::research:show <session>      # Show evidence cards
ada::research:cleanup --all       # Clear PDFs
```

**Load References On-Demand:**
```bash
ada::research:status --ref workflow      # Workflow guide
ada::research:status --ref evidence-cards # Card guide
ada::research:status --ref template-card  # Card template
ada::research:status --ref weighting      # Weighting framework
```

## Key Tips (Reminders)

### Source Weighting
| Type | Weight | Examples |
|------|--------|----------|
| Academic (50+ citations) | High | Peer-reviewed papers |
| Academic (10-50 citations) | Medium | Recent SOTA |
| Real-world case studies | High | Company post-mortems |
| Blogs, tutorials | Medium-Low | Expert content |

### Evidence Card Essentials
- Key claims with page number citations
- Assumptions and conditions
- Tradeoffs and limitations
- Related/conflicting approaches
- Implementation resources

### Common Mistakes
- ❌ Reading 3+ papers before writing → Write after 1-2
- ❌ Not seeking conflicts → Explicitly search opposing views
- ❌ Skipping codebase context → Always start with Step 0
- ❌ Stopping at 3 cards → Must reach 5+ for broad coverage

## Directory Structure

```
.ada/
├── data/research/{topic}/
│   ├── research-question.md
│   ├── evidence-card-*.md
│   ├── research-report.md
│   └── references.json
└── temp/research/downloads/  # Temporary PDFs
```

## References

**Templates:**
- `references/templates/template-research-question.md`
- `references/templates/template-evidence-card.md`
- `references/templates/template-research-report.md`
- `references/templates/template-references.json`

**Guides:**
- `references/guides/guide-workflow.md` - Detailed workflows
- `references/guides/guide-evidence-cards.md` - Card creation
- `references/guides/guide-weighting.md` - Source weighting
- `references/guides/guide-critical-evaluation.md` - Evaluation framework
- `references/guides/guide-reports.md` - Report generation
- `references/guides/guide-adaptive-strategies.md` - Handling edge cases

**Examples:**
- `references/examples/example-evidence-card.md`
- `references/examples/example-research-report.md`
- `references/examples/example-workflows.md`

**Reference:**
- `references/reference/reference-tools.md` - Complete MCP documentation

## Integration

- **With search skill**: Use Tavily in parallel for non-academic sources
- **With docs-write**: Use evidence cards for documentation decisions
