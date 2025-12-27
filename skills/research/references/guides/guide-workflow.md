# Research Workflow Guide

Detailed step-by-step workflow for comprehensive research, including codebase context gathering, dual-source discovery, conflict-seeking strategies, and approach grouping methodology.

## Write-First Pattern (MANDATORY)

**CRITICAL RULE:** After reading 1-2 papers maximum, you MUST:
1. Write or update evidence card immediately
2. Update `references.json` immediately (add paper, update approach, update evidence card metadata)
3. Save files before reading next paper

**Why:** Context windows are limited. Writing preserves knowledge even if context is compressed or reset. Evidence cards serve as persistent knowledge store that can be re-read when context resets.

**Pattern (MANDATORY):**
```
Read paper/source 1 → Extract content → Write evidence card → Update references.json → SAVE
Read paper/source 2 → Check alignment → Update/create evidence card → Update references.json → SAVE
Read paper/source 3 → Check alignment → Update/create evidence card → Update references.json → SAVE
Continue: Never read more than 2 papers/sources before writing
```

**Context Checkpoints (After each evidence card write):**
1. Verify evidence card file exists and is saved
2. Verify `references.json` is updated with:
   - Paper added to `papers` array
   - Approach added/updated in `approaches` array
   - Evidence card added/updated in `evidence_cards` array
   - Paper linked to approach via `approach` field
   - `updated` timestamp updated
3. Optionally re-read evidence card to verify content before continuing
4. Continue to next paper (maximum 2 papers before next write)

**Failure Mode:** Reading 3+ papers/sources before writing causes context overload and information loss. You will forget details from earlier papers/sources and lose the ability to synthesize effectively.

**REMINDER:** This pattern applies to ALL comprehensive research. Write-first is not optional - it is essential for preventing context overload.

## Comprehensive Research Workflow

**This skill always produces comprehensive reports. Follow this workflow for all research.**

### Step 0: Gather Codebase Context (ALWAYS FIRST)

**Goal:** Understand current codebase before formulating research question to ensure research is relevant and actionable.

**Workflow:**
1. **Search codebase** for relevant patterns, files, architecture:
   - Use codebase search to find files related to research topic
   - Identify technologies, frameworks, patterns currently used
   - Understand existing implementations
   - Note specific areas where research applies

2. **Document codebase context**:
   - Current architecture/patterns
   - Technologies/frameworks in use
   - Existing implementations
   - Specific files/areas relevant to research

3. **Use context to inform research question** (see Step 1)

### Step 1: Formulate Research Question (Informed by Codebase Context)

**Goal:** Write research question informed by codebase context.

**Workflow:**
1. Create research directory: `.ada/data/research/{topic}/`
2. Create `research-question.md` from template:
   - Include codebase context section (from Step 0)
   - Research question/problem statement (informed by codebase)
   - Context/background (reference codebase context)
   - Desired outcome
   - Constraints/requirements (from codebase)
3. Create/update `references.json` with:
   - `research_question`: The original question
   - `original_intent`: Object with `problem`, `desired_outcome`, `constraints`
   - `codebase_context`: Summary of codebase context gathered
4. **Reference this intent throughout research**

### Step 2: Comprehensive Discovery (Target: 25+ Sources)

**Goal:** Find 25+ relevant academic papers and non-academic sources covering diverse and potentially conflicting ideas, as well as best approaches.

**Parallel Dual-Source Discovery:**

**Academic Sources** (OpenAlex, Paper-search MCP):
1. **Highly cited foundational papers**: `get_top_cited_works` (OpenAlex) for influential papers (`min_citations: 50+`). If insufficient, reduce to `min_citations: 10+` or remove filter.
2. **Recent/bleeding edge academic**: `search_works` (OpenAlex) with `from_publication_year: 2020+` and `sort: "publication_year"` + Paper-search MCP (`search_arxiv`, `search_pubmed`) for latest SOTA research.
3. **Citation networks**: `get_citation_network` (OpenAlex) for key papers (depth: 1-2).
4. **Multiple queries**: Run searches in parallel with synonyms (`per_page: 25-50` for academic).
5. **Expand with related works**: For top results, use `get_related_works`, `get_work_citations`, `get_work_references`.
6. **Target**: 15-20 relevant academic papers (mix of highly cited foundational + recent SOTA advances + less cited but relevant papers if needed).

