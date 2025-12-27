# Weighting Evidence Guide

How to systematically weight and compare different ideas to make informed decisions.

## Purpose

To make informed decisions, you must systematically weight and compare different ideas. This framework provides a clear process for evaluating evidence strength and determining which approaches are most credible for your context.

## How to Weight Evidence

### Academic Papers - Weight by Citations and Quality

**High Weight (Strongest Evidence):**
- **50+ citations**: Well-established, influential papers
- **Peer-reviewed journals/conferences**: Validated methodology
- **Foundational papers**: Established principles that others build on
- **Multiple sources agreeing**: Higher confidence when several papers support same claim

**Medium Weight (Good Evidence):**
- **10-50 citations**: Solid research, may be newer or more specialized
- **Peer-reviewed**: Still validated, but less influential
- **Recent SOTA (2020+)**: Current best practices, may not have accumulated citations yet

**Lower Weight (Relevant but Less Strong):**
- **<10 citations**: May be very recent, niche, or less influential
- **Still valuable**: Can provide unique perspectives or address specific aspects
- **Use when**: Highly relevant to your specific question or fills gaps

### Non-Academic Sources - Weight by Recency, Authority, and Practical Value

**High Weight (Strong Real-World Evidence):**
- **Case studies from reputable companies**: Real-world validation, especially when they document switching from one approach to another (reveals why not to use Y, why to use X)
- **Company blog posts about technology decisions**: "Why we switched from X to Y" posts provide critical practical insights about tradeoffs, failures, and real-world constraints
- **Production post-mortems and lessons learned**: Documented failures and successes from real implementations
- **Official documentation from major projects (2024+)**: Authoritative for specific tools/frameworks, reflects production-tested patterns

**Medium Weight (Authoritative Practical Sources):**
- **Tutorials from recognized experts**: Practical implementation guidance
- **Recent blog posts (2024+)**: May have latest insights, SOTA approaches
- **Community tutorials**: Practical examples, may reflect current best practices

**Low Weight (Valuable but Less Authoritative):**
- **Stack Overflow / forums**: Specific implementation details, troubleshooting
- **General blog posts**: May have insights but less authoritative

**Important**: Real-world implementation sources (case studies, company decision blogs, post-mortems) often provide **critical insights that academic papers cannot**—they reveal:
- Why approaches fail in production (not just theory)
- Real-world tradeoffs and constraints
- Migration challenges and solutions
- Production-tested patterns and anti-patterns

**Weighting Principle**: Balance academic rigor with practical value. A company blog post about "Why we switched from X to Y" may provide more actionable insights for your decision than a theoretical academic paper. Weight based on:
- **Practical value**: Does it help you understand real-world implications?
- **Authority**: Is the source credible (reputable company, recognized expert)?
- **Recency**: Is it current (2020+ preferred)?
- **Specificity**: Does it address your specific use case or constraints?

**Example**: A company blog post documenting why they switched from microservices to modular monolith (with specific failure modes and metrics) may be weighted **high** because it provides practical insights that complement academic theory.

## Weighting Process

**Step 1: Assess Each Source**
- **Academic papers**: Check citation count, publication venue, peer-review status
- **Non-academic**: Check recency, author/organization authority, practical value
- **Document in evidence card**: Note weighting (high/medium/low) and reasoning

**Step 2: Compare Evidence Strength**
- **Multiple high-weight sources agreeing** = Very strong evidence
- **High-weight academic + high-weight practical sources** = Strongest evidence (theory + practice)
- **High-weight + medium-weight sources agreeing** = Strong evidence
- **Conflicting high-weight sources** = Important tradeoff to explore
- **Low-weight sources with unique insights** = May fill gaps or provide SOTA perspective

**Balancing Academic and Practical:**
- **Academic papers** provide: Theoretical foundation, correctness proofs, established principles
- **Real-world sources** provide: Production validation, failure modes, migration challenges, practical constraints
- **Best evidence**: Combination of both—academic rigor + practical validation

**Step 3: Apply to Your Context**
- **Your codebase constraints** = Determines which evidence matters most
- **Your team expertise** = Affects feasibility of different approaches
- **Your requirements** = Prioritizes certain evidence over others

## Example Weighting

**Research Topic**: "Distributed Consensus Algorithms"

**Evidence Card 1: Raft Consensus**
- Paper A: "In Search of an Understandable Consensus Algorithm" (2013, 7,000+ citations, peer-reviewed) → **High weight** (foundational)
- Paper B: "Raft Refloated" (2020, 150 citations, peer-reviewed) → **High weight** (improvements)
- Blog post: "Raft Implementation Guide" (2024, official etcd docs) → **Medium weight** (authoritative practical)
- **Overall**: Strong evidence, well-established approach

**Evidence Card 2: Alternative Consensus**
- Paper C: "New Consensus Algorithm" (2023, 25 citations, peer-reviewed) → **Medium weight** (recent, fewer citations)
- Blog post: "Why We Switched to New Algorithm" (2024, company blog from reputable tech company) → **High weight** (real-world implementation insights, documents why they switched, production-tested)
- **Overall**: Strong practical evidence from real-world implementation, newer approach, validated in production

**Decision Weighting:**
- Raft has stronger academic evidence (high citations, multiple papers)
- Alternative has strong practical evidence (real-world implementation, documented migration, production-tested)
- **For production system**: Weight both highly—Raft for academic rigor, Alternative for practical validation
- **Synthesis**: Academic papers provide theoretical foundation, company blog provides practical validation and real-world constraints
- **Decision**: Consider both—academic evidence establishes correctness, practical evidence validates feasibility and reveals production challenges

## When Sources Conflict

**Conflicting High-Weight Sources:**
- Both have strong evidence but disagree
- **Resolution**: Identify conditions where each applies
- **Example**: Approach A works best for small clusters, Approach B for large clusters

**High-Weight Academic vs High-Weight Practical Conflict:**
- Academic paper (high) vs company case study/blog (high)
- **Resolution**: Both are valuable—academic provides theory, practical provides real-world validation
- **Action**: Weight both highly, synthesize insights. Academic establishes correctness, practical reveals production challenges and constraints
- **Example**: Academic paper proves algorithm correctness, company blog reveals why it failed in their specific production environment

**High-Weight vs Low-Weight Conflict:**
- Academic paper (high) vs general blog post (low)
- **Resolution**: Academic paper has stronger evidence, but blog may reflect newer practices or specific insights
- **Action**: Weight academic higher, but acknowledge blog insights if they address specific practical concerns

**Multiple Sources with Different Findings:**
- Several papers with varying results
- **Resolution**: Identify patterns, note context-dependent differences
- **Action**: Weight based on your specific context and requirements

