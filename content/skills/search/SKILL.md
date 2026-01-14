---
name: search
description: "Search the web, library documentation, and GitHub repositories using Tavily, Context7, and GitHub Grep MCPs. Use when: (1) Looking up documentation for libraries or frameworks, (2) Searching for code examples or tutorials, (3) Finding API references or specifications, (4) Researching best practices or solutions, (5) Looking up error messages or troubleshooting guides, (6) Finding library installation instructions, (7) Searching for real-world code patterns in GitHub repositories, or (8) When you need current web information or documentation. Triggers: search, look up, find documentation, search web, lookup, find examples, search for, how to, tutorial, API reference, documentation for, error message, troubleshoot, best practices, find code examples, GitHub search."
metadata:
  author: ai-dev-atelier
  version: "1.0"
---

# Search

Search web, library docs, and GitHub code using progressive escalation.

## Quick Start

**Decision Tree:**
- **Library/framework docs?** → Context7 `get-library-docs`
- **Code examples/patterns?** → GitHub Grep `grep_searchGitHub`
- **Web info/tutorials?** → Tavily `tavily_search`
- **Error screenshot/diagram?** → Z.AI Vision `diagnose_error_screenshot` / `understand_technical_diagram`
- **Multiple sources needed?** → Run tools in parallel

**Default Workflow:**
1. Start simple: `search_depth: "basic"`, `maxResults: 5`
2. If insufficient: Escalate to Level 2 (expand query, increase results)
3. If repeated problem: Escalate to Level 3 (parallel queries, extraction, crawling)

## Agent Roles

**If you are the main agent (orchestrator):**
- **External questions** → Fire 3-5 `librarian` agents in parallel with different angles
- **Local codebase patterns** → Fire `explore` in background
- **Quick web lookups** → Do Tavily yourself (faster than delegation overhead)
- **Build confidence** → Fire multiple librarians: 2 for docs, 2 for real-world examples, 2 to find edge cases/gotchas
- Collect results with `background_output`, synthesize, cross-validate

**If you are the librarian (subagent):**
- **You are the WORKHORSE** - do NOT be lazy or return minimal results
- **Fire 3-5 parallel tool calls** depending on request complexity (see TYPE A/B/C/D in your system prompt)
- **Vary your queries** - different angles, not the same pattern repeated
- **Always cite with permalinks** - every claim needs `[Source](url#L10-L20)` format
- **Rate your confidence** - end with: `CONFIDENCE: HIGH/MEDIUM/LOW` and why

### Subagent Calling Example

```typescript
// GOOD: Fire multiple librarians with different angles for comprehensive coverage
background_task({
  agent: "librarian",
  prompt: `Find OFFICIAL documentation for Next.js 15 App Router authentication.

FIRST: MUST load and read 'search' skill before starting
LEVEL: 3 (deep research - parallel queries, thorough extraction)
FOCUS: Official Next.js and next-auth docs only
TOOLS: Context7 for Next.js, next-auth docs
FORMAT: Use markdown tables for comparisons, code blocks for snippets
OUTPUT: Official recommended approach with doc permalinks
END WITH: CONFIDENCE rating (HIGH/MEDIUM/LOW) and reasoning`
})

background_task({
  agent: "librarian", 
  prompt: `Find REAL-WORLD implementations of Next.js 15 authentication.

FIRST: MUST load and read 'search' skill before starting
LEVEL: 3 (deep research - multiple pattern variations, cross-repo)
FOCUS: Production codebases on GitHub
TOOLS: grep_searchGitHub with queries: "getServerSession(", "auth(", language: TypeScript
FORMAT: For each example: repo name, permalink, architecture notes
OUTPUT: 3-5 code examples with GitHub permalinks, note patterns/variations
END WITH: CONFIDENCE rating (HIGH/MEDIUM/LOW) and reasoning`
})

background_task({
  agent: "librarian",
  prompt: `Find EDGE CASES and GOTCHAS for Next.js 15 authentication.

