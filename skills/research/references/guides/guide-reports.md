# Report Generation Guide

How to synthesize multiple evidence cards (approaches) into comprehensive research reports.

## Overview

**Research reports** synthesize evidence from multiple evidence cards to provide comparative analysis and evidence-based recommendations. Reports are created in Level 3 (Deep Research) when multiple approaches need to be compared.

**Key principles:**
- **Synthesize from evidence cards**: Don't re-read papers, use evidence cards (they are the source of truth)
- **Re-read evidence cards**: Re-read all evidence cards before generating report (they contain all necessary information)
- **Re-read research question**: Re-read `research-question.md` to recall original intent
- **Comparative analysis**: Compare approaches objectively
- **Evidence-based**: All recommendations backed by evidence from cards
- **Balanced**: Highlight both benefits and negatives for each approach
- **Actionable**: Provide clear recommendations for different scenarios
- **Context management**: Re-reading evidence cards prevents context overload from re-reading papers

## When to Create a Report

Create a research report when:
- Multiple evidence cards exist (2+ approaches)
- Need to compare approaches systematically
- User requests comprehensive analysis
- Building knowledge base for documentation
- Making evidence-based recommendations

**Not needed for:**
- Single paper lookup (Level 1)
- Single approach research (Level 2 with one evidence card)

## Report Structure

See `templates/template-research-report.md` for complete template. Key sections:

1. **Executive Summary** - Overview of findings and recommendations
2. **Research Methodology** - How research was conducted
3. **Approaches Compared** - One section per evidence card
4. **Comparative Analysis** - Tables comparing approaches
5. **Evidence Summary** - Supporting, conflicting, gaps
6. **Recommendations** - Primary, alternatives, implementation
7. **References** - Papers, evidence cards, queries

## Step-by-Step Generation Process

**CRITICAL: Context Management for Report Generation**

