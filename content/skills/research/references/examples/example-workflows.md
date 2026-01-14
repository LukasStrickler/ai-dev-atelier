# Research Examples Guide

Complete examples showing the decision-making process from research to implementation.

## Example 1: Architecture Decision - Distributed Consensus

**Task**: "Research distributed consensus algorithms for our distributed system"

**Decision-Making Process:**

1. **Step 0**: Gather codebase context
   - Found: Node.js microservices, Kubernetes deployment, PostgreSQL database
   - Current: No consensus implementation, need for distributed coordination
   - Constraints: Small team, need simplicity, crash-fault tolerance sufficient

2. **Step 1**: Research question
   - Question: "Which consensus algorithm fits our Node.js microservices architecture with crash-fault tolerance requirements?"
   - Context: Small team, need understandability, Kubernetes infrastructure

3. **Step 2**: Comprehensive discovery (25+ sources)
   - Academic: Paxos (7,000+ citations), Raft (7,000+ citations), PBFT (2,000+ citations)
   - Non-academic: "Raft implementation Node.js", "Consensus algorithms comparison 2024"
   - Conflicts: Found papers debating Raft vs Paxos simplicity

4. **Step 3**: Evidence cards (5+ cards)
   - Card 1: Raft (high weight - strong evidence, fits Node.js)
   - Card 2: Paxos (high weight - foundational, but complex)
   - Card 3: PBFT (medium weight - overkill for crash faults)
   - Card 4: Alternative approaches (lower weight - newer, less validated)
   - Card 5: Conflicts (Raft simplicity vs Paxos theoretical elegance)

5. **Critical Evaluation**:
   - **Raft**: ✅ Fits Node.js, ✅ Team can understand, ✅ Meets requirements
   - **Paxos**: ❌ Too complex for team, ⚠️ Harder to implement
   - **PBFT**: ❌ Overkill (Byzantine not needed)
   - **Weighting**: Raft has strong evidence + best codebase fit

6. **Step 4**: Report and decision
   - **Recommendation**: Raft consensus
   - **Rationale**: Strong evidence (high citations) + fits Node.js stack + team expertise + meets constraints
   - **Implementation**: Use etcd (Raft implementation) for coordination

**Outcome**: Evidence-based decision with clear rationale tied to codebase context.

## Example 2: Technology Selection - Authentication Strategy

**Task**: "Research authentication strategies for our microservices API"

**Decision-Making Process:**

1. **Step 0**: Codebase context
   - Found: REST API, microservices, Node.js/Express, JWT currently used
   - Problem: JWT validation overhead, need stateless auth
   - Constraints: Must work across services, low latency required

2. **Step 1**: Research question
   - Question: "Which authentication strategy provides stateless, low-latency auth for microservices?"
   - Context: Current JWT issues, need better performance

3. **Step 2**: Discovery (25+ sources)
   - Academic: OAuth2, JWT optimization, session-based auth papers
   - Non-academic: "Microservices authentication patterns 2024", "JWT vs OAuth2 performance"
   - Conflicts: Found debates on JWT vs OAuth2 for microservices

4. **Step 3**: Evidence cards (5+ cards)
   - Card 1: JWT optimization (high weight - current approach, can improve)
   - Card 2: OAuth2 (high weight - industry standard)
   - Card 3: Session-based (medium weight - stateful, higher latency)
   - Card 4: API keys (low weight - simple but less secure)
   - Card 5: Conflicts (stateless vs stateful, performance vs security)

5. **Critical Evaluation**:
   - **JWT optimization**: ✅ Already using, ✅ Can improve without migration
   - **OAuth2**: ⚠️ More complex, ⚠️ Higher latency, ✅ Better for external APIs
   - **Weighting**: JWT optimization has practical value (current stack) + academic support
   - **Context fit**: Optimization fits better than migration

6. **Step 4**: Report and decision
   - **Recommendation**: Optimize JWT (short-term) + plan OAuth2 (long-term for external APIs)
   - **Rationale**: Evidence supports both, but optimization fits immediate needs
   - **Implementation**: JWT caching, shorter tokens, async validation

