# Evidence Card Creation Guide

How to create effective approach-based evidence cards that synthesize multiple papers.

## CRITICAL: Write-First Pattern (MANDATORY)

**You MUST follow the write-first pattern from `guides/guide-workflow.md` when creating evidence cards.**

**Key Rule:** After reading 1-2 papers/sources maximum, you MUST:
1. Write or update evidence card immediately
2. Update `references.json` immediately (add paper, update approach, update evidence card metadata)
3. Save files before reading next paper/source
4. **CONTINUE** the research workflow - writing does NOT mean stopping

**See `guides/guide-workflow.md` for complete write-first pattern details, context checkpoints, and failure modes.**

## Overview

**Evidence cards** are structured summaries that synthesize knowledge from multiple papers/sources supporting the same approach. One evidence card per approach, containing multiple papers/sources (academic and non-academic). **Always create 5+ evidence cards** to ensure broad coverage of diverse and potentially conflicting ideas.

**Key principles:**
- **Synthesize, don't list**: Combine insights from multiple papers/sources into coherent claims
- **Evidence-based**: Every claim supported by direct quotes (with page numbers for academic papers)
- **Balanced**: Include both benefits and negatives/limitations
- **Actionable**: Focus on what the approach demonstrates and when to use it
- **Write-first**: Create/update evidence cards after each 1-2 papers/sources, not in batch
- **Diverse coverage**: Explicitly seek conflicting ideas and alternative approaches, not just best practices
- **Source weighting**: Academic papers (high weight), non-academic sources (lower weight but valuable for SOTA)

## Structure

Each evidence card follows this structure (see `templates/template-evidence-card.md`):

1. **Metadata** - Approach name, papers/sources included, topic, dates
2. **Approach Overview** - What this approach is, key characteristics
3. **Papers Supporting This Approach** - List of academic papers with summaries and weighting
4. **Non-Academic Sources Supporting This Approach** - List of blogs, docs, tutorials with source type and weighting
5. **Key Claims** - Synthesized claims from multiple papers/sources
6. **Supporting Evidence** - Quotes organized by claim (with page numbers for academic papers)
7. **Assumptions/Conditions** - When this approach applies
8. **Tradeoffs/Limitations** - Consolidated limitations
9. **Failure Modes** - When this approach fails
10. **Related Approaches** - Connections to other evidence cards (explicitly note conflicts)
11. **Implementation Resources** - Packages, guides, examples
12. **Notes** - Additional observations

## Step-by-Step Creation Process (Write-First Pattern)

**REMINDER: Never read more than 2 papers before writing an evidence card and updating references.json**

### Step 1: Extract PDF Content (Paper 1)

**Goal:** Get paper content directly to context (no file saving).

1. **Download PDF** (if not already downloaded)
   - Save to `.ada/temp/research/downloads/{doi-or-id}.pdf`
   - Use descriptive filenames

2. **Extract content**
   - Use PDF extractor `read_pdf` with `include_full_text: true`
   - Content goes directly to context (no file saving)
   - Extract full text or specific sections as needed

3. **Read key sections**
   - Abstract: Overview and main contributions
   - Introduction: Problem statement and approach
   - Methodology: How the approach works
   - Results: What the approach demonstrates
   - Conclusion: Key findings and limitations

4. **Identify approach** this paper supports
   - What methodology/architecture/solution does this paper support?
   - Check existing evidence cards: Does this align with existing approach?

**After reading paper 1:**
- **Write evidence card immediately** (create new or update existing)
- **Update `references.json` immediately:**
  - Add paper to `papers` array
  - Add/update approach in `approaches` array
  - Add/update evidence card in `evidence_cards` array
  - Link paper to approach via `approach` field
  - Update `updated` timestamp
- **SAVE `references.json`**
- **Context Checkpoint:** Verify files are saved before continuing

### Step 1b: Extract PDF Content (Paper 2)

**After reading paper 1 and writing evidence card, continue with paper 2:**