**MANDATORY Steps Before Writing Report:**
1. **Re-read all evidence cards** (they contain all necessary information - don't re-read papers)
2. **Re-read `research-question.md`** to recall original intent
3. **Verify `references.json`** is up-to-date with all papers, approaches, and evidence cards

**Why:** Evidence cards are the source of truth. Re-reading papers causes context overload. Re-reading evidence cards ensures you have all necessary information without context overflow.

### Step 1: Re-Read All Evidence Cards (MANDATORY - Don't Re-Read Papers)

**Goal:** Understand all approaches before synthesizing. Evidence cards contain all necessary information.

**MANDATORY Process:**

1. **Re-read each evidence card** (don't re-read original papers)
   - Note approach name and overview
   - Identify key claims for each approach
   - Note benefits and negatives
   - Check assumptions and conditions
   - Review tradeoffs and failure modes
   - Review implementation resources found
   - **Why re-read:** Evidence cards are the persistent knowledge store. They contain all synthesized information from papers.

2. **Re-read `research-question.md`** (MANDATORY)
   - Read original research question/problem statement
   - Note original context/background
   - Review desired outcome
   - Check constraints/requirements
   - **Why re-read:** Ensures report answers the original question, not a modified understanding

3. **Verify `references.json`** is up-to-date
   - Check all papers are listed
   - Verify all approaches are documented
   - Confirm all evidence cards are referenced
   - **Why verify:** Ensures complete traceability and no missing information

4. **Identify patterns** (after re-reading evidence cards)
   - Common benefits across approaches
   - Common limitations
   - Conflicting claims between approaches
   - Complementary approaches

5. **Note gaps** (after re-reading evidence cards)
   - Areas where evidence is weak
   - Questions not answered by current papers
   - Contradictions needing resolution

### Step 2: Write Executive Summary

**Goal:** 2-3 paragraph overview for quick understanding.

**Include:**
- Research question/topic
- Number of approaches compared
- Key finding (primary recommendation)
- Brief rationale

**Example:**
> This report compares three distributed consensus algorithms: Paxos-based consensus, Raft consensus, and PBFT consensus. Based on analysis of 12 papers, Raft is recommended for most use cases due to its balance of simplicity and safety guarantees. However, Paxos-based approaches are preferred for high-performance scenarios, while PBFT is necessary for Byzantine fault tolerance.

### Step 3: Document Research Methodology

**Goal:** Show how research was conducted for reproducibility.

**Include:**
- **Search strategy**: Queries used, databases searched, filters applied
- **Selection criteria**: Inclusion/exclusion criteria, how papers were chosen
- **Approach grouping**: Rationale for how papers were grouped into approaches
- **Papers analyzed**: Total count, time range, types
- **Evidence card creation**: How evidence was extracted and synthesized
- **Research Process Flow Diagram** (optional): Visual representation of paper selection and approach grouping

**Example:**
```markdown
## Research Methodology

**Search Strategy:**
- Primary query: "distributed consensus algorithms"
- Searched: OpenAlex, arXiv, Semantic Scholar
- Filters: cited_by_count > 50, publication_year >= 2000
- Total papers found: 45

**Selection Criteria:**
- Included: Peer-reviewed papers, highly cited works, foundational papers
- Excluded: Low-quality sources, off-topic papers
- Selected: 12 papers for analysis

**Approach Grouping:**
- Grouped by consensus algorithm type:
  - Paxos-based: Papers proposing Paxos variants (5 papers)
  - Raft: Papers on Raft consensus (4 papers)
  - PBFT: Papers on Byzantine fault tolerance (3 papers)

**Papers Analyzed:**
- Total: 12 papers
- Time range: 1998-2020
- Types: Conference papers, journal articles
```

#### Research Process Flow Diagram (Optional)

**Purpose:** Visualize paper selection and approach grouping process for transparency and reproducibility.

**When to Include:** For comprehensive reviews (Level 3), helps with transparency and allows readers to understand the research process.

**Simple Text Format:**

Create a tree structure showing the flow from papers found to final approaches:

```
Papers Found: 50
  ├─ Relevant: 25
  │   ├─ Included: 12
  │   │   ├─ Approach 1: Paxos-based Consensus (5 papers)
  │   │   ├─ Approach 2: Raft Consensus (4 papers)
  │   │   └─ Approach 3: PBFT Consensus (3 papers)
  │   └─ Excluded: 13
  │       ├─ Off-topic: 8 papers
  │       └─ Insufficient detail: 5 papers
  └─ Not Relevant: 25
```

**Example with Details:**

```
Initial Search: "distributed consensus algorithms"
  ├─ Papers Found: 50
  │   ├─ Round 1: Initial discovery (15 papers)
  │   │   ├─ Relevant: 12
  │   │   └─ Not relevant: 3
  │   ├─ Round 2: Gap filling - "Byzantine fault tolerance" (8 papers)
  │   │   ├─ Relevant: 7
  │   │   └─ Not relevant: 1
  │   └─ Round 3: Deep dive - "optimizations 2020" (5 papers)
  │       ├─ Relevant: 3
  │       └─ Not relevant: 2
  │
  └─ Total Selected: 22 papers
      ├─ Approach 1: Paxos-based Consensus
      │   ├─ Paper 1 (high quality, 1998)
      │   ├─ Paper 2 (high quality, 2001)
      │   ├─ Paper 3 (medium quality, 2010)
      │   ├─ Paper 4 (high quality, 2015)
      │   └─ Paper 5 (medium quality, 2018)
      ├─ Approach 2: Raft Consensus
      │   ├─ Paper 6 (high quality, 2013)
      │   ├─ Paper 7 (high quality, 2014)
      │   ├─ Paper 8 (medium quality, 2015)
      │   └─ Paper 9 (high quality, 2016)
      └─ Approach 3: PBFT Consensus
          ├─ Paper 10 (high quality, 1999)
          ├─ Paper 11 (high quality, 2010)
          └─ Paper 12 (medium quality, 2015)
```

**How to Create:**

1. **Count papers at each stage:**
   - Total papers found
   - Papers after each refinement round
   - Papers included vs excluded
   - Papers per approach

2. **Show selection process:**
   - Initial search results
   - Refinement rounds (if used)
   - Inclusion/exclusion decisions
   - Approach grouping

3. **Include quality indicators** (optional):
   - Mark high/medium/low quality papers
   - Show quality distribution per approach

4. **Keep it simple:**
   - Use text-based tree structure (no special tools needed)
   - Focus on transparency, not complexity
   - Update from `references.json` data if available

**Benefits:**
- **Transparency:** Shows how papers were selected and grouped
- **Reproducibility:** Others can understand and replicate the process
- **Quality assessment:** Visual representation of paper selection rigor
- **Traceability:** Links search strategy to final approaches

### Step 4: Write Approaches Compared Section

**Goal:** One section per evidence card, synthesizing approach information.

**For each approach (evidence card):**

1. **Approach name and overview**
   - Use name from evidence card
   - Brief overview (1-2 sentences)

2. **Papers supporting this approach**
   - List papers from evidence card
   - Brief note on each paper's contribution

3. **Key claims**
   - Copy from evidence card
   - Ensure claims are clear and specific

4. **Benefits**
   - Synthesize from evidence card
   - Organize by category if multiple

5. **Negatives/Limitations**
   - Synthesize from evidence card
   - Be specific about what doesn't work

6. **Tradeoffs**
   - What you gain and lose
   - Performance vs consistency, etc.

7. **When to use**
   - Conditions from evidence card
   - Specific scenarios

**Example:**
```markdown
### Approach 1: Raft Consensus

**Overview:** Leader-based consensus algorithm designed for understandability while maintaining safety guarantees equivalent to Paxos.

**Papers Supporting This Approach:**
- "In Search of an Understandable Consensus Algorithm" (2013) - Foundational paper
- "Raft Refloated" (2014) - Improvements and optimizations
- "Raft in Production" (2015) - Practical deployment experiences

**Key Claims:**
- Raft provides equivalent safety guarantees to Paxos with simpler implementation
- Raft's leader-based design makes it easier to understand and implement
- Raft achieves consensus with O(n) messages per operation in normal case

**Benefits:**
- **Simplicity**: Easier to understand and implement than Paxos
- **Performance**: O(n) messages per operation in normal case
- **Usability**: Strong leader simplifies client interactions
- **Correctness**: Equivalent safety guarantees to Paxos

**Negatives/Limitations:**
- **Network partitions**: Requires majority to make progress
- **Byzantine faults**: Doesn't handle malicious nodes (unlike PBFT)
- **Performance**: Leader bottleneck in high-throughput scenarios
- **Complexity**: Still complex for some use cases

**Tradeoffs:**
- Simplicity vs performance (simpler but may be slower than optimized Paxos)
- Consistency vs availability (prioritizes consistency)

**When to Use:**
- Need understandable consensus algorithm
- Crash failures only (not Byzantine)
- Small to medium clusters (<100 nodes)
- Consistency prioritized over availability
```

### Step 5: Create Comparative Analysis Tables

**Goal:** Side-by-side comparison of approaches.

**Tables to create:**

1. **Strengths Comparison**
   | Approach | Primary Strength | Best For |
   |----------|------------------|----------|
   | Approach 1 | {Strength} | {Use case} |
   | Approach 2 | {Strength} | {Use case} |

2. **Limitations Comparison**
   | Approach | Primary Limitation | When to Avoid |
   |----------|---------------------|---------------|
   | Approach 1 | {Limitation} | {Scenario} |
   | Approach 2 | {Limitation} | {Scenario} |

3. **Best For Scenarios**
   | Scenario | Recommended Approach | Reason |
   |----------|----------------------|--------|
   | {Scenario 1} | Approach X | {Reason} |
   | {Scenario 2} | Approach Y | {Reason} |

**Example:**
```markdown
### Strengths Comparison
| Approach | Primary Strength | Best For |
|----------|------------------|----------|
| Raft | Simplicity and understandability | Teams needing maintainable consensus |
| Paxos | Performance and optimization | High-throughput systems |
| PBFT | Byzantine fault tolerance | Systems with malicious nodes |

### Limitations Comparison
| Approach | Primary Limitation | When to Avoid |
|----------|---------------------|---------------|
| Raft | Leader bottleneck | Very high throughput requirements |
| Paxos | Complexity | Teams needing simple implementation |
| PBFT | High message complexity | Systems without Byzantine threats |
```

### Step 6: Write Evidence Summary

**Goal:** Synthesize evidence across all approaches.

**Sections:**

1. **Supporting Evidence**
   - Claims supported by multiple approaches
   - Claims with strong evidence
   - List with paper citations

2. **Conflicting Evidence**
   - Where approaches disagree
   - Contradictory findings
   - Explain context for conflicts

3. **Gaps in Research**
   - Areas needing more study
   - Unanswered questions
   - Conflicting findings without resolution

**Example:**
```markdown
## Evidence Summary

### Supporting Evidence
- **Consensus requires majority**: Supported by all approaches (Paxos, Raft, PBFT papers)
- **Leader-based design improves understandability**: Supported by Raft papers, confirmed by Paxos comparisons
- **Byzantine faults require different approach**: Supported by PBFT papers, acknowledged by Raft/Paxos papers

### Conflicting Evidence
- **Performance**: Paxos papers claim better performance, Raft papers claim simplicity is worth tradeoff
  - Context: Depends on implementation and optimization level
- **Complexity**: Raft claims simplicity, but some argue it's still complex
  - Context: Simpler than Paxos, but consensus inherently complex

### Gaps in Research
- **Hybrid approaches**: Limited research on combining approaches
- **Large-scale deployments**: Few papers on 100+ node clusters
- **Real-world performance**: More empirical studies needed
```

### Step 7: Write Recommendations

**Goal:** Provide evidence-based recommendations for different scenarios.

**Structure:**

1. **Primary Recommendation**
   - Best approach for general case
   - 3-5 reasons with evidence
   - Link to evidence cards

2. **Alternative Recommendations**
   - For specific scenarios
   - When to use each alternative
   - Evidence for each

3. **Implementation Considerations**
   - Practical considerations
   - Deployment challenges
   - Operational requirements

**Example:**
```markdown
## Recommendations

### Primary Recommendation

**Raft Consensus** is recommended for most distributed systems requiring consensus because:

1. **Simplicity**: Easier to understand and implement than Paxos (see Raft evidence card)
2. **Safety**: Equivalent safety guarantees to Paxos (see Raft evidence card, Claim 1)
3. **Practical**: Strong leader simplifies client interactions (see Raft evidence card, Benefits)
4. **Proven**: Successfully deployed in production systems (see Raft evidence card, Papers)

### Alternative Recommendations

- **For high-throughput systems**: Use **Paxos-based consensus** because optimized implementations achieve better performance (see Paxos evidence card, Benefits)
- **For systems with malicious nodes**: Use **PBFT consensus** because it handles Byzantine faults (see PBFT evidence card, Benefits)
- **For very large clusters (100+ nodes)**: Consider **Paxos variants** optimized for scale (see Paxos evidence card, When to Use)

### Implementation Considerations

- **Team expertise**: Raft easier for teams new to consensus
- **Performance requirements**: Paxos may be better for very high throughput
- **Fault model**: PBFT only if Byzantine faults are a concern
- **Operational complexity**: Raft simpler to operate and debug
```

### Step 8: Write References Section

**Goal:** Provide complete traceability to sources.

**Include:**

1. **Papers Analyzed**
   - List all papers with metadata
   - Link to evidence cards
   - Note which approach each supports

2. **Evidence Cards**
   - List all evidence cards with paths
   - Note approach name for each

3. **Search Queries**
   - All queries that led to papers
   - Note which queries found which papers

**Example:**
```markdown
## References

### Papers Analyzed

1. "In Search of an Understandable Consensus Algorithm" (2013) - Raft approach
   - Evidence card: `evidence-card-approach-raft.md`
   - DOI: 10.1145/2517349.2517350

2. "The Part-Time Parliament" (1998) - Paxos approach
   - Evidence card: `evidence-card-approach-paxos.md`
   - DOI: 10.1145/279227.279229

[... list all papers ...]

### Evidence Cards

- `evidence-card-approach-raft.md` - Raft Consensus (4 papers)
- `evidence-card-approach-paxos.md` - Paxos-based Consensus (5 papers)
- `evidence-card-approach-pbft.md` - PBFT Consensus (3 papers)

### Search Queries Used

- "distributed consensus algorithms" (OpenAlex, 15 results)
- "Paxos consensus" (OpenAlex, 8 results)
- "Raft consensus" (OpenAlex, 6 results)
- "Byzantine fault tolerance consensus" (OpenAlex, 5 results)
```

### Step 9: Add Appendix (Optional)

**Goal:** Include supplementary information.

**May include:**
- Related topics discovered
- Papers reviewed but not included
- Additional notes
- Future research directions

## Quality Checklist

Before finalizing a report, verify:

- [ ] **Executive summary** clear and concise
- [ ] **Methodology** documented completely
- [ ] **All approaches** covered (one section per evidence card)
- [ ] **Comparative tables** accurate and complete
- [ ] **Evidence summary** includes supporting, conflicting, gaps
- [ ] **Recommendations** evidence-based and actionable
- [ ] **References** complete with all papers and evidence cards
- [ ] **Links** to evidence cards work correctly
- [ ] **Balanced** - both benefits and negatives for each approach
- [ ] **Traceable** - all claims link back to evidence cards

## Common Pitfalls

**Avoid:**
- ❌ **Re-reading papers instead of re-reading evidence cards** (causes context overload)
- ❌ **Not re-reading `research-question.md`** (lose track of original intent)
- ❌ **Not updating `references.json`** with report path (lose traceability)
- ❌ Biased comparison (favoring one approach)
- ❌ Vague recommendations without evidence
- ❌ Missing limitations or tradeoffs
- ❌ Not linking to evidence cards
- ❌ Ignoring conflicting evidence
- ❌ One-size-fits-all recommendations

**Do:**
- ✅ **Re-read all evidence cards** before generating report (they contain all necessary information)
- ✅ **Re-read `research-question.md`** to recall original intent
- ✅ **Update `references.json`** with report path after generating report
- ✅ Synthesize from evidence cards (don't re-read papers)
- ✅ Compare approaches objectively
- ✅ Provide scenario-specific recommendations
- ✅ Include both benefits and negatives
- ✅ Link all claims to evidence cards
- ✅ Address conflicts and gaps
- ✅ Be specific about when to use each approach

## Integration with Workflow

Report generation happens in:
- **Level 3**: After creating 2+ evidence cards

**Process:**
1. Complete evidence card creation for all approaches (using write-first pattern)
2. **Re-read all evidence cards** (MANDATORY - don't re-read papers)
3. **Re-read `research-question.md`** (MANDATORY - recall original intent)
4. Generate report using template (synthesize from evidence cards)
5. **Update `references.json`** with `research_report: "research-report.md"` → **SAVE**
6. Report becomes permanent artifact alongside evidence cards

See `guides/guide-workflow.md` for complete workflow context.

