# Search Workflow Examples

Practical examples of search workflows at different levels.

## Example 1: Simple Lookup (Level 1)

**Query:** "How to use React useState hook"

**Workflow:**
1. Tavily search: `search_depth: "basic"`, `maxResults: 5`
2. Context7: React docs on hooks (`mode: "code"`, `topic: "hooks"`)
3. ✅ Results sufficient → Use and done

## Example 2: Insufficient Results (Level 1 → 2)

**Query:** "Next.js middleware authentication"

**Workflow:**
1. **Level 1:** Basic search returns partial information
2. **Level 2:**
   - Expand: "Next.js middleware authentication JWT tokens"
   - Increase: `maxResults: 10`, `search_depth: "advanced"`
   - Extract: Top 3 URLs with `extract_depth: "advanced"`
3. ✅ Results sufficient → Use and done

## Example 3: Repeated Problem (Level 1 → 3)

**Query:** "TypeScript generic constraints" (encountered 3rd time)

**Workflow:**
1. **Level 1:** Basic search (already tried before)
2. **Level 3:**
   - Parallel queries: ["TypeScript generic constraints", "TypeScript extends keyword generics", "TypeScript generic type parameters"]
   - Extract: Top 5 URLs from each query
   - Context7: TypeScript docs (`mode: "info"`, `topic: "generics"`)
   - Crawl: TypeScript handbook section on generics
   - Synthesize: Comprehensive understanding

## Example 4: Error Message Resolution

**Error:** "TypeError: Cannot read property 'map' of undefined"

**Workflow:**
1. **Level 1:** Search exact error with `include_domains: ["stackoverflow.com"]`
2. **Level 2:** Remove quotes, add context: "React TypeError Cannot read property map undefined"
3. **Level 3:** Extract top Stack Overflow answers, cross-reference with React docs

## Example 5: Best Practices Research

**Query:** "Next.js 14 best practices"

**Workflow:**
1. **Level 1:** "Next.js 14 best practices 2024" with `time_range: "year"`
2. **Level 2:** Add domain filtering: `include_domains: ["nextjs.org", "vercel.com"]`, extract top guides
3. **Level 3:** Parallel searches for different aspects (performance, security, SEO), systematic comparison