1. **Download PDF** (if not already downloaded)
2. **Extract content** with `read_pdf`
3. **Read key sections**
4. **Check existing evidence cards** - Does this paper align with existing approach?
   - **If aligns:** Update existing evidence card → Add paper, synthesize claims, add evidence
   - **If new approach:** Create new evidence card → Save immediately

**After reading paper 2:**
- **Update/create evidence card immediately**
- **Update `references.json` immediately:**
  - Add paper to `papers` array
  - Update approach in `approaches` array (add paper ID to papers array if updating existing)
  - Add new approach/evidence card if creating new
  - Update evidence card in `evidence_cards` array (increment papers_count if updating)
  - Update `updated` timestamp
- **SAVE `references.json`**
- **Context Checkpoint:** Verify files are saved before continuing

**Continue incrementally:** Read paper 3 → Write → Update JSON → SAVE → Read paper 4 → Write → Update JSON → SAVE

### Step 2: Identify Approach Characteristics

**Goal:** Understand what makes this approach distinct.

**Questions to answer:**
- What problem does this approach solve?
- How does it solve it (methodology/technique)?
- What are its key characteristics?
- How does it differ from other approaches?
- When did it emerge or become popular?

**Example:**
- **Approach**: Raft Consensus
- **Problem**: Need for understandable consensus algorithm
- **Methodology**: Leader-based, log replication, majority voting
- **Key characteristics**: Simpler than Paxos, strong leader, log-based
- **Differs from**: Paxos (more complex), PBFT (Byzantine fault tolerance)
- **Emergence**: 2013 (In Search of an Understandable Consensus Algorithm)

### Step 3: Synthesize Claims (Incremental - As You Read Papers)

**Goal:** Identify 3-5 key claims that this approach demonstrates across multiple papers.

**Process (Incremental - Update as you read each paper):**

1. **After reading paper 1:**
   - Identify main claims from this paper
   - Write initial claims in evidence card
   - **Update `references.json`** → **SAVE**

2. **After reading paper 2:**
   - Identify main claims from this paper
   - **Check existing claims** in evidence card - Do they align?
   - **Synthesize:** Combine similar claims, generalize specific findings
   - **Update evidence card** with synthesized claims
   - **Update `references.json`** → **SAVE**

3. **Continue incrementally:**
   - After each paper: Update claims, synthesize, update evidence card, update `references.json`, SAVE
   - **Never wait to read all papers before synthesizing claims**
   - Look for common themes as you read
   - Note unique contributions from each paper

4. **Validate claims (as you update):**
   - Ensure each claim is supported by multiple papers (as you add papers)
   - Check for contradictions
   - Note if claim is supported by all papers or just some

**Example Claims (Raft Consensus):**
- **Claim 1**: Raft provides equivalent safety guarantees to Paxos with simpler implementation
- **Claim 2**: Raft's leader-based design makes it easier to understand and implement
- **Claim 3**: Raft achieves consensus with O(n) messages per operation in normal case
- **Claim 4**: Raft handles leader failures through election mechanism

### Three-Stage Synthesis Methodology (Thematic Synthesis)

**Goal:** Go beyond simple summaries to generate analytical insights that synthesize knowledge across multiple papers.

**REMINDER:** Apply stages incrementally as you read papers (not all at once). Write evidence cards after each 1-2 papers, maintaining write-first pattern.

#### Stage 1: Line-by-Line Coding (As You Read Each Paper)

**Process:**
- Extract meaning and content from paper text
- Identify key concepts, claims, and evidence
- Code incrementally: Read paper 1 → Code → Write evidence card → Read paper 2 → Code → Update evidence card → Write

**What to Code:**
- Key concepts and terminology
- Main claims and arguments
- Supporting evidence and data
- Methodologies and approaches
- Benefits and limitations mentioned

**Example (Raft Consensus - Paper 1):**
- Codes extracted: "simpler than Paxos", "leader-based design", "log replication", "majority voting", "understandability focus"
- Write these codes into evidence card immediately
- **Update `references.json`** → **SAVE**