FIRST: MUST load and read 'search' skill before starting
LEVEL: 3 (deep research - cross-reference multiple sources)
FOCUS: Issues, discussions, Stack Overflow
TOOLS: zai-zread_search_doc for repo issues/discussions (thorough), tavily_search for blog posts/SO
FORMAT: Problem → Evidence → Solution table
OUTPUT: Common pitfalls, breaking changes, migration issues
END WITH: CONFIDENCE rating (HIGH/MEDIUM/LOW) and reasoning`
})

// Then collect and cross-validate:
// - Do real-world examples match official docs?
// - Are there gotchas the docs don't mention?
// - Synthesize into recommendation with overall confidence

// BAD: No skill loading, no structure
background_task({
  agent: "librarian", 
  prompt: "How does Next.js auth work?"  // Missing FIRST step, no level, no format = lazy results
})
```

## Tools Overview

### Tavily (Web Search)
| Tool | When to Use | Key Params |
|------|-------------|------------|
| `tavily_search` | General web search, tutorials, blog posts, news | `search_depth`: "basic"/"advanced", `max_results`: 5-20, `time_range`: "day"/"week"/"month"/"year", `include_domains`: filter to specific sites |
| `tavily_extract` | Get full content from specific URLs (after search) | `extract_depth`: "basic"/"advanced", `query`: rerank chunks by relevance |
| `tavily_crawl` | Crawl multiple pages from a docs site | `max_depth`: 1-3, `limit`: max pages, `select_paths`: regex to include, `instructions`: natural language filter |
| `tavily_map` | Discover site structure before crawling | `max_depth`: 1-3, `limit`: max URLs to return |
| `websearch_web_search_exa` | Alternative web search (Exa AI) | `numResults`: 5-20, `type`: "auto"/"fast"/"deep" |

### Context7 (Library Docs)
| Tool | When to Use | Key Params |
|------|-------------|------------|
| `resolve-library-id` | Get library ID (required first) | `libraryName`: package name |
| `get-library-docs` | Fetch official docs | `mode`: "code" for API/params, "info" for concepts; `topic`: specific area |

### GitHub Grep (Code Search)
| Tool | When to Use | Key Params |
|------|-------------|------------|
| `grep_searchGitHub` | Find real code patterns across GitHub | `query`: literal code pattern, `language`: ["TypeScript"], `repo`: "owner/repo", `path`: "/api/", `useRegexp`: true for regex |

**Critical:** GitHub Grep searches **literal code patterns**, not keywords!
- ✅ Good: `useState(`, `getServerSession`, `(?s)try {.*await`
- ❌ Bad: `react tutorial`, `how to authenticate`

### Z.AI Zread (Semantic GitHub Search)
| Tool | When to Use | Key Params |
|------|-------------|------------|
| `zai-zread_search_doc` | Semantic search for issues/PRs/docs when keyword search fails | `repo_name`: "owner/repo", `query`: natural language question, `language`: "en"/"zh" |

**Use when:** Code/keyword search misses context, need discussion threads, searching for "why" not "what". 

### Z.AI Vision (Visual Content)
| Tool | When to Use | Key Params |
|------|-------------|------------|
| `zai-vision_diagnose_error_screenshot` | Analyze error screenshots, stack traces | `image_source`: file path or URL, `prompt`: describe what help you need, `context`: when error occurred |
| `zai-vision_understand_technical_diagram` | Interpret architecture/flow/UML/ER diagrams | `image_source`: file path or URL, `prompt`: what to extract, `diagram_type`: "architecture"/"flowchart"/"uml"/"er-diagram" (optional) |
| `zai-vision_analyze_data_visualization` | Understand charts/graphs/dashboards | `image_source`: file path or URL, `prompt`: what insights needed, `analysis_focus`: "trends"/"anomalies"/"comparisons" |
| `zai-vision_ui_to_artifact` | Generate code from UI screenshots | `image_source`: file path or URL, `output_type`: "code"/"prompt"/"spec"/"description", `prompt`: specific requirements |

**Use when:** User provides screenshot, error image, architecture diagram, or UI mockup. 

