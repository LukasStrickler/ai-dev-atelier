# Adaptive Research Strategies Guide

How to handle different research scenarios and ensure comprehensive coverage.

## Purpose

Research scenarios vary. Use these adaptive techniques to handle different situations and ensure comprehensive coverage.

## When Research Is Too Narrow

**Symptoms:**
- All evidence cards support similar approaches
- Limited diversity in perspectives
- Missing alternative viewpoints

**Strategies:**
- **Broaden search queries**: Use more general terms, remove specific filters
- **Search for critiques**: "{approach} limitations", "{approach} problems", "{approach} alternatives"
- **Explore related fields**: Look for approaches from different domains
- **Explicitly seek conflicts**: "{approach A} vs {approach B}", "debate about {topic}"
- **Remove citation filters**: Include less cited but potentially relevant papers

**Example:**
- Initial search: "Raft consensus" → Only found Raft papers
- Broadened: "consensus algorithms", "distributed consensus alternatives", "Raft vs Paxos debate"
- Result: Found Paxos, PBFT, and alternative approaches

## When Too Many Conflicts

**Symptoms:**
- Many conflicting approaches with strong evidence
- Unclear which approach to choose
- Conflicting evidence cards

**Strategies:**
- **Focus on specific aspects**: Narrow to performance, scalability, or specific use case
- **Identify context-dependent differences**: When does each approach work best?
- **Weight evidence more carefully**: Use citation counts and source authority
- **Consider your specific constraints**: Which conflicts matter for your codebase?
- **Look for synthesis**: Are there hybrid approaches that combine benefits?

**Example:**
- Many conflicting approaches for authentication
- Focused on: "stateless authentication for microservices" (specific use case)
- Result: JWT vs OAuth2 conflict resolved by use case (JWT for internal, OAuth2 for external)

## When Insufficient Evidence

**Symptoms:**
- Few papers found (<10 relevant)
- Evidence cards lack depth
- Missing key aspects of research question

**Strategies:**
- **Expand search terms**: Use synonyms, related concepts, broader categories
- **Remove year filters**: Include older foundational papers
- **Search non-academic sources**: Blogs, documentation, case studies
- **Use citation networks**: Follow references from found papers
- **Search related topics**: Broaden to adjacent research areas
- **Iterative refinement**: Query → Assess gaps → Refine → Repeat

**Example:**
- Initial: "new framework X" → Only 3 papers
- Expanded: "framework X", "similar to framework X", "framework X architecture patterns"
- Added: Citation networks from found papers
- Result: 15+ sources including foundational concepts

## When Codebase Constraints Conflict with Research

**Symptoms:**
- Research recommends approach that doesn't fit codebase
- Constraints (technology stack, team expertise) conflict with best practices
- Evidence suggests approach incompatible with existing architecture

**Strategies:**
- **Identify compromise solutions**: Approaches that balance research and constraints
- **Search for adaptations**: "{approach} for {your stack}", "{approach} simplified"
- **Evaluate tradeoffs explicitly**: What do you gain/lose by adapting?
- **Consider migration paths**: Can you evolve toward recommended approach?
- **Document constraints**: Note why certain approaches don't fit

**Example:**
- Research recommends: Microservices architecture
- Codebase constraint: Monolithic Node.js app, small team
- Compromise: "Modular monolith" approach (microservices principles in monolith)
- Result: Evidence-based adaptation that fits constraints

## When Evidence Quality Varies

**Symptoms:**
- Mix of high-citation and low-citation papers
- Academic and non-academic sources with different quality
- Some evidence cards stronger than others

**Strategies:**
- **Weight evidence systematically**: Use weighting framework (see `guides/guide-weighting.md`)
- **Prioritize high-weight sources**: But don't ignore low-weight if highly relevant
- **Note quality in evidence cards**: Document weighting and reasoning
- **Cross-reference**: Check if low-weight sources align with high-weight
- **Acknowledge limitations**: Be transparent about evidence strength

**Example:**
- High-weight: Foundational paper (500 citations) recommends Approach A
- Low-weight: Recent blog (2024) suggests Approach B improvements
- Strategy: Weight foundational paper higher, but note blog for future consideration
- Decision: Use Approach A, but monitor Approach B developments

## Research Quality Assessment

**How to know when research is sufficient:**

**Indicators of Sufficient Research:**
- ✅ 5+ evidence cards covering diverse approaches
- ✅ Both conflicting and supporting evidence included
- ✅ Mix of foundational (high citations) and recent (SOTA) sources
- ✅ Non-academic sources included for practical insights
- ✅ Evidence cards have sufficient depth (multiple sources per approach)
- ✅ Research question is answered or can be answered with current evidence

**When to Continue Research:**
- ⚠️ <5 evidence cards (need broader coverage)
- ⚠️ All evidence cards support same approach (need conflicting perspectives)
- ⚠️ Missing key aspects of research question (need more sources)
- ⚠️ Evidence quality too low (need higher-weight sources)
- ⚠️ No clear answer to research question (need more evidence)

**When to Synthesize:**
- ✅ 5+ evidence cards with diverse approaches
- ✅ Sufficient evidence to compare approaches
- ✅ Can make evidence-based recommendations
- ✅ Research question can be answered with current evidence