**Example (Raft Consensus - Paper 2):**
- Codes extracted: "leader election", "safety guarantees equivalent to Paxos", "easier implementation"
- Check existing codes: "simpler than Paxos" aligns with "easier implementation"
- Update evidence card: Combine related codes, add new codes
- **Update `references.json`** → **SAVE**

#### Stage 2: Descriptive Themes (As You Group Papers)

**Process:**
- Organize codes into related areas
- Stay close to primary studies (describe what papers say)
- Create themes that summarize findings from papers
- Update incrementally: After each 1-2 papers, organize codes into themes

**How to Create Descriptive Themes:**
- Group related codes together
- Name themes based on what papers describe
- Keep themes close to original paper content
- Update themes as you read more papers

**Example (Raft Consensus):**
- Codes: "simpler than Paxos", "easier implementation", "understandability focus", "leader-based design"
- **Descriptive Theme:** "Raft uses leader-based design for understandability"
- Codes: "safety guarantees equivalent to Paxos", "majority voting", "log replication"
- **Descriptive Theme:** "Raft provides equivalent safety to Paxos through log-based consensus"

**Context Management:**
- After organizing codes into themes: Write/update evidence card → Update `references.json` → SAVE
- Don't wait to read all papers before creating themes

#### Stage 3: Analytical Themes (When Synthesizing Across Papers)

**Process:**
- Go beyond primary studies to generate new insights
- Create interpretive constructs not found in individual papers
- Generate insights that emerge from comparing multiple papers
- Apply when updating evidence cards with multiple papers (typically after 2+ papers)

**How to Create Analytical Themes:**
- Look for patterns across papers
- Identify relationships between different findings
- Generate new interpretations or explanations
- Create insights that answer "why" or "how" questions

**Example (Raft Consensus):**
- Descriptive Theme: "Raft uses leader-based design for understandability"
- Descriptive Theme: "Raft provides equivalent safety to Paxos through log-based consensus"
- **Analytical Theme:** "Leader-based consensus enables better maintainability through reduced cognitive complexity, while maintaining safety guarantees equivalent to more complex algorithms"

**Context Management:**
- Apply analytical themes when you have 2+ papers in an approach
- Write/update evidence card with analytical themes → Update `references.json` → SAVE
- Continue reading papers and refining analytical themes incrementally

**Complete Example (Raft Consensus - All Three Stages):**

**Stage 1 Codes (from multiple papers):**
- "simpler than Paxos", "leader-based", "log replication", "majority voting", "understandability", "safety guarantees", "easier implementation"

**Stage 2 Descriptive Themes:**
- "Raft uses leader-based design for understandability"
- "Raft provides equivalent safety to Paxos through log-based consensus"
- "Raft simplifies consensus through strong leader model"

**Stage 3 Analytical Theme:**
- "Leader-based consensus enables better maintainability through reduced cognitive complexity, while maintaining safety guarantees equivalent to more complex algorithms. This design tradeoff prioritizes operational simplicity over theoretical elegance, making consensus accessible to broader engineering teams."

**Key Principle:** Move from specific codes (Stage 1) → organized descriptions (Stage 2) → synthesized insights (Stage 3), all done incrementally as you read papers.

### Step 4: Extract Supporting Evidence (Incremental - As You Read Papers)

**Goal:** Find direct quotes from papers that support each claim.

**Process (Incremental - Add evidence as you read each paper):**

**After reading paper 1:**
1. **Find supporting quotes** for initial claims
   - Search paper text for relevant sections
   - Look for explicit statements supporting the claim
   - Note page numbers and sections
2. **Add quotes to evidence card** under appropriate claims
3. **Update `references.json`** → **SAVE**

**After reading paper 2:**
1. **Find supporting quotes** for claims (new or existing)
2. **Add quotes to evidence card:**
   - If claim already exists: Add additional quotes from paper 2
   - If new claim: Add quotes for new claim