### GitHub CLI (Repo Search)
```bash
# Repository structure
gh api "repos/{owner}/{repo}/git/trees/{branch}?recursive=1"

# Search issues
gh api -X GET search/issues -f q="repo:{owner}/{repo} is:issue {keywords}"

# Read file directly
webfetch("https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}")
```

## Progressive Escalation Levels

### Level 1: Simple Search (Default)
**When:** Quick lookups, straightforward questions, first encounter

1. Tavily: `search_depth: "basic"`, `maxResults: 5`
2. Context7: `mode: "code"` for API, `mode: "info"` for concepts
3. GitHub Grep: literal code patterns with language filter
4. **Parallel execution** when appropriate

**Sufficient? → Done. Insufficient? → Level 2**

### Level 2: Enhanced Search
**When:** Initial results incomplete, need more examples, outdated results

1. **Expand query:** Add synonyms, context (keep <400 chars)
2. **Increase:** `maxResults: 10-15`, `search_depth: "advanced"`
3. **Filter domains:** `include_domains: ["stackoverflow.com", "github.com"]`
4. **Time filter:** `time_range: "year"` for recent info
5. **Two-step extraction:** Search → Filter by score (>0.5) → Extract top URLs
6. **Discussions/docs gap:** Use `search_doc` or `gh api search/issues` when keyword/code search misses context

**Sufficient? → Done. Insufficient? → Level 3**

### Level 3: Deep Research
**When:** Problem encountered 2+ times, complex topic, building knowledge base

1. **Parallel queries:** 3-5 query variations with synonyms
2. **Systematic extraction:** Top 5-10 URLs with `extract_depth: "advanced"`
3. **Website exploration:** `tavily_map` → `tavily_crawl`
4. **GitHub deep dive:** Multiple pattern variations, regex, cross-repo comparison
5. **Cross-reference:** Verify across multiple sources

## Key Tips (Reminders)

### Query Formulation
- **400 char limit** - Break complex queries into sub-queries
- **Natural language works better** - Full sentences > keywords
- **Be specific** - Include technology, use case, context
- For full guide: See `references/query-guide.md`

### Score-Based Filtering
- Tavily results include `score` (0-1)
- **>0.5 typically good** - Adjust based on distribution
- Filter before extracting to save credits

### Two-Step Extraction Pattern
```
1. Search with search_depth: "advanced"
2. Filter URLs by score (>0.5)
3. Extract top 2-5 URLs with extract_depth: "basic"
4. Upgrade to "advanced" only if needed
```

### GitHub Grep Patterns
```
# API usage
Query: getServerSession
Language: ['TypeScript'], Path: '/api/'

# Multiline with regex
Query: (?s)useEffect\(\(\) => {.*cleanup
useRegexp: true
```

### Cost Optimization
- `basic` = 1 credit, `advanced` = 2 credits
- Prefer two-step extraction over `include_raw_content: true`
- Use `tavily_map` before `tavily_crawl`

For advanced techniques: See `references/advanced-techniques.md`

## Common Patterns

| Pattern | Level 1 | Level 2 | Level 3 |
|---------|---------|---------|---------|
| **Error resolution** | Exact error + SO domain | Remove quotes, add context | Extract top answers, cross-ref docs |
| **Best practices** | "Tech best practices 2024" | Domain filter + extract | Parallel aspect searches |
| **API reference** | Context7 with topic | + Tavily + GitHub Grep | Crawl official docs |
| **Code patterns** | GitHub Grep literal | + language/path filters | Regex + cross-repo |

For workflow examples: See `references/examples/example-workflows.md`

## References

- **`references/reference-parameters.md`** - Complete parameter reference for all tools
- **`references/query-guide.md`** - Query structuring, 400 char limit, expansion strategies
- **`references/advanced-techniques.md`** - Two-step extraction, post-processing, cost optimization
- **`references/examples/example-workflows.md`** - Practical workflow examples

## Output

Search results are used directly in context. No files saved unless requested. For comprehensive research with evidence cards, use the `research` skill.
