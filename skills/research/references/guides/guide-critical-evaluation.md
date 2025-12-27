# Critical Evaluation Guide

How to critically evaluate research approaches to determine which best fits your codebase context.

## Purpose

After creating evidence cards, critically evaluate each approach to determine which best fits your codebase context and requirements. This phase transforms research into actionable decisions.

**When to Perform:** After Step 3 (creating 5+ evidence cards) and before Step 4 (generating report). Critical evaluation informs the synthesis and recommendations in the final report.

## Evaluation Framework

### 1. Assess Strengths of Each Approach

For each evidence card, identify:
- **What does this approach do well?** (from evidence cards)
- **What evidence supports its effectiveness?** (citations, multiple sources)
- **What contexts does it work best in?** (from evidence cards' "When to Use" sections)
- **What are its primary benefits?** (synthesized from evidence)

**Example Evaluation:**
- **Raft Consensus**: Strengths = Simplicity, understandability, strong safety guarantees. Evidence = 7,000+ citations, multiple validation studies. Works best in = Small to medium clusters, crash-fault scenarios.

### 2. Identify Weaknesses and Limitations

For each evidence card, identify:
- **What are the limitations?** (from evidence cards' "Tradeoffs/Limitations" sections)
- **When does this approach fail?** (from "Failure Modes" sections)
- **What tradeoffs does it require?** (from "Tradeoffs" sections)
- **What assumptions must be met?** (from "Assumptions/Conditions" sections)

**Example Evaluation:**
- **Raft Consensus**: Weaknesses = Doesn't handle Byzantine faults, requires majority for progress. Fails when = Network partitions, malicious nodes. Tradeoffs = Simplicity vs. fault tolerance.

### 3. Evaluate for Your Codebase Context

**Critical Questions:**
- **Does this fit your codebase architecture?** (from Step 0 codebase context)
- **Can your team implement this?** (team expertise, complexity)
- **Do you have required infrastructure?** (dependencies, infrastructure needs)
- **Does it meet your constraints?** (performance, scalability, cost)
- **Is it compatible with existing technologies?** (from codebase context)

**Example Evaluation:**
- **Raft Consensus**: Fits Node.js stack? ✅ Yes, multiple implementations available. Team expertise? ✅ Team has experience with distributed systems. Infrastructure? ✅ Can run on existing Kubernetes cluster. Constraints? ✅ Meets performance requirements. Compatible? ✅ Works with existing PostgreSQL.

### 4. Compare Tradeoffs Systematically

**Create Comparison Matrix:**

| Approach | Primary Strength | Primary Limitation | Best For | Fits Our Context? |
|----------|------------------|-------------------|----------|-------------------|
| Raft | Simplicity | No Byzantine tolerance | Small-medium clusters | ✅ Yes |
| PBFT | Byzantine tolerance | Complexity | Large clusters, security-critical | ❌ Too complex |
| Alternative | SOTA features | Less validated | Experimental projects | ⚠️ Consider for future |

**Weight Evidence for Each Criterion:**
- Use weighting framework to assess evidence strength
- Consider your specific context (codebase, team, constraints)
- Identify which criteria matter most for your decision

### 5. Identify Best Fit

**Synthesis Process:**
1. **Weight evidence** for each approach (using weighting framework)
2. **Assess codebase fit** (from Step 0 context)
3. **Evaluate constraints** (performance, scalability, team expertise)
4. **Consider tradeoffs** (what you gain vs. what you lose)
5. **Make recommendation** based on weighted evidence + context fit

**Example Decision:**
- **Evidence**: Raft has strongest evidence (high citations, multiple papers)
- **Codebase fit**: ✅ Fits Node.js stack, team has experience
- **Constraints**: ✅ Meets performance requirements, scalable enough
- **Tradeoffs**: Acceptable (simplicity > Byzantine tolerance for our use case)
- **Recommendation**: Raft is the best fit because [evidence] + [codebase fit] + [constraints] + [tradeoffs acceptable]

## Critical Evaluation Checklist

Before moving to report generation, ensure you have:

- [ ] Assessed strengths of each approach
- [ ] Identified weaknesses and limitations
- [ ] Evaluated fit for your codebase context
- [ ] Compared tradeoffs systematically
- [ ] Weighted evidence for each approach
- [ ] Identified which approach fits best and why
- [ ] Documented evaluation in evidence cards or notes