3. **Update evidence card** with new evidence
4. **Update `references.json`** → **SAVE**

**Continue incrementally:**
- After each paper: Extract quotes, add to evidence card, update `references.json`, SAVE
- **Organize by claim** as you add quotes
- **Note which paper** each quote comes from
- **Include page numbers and sections** for all quotes

**Example Evidence Structure:**

```markdown
### Claim 1: Raft provides equivalent safety guarantees to Paxos

**Supporting Evidence:**

**From Paper A (Raft paper, page 3):**
> "Raft provides the same safety guarantees as Paxos, but with a simpler implementation."

**From Paper B (Raft Refloated, page 5):**
> "Our analysis confirms that Raft maintains the same safety properties as Paxos while being more understandable."

**Context:** Both papers explicitly state that Raft provides equivalent safety to Paxos.

**Relevance:** This claim addresses the primary motivation for Raft - maintaining Paxos safety with simplicity.
```

### Step 5: Consolidate Benefits (Incremental - As You Read Papers)

**Goal:** Identify benefits mentioned across all papers in the approach.

**Process (Incremental - Update as you read each paper):**

**After reading paper 1:**
1. **Extract benefits** from this paper
   - Look in results, conclusions, abstract
   - Note performance benefits, simplicity, usability, etc.
2. **Add to evidence card**
3. **Update `references.json`** → **SAVE**

**After reading paper 2:**
1. **Extract benefits** from this paper
2. **Consolidate with existing benefits:**
   - Benefits mentioned in both papers → strong evidence (emphasize)
   - Benefits mentioned in one paper → note as potential
3. **Update evidence card** with consolidated benefits
4. **Update `references.json`** → **SAVE**

**Continue incrementally:**
- After each paper: Extract benefits, consolidate, update evidence card, update `references.json`, SAVE
- **Organize by category** as you add benefits (performance, simplicity, practical, theoretical)

**Example Benefits (Raft):**
- **Simplicity**: Easier to understand and implement than Paxos
- **Performance**: O(n) messages per operation in normal case
- **Usability**: Strong leader simplifies client interactions
- **Correctness**: Equivalent safety guarantees to Paxos

### Step 6: Consolidate Negatives and Limitations (Incremental - As You Read Papers)

**Goal:** Identify limitations, tradeoffs, and failure modes across all papers.

**Process (Incremental - Update as you read each paper):**

**After reading paper 1:**
1. **Extract limitations** from this paper
   - Look in limitations, future work, discussion sections
   - Note what paper says the approach doesn't handle
   - Identify tradeoffs mentioned
2. **Add to evidence card**
3. **Update `references.json`** → **SAVE**

**After reading paper 2:**
1. **Extract limitations** from this paper
2. **Consolidate with existing limitations:**
   - Limitations mentioned in both papers → strong evidence (emphasize)
   - Contradictions → note as areas of disagreement
3. **Update evidence card** with consolidated limitations
4. **Update `references.json`** → **SAVE**

**Continue incrementally:**
- After each paper: Extract limitations, consolidate, update evidence card, update `references.json`, SAVE
- **Identify failure modes** as you read (when does approach fail, what conditions cause problems, edge cases)

**Example Limitations (Raft):**
- **Network partitions**: Requires majority to make progress
- **Byzantine faults**: Doesn't handle malicious nodes (unlike PBFT)
- **Performance**: Leader bottleneck in high-throughput scenarios
- **Complexity**: Still complex for some use cases

### Quality Assessment: Sensitivity Analysis

**Goal:** Assess impact of paper quality on synthesis without excluding papers. Maintain transparency and traceability.

**REMINDER:** Include all relevant papers initially. Don't exclude based on quality. Assess and document quality impact incrementally as you read papers.

**Process (Incremental - Apply as you read each paper):**

