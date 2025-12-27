# Evidence Card: {Approach Name}

## Metadata
- **Approach Name:** {Descriptive name of the approach}
- **Research Topic:** {Topic this approach relates to}
- **Papers Included:** {Number} papers
- **Created:** {Timestamp}
- **Updated:** {Timestamp}

## Approach Overview

{2-3 paragraph overview of what this approach is, key characteristics, when it emerged, and how it differs from other approaches}

**Key Characteristics:**
- {Characteristic 1}
- {Characteristic 2}
- {Characteristic 3}

## Papers Supporting This Approach

### Paper 1: {Title}
- **Authors:** {Author list}
- **Year:** {Publication year}
- **DOI:** {DOI if available}
- **URL:** {Official URL for re-downloading}
- **Source:** {arXiv/Publisher/etc.}
- **Source Type:** Academic paper
- **Weighting:** High (peer-reviewed, highly cited)
- **Key Contribution:** {How this paper supports the approach}
- **Brief Summary:** {1-2 sentence summary}

### Paper 2: {Title}
[Same structure as Paper 1]

### Paper 3: {Title}
[Same structure as Paper 1]

## Non-Academic Sources Supporting This Approach

{Non-academic sources (blogs, docs, tutorials) that support this approach. Weighted lower than academic papers but valuable for SOTA and practical insights.}

### Source 1: {Title/Name}
- **Type:** {Blog post / Documentation / Tutorial / Case study}
- **URL:** {Source URL}
- **Author/Organization:** {Author or organization name}
- **Date:** {Publication date if available}
- **Weighting:** {Low / Medium - based on source type and authority}
- **Quality Indicators:** {Recency, authority, practical value}
- **Key Contribution:** {How this source supports the approach}
- **Brief Summary:** {1-2 sentence summary}

### Source 2: {Title/Name}
[Same structure as Source 1]

**Note on Weighting:**
- **Academic papers** (high weight): Peer-reviewed, highly cited, foundational
- **Non-academic sources** (lower weight): Blogs, docs, tutorials - may be more SOTA or up-to-date but less authoritative. Still valuable for practical insights and current best practices.

## Key Claims

{3-5 synthesized claims that this approach demonstrates across multiple papers. These should be specific and actionable, not just paper summaries.}

### Claim 1: {What this approach demonstrates}
{Clear statement of the claim, supported by multiple papers}

### Claim 2: {What this approach demonstrates}
{Clear statement of the claim, supported by multiple papers}

### Claim 3: {What this approach demonstrates}
{Clear statement of the claim, supported by multiple papers}

## Supporting Evidence

{Organize evidence by claim. For each claim, provide direct quotes from papers with page numbers.}

### Evidence for Claim 1: {Claim text}

**From {Paper Title} (Page X, Section Y):**
> "{Direct quote from paper}"

**Context:** {Why this supports the claim, what the quote is responding to}

**Relevance:** {How this relates to the research question}

**From {Paper Title} (Page X, Section Y):**
> "{Direct quote from paper}"

**Context:** {Why this supports the claim}

**Relevance:** {How this relates to the research question}

### Evidence for Claim 2: {Claim text}
[Same structure as Claim 1]

### Evidence for Claim 3: {Claim text}
[Same structure as Claim 1]

## Assumptions/Conditions

{When this approach applies - consolidated from all papers in the group}

**Required Conditions:**
- {Condition 1 - must be met for approach to work}
- {Condition 2}
- {Condition 3}

**Assumptions:**
- {Assumption 1 - what the approach assumes}
- {Assumption 2}
- {Assumption 3}

**When to Use:**
- {Scenario 1 - when this approach is appropriate}
- {Scenario 2}
- {Scenario 3}

## Tradeoffs / Limitations

{Consolidated limitations and tradeoffs from all papers}

