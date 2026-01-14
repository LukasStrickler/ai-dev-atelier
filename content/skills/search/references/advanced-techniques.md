# Advanced Search Techniques

## Two-Step Extraction (Recommended)

**Process:** Search → Filter by score → Extract top URLs

**Benefits:** More control, higher accuracy, better cost efficiency

**When to use:** After identifying 2-5 highly relevant URLs, when search snippets insufficient, for technical documentation

**Detailed Process:**
1. **Step 1:** Search with `search_depth: "advanced"` to find relevant URLs
2. **Step 2:** Filter by score (>0.5), then extract from top URLs
   - Use `extract_depth: "basic"` first, upgrade to `"advanced"` if needed
   - Use `query` parameter to rerank extracted chunks by relevance
   - Use `chunks_per_source: 3-5` for comprehensive coverage (only when `query` provided)

## Post-Processing Techniques

### Score-Based Filtering
- Tavily assigns a `score` to each result indicating relevance
- Higher score = more relevant (no fixed threshold, depends on use case)
- Best practices:
  - Set minimum score threshold (>0.5 typically good)
  - Analyze score distribution to adjust thresholds dynamically
  - Combine scores with other metadata for ranking

### Metadata Utilization
- `title`: Filter by keyword occurrences for better relevancy
- `content`: Quick relevance gauge (better with `search_depth: "advanced"`)
- `raw_content`: Deeper analysis when content insufficient
- `score`: Primary ranking indicator
- `url`: Source verification

### Keyword & Regex Filtering
- Combine LLM analysis with deterministic keyword filtering
- Use regex patterns (`re.search`, `re.findall`) for structured data extraction
- Remove results with unwanted terms
- Prioritize articles with high-value keywords

## Concurrent Execution

- Execute multiple `tavily_search` calls in parallel when queries are independent
- Run Tavily + Context7 + built-in search simultaneously when available
- MCP handles rate limiting and retries automatically
- Use `return_exceptions=True` pattern when running multiple concurrent searches for resilience

## Cost Optimization

- Use `search_depth: "basic"` when possible (1 credit vs 2 for advanced)
- Use `auto_parameters: true` but override `search_depth: "basic"` to control cost
- Prefer two-step extraction over `include_raw_content: true` in search
- Use `extract_depth: "basic"` when possible (1 credit per 5 extractions vs 2)
- Set appropriate `limit` and `max_depth` for crawls
- Use `tavily_map` before `tavily_crawl` to plan efficiently

## Performance Optimization

- Use concurrent execution for multiple independent queries
- Limit concurrent requests to avoid overwhelming the MCP
- Start with shallow crawls (`max_depth: 1`) and increase only if needed
- Use `tavily_map` before `tavily_crawl` to plan efficient crawl strategies

## Error Handling

- The Tavily MCP automatically handles rate limits, timeouts, and network failures
- If a search fails, retry with simpler parameters or break into sub-queries
- Use `return_exceptions=True` pattern when running multiple concurrent searches

## Credit Management

- Monitor credit usage: `basic` search = 1 credit, `advanced` search = 2 credits
- Extract: 1 credit per 5 successful extractions (basic), 2 credits per 5 (advanced)
- Use `search_depth: "basic"` when possible to conserve credits
- Prefer two-step extraction (search then extract) over `include_raw_content: true` for better cost efficiency

## Website Exploration Pattern

Use `tavily_map` first to understand site structure, then `tavily_crawl` for focused extraction:

1. **Map Phase:**
   - `max_depth: 1-2`, `limit: 50-100` to discover structure
   - Identify relevant sections and paths

2. **Crawl Phase:**
   - `max_depth: 2-3`, `select_paths` for focused extraction
   - Use `instructions` parameter for semantic guidance
   - Use `extract_depth: "advanced"` for documentation sites with tables/structured content

## GitHub Code Search Deep Dive

For comprehensive code pattern research:

1. **Multiple Pattern Variations:** Search different ways the same concept might be implemented
2. **Regex for Complex Patterns:** Use `(?s)` prefix for multiline matching
3. **Cross-Repository Comparison:** Compare implementations across different codebases
4. **Filter by Quality Signals:** Focus on repos with stars, recent activity

### GitHub Grep Examples

**Finding API Usage:**
```
Query: getServerSession
Language: ['TypeScript']
Path: '/api/'
```

**Finding Patterns with Regex:**
```
Query: (?s)useEffect\(\(\) => {.*removeEventListener
useRegexp: true
Language: ['TSX']
```

**Complex Multi-line Patterns:**
```
Query: (?s)try {.*await.*catch
useRegexp: true
```

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