1. **Include all relevant papers initially** (don't exclude based on quality)
   - If paper is relevant to research question, include it
   - Quality assessment happens after inclusion, not before

2. **Assess quality** (as you read each paper):
   - **High quality indicators:** Highly cited (50+ citations), peer-reviewed journal/conference, rigorous methodology, recent and validated
   - **Medium quality indicators:** Recent preprint, conference paper, some citations, reasonable methodology
   - **Low quality indicators:** Blog post, no peer review, few/no citations, unclear methodology
   - Note quality in evidence card and `references.json`

3. **Note quality in evidence card** (mark papers as high/medium/low quality):
   - Add quality indicator to paper metadata in evidence card
   - Note why paper is high/medium/low quality
   - Update `references.json` with `quality_indicator` field → **SAVE**

4. **Test sensitivity** (after synthesis with multiple papers):
   - Note which papers contribute most to key claims
   - Document relative contributions: High quality papers typically contribute more claims/evidence
   - Note if low quality papers provide unique perspectives or context

5. **Document impact** (in evidence card):
   - Better quality papers typically contribute more, but include all for transparency
   - Note which claims are supported primarily by high-quality papers
   - Note if any claims rely heavily on lower-quality sources (flag for caution)

**Example (Raft Consensus):**

**Paper A: High quality** (highly cited, peer-reviewed journal, 2013)
- Quality notes: "Foundational paper, 7,000+ citations, peer-reviewed"
- Contributes: 3 key claims (safety guarantees, leader-based design, understandability)
- **Update evidence card** → Add quality indicator → **Update `references.json`** → **SAVE**

**Paper B: Medium quality** (recent preprint, 2024)
- Quality notes: "Recent preprint, 50 citations, not yet peer-reviewed"
- Contributes: 1 key claim (performance optimizations)
- **Update evidence card** → Add quality indicator → **Update `references.json`** → **SAVE**

**Paper C: Low quality** (blog post, no peer review)
- Quality notes: "Engineering blog post, no citations, practical experience only"
- Contributes: Background context and practical deployment notes
- **Update evidence card** → Add quality indicator → **Update `references.json`** → **SAVE**

**Sensitivity Analysis Result:**
- All papers included for transparency
- High quality paper (Paper A) contributes most claims (3 of 4 key claims)
- Medium quality paper (Paper B) contributes specialized knowledge (optimizations)
- Low quality paper (Paper C) provides practical context but not core claims
- **Synthesis:** Core claims primarily supported by high-quality paper, with additional insights from other sources

**Why Sensitivity Analysis:**
- **Transparency:** Shows all sources considered, not just "good" ones
- **Traceability:** Readers can see which claims rely on which quality levels
- **Bias reduction:** Exclusion can introduce bias; inclusion with quality assessment is more transparent
- **Context preservation:** Lower quality papers may provide unique perspectives or practical context

**Context Management:**
- Assess quality as you read each paper (incremental)
- Update evidence card with quality indicators → Update `references.json` → SAVE
- Don't wait to assess quality until all papers are read

### Step 7: Identify Assumptions and Conditions

**Goal:** Document when this approach applies and what it assumes.

**Questions:**
- What conditions must be met for this approach to work?
- What assumptions does it make?
- What environment is it designed for?
- When is it appropriate to use?

**Example Assumptions (Raft):**
- **Network**: Assumes reliable network (messages can be delayed but not lost)
- **Failures**: Assumes crash failures only (not Byzantine)
- **Size**: Works best for small to medium clusters (typically <100 nodes)
- **Consistency**: Prioritizes consistency over availability

### Step 8: Link to Related Approaches

**Goal:** Connect this approach to other evidence cards.

**Identify:**
- **Conflicting approaches**: Approaches that solve same problem differently
- **Complementary approaches**: Approaches that work well together
- **Alternative approaches**: Different solutions to related problems
- **Evolutionary relationships**: Approaches that build on or improve this one

**Example Links (Raft):**
- **Conflicts with**: PBFT (different failure model)
- **Improves on**: Paxos (simpler but equivalent)
- **Alternative to**: Multi-Paxos (different design philosophy)

### Step 9: Write the Evidence Card (Incremental - After Each Paper)

**Goal:** Create/update the evidence card file using the template.

**MANDATORY Pattern:**
- **After reading paper 1:** Create evidence card → Update `references.json` → SAVE
- **After reading paper 2:** Update evidence card → Update `references.json` → SAVE
- **Continue:** Never read more than 2 papers before writing

1. **Use template**
   - Start from `templates/template-evidence-card.md` (for new cards)
   - Or update existing evidence card (for additional papers)
   - Fill in/update all sections incrementally

2. **Save file immediately**
   - Name: `evidence-card-approach-{N}.md` or `evidence-card-{descriptive-name}.md`
   - Location: `.ada/data/research/{topic}/`
   - Use descriptive names when possible
   - **SAVE after each update**

3. **Update `references.json` immediately (MANDATORY after each evidence card write):**
   - Add paper to `papers` array (if new paper)
   - Add/update approach in `approaches` array
   - Link paper to approach via `approach` field
   - Add/update evidence card in `evidence_cards` array
   - Update `updated` timestamp
   - **SAVE `references.json`**

4. **Context Checkpoint:**
   - Verify evidence card file exists and is saved
   - Verify `references.json` is updated
   - Optionally re-read evidence card to verify content
   - Continue to next paper (maximum 2 papers before next write)

## Quality Checklist

Before finalizing an evidence card, verify:

- [ ] **Metadata complete**: Approach name, all papers listed, topic, dates
- [ ] **Approach overview clear**: What it is, key characteristics
- [ ] **Papers documented**: All papers listed with summaries
- [ ] **Claims synthesized**: 3-5 key claims, not just listed
- [ ] **Evidence provided**: Direct quotes with page numbers for each claim
- [ ] **Benefits balanced**: Both strengths and limitations included
- [ ] **Tradeoffs documented**: What you gain and lose with this approach
- [ ] **Conditions clear**: When to use, what it assumes
- [ ] **Failure modes identified**: When it doesn't work
- [ ] **Related approaches linked**: Connections to other evidence cards
- [ ] **Quotes accurate**: Page numbers correct, quotes exact

## Common Pitfalls

**Avoid:**
- ❌ **Reading 3+ papers before writing evidence card** (causes context overload)
- ❌ **Only updating `references.json` once at the end** (lose track of progress)
- ❌ Just listing papers without synthesis
- ❌ Only including benefits, ignoring limitations
- ❌ Vague claims without supporting evidence
- ❌ Quotes without page numbers or context
- ❌ One paper per claim (should synthesize multiple)
- ❌ Ignoring contradictions between papers
- ❌ Not linking to related approaches
- ❌ **Batch processing** (reading all papers, then writing all cards)

**Do:**
- ✅ **Write evidence card after each 1-2 papers** (write-first pattern)
- ✅ **Update `references.json` after each evidence card write** (incremental updates)
- ✅ **SAVE files before reading next paper** (context checkpoints)
- ✅ Synthesize claims from multiple papers (incrementally as you read)
- ✅ Include both benefits and negatives
- ✅ Provide direct quotes with page numbers
- ✅ Note when papers disagree
- ✅ Link to related approaches
- ✅ Be specific about conditions and assumptions

## Examples

### Example 1: Single Approach, Multiple Papers

**Approach:** Service Mesh Pattern

**Papers:** 4 papers on service mesh architectures

**Claims:**
- Service mesh provides transparent service-to-service communication
- Sidecar proxy pattern enables consistent policy enforcement
- Service mesh improves observability and security

**Evidence:** Quotes from all 4 papers supporting each claim

**Benefits:** Transparent, consistent, improved observability

**Limitations:** Overhead, complexity, operational burden

### Example 2: Conflicting Approaches

**Approach 1:** Synchronous Replication (3 papers)
**Approach 2:** Asynchronous Replication (2 papers)

**Claims differ:**
- Approach 1: Strong consistency, lower performance
- Approach 2: Higher performance, eventual consistency

**Evidence cards highlight different tradeoffs**

## Integration with Workflow

Evidence card creation happens during comprehensive research workflow:
- **Always create 5+ evidence cards** for broad coverage
- **Explicitly seek conflicting ideas** - not just best approaches, but diverse perspectives
- **Include both academic and non-academic sources** with appropriate weighting

**REMINDER: Write-First Pattern**
- Evidence cards are created/updated **after each 1-2 papers/sources**
- `references.json` is updated **after each evidence card write**
- Files are saved **before reading next paper/source**
- This prevents context overload and information loss

**Conflict-Seeking Strategies:**
- Explicitly search for opposing viewpoints ("{approach A} vs {approach B}")
- Search for critiques and limitations ("{approach} limitations", "{approach} problems")
- Find alternative approaches ("alternative to {approach}", "{approach} vs {alternative}")
- Create evidence cards for conflicting approaches, not just best practices

## Weighting Sources in Evidence Cards

**Purpose:** Document how you weight different sources to enable evidence-based decision-making. Weighting helps determine which evidence is strongest and most credible.

### Weighting Academic Papers

**High Weight (Strongest Evidence):**
- 50+ citations: Well-established, influential papers
- Peer-reviewed journals/conferences: Validated methodology
- Foundational papers: Established principles
- Multiple sources agreeing: Higher confidence

**Medium Weight (Good Evidence):**
- 10-50 citations: Solid research, may be newer or specialized
- Peer-reviewed: Still validated, but less influential
- Recent SOTA (2020+): Current best practices, may not have accumulated citations yet

**Lower Weight (Relevant but Less Strong):**
- <10 citations: May be very recent, niche, or less influential
- Still valuable: Can provide unique perspectives or address specific aspects
- Use when: Highly relevant to your specific question or fills gaps

**Document in Evidence Card:**
- Note citation count for each paper
- Indicate weighting (high/medium/lower) and reasoning
- Explain why certain papers have higher weight

### Weighting Non-Academic Sources

**Medium Weight (Authoritative Practical Sources):**
- Official documentation (2024+): Authoritative for specific tools/frameworks
- Case studies from reputable companies: Real-world validation
- Tutorials from recognized experts: Practical implementation guidance

**Low Weight (Valuable but Less Authoritative):**
- Recent blog posts (2024+): May have latest insights, SOTA approaches
- Community tutorials: Practical examples, may reflect current best practices
- Stack Overflow / forums: Specific implementation details, troubleshooting

**Document in Evidence Card:**
- Note source type (blog post, documentation, tutorial, case study)
- Indicate weighting (medium/low) and reasoning
- Explain why non-academic sources are valuable despite lower weight

### Weighting Process

1. **Assess Each Source:**
   - Academic: Check citation count, publication venue, peer-review status
   - Non-academic: Check recency, author/organization authority, practical value

2. **Document Weighting:**
   - Add weighting annotation to each source in evidence card
   - Note reasoning (citations, authority, recency, practical value)

3. **Compare Evidence Strength:**
   - Multiple high-weight sources agreeing = Very strong evidence
   - High-weight + medium-weight sources agreeing = Strong evidence
   - Conflicting high-weight sources = Important tradeoff to explore
   - Low-weight sources with unique insights = May fill gaps or provide SOTA perspective

**Example Weighting in Evidence Card:**
```
### Paper 1: "Raft Consensus Algorithm"
- **Citations:** 7,000+
- **Weighting:** High (foundational, highly cited, peer-reviewed)
- **Reasoning:** Strongest evidence, well-established, multiple validation studies
```

**See SKILL.md "Weighting Different Ideas" section for detailed framework.**

After creating evidence cards:
- `references.json` is already updated incrementally (not done at end)
- Proceed to report generation - re-read evidence cards, don't re-read papers
- Report will synthesize all evidence cards, including conflicts

See `guides/guide-workflow.md` for complete workflow context.