**Non-Academic Sources** (Tavily via search skill):
1. **Blog posts**: Search for "{topic} best practices 2024", "{topic} implementation guide", "{topic} tutorial"
2. **Documentation**: Official docs, tutorials, guides
3. **Case studies**: Real-world examples and usage
4. **Run in parallel** with academic searches
5. **Target**: 5-10 relevant non-academic sources

**Conflict-Seeking Strategies:**
- Explicitly search for opposing viewpoints ("{approach A} vs {approach B}")
- Search for critiques and limitations ("{approach} limitations", "{approach} problems")
- Find alternative approaches ("alternative to {approach}", "{approach} vs {alternative}")
- Target 5+ evidence cards covering spectrum of approaches (best practices to conflicts)

**Source Weighting:**
- **Academic papers** (high weight): Highly cited, peer-reviewed, foundational
- **Non-academic sources** (lower weight): Blogs, docs, tutorials - may be more SOTA or up-to-date but less authoritative

**Iterative Query Refinement** (IM-RAG): Query → Retrieve → Assess → Refine → Repeat. Assess gaps, refine with synonyms/related terms, continue until sufficient coverage (typically 2-3 rounds). ⚠️ **REMINDER:** Write evidence cards after each 1-2 papers/sources (don't wait for all queries to complete).

### Step 3: Incremental Evidence Card Creation (5+ Cards Required)

**Goal:** Create 5+ evidence cards, each synthesizing 1-2 papers/sources, covering diverse and potentially conflicting approaches.

**MANDATORY - Write after each 1-2 papers/sources:**
   
   **REMINDER: Never read more than 2 papers before writing an evidence card and updating references.json**
   
   - **Read paper/source 1:**
     - Download PDF to `.ada/temp/research/downloads/{doi-or-id}.pdf` (if academic paper)
     - Use `read_pdf` to extract content directly to context (if academic paper)
     - Or extract content from non-academic source (blog, doc, tutorial)
     - Identify approach this paper/source supports
     - **Write evidence card immediately** → Save to `.ada/data/research/{topic}/evidence-card-{approach}.md`
     - **Include source type and weighting** (academic paper vs blog post vs documentation)
     - **Update `references.json` immediately:**
       - Add paper/source to `papers` array (with metadata: id, title, authors, year, doi, urls, approach, download_date, source_type, weighting)
       - Add approach to `approaches` array (with id, name, evidence_card filename, papers array)
       - Add evidence card to `evidence_cards` array (with id, file, approach_name, papers_count)
       - Update `updated` timestamp
     - **SAVE `references.json`**
     - **Context Checkpoint:** Verify evidence card and `references.json` are saved before continuing
   
   - **Read paper/source 2:**
     - Extract content with `read_pdf` (if academic) or from source (if non-academic)
     - **Check existing evidence cards** - Does this paper/source align with existing approach?
     - **If aligns with existing approach:**
       - **Update existing evidence card** → Add paper/source, synthesize claims, add evidence
       - **Include source type and weighting**
       - **Update `references.json`:**
         - Add paper/source to `papers` array
         - Update approach in `approaches` array (add paper ID to papers array)
         - Update evidence card in `evidence_cards` array (increment papers_count)
         - Update `updated` timestamp
     - **If new approach:**
       - **Create new evidence card** → Save immediately
       - **Include source type and weighting**
       - **Update `references.json`:**
         - Add paper/source to `papers` array
         - Add new approach to `approaches` array
         - Add new evidence card to `evidence_cards` array
         - Update `updated` timestamp
     - **SAVE `references.json`**
     - **Context Checkpoint:** Verify files are saved before continuing
   
   - **Continue incrementally:** 
     - Read paper/source 3 → Check alignment → Update/create evidence card → Update `references.json` → SAVE → Context Checkpoint
     - Read paper/source 4 → Check alignment → Update/create evidence card → Update `references.json` → SAVE → Context Checkpoint
     - **Key:** Write cards as you read (after each 1-2 papers/sources), see alignment early, make grouping decisions in real-time
     - **Never read 3+ papers/sources before writing**
     - **Continue until 5+ evidence cards created**, covering diverse and potentially conflicting approaches

4. **Search for implementation resources** (after or alongside academic research):
   - Use search skill (Tavily, Context7) to find:
     - Packages/libraries implementing each approach
     - Blog posts/tutorials about implementation
     - Code examples and repositories
     - Real-world usage examples
   - Add implementation resources to evidence cards (see `templates/template-evidence-card.md`)

5. **Update evidence cards with implementation resources:**
   - For each evidence card, add implementation resources found
   - **Update `references.json`** after each evidence card update:
     - Update evidence card metadata if needed
     - Update `updated` timestamp
   - **SAVE `references.json`**

### Step 3.5: Critical Evaluation (After Evidence Cards, Before Report)

**Goal:** Critically evaluate each approach to determine which best fits your codebase context and requirements. This transforms research into actionable decisions.

**When to Perform:** After creating 5+ evidence cards (Step 3) and before generating report (Step 4).

**Evaluation Framework:**

1. **Assess Strengths of Each Approach:**
   - What does this approach do well? (from evidence cards)
   - What evidence supports its effectiveness? (citations, multiple sources)
   - What contexts does it work best in? (from evidence cards' "When to Use" sections)

2. **Identify Weaknesses and Limitations:**
   - What are the limitations? (from evidence cards' "Tradeoffs/Limitations")
   - When does this approach fail? (from "Failure Modes")
   - What tradeoffs does it require? (from "Tradeoffs")

3. **Evaluate for Your Codebase Context:**
   - Does this fit your codebase architecture? (from Step 0)
   - Can your team implement this? (team expertise, complexity)
   - Do you have required infrastructure? (dependencies, infrastructure needs)
   - Does it meet your constraints? (performance, scalability, cost)
   - Is it compatible with existing technologies? (from codebase context)

4. **Compare Tradeoffs Systematically:**
   - Create comparison matrix (see SKILL.md for template)
   - Weight evidence for each criterion (use weighting framework)
   - Identify which approach fits best for your context

5. **Identify Best Fit:**
   - Weight evidence for each approach
   - Assess codebase fit
   - Evaluate constraints
   - Consider tradeoffs
   - Make preliminary recommendation

**Output:** Evaluation notes that inform report generation and recommendations.

### Step 4: Generate Comprehensive Research Report

**Goal:** Synthesize all findings into a comprehensive report, comparing approaches (including conflicts), providing recommendations, and explicitly answering the original research question.

**Workflow:**

1. **Re-read all evidence cards (MANDATORY - Don't re-read papers)**
   - **Use `ada::research:show <session-name>` to read all evidence cards efficiently**
   - **Re-read each evidence card** for the research session (evidence cards contain all necessary information)
   - Note key claims, benefits, negatives for each approach
   - Review implementation resources found
   - Identify patterns and conflicts
   - **Why re-read evidence cards:** They are the source of truth. Re-reading papers causes context overload.

2. **Re-read original research question (MANDATORY)**
   - **Re-read `research-question.md`** to recall original intent
   - Note original problem, desired outcome, constraints
   - Review codebase context section
   - **Why re-read:** Ensures report answers the original question, not a modified understanding

3. **Create report structure**
   - Use template: `templates/template-research-report.md`
   - Save to: `research-report.md` in same directory

4. **Write sections:**
   - **Executive Summary**: 2-3 paragraphs synthesizing findings (emphasize 5+ evidence cards and conflict discussion)
   - **Research Methodology**: Document search strategy, selection, grouping (including non-academic sources)
   - **Approaches Compared**: One section per evidence card (including implementation resources)
   - **Comparative Analysis**: Tables comparing strengths, limitations (in context of original problem)
   - **Evidence Summary**: Supporting, conflicting (explicitly discuss conflicts), gaps
   - **Implementation Resources**: Packages, guides, examples per approach
   - **Recommendations**: Primary, alternatives, implementation (tied to original problem and codebase context)
   - **Answer to Original Question**: Explicitly address original research question with evidence

5. **Update references.json (MANDATORY)**
   - Add `research_report: "research-report.md"` field
   - Update `updated` timestamp
   - **SAVE `references.json`**

See `guides/guide-reports.md` for detailed instructions.

## Multi-Round Retrieval Strategy (IM-RAG Inspired)

**Goal:** Use iterative query refinement to achieve comprehensive coverage through multiple rounds of discovery.

**Pattern:** Query → Retrieve → Assess → Refine → Retrieve → Assess → Continue

**REMINDER:** Write evidence cards after each 1-2 papers/sources (don't wait for all rounds to complete). Maintain write-first pattern throughout.

**Round 1: Initial Discovery**
- **Query:** Main research question keywords
- **Retrieve:** 10-15 papers using initial search strategies
- **Assess:** What aspects are covered? What's missing?
  - Review abstracts and metadata
  - Identify gaps in coverage
  - Note which sub-topics need more papers
- **Write evidence cards** for papers read so far (if any) → Update `references.json` → SAVE

**Round 2: Gap Filling**
- **Query:** Refined queries for missing aspects
  - Use synonyms, related terms, specific sub-topics
  - Target identified gaps from Round 1
- **Retrieve:** 5-10 additional papers
- **Assess:** Coverage improved? Still missing anything?
  - Check if gaps are filled
  - Identify any remaining gaps
- **Write evidence cards** for papers read → Update `references.json` → SAVE

**Round 3: Deep Dive** (if needed)
- **Query:** Specific sub-topics or edge cases
  - Very specific queries for remaining gaps
  - Alternative phrasings or domain-specific terms
- **Retrieve:** 3-5 specialized papers
- **Assess:** Comprehensive coverage achieved?
  - Verify all aspects of research question are covered
  - Check if additional rounds needed
- **Write evidence cards** for papers read → Update `references.json` → SAVE

**Example (Distributed Consensus Research):**

**Round 1: Initial Discovery**
- Query: "distributed consensus algorithms"
- Retrieve: 15 papers (Paxos, Raft, PBFT variants)
- Assess: Missing Byzantine fault tolerance details, missing recent optimizations
- **Write evidence cards** for 2 papers read → Update `references.json` → SAVE

**Round 2: Gap Filling**
- Query: "Byzantine fault tolerance consensus"
- Retrieve: 5 papers (PBFT, BFT variants)
- Assess: Byzantine coverage improved, still missing recent optimizations
- **Write evidence cards** for 2 more papers → Update `references.json` → SAVE

**Round 3: Deep Dive**
- Query: "consensus algorithm optimizations 2020"
- Retrieve: 3 papers (recent performance improvements)
- Assess: Comprehensive coverage achieved
- **Write evidence cards** for remaining papers → Update `references.json` → SAVE

**Total:** 25+ sources (20 academic papers + 5 non-academic sources) discovered through iterative refinement, evidence cards written incrementally

**Context Management:**
- After each round: Write evidence cards for papers/sources read (don't wait for all rounds)
- Update `references.json` incrementally after each evidence card write
- Maximum 2 papers/sources before writing (maintain write-first pattern)
- Continue rounds until comprehensive coverage (25+ sources, 5+ evidence cards) or diminishing returns

## Approach Grouping

**Goal:** Group papers by approach/methodology to enable comparative analysis.

**Methodology:**

1. **Read abstracts and metadata**
   - Use `get_work` for each selected paper
   - Read abstracts to understand approach
   - Check topics and keywords

2. **Identify approaches**
   - Look for:
     - Different methodologies (e.g., Paxos vs Raft)
     - Different architectures (e.g., service mesh vs API gateway)
     - Different techniques (e.g., synchronous vs asynchronous)
     - **Conflicting solutions to same problem** (explicitly seek these)
     - **Opposing viewpoints** (not just best practices, but diverse perspectives)
   - Papers/sources supporting same approach → same group
   - Papers/sources with different approaches → separate groups
   - **Conflicting approaches** → separate groups (this is valuable, not a problem)

3. **Group papers**
   - **Approach 1**: Papers supporting approach A (e.g., "Paxos-based consensus")
   - **Approach 2**: Papers supporting approach B (e.g., "Raft consensus")
   - **Approach 3**: Papers supporting approach C (e.g., "PBFT consensus")
   - **Uncategorized**: Papers that don't fit clearly (review later)

4. **Validate groupings**
   - Check if papers in same group actually support same approach
   - Identify any papers that belong to multiple approaches (edge cases)
   - Refine groups as needed

5. **Name approaches**
   - Use descriptive names: "Paxos-based Consensus", "Raft Consensus", "Service Mesh Pattern"
   - Or numbered: "Approach 1: Synchronous Replication", "Approach 2: Asynchronous Replication"

**Example Grouping:**

**Topic:** Distributed consensus algorithms

- **Approach 1: Paxos-based Consensus**
  - Paper A: "The Part-Time Parliament" (foundational)
  - Paper B: "Paxos Made Simple" (simplification)
  - Paper C: "Multi-Paxos" (extension)

- **Approach 2: Raft Consensus**
  - Paper D: "In Search of an Understandable Consensus Algorithm"
  - Paper E: "Raft Refloated" (improvements)

- **Approach 3: PBFT Consensus**
  - Paper F: "Practical Byzantine Fault Tolerance"
  - Paper G: "PBFT Optimizations"

## Incremental Evidence Card Creation (5+ Cards Required)

**Goal:** Create evidence cards incrementally as papers are read, not in batch.

**CRITICAL: MANDATORY Write-First Pattern**

**REMINDER: Never read more than 2 papers before writing an evidence card and updating references.json**

**Process (Incremental Write-First):**

**This process is detailed in Step 3 above. Key points:**
- Read 1-2 papers/sources → Write evidence card → Update `references.json` → SAVE
- Include source type and weighting (academic vs non-academic)
- Continue until 5+ evidence cards created, covering diverse and potentially conflicting approaches
- Never read 3+ papers/sources before writing

**This process is detailed in Step 3 above. Implementation resources are added to evidence cards as they are found.**

## Approach Grouping Methodology

### When to Group

Group papers when:
- Papers propose different solutions to the same problem
- Papers use different methodologies or techniques
- Papers have conflicting findings or recommendations
- Papers represent different architectural patterns
- Papers come from different research traditions

### How to Identify Approaches

1. **Read abstracts and introductions**
   - Look for problem statements
   - Identify proposed solutions
   - Note methodology differences

2. **Check keywords and topics**
   - Papers with similar topics may use different approaches
   - Look for distinguishing characteristics

3. **Review methodology sections**
   - Different methodologies → different approaches
   - Similar methodologies → same approach

4. **Check results and conclusions**
   - Different findings → may indicate different approaches
   - Similar findings → may support same approach

### Grouping Strategies

**Strategy 1: By Methodology**
- Papers using same methodology → same approach
- Example: "Synchronous replication" vs "Asynchronous replication"

**Strategy 2: By Architecture**
- Papers proposing same architecture → same approach
- Example: "Service mesh" vs "API gateway"

**Strategy 3: By Solution Type**
- Papers solving problem in same way → same approach
- Example: "Paxos-based" vs "Raft-based" consensus

**Strategy 4: By Tradeoffs**
- Papers making similar tradeoffs → same approach
- Example: "Consistency-first" vs "Availability-first"

### Handling Edge Cases

**Paper supports multiple approaches:**
- Place in primary approach group
- Note in evidence card that it also relates to other approaches
- Link to related approaches in evidence card

**Paper doesn't fit clearly:**
- Review more carefully
- May represent hybrid approach or new category
- Create separate approach if significant enough

**Conflicting papers in same group:**
- Review grouping - may need to split
- Or note conflicts within the approach
- Document in evidence card

## Best Practices

### Discovery
- Start broad, narrow down based on results
- Use multiple search strategies in parallel
- Follow citation networks systematically
- Use top-cited works to find foundational papers

### Selection
- Apply clear inclusion/exclusion criteria
- Prioritize quality (citations, venue, authors) for academic papers
- Balance foundational and recent papers
- Include both supporting and conflicting evidence
- Include non-academic sources (weighted lower but valuable for SOTA)
- Target 25+ sources (15-20 academic + 5-10 non-academic)

### Grouping
- Group by clear distinguishing characteristics
- **Always aim for 5+ evidence cards** (ensures broad coverage)
- Explicitly seek conflicting approaches (not just best practices)
- Validate groupings by reading key papers/sources
- Use descriptive approach names
- Include both academic and non-academic sources in evidence cards

### Evidence Cards
- Synthesize, don't just list
- Focus on claims and evidence
- Include benefits AND negatives
- Link to related approaches (explicitly note conflicts)
- Include source type and weighting (academic vs non-academic)
- Always create 5+ evidence cards for broad coverage

### Reports
- Compare approaches objectively
- Highlight both strengths and weaknesses
- **Explicitly discuss conflicts** and provide guidance on when each approach applies
- Provide evidence-based recommendations (tied to codebase context)
- Link back to evidence cards for traceability
- Emphasize broad coverage (5+ evidence cards) in executive summary

