---
name: search
description: Search the web and library documentation using Tavily and Context7 MCPs. Use when: (1) Looking up documentation for libraries or frameworks, (2) Searching for code examples or tutorials, (3) Finding API references or specifications, (4) Researching best practices or solutions, (5) Looking up error messages or troubleshooting guides, (6) Finding library installation instructions, or (7) When you need current web information or documentation. Triggers: "search", "look up", "find documentation", "search web", "lookup", "find examples", "search for", "how to", "tutorial", "API reference", "documentation for", "error message", "troubleshoot", "best practices".
---

# Search

Search the web and library documentation using Tavily and Context7 MCPs. Start with simple searches and escalate to advanced methods only when initial results are insufficient or when encountering repeated problems.

## MCPs Used

- **Tavily MCP** - Web search, content extraction, and website crawling
- **Context7 MCP** - Library documentation and API references

## Available Tools

### Tavily MCP

- **`tavily_search`** - Web search with filters (search_depth, topic, time_range, domains, max_results)
- **`tavily_extract`** - Extract content from URLs (extract_depth: basic/advanced, format: markdown/text)
- **`tavily_crawl`** - Crawl multiple pages from a website (max_depth, select_paths, limit)
- **`tavily_map`** - Map website structure without extracting content

### Context7 MCP

- **`resolve-library-id`** - Resolve library name to Context7 ID
- **`get-library-docs`** - Get documentation (mode: code/info, topic, page)

### Built-in Web Search Tools (When Available)

**Note:** Some agents provide built-in web search tools. Always check for and use them in addition to Tavily for:
- Broader search coverage
- Different search algorithms/perspectives
- Parallel searches for faster results
- Cross-validation of results

If built-in web search tools are available, use them alongside Tavily and Context7. If not available, rely on MCP tools.

## Search Strategy: Progressive Escalation

**Core Principle:** Start simple, escalate only when needed. Use advanced methods for insufficient results or repeated problems.

### Level 1: Simple Search (Default)

**When to use:** Most searches, quick lookups, straightforward questions

**Approach:**
1. **Built-in web search** (if available) - Use native web search tools provided by the agent
2. **Tavily basic search** (`search_depth: "basic"`, `max_results: 5`) - For web information
3. **Context7 docs** (if library-related, `mode: "code"`, no topic filter) - For official documentation
4. **Parallel execution** - Run built-in web search + Tavily simultaneously if both available
5. **Evaluate results** - Are they sufficient?

**If sufficient:** ✅ Use results, done.

**If insufficient:** ⚠️ Proceed to Level 2.

### Level 2: Enhanced Search (Insufficient Results)

**When to use:** Initial results don't fully answer the question

**Approach:**
1. **Expand query** - Add synonyms, related terms, or context
2. **Increase results** - `max_results: 10-15`, `search_depth: "advanced"`
3. **Domain filtering** - Use `include_domains` for trusted sources
4. **Time filtering** - Add `time_range` for recent information
5. **Parallel searches** - Run built-in web search (if available) + Tavily + Context7 simultaneously
6. **Extract top URLs** - Use `tavily_extract` on 2-3 most relevant results

**If sufficient:** ✅ Use results, done.

**If insufficient:** ⚠️ Proceed to Level 3.

### Level 3: Deep Research (Repeated Problems or Complex Topics)

**When to use:**
- Same problem encountered multiple times
- Complex topic requiring comprehensive understanding
- Building knowledge base for documentation
- User explicitly requests thorough research

**Approach:**
1. **Query expansion** - Generate 3-5 query variations with synonyms and related terms
2. **Parallel execution** - Run all variations simultaneously using built-in web search (if available) + Tavily + Context7
3. **Systematic extraction** - Extract content from top 5-10 URLs
4. **Website exploration** - Use `tavily_map` then `tavily_crawl` for documentation sites
5. **Multi-tool synthesis** - Combine built-in web search results (if available) + Tavily community content + Context7 official docs
6. **Cross-reference** - Verify information across multiple sources and search tools

## Decision Framework

### Start with Simple Search When:
- ✅ Quick lookup needed
- ✅ Single, specific question
- ✅ First time encountering topic
- ✅ Simple "how to" or "what is" questions

### Escalate to Enhanced Search When:
- ⚠️ Initial results are incomplete or unclear
- ⚠️ Need more examples or variations
- ⚠️ Results seem outdated
- ⚠️ Need to verify information

### Escalate to Deep Research When:
- 🔍 Same problem encountered 2+ times
- 🔍 Complex topic requiring comprehensive understanding
- 🔍 Building documentation or knowledge base
- 🔍 User explicitly requests thorough research
- 🔍 Need to compare multiple approaches or libraries

## References

See reference files for detailed guides:

**Parameters:**
- `search_depth: "basic"` (default) → `"advanced"` (if insufficient)
- `max_results: 5` (default) → `10-20` (if insufficient)
- `include_domains`: Trusted sources (Stack Overflow, GitHub, official docs)
- `exclude_domains`: Filter low-quality sources
- `time_range`: "week" or "month" for recent information

### Use Tavily `tavily_extract` for:
- Deep-diving into specific URLs from search results
- Getting full content from articles or documentation
- Extracting code examples or tutorials

**When to use:**
- After identifying 2-5 highly relevant URLs
- When search snippets aren't sufficient
- For technical documentation with code examples

**Parameters:**
- `extract_depth: "basic"` (default) → `"advanced"` (for tables, embedded content)
- `query`: Rerank content chunks by relevance
- `format: "markdown"` (preserves structure and code blocks)

