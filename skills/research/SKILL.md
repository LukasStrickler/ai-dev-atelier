---
name: research
description: Conduct comprehensive academic research using OpenAlex, PDF extraction, paper search MCPs, and web search. Always produces comprehensive reports with 5+ evidence cards covering conflicting ideas and best approaches. Integrates academic papers (high weight) and non-academic sources (blogs, docs - lower weight but valuable for SOTA). Use when: (1) Researching software architecture patterns, (2) Finding academic papers on technical topics, (3) Conducting literature reviews, (4) Analyzing research papers for evidence-based decisions, (5) Building evidence cards from papers, (6) Finding related works and citations, or (7) When you need grounded, paper-backed technical recommendations. Triggers: "research", "find papers", "literature review", "evidence-based", "academic research", "compare approaches", "what does research say", "find studies on", "search for papers about".
---

# Research

Conduct comprehensive academic research using OpenAlex, PDF extraction, paper search MCPs, and web search (Tavily). Always produces comprehensive reports with 5+ evidence cards covering conflicting ideas and best approaches. Integrates academic papers (high weight) and non-academic sources (blogs, docs - lower weight but valuable for SOTA). PDF content goes directly to context - no intermediate file storage needed.

## Quick Start

**Purpose:** Conduct deep research to enable **informed decision-making** and **understanding complex topics**. This skill helps you weigh different ideas against each other to find the best solution for your specific codebase context.

**Workflow:**
1. **Step 0 (ALWAYS FIRST)**: Gather codebase context to understand current patterns, architecture, and technologies
2. **Step 1**: Write research question informed by codebase context using templates
3. **Step 2**: Comprehensive discovery - parallel search academic papers (OpenAlex, Paper-search) + non-academic sources (Tavily via search skill)
4. **Step 3**: Create 5+ evidence cards incrementally, explicitly seeking conflicting ideas and diverse approaches
5. **Critical Evaluation**: Assess each approach for your codebase context, weight evidence, compare tradeoffs
6. **Step 4**: Generate comprehensive report synthesizing all evidence cards, discussing conflicts, and providing evidence-based recommendations
7. **Use bash tools**: Use `ada::research:list`, `ada::research:show`, `ada::research:cleanup` for managing research sessions

**Key Requirements:**
- **Always produce comprehensive reports** - no quick lookups or focused research
- **Always target 5+ evidence cards** - ensures broad coverage of ideas for informed decision-making
- **Explicitly seek conflicting ideas** - not just best approaches, but diverse perspectives to understand tradeoffs
- **Integrate non-academic sources** - blogs, docs, tutorials (weighted lower than academic papers but valuable for SOTA)
- **Codebase context first** - understand current codebase before formulating research question
- **Weight evidence systematically** - use citations, recency, and authority to compare different ideas
- **Critical evaluation** - assess each approach for your specific context before making decisions

**See `references/guides/guide-workflow.md` for detailed step-by-step workflows.**
**See `references/guides/guide-decision-making.md` for research philosophy and decision-making framework.**
**See `references/guides/guide-weighting.md` for detailed weighting framework.**
**See `references/guides/guide-critical-evaluation.md` for detailed evaluation process.**

## CRITICAL: Write-First Pattern

**MANDATORY RULE:** After 1-2 tool calls maximum (searches, paper reads, etc.), you MUST:
1. Write or update evidence card immediately
2. Update `references.json` immediately (add paper, update approach, update evidence card metadata)
3. Save files before next tool calls
4. **CONTINUE** the research workflow - writing does NOT mean stopping

**Why:** Context windows are limited. Writing preserves knowledge even if context is compressed or reset. Evidence cards serve as persistent knowledge store that can be re-read when context resets.

**Pattern:** Do 1-2 tool calls → Write/update evidence card → Update `references.json` → SAVE → **CONTINUE** with next 1-2 tool calls → Write/update → Update `references.json` → SAVE → **REPEAT until research level is complete**

**Failure Modes:**
- Doing 3+ tool calls before writing causes context overload and information loss
- Stopping after writing one evidence card (must continue until research level is complete)
- Not updating evidence cards after each tool call

## Workflow: Comprehensive Research

**This skill always produces comprehensive reports. There are no quick lookups or focused research - all research follows this comprehensive workflow.**

### Step 0: Gather Codebase Context (ALWAYS FIRST)

**Purpose:** Understand current codebase before formulating research question to ensure research is relevant and actionable.