**Limitations:**
- {Limitation 1 - what this approach doesn't handle}
- {Limitation 2}
- {Limitation 3}

**Tradeoffs:**
- {Tradeoff 1 - what you gain and lose}
- {Tradeoff 2}
- {Tradeoff 3}

## Failure Modes

{When this approach fails or doesn't work - consolidated from all papers}

- **Failure Mode 1:** {When it fails} - {Why it fails, what causes it}
- **Failure Mode 2:** {When it fails} - {Why it fails}
- **Failure Mode 3:** {When it fails} - {Why it fails}

## Related Approaches

{Connections to other evidence cards (approaches). Explicitly note conflicts and alternative viewpoints.}

- **Conflicts with:** {Approach name} - {How they conflict, why different, what conditions matter}
- **Complementary to:** {Approach name} - {How they work together}
- **Alternative to:** {Approach name} - {Different solution to same problem}
- **Improves on:** {Approach name} - {How this builds on or improves}
- **Similar to:** {Approach name} - {How they're similar but different}
- **Opposing viewpoint:** {Approach name} - {Explicitly note when this approach contradicts or opposes another approach}

## Implementation Resources

{Resources found using search skill (Tavily, Context7) for practical implementation of this approach}

### Packages / Libraries

{Packages/libraries that implement this approach}

- **{Package name}** ({Language/Platform}) - {Brief description}
  - URL: {Package URL}
  - Documentation: {Docs URL}
  - Notes: {Usage notes, maturity, community support}

### Implementation Guides / Tutorials

{Blog posts, tutorials, and guides for implementing this approach}

- **{Title}** - {URL}
  - Author: {Author}
  - Summary: {Brief summary of what it covers}
  - Notes: {Key takeaways, code examples included}

### Code Examples

{Code examples and repositories demonstrating this approach}

- **{Example name}** - {URL}
  - Description: {What it demonstrates}
  - Language: {Programming language}
  - Notes: {Key implementation details}

### Real-World Usage

{Real-world examples and case studies}

- **{Company/Project name}** - {URL}
  - Use case: {How they use this approach}
  - Scale: {Scale/context}
  - Notes: {Lessons learned, challenges}

## Methodology Notes

{Key methodological details if relevant - how the approach works, implementation considerations}

## Notes

{Additional observations, questions, connections, or insights that don't fit elsewhere}

---

## Complete Example: Raft Consensus Algorithm

### Metadata
- **Approach Name:** Raft Consensus Algorithm
- **Research Topic:** Distributed Consensus for Leader Election
- **Papers Included:** 3 academic papers, 2 non-academic sources
- **Created:** 2024-01-15T10:30:00Z
- **Updated:** 2024-01-15T14:45:00Z

### Approach Overview

Raft is a consensus algorithm designed to be more understandable than Paxos while providing equivalent safety guarantees. It uses a leader-based approach with log replication and majority voting to achieve distributed consensus. Raft emerged in 2013 as a response to Paxos's complexity, focusing on understandability for practical implementation.

**Key Characteristics:**
- Leader-based design (strong leader model)
- Log replication for consistency
- Majority voting for safety
- Explicit separation of leader election and log replication
- Designed for understandability and practical implementation

### Papers Supporting This Approach

#### Paper 1: "In Search of an Understandable Consensus Algorithm"
- **Authors:** Diego Ongaro, John Ousterhout
- **Year:** 2013
- **DOI:** 10.5555/2643634.2643666
- **URL:** https://raft.github.io/raft.pdf
- **Source:** USENIX ATC 2014
- **Source Type:** Academic paper
- **Weighting:** High (7,000+ citations, peer-reviewed, foundational)
- **Key Contribution:** Introduced Raft as a simpler alternative to Paxos with equivalent safety
- **Brief Summary:** Foundational paper establishing Raft's design principles and proving safety properties.

#### Paper 2: "Raft Refloated: Do We Have Consensus?"
- **Authors:** Heidi Howard, et al.
- **Year:** 2020
- **DOI:** 10.1145/3380787.3393681
- **URL:** https://dl.acm.org/doi/10.1145/3380787.3393681
- **Source:** ACM SIGOPS Operating Systems Review
- **Source Type:** Academic paper
- **Weighting:** High (150+ citations, peer-reviewed, improvements)
- **Key Contribution:** Identified and fixed safety issues in original Raft specification
- **Brief Summary:** Critical analysis of Raft's safety properties with improvements.

#### Paper 3: "Raft Consensus Algorithm: A Comprehensive Survey"
- **Authors:** Multiple authors
- **Year:** 2021
- **DOI:** 10.1109/ACCESS.2021.3056789
- **URL:** https://ieeexplore.ieee.org/document/9351234
- **Source:** IEEE Access
- **Source Type:** Academic paper
- **Weighting:** Medium (45 citations, peer-reviewed, survey)
- **Key Contribution:** Comprehensive survey of Raft variants and applications
- **Brief Summary:** Survey paper covering Raft implementations and extensions.

### Non-Academic Sources Supporting This Approach

#### Source 1: "Raft Implementation Guide - etcd Documentation"
- **Type:** Documentation
- **URL:** https://etcd.io/docs/latest/learning/raft/
- **Author/Organization:** etcd (CNCF project)
- **Date:** 2024 (continuously updated)
- **Weighting:** Medium (authoritative for etcd implementation, practical value)
- **Quality Indicators:** Official documentation, maintained by CNCF, widely used in production
- **Key Contribution:** Practical implementation guidance and production-tested patterns
- **Brief Summary:** Official etcd documentation explaining Raft implementation with code examples.

#### Source 2: "Understanding Raft: The Consensus Algorithm for Distributed Systems"
- **Type:** Blog post / Tutorial
- **URL:** https://example.com/raft-tutorial
- **Author/Organization:** Distributed Systems Expert Blog
- **Date:** 2024-01-10
- **Weighting:** Low (practical tutorial, less authoritative)
- **Quality Indicators:** Recent, clear explanations, code examples, but not peer-reviewed
- **Key Contribution:** Clear tutorial explaining Raft concepts with visualizations
- **Brief Summary:** Educational blog post with step-by-step Raft explanation and diagrams.

**Note on Weighting:**
- **Academic papers** (high weight): Peer-reviewed, highly cited, foundational. Paper 1 (7,000+ citations) provides strongest evidence.
- **Non-academic sources** (lower weight): Documentation and tutorials - valuable for practical implementation and SOTA insights, but less authoritative than peer-reviewed papers.

### Key Claims

#### Claim 1: Raft provides equivalent safety guarantees to Paxos with simpler implementation
Raft achieves the same safety properties as Paxos (consistency, availability during partitions) but through a more understandable design. The leader-based model with explicit states makes correctness easier to reason about.

#### Claim 2: Raft's leader-based design improves understandability and maintainability
The strong leader model simplifies the algorithm by centralizing decision-making. This makes Raft easier to teach, implement, and debug compared to Paxos's peer-to-peer approach.

#### Claim 3: Raft achieves consensus with O(n) messages per operation in normal case
In the normal case (no failures), Raft requires O(n) messages where n is the number of servers. This is efficient for typical cluster sizes (3-10 nodes).

#### Claim 4: Raft handles leader failures through election mechanism
When the leader fails, Raft uses a timeout-based election mechanism to select a new leader. The election ensures safety by requiring majority votes.

### Supporting Evidence

#### Evidence for Claim 1: Raft provides equivalent safety guarantees to Paxos

**From "In Search of an Understandable Consensus Algorithm" (Page 3, Section 2):**
> "Raft provides the same safety guarantees as Paxos, but with a simpler implementation. We prove Raft's safety properties and show that it maintains consistency even during network partitions."

**Context:** This is the core claim of the Raft paper - equivalent safety with simplicity.

**Relevance:** Directly addresses the research question about consensus algorithm choice.

**From "Raft Refloated" (Page 5, Section 3):**
> "Our analysis confirms that Raft maintains the same safety properties as Paxos while being more understandable. The improvements we propose further strengthen these guarantees."

**Context:** Validation of Raft's safety properties with improvements.

**Relevance:** Confirms foundational claim with additional safety improvements.

#### Evidence for Claim 2: Raft's leader-based design improves understandability

**From "In Search of an Understandable Consensus Algorithm" (Page 4, Section 3):**
> "Raft's leader-based design makes the algorithm easier to understand. All decisions flow through the leader, eliminating the need for complex peer-to-peer coordination found in Paxos."

**Context:** Explains the design choice that enables understandability.

**Relevance:** Addresses team expertise constraint - need for understandable algorithm.

#### Evidence for Claim 3: Raft achieves consensus with O(n) messages

**From "In Search of an Understandable Consensus Algorithm" (Page 8, Section 5.1):**
> "In the normal case, Raft requires O(n) messages per operation, where n is the number of servers. This is efficient for typical cluster sizes."

**Context:** Performance analysis of Raft's message complexity.

**Relevance:** Addresses performance requirements (<100ms latency).

### Assumptions/Conditions

**Required Conditions:**
- Crash-fault model (no Byzantine faults)
- Majority of servers must be available for progress
- Network can delay messages but not lose them (eventual delivery)
- Servers have stable storage (logs persist across crashes)

**Assumptions:**
- Network partitions are temporary (eventually heal)
- Servers fail by crashing (not malicious behavior)
- Clock synchronization is approximate (not perfect)
- Cluster size is small to medium (typically 3-10 nodes)

**When to Use:**
- Need distributed consensus for coordination (leader election, configuration)
- Crash-fault tolerance is sufficient (no Byzantine faults)
- Value simplicity and understandability
- Small to medium cluster sizes (3-10 nodes, up to ~100)
- Team needs to understand and maintain the algorithm

### Tradeoffs / Limitations

**Limitations:**
- **No Byzantine fault tolerance**: Doesn't handle malicious nodes (unlike PBFT)
- **Requires majority**: Cannot make progress during network partitions that split majority
- **Leader bottleneck**: All writes go through leader (can limit throughput)
- **Complexity still exists**: Simpler than Paxos but still complex for some teams

**Tradeoffs:**
- **Simplicity vs. Fault tolerance**: Easier to understand but doesn't handle Byzantine faults
- **Leader-based vs. Peer-to-peer**: Simpler coordination but single point of coordination
- **Understandability vs. Theoretical elegance**: Practical focus over mathematical elegance

### Failure Modes

- **Network partitions splitting majority**: System cannot make progress, but maintains safety (no split-brain)
- **Leader failure during election**: Temporary unavailability until new leader elected
- **Clock skew**: Can cause election timeouts, but algorithm handles this
- **Log inconsistencies**: Handled through leader's log replication and majority agreement

### Related Approaches

- **Conflicts with:** PBFT - Different failure model (crash vs Byzantine), PBFT is more complex but handles malicious nodes
- **Improves on:** Paxos - Simpler design while maintaining equivalent safety
- **Alternative to:** Multi-Paxos - Different design philosophy (leader-based vs peer-to-peer)
- **Similar to:** Viewstamped Replication - Also leader-based, but Raft is more recent and better documented

### Implementation Resources

#### Packages / Libraries

- **etcd** (Go) - Production-grade Raft implementation
  - URL: https://github.com/etcd-io/etcd
  - Documentation: https://etcd.io/docs/
  - Notes: CNCF project, widely used in Kubernetes, production-tested

- **hashicorp/raft** (Go) - Library for implementing Raft
  - URL: https://github.com/hashicorp/raft
  - Documentation: https://pkg.go.dev/github.com/hashicorp/raft
  - Notes: Well-documented, used by Consul, good for learning

- **raft-js** (JavaScript/TypeScript) - Raft implementation for Node.js
  - URL: https://github.com/notechs/raft-js
  - Documentation: https://github.com/notechs/raft-js#readme
  - Notes: JavaScript implementation, fits Node.js stack, less mature than Go implementations

#### Implementation Guides / Tutorials

- **"Building a Raft Implementation"** - https://example.com/raft-implementation
  - Author: Distributed Systems Blog
  - Summary: Step-by-step guide to implementing Raft from scratch
  - Notes: Good for understanding internals, includes code examples

#### Code Examples

- **Raft Visualization** - https://raft.github.io/
  - Description: Interactive visualization of Raft algorithm
  - Language: JavaScript
  - Notes: Excellent for understanding Raft's behavior visually

### Methodology Notes

Raft works by:
1. **Leader election**: Servers elect a leader using timeouts and votes
2. **Log replication**: Leader replicates log entries to followers
3. **Majority agreement**: Entries committed when majority acknowledges
4. **Safety**: Ensures consistency through majority voting and log matching

This design makes Raft easier to understand and implement than Paxos while maintaining equivalent safety guarantees.

### Notes

- Raft is widely adopted in production (etcd, Consul use it)
- Strong community support and documentation
- Multiple implementations available in different languages
- Well-suited for our Node.js stack (raft-js available, though etcd via gRPC also viable)
- Team can learn Raft through excellent visualizations and tutorials