### Use Tavily `tavily_crawl` for:
- Systematic exploration of documentation sites
- Gathering information from multi-page tutorials
- Building comprehensive knowledge base

**When to use:**
- Level 3 (deep research) only
- Learning new library or framework comprehensively
- User explicitly requests thorough exploration

**Parameters:**
- `max_depth: 1-2` (start shallow, increase if needed)
- `select_paths`: Focus on relevant sections (e.g., `["/docs/.*", "/api/.*"]`)
- `exclude_paths`: Skip irrelevant pages
- `limit: 20-50` (based on needs)

### Use Tavily `tavily_map` for:
- Understanding website structure before crawling
- Finding specific pages to extract
- Planning targeted extraction strategy

**When to use:**
- Before `tavily_crawl` to understand structure
- Level 3 (deep research) only

### Use Context7 `resolve-library-id` then `get-library-docs` for:
- Official library documentation
- API references and code examples
- Framework-specific patterns

**Parameters:**
- `mode: "code"` - API references, code examples, implementation details
- `mode: "info"` - Conceptual guides, architecture, best practices
- `topic` - Narrow down large documentation sets
- `page` - Get more content if initial results insufficient

## Query Formulation

### Good Queries
- ✅ Specific and contextual: "Next.js 14 App Router API routes authentication"
- ✅ Include technology and use case: "React hooks useState best practices"
- ✅ Specify information type: "TypeScript generic types tutorial"
- ✅ Natural language: Full sentences work better than keywords

### Poor Queries
- ❌ Too broad: "React"
- ❌ Too vague: "error"
- ❌ Missing context: "how to"

### Query Expansion Strategies (Level 2-3)

**Synonym expansion:**
- Original: "React state management"
- Expanded: "React state management hooks useState useReducer patterns"

**Decomposition:**
- Complex: "Next.js authentication with JWT and refresh tokens"
- Decomposed: ["Next.js JWT authentication", "Next.js refresh token implementation"]

**Progressive broadening:**
- Start: "Next.js 14 App Router API routes"
- Broaden: "Next.js App Router API routes" → "Next.js API routes"

**Context-aware:**
- Use terms from initial results to generate new queries

## Common Search Patterns

### Error Message Resolution
1. **Level 1:** Search exact error message in quotes with `include_domains: ["stackoverflow.com"]`
2. **Level 2:** Remove quotes, add context and solution keywords
3. **Level 3:** Extract top Stack Overflow answers, cross-reference with official docs

### Best Practices Research
1. **Level 1:** "Technology best practices 2024" with `time_range: "year"`
2. **Level 2:** Add domain filtering for authoritative sources, extract top guides
3. **Level 3:** Parallel searches for different aspects, systematic comparison

### API Reference Lookup
1. **Level 1:** Context7 `get-library-docs` with `mode: "code"` and specific `topic`
2. **Level 2:** Add Tavily search for examples, extract from GitHub/docs
3. **Level 3:** Crawl official documentation site, extract comprehensive examples

### Tutorial Discovery
1. **Level 1:** "Technology tutorial step by step" with domain filtering
2. **Level 2:** Extract tutorial content, find related tutorials
3. **Level 3:** Crawl tutorial series, extract all relevant content

## Workflow Examples

### Example 1: Simple Lookup (Level 1)
**Query:** "How to use React useState hook"

1. Tavily search: `search_depth: "basic"`, `max_results: 5`
2. Context7: React docs on hooks (`mode: "code"`, `topic: "hooks"`)
3. ✅ Results sufficient → Use and done

### Example 2: Insufficient Results (Level 1 → 2)
**Query:** "Next.js middleware authentication"

1. **Level 1:** Basic search returns partial information
2. **Level 2:** 
   - Expand: "Next.js middleware authentication JWT tokens"
   - Increase: `max_results: 10`, `search_depth: "advanced"`
   - Extract: Top 3 URLs with `extract_depth: "advanced"`
3. ✅ Results sufficient → Use and done

### Example 3: Repeated Problem (Level 1 → 3)
**Query:** "TypeScript generic constraints" (encountered 3rd time)

1. **Level 1:** Basic search (already tried before)
2. **Level 3:**
   - Parallel queries: ["TypeScript generic constraints", "TypeScript extends keyword generics", "TypeScript generic type parameters"]
   - Extract: Top 5 URLs from each query
   - Context7: TypeScript docs (`mode: "info"`, `topic: "generics"`)
   - Crawl: TypeScript handbook section on generics
   - Synthesize: Comprehensive understanding

## Best Practices

### General
- Start simple, escalate only when needed
- Use parallel execution for independent searches
- Cross-reference multiple sources for important decisions
- Prefer official documentation when available
- Check recency for time-sensitive information

### Performance
- Use `search_depth: "basic"` for speed (default)
- Use `max_results: 5` for quick lookups (default)
- Extract URLs only when snippets insufficient
- Crawl only for comprehensive research (Level 3)

### Quality
- Use `include_domains` for trusted sources
- Use `exclude_domains` to filter low-quality sources
- Verify information with multiple sources
- Document sources for future reference

## Integration with Other Skills

### With docs-check
- Search for documentation standards when updates suggested
- Find examples of similar documentation patterns

### With docs-write
- Search for templates, style guides, and best practices
- Research similar libraries' documentation approaches

### With code-review
- Search for explanations of review feedback
- Find best practices related to review comments

### With research
- Use search to find related web resources for academic papers
- Cross-reference academic findings with current best practices

## Output

Search results are used directly in context. No files are saved unless explicitly requested. For comprehensive research workflows with evidence cards, use the `research` skill.