**Workflow:**
1. **Search codebase** for relevant patterns, files, architecture
2. **Document codebase context**: Architecture/patterns, technologies/frameworks, existing implementations, specific files/areas
3. **Use context to inform research question** (see Step 1)

### Step 1: Formulate Research Question

**Workflow:**
1. Create research directory: `.ada/data/research/{topic}/` (sanitize topic for directory name)
2. Create `research-question.md` using `references/templates/template-research-question.md` (include codebase context from Step 0, see `references/examples/example-research-question.md` for example)
3. Create/update `references.json` using `references/templates/template-references.json` with intent
4. Reference this intent throughout research process

### Step 2: Comprehensive Discovery (Target: 25+ Sources)

**Goal:** Find 25+ relevant academic papers and non-academic sources covering diverse and potentially conflicting ideas.

**Academic Sources** (OpenAlex, Paper-search MCP):
- **Highly cited foundational papers**: `get_top_cited_works` (OpenAlex, `min_citations: 50+`, reduce to `10+` if insufficient)
- **Recent SOTA**: `search_works` (OpenAlex, `from_publication_year: 2020+`) + Paper-search MCP (`search_arxiv`, `search_pubmed`)
- **Citation networks**: `get_citation_network` (OpenAlex, depth: 1-2)
- **Target**: 15-20 relevant academic papers (mix of foundational + recent SOTA + less cited but relevant)

**Non-Academic Sources** (Tavily via search skill):
- **Blog posts, documentation, case studies**: Search for "{topic} best practices 2024", "{topic} implementation guide"
- **Run in parallel** with academic searches
- **Target**: 5-10 relevant non-academic sources

**Conflict-Seeking Strategies:**
- Explicitly search for opposing viewpoints ("{approach A} vs {approach B}")
- Search for critiques and limitations ("{approach} limitations", "{approach} problems")
- Find alternative approaches ("alternative to {approach}")

**Source Weighting:** See `references/weighting-guide.md` for detailed framework.