**Outcome**: Context-aware recommendation balancing evidence with practical constraints.

## Example 3: Performance Optimization - Database Query Patterns

**Task**: "Research database query optimization patterns for our PostgreSQL system"

**Decision-Making Process:**

1. **Step 0**: Codebase context
   - Found: PostgreSQL, Node.js, slow queries on user lookup
   - Current: N+1 query problem, missing indexes
   - Constraints: Can't change database, need quick wins

2. **Step 1**: Research question
   - Question: "Which query optimization patterns improve PostgreSQL performance for our N+1 query issues?"
   - Context: PostgreSQL constraints, need immediate improvements

3. **Step 2**: Discovery (25+ sources)
   - Academic: Query optimization papers, indexing strategies, N+1 solutions
   - Non-academic: "PostgreSQL performance tuning 2024", "N+1 query solutions"
   - Conflicts: Eager loading vs lazy loading, indexing strategies

4. **Step 3**: Evidence cards (5+ cards)
   - Card 1: Eager loading (high weight - solves N+1, well-established)
   - Card 2: Database indexing (high weight - foundational, strong evidence)
   - Card 3: Query batching (medium weight - recent pattern, good results)
   - Card 4: Caching strategies (medium weight - complements optimization)
   - Card 5: Conflicts (eager loading overhead vs N+1 queries)

5. **Critical Evaluation**:
   - **Eager loading**: ✅ Solves N+1, ✅ Fits ORM (Sequelize), ✅ Quick to implement
   - **Indexing**: ✅ Foundational, ✅ Long-term benefit, ✅ Fits PostgreSQL
   - **Weighting**: Both have strong evidence, both needed
   - **Context fit**: Both work with current stack

6. **Step 4**: Report and decision
   - **Recommendation**: Combine eager loading (immediate) + indexing (ongoing)
   - **Rationale**: Evidence supports both, complementary benefits
   - **Implementation**: Add eager loading to user queries, create indexes on lookup columns

**Outcome**: Multi-pronged approach based on weighted evidence and codebase fit.

## Example 4: Security Pattern - API Rate Limiting

**Task**: "Research API rate limiting strategies to prevent abuse"

**Decision-Making Process:**

1. **Step 0**: Codebase context
   - Found: Express.js API, Redis available, need protection from abuse
   - Current: No rate limiting, experiencing DDoS-like traffic
   - Constraints: Must be stateless, low overhead, Redis available

2. **Step 1**: Research question
   - Question: "Which rate limiting strategy provides effective protection with minimal overhead for our Express.js API?"
   - Context: Redis available, stateless requirement, need quick implementation

3. **Step 2**: Discovery (25+ sources)
   - Academic: Rate limiting algorithms, token bucket, sliding window
   - Non-academic: "API rate limiting best practices 2024", "Redis rate limiting patterns"
   - Conflicts: Token bucket vs sliding window, fixed vs dynamic limits

4. **Step 3**: Evidence cards (5+ cards)
   - Card 1: Token bucket (high weight - well-established, efficient)
   - Card 2: Sliding window (high weight - accurate, more complex)
   - Card 3: Fixed window (medium weight - simple, less accurate)
   - Card 4: Redis-based implementation (medium weight - practical, fits stack)
   - Card 5: Conflicts (accuracy vs simplicity, memory vs CPU tradeoffs)

5. **Critical Evaluation**:
   - **Token bucket**: ✅ Efficient, ✅ Fits Redis, ✅ Well-documented
   - **Sliding window**: ⚠️ More complex, ✅ More accurate, ⚠️ Higher overhead
   - **Weighting**: Token bucket has strong evidence + better fit for constraints
   - **Context fit**: Token bucket works with Redis, stateless, low overhead

6. **Step 4**: Report and decision
   - **Recommendation**: Token bucket algorithm with Redis
   - **Rationale**: Strong evidence + fits Redis infrastructure + meets constraints
   - **Implementation**: Use `express-rate-limit` with Redis store, token bucket algorithm

**Outcome**: Security decision based on evidence and infrastructure fit.