**Iterative Query Refinement** (IM-RAG): Query → Retrieve → Assess → Refine → Repeat. ⚠️ **REMINDER:** Write evidence cards after each 1-2 papers/sources (don't wait for all queries to complete).

### Step 3: Incremental Evidence Card Creation (5+ Cards Required)

**Goal:** Create 5+ evidence cards, each synthesizing 1-2 papers/sources, covering diverse and potentially conflicting approaches.

**Workflow:**
1. **Read 1-2 papers/sources**: Extract key claims, supporting evidence, assumptions, limitations, and failure modes
2. **Create/Update evidence card**: Use `references/templates/template-evidence-card.md` (see `references/examples/example-evidence-card.md` for example)
   - **Grouping logic**: Papers/sources supporting the same approach → same evidence card. Conflicting/different approaches → separate evidence cards
   - **Include non-academic sources**: Add with source type and weighting (academic paper vs blog post vs documentation)
3. **Update `references.json`**: Add paper/source, approach, evidence card metadata
4. **SAVE files**: Before reading the next paper/source
5. **Repeat**: Continue until 5+ evidence cards are created, covering a broad overview of ideas

**See `references/guides/guide-evidence-cards.md` for detailed instructions.**

### Critical Evaluation Phase

**When to Perform:** After Step 3 (creating 5+ evidence cards) and before Step 4 (generating report).

**Process:**
1. **Assess strengths** of each approach (from evidence cards)
2. **Identify weaknesses and limitations** (from evidence cards)
3. **Evaluate for your codebase context** (architecture fit, team expertise, infrastructure, constraints)
4. **Compare tradeoffs systematically** (create comparison matrix, weight evidence)
5. **Identify best fit** (weight evidence + codebase fit + constraints + tradeoffs)

**See `references/guides/guide-critical-evaluation.md` for detailed evaluation framework.**

### Step 4: Generate Comprehensive Research Report

**Goal:** Synthesize all findings into a comprehensive report, comparing approaches, providing recommendations, and explicitly answering the original research question.

**Workflow:**
1. **Re-read all evidence cards**: Use `ada::research:show <session-name>` to read evidence cards (they are the source of truth)
2. **Re-read `research-question.md`**: To recall original intent
3. **Create `research-report.md`**: Use `references/templates/template-research-report.md` (see `references/examples/example-research-report.md` for example)
4. **Synthesize findings**: Compare approaches objectively, highlight benefits and negatives, and provide evidence-based recommendations
5. **Include "Answer to Original Question" section**: Directly address the research question
6. **Update `references.json`**: Set `research_report: "research-report.md"`

**See `references/guides/guide-reports.md` for detailed instructions.**

## Tools Available

### Required MCPs

**OpenAlex MCP** (Required)
- **Paper discovery**: `search_works`, `search_by_topic`, `get_top_cited_works`
- **Citation networks**: `get_work_citations`, `get_work_references`, `get_related_works`, `get_citation_network`
- **Paper details**: `get_work` for complete metadata

**Paper-search MCP** (Required)
- **Search**: `search_papers`, `search_arxiv`, `search_pubmed`, `search_crossref`
- **Download**: `download_paper` for automated PDF download
- **Use alongside OpenAlex**: Run parallel searches with both MCPs for comprehensive coverage

**PDF Extractor MCP** (Required)
- **`read_pdf`**: Extract content directly to context (no file saving needed)
  - Parameters: `sources` (path/url, pages), `include_full_text`, `include_metadata`

### Integration Tools

**Search Skill** (Integration)
- **Use search skill** (Tavily, Context7) to find implementation resources: packages, blogs, examples, tutorials
- **When to use:** In parallel with academic paper research during comprehensive discovery

**See `references/reference/reference-tools.md` for complete tool documentation.**

## Research Management Scripts

**CRITICAL: Always use bash tools correctly** - These scripts are essential for managing research workflow.

**When to use bash tools:**
- **Before starting research**: Use `ada::research:list` to check if topic already researched
- **During research**: Use `ada::research:status` to get current state and next action
- **After context reset**: Use `ada::research:status --next` to resume research
- **When stuck**: Use `ada::research:status --ref <file>` to load needed reference files
- **Before generating report**: Use `ada::research:show` to re-read all evidence cards
- **After research complete**: Use `ada::research:cleanup` to clear temporary PDFs

## Research Status & Direction

**CRITICAL: Use `ada::research:status` to manage context and get direction**

### Quick Status Check

```bash
ada::research:status              # Full status with progress, metrics, next actions
ada::research:status --next       # Just next action (for quick direction)
ada::research:status --checkpoint # Verify state and check for issues
ada::research:status --summary    # Brief one-line status summary
```

**What it shows:**
- Current step and progress percentage
- Completed steps and in-progress work
- Next actions with specific instructions
- File status (what exists, what's missing)
- Metrics (papers, evidence cards, coverage)
- Issues/warnings if any
- Suggested next command

### Load Reference Files On-Demand

**Instead of loading all reference files into context, load only what you need:**

```bash
ada::research:status --ref workflow          # Load workflow guide
ada::research:status --ref evidence-cards    # Load evidence card guide
ada::research:status --ref template-card     # Load evidence card template
ada::research:status --ref example-workflows # Load workflow examples
ada::research:status --ref weighting        # Load weighting framework
ada::research:status --ref reports          # Load report generation guide
```

**Available references:**
- `workflow`, `evidence-cards`, `reports`, `weighting`, `critical-evaluation`, `decision-making`, `adaptive-strategies`
- `template-question`, `template-card`, `template-report`, `template-json`
- `example-question`, `example-card`, `example-report`, `example-workflows`
- `tools`

### When to Use Status Command

- **Before starting**: Check if research exists, get initial direction
- **After context reset**: Get current state and next action to resume seamlessly
- **When stuck**: Get clear direction on what to do next
- **Before report**: Verify all steps complete, load report guide
- **During research**: Check progress and ensure you're on track

**Benefits:**
- **Prevents context overload**: Load only what's needed, when needed (70-80% context reduction)
- **Provides clear direction**: Know exactly what to do next without reading through guides
- **Enables state recovery**: Resume after context reset without losing progress
- **On-demand reference loading**: Load guides only when needed, not all at once

### `ada::research:status <session-name>` - Research Status

```bash
ada::research:status                          # Auto-detect session or show most recent
ada::research:status microservices-20250115-103000  # Specific session
ada::research:status --next                   # Show only next action
ada::research:status --checkpoint             # Verify state and check for issues
ada::research:status --ref workflow           # Load workflow guide
```

**What it shows:** Current step, progress, completed work, next actions, file status, metrics, issues, and suggested commands.

### `ada::research:list` - List Research Sessions

```bash
ada::research:list                    # List all research sessions
ada::research:list --topic "consensus" # Filter by topic
```

**What it shows:** All research sessions with topic, creation date, paper count, approaches, evidence cards, report status, and current step status.

### `ada::research:show <session-name>` - Show Research Session

```bash
ada::research:show microservices-20250115-103000              # Show all evidence cards and report
ada::research:show microservices-20250115-103000 --approach approach-1  # Show specific approach
```

**What it shows:** Status header with current step, all evidence cards (full content), research report (if completed), approaches summary, PDF status.

### `ada::research:cleanup` - Clean Up PDF Files

```bash
ada::research:cleanup --all                              # Delete all PDFs
ada::research:cleanup --older-than 7                     # Delete PDFs older than 7 days
ada::research:cleanup --topic "microservices"             # Delete PDFs for specific topic
```

**What it does:** Removes PDFs from `.ada/temp/research/downloads/`, preserves evidence cards/reports/`references.json`, optionally updates `references.json` to mark PDFs as cleared.

## Example: Architecture Decision

**Task**: "Research distributed consensus algorithms for our distributed system"

**Process:**
1. **Step 0**: Gather codebase context (Node.js microservices, Kubernetes, need consensus)
2. **Step 1**: Research question: "Which consensus algorithm fits our Node.js microservices with crash-fault tolerance?"
3. **Step 2**: Discovery (25+ sources) - Academic: Paxos, Raft, PBFT. Non-academic: Implementation guides
4. **Step 3**: Evidence cards (5+ cards) - Raft, Paxos, PBFT, alternatives, conflicts
5. **Critical Evaluation**: Raft fits Node.js, team can understand, meets requirements
6. **Step 4**: Report recommends Raft with rationale: Strong evidence + codebase fit + team expertise

**Outcome**: Evidence-based decision with clear rationale tied to codebase context.

**See `references/examples/example-workflows.md` for complete examples with detailed decision-making processes.**

## Adaptive Research Strategies

Research scenarios vary. Use adaptive techniques to handle different situations:

- **When research is too narrow**: Broaden queries, search for critiques, explore related fields
- **When too many conflicts**: Focus on specific aspects, identify context-dependent differences
- **When insufficient evidence**: Expand search terms, use citation networks, search non-academic sources
- **When codebase constraints conflict**: Identify compromise solutions, search for adaptations
- **When evidence quality varies**: Weight evidence systematically, prioritize high-weight sources

**See `references/guides/guide-adaptive-strategies.md` for detailed strategies and examples.**

## Directory Structure

```
.ada/
├── data/research/
│   └── {topic}/
│       ├── research-question.md
│       ├── evidence-card-approach-1.md
│       ├── evidence-card-approach-2.md
│       ├── research-report.md
│       └── references.json
└── temp/research/
    └── downloads/  # Temporary PDFs (can be cleared)
        └── {doi-or-id}.pdf
```

## Templates and Guides

**Templates (use in this order):**
1. `references/templates/template-research-question.md` → Create `research-question.md` (Step 0)
2. `references/templates/template-references.json` → Create `references.json` (Step 0)
3. `references/templates/template-evidence-card.md` → Create evidence cards (Step 3, incrementally)
4. `references/templates/template-research-report.md` → Create report (Step 4)

**Guides (reference when needed):**
- `references/guides/guide-workflow.md` → Detailed step-by-step workflows (includes write-first pattern)
- `references/guides/guide-decision-making.md` → Research philosophy and decision-making framework
- `references/guides/guide-weighting.md` → How to weight evidence (academic vs real-world sources)
- `references/guides/guide-critical-evaluation.md` → How to evaluate approaches for codebase context
- `references/guides/guide-evidence-cards.md` → How to create evidence cards
- `references/guides/guide-reports.md` → How to create reports
- `references/guides/guide-adaptive-strategies.md` → How to handle different research scenarios

**Examples (reference for "what good looks like"):**
- `references/examples/example-research-question.md` → Complete filled-in research question example
- `references/examples/example-evidence-card.md` → Complete filled-in evidence card example
- `references/examples/example-research-report.md` → Complete filled-in research report example
- `references/examples/example-workflows.md` → Complete end-to-end research workflow examples

**Reference:**
- `references/reference/reference-tools.md` → Complete MCP tool documentation

**CRITICAL: Adherence Statement**

**Agents MUST strictly adhere to the definitions, workflows, and guidelines provided in these referenced files for conducting good research.** This includes:
- Following the write-first pattern from `guides/guide-workflow.md` (mandatory, not optional)
- Using templates exactly as specified in `templates/` directory
- Weighting evidence according to `guides/guide-weighting.md` framework
- Creating 5+ evidence cards covering diverse and conflicting approaches
- Performing critical evaluation using `guides/guide-critical-evaluation.md` framework
- Generating comprehensive reports using `templates/template-research-report.md`
- Following all workflows, checkpoints, and best practices documented in the guides

**Deviating from these guidelines will result in incomplete or low-quality research.**

## Integration with Other Skills

**With search**: Use search skill (Tavily) in parallel with academic research to find non-academic sources (blogs, docs, tutorials). Find implementation resources (packages, blogs, examples). Add to evidence cards with source type and weighting.

**With docs-write**: After completing research. Use evidence cards for documentation decisions, research reports for architecture decisions, cite papers in documentation, reference implementation resources.

## Best Practices

**General**: Always produce comprehensive reports, target 5+ evidence cards for broad coverage, explicitly seek conflicting ideas, use parallel execution across OpenAlex, Paper-search MCPs, and Tavily (search skill), cross-reference sources, always mix foundational (highly cited) + recent SOTA papers + non-academic sources.

**Codebase context**: Always gather codebase context before formulating research question.

**Performance**: Write after 1-2 papers/sources, parallel searches across all MCPs, extract PDFs only when needed.

**Quality**: All claims cited (page numbers), include benefits and limitations, synthesize insights, verify citations, cross-reference evidence cards, apply findings to task.

**Source weighting**: Academic papers (high weight), real-world sources (high weight - case studies, company blogs), non-academic sources (medium/low weight but valuable for SOTA). See `references/guides/guide-weighting.md` for detailed framework.

**Conflict coverage**: Explicitly seek and document conflicting ideas, not just best approaches.

**Common mistakes**: Reading 3+ papers before writing → Write after 1-2 papers. Delayed JSON updates → Update after each write. Re-reading papers for reports → Re-read evidence cards. Skipping checkpoints → Verify files saved. Treating write-first as optional → Write-first is MANDATORY. Not gathering codebase context → Always start with Step 0. Not seeking conflicts → Explicitly search for opposing viewpoints. Not reaching 5+ evidence cards → Continue until broad coverage achieved.

## Evidence-Based Methodology

This skill follows systematic review best practices: Intent tracking via `research-question.md` and `references.json`, incremental synthesis (write as you read), evidence-based claims (quotes with page numbers), balanced discovery (foundational + recent papers), comparative analysis, machine-actionable metadata, workflow checkpoints, iterative refinement, structured reporting, objective metrics, implementation bridge. **Key principle**: Write to preserve, query to discover, write immediately, update incrementally, synthesize to answer.

## Reference Files Summary

| File | Purpose |
|------|---------|
| `references/templates/template-research-question.md` | Template for defining research questions with codebase context |
| `references/templates/template-references.json` | JSON template for tracking research session metadata |
| `references/templates/template-evidence-card.md` | Template for creating evidence cards synthesizing multiple sources |
| `references/templates/template-research-report.md` | Template for generating comprehensive research reports |
| `references/guides/guide-workflow.md` | Detailed step-by-step research workflow including write-first pattern |
| `references/guides/guide-decision-making.md` | Research philosophy and framework for evidence-based decision-making |
| `references/guides/guide-weighting.md` | Framework for weighting academic vs real-world vs non-academic sources |
| `references/guides/guide-critical-evaluation.md` | Process for evaluating approaches against codebase context and requirements |
| `references/guides/guide-evidence-cards.md` | Instructions for creating effective evidence cards |
| `references/guides/guide-reports.md` | Instructions for generating comprehensive research reports |
| `references/guides/guide-adaptive-strategies.md` | Techniques for handling different research scenarios (narrow, conflicts, etc.) |
| `references/examples/example-research-question.md` | Complete filled-in example of a research question |
| `references/examples/example-evidence-card.md` | Complete filled-in example of an evidence card |
| `references/examples/example-research-report.md` | Complete filled-in example of a research report |
| `references/examples/example-workflows.md` | Complete end-to-end examples of research workflows and decision-making |
| `references/reference/reference-tools.md` | Complete documentation for all MCP tools used in research |
