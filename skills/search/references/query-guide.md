# Query Structuring Guide

Effective query formulation is crucial for getting relevant search results. Tavily is optimized for natural language queries that clearly express intent.

## The 400 Character Limit

**Critical:** Tavily enforces a strict 400-character limit on queries. Exceeding this limit will return an error: `"Query is too long. Max query length is 400 characters."`

**Why it matters:**
- Think of queries as search engine queries, not long-form prompts
- Shorter, focused queries perform better
- Forces you to be specific and clear about what you're looking for

**If your query exceeds 400 characters:**
- Break it into multiple smaller, focused queries
- Remove unnecessary words or context
- Focus on the core information need

## Good Query Patterns

**✅ Specific and Contextual:**
- Good: "Next.js 14 App Router API routes authentication"
- Good: "React hooks useState best practices 2024"
- Good: "TypeScript generic constraints extends keyword tutorial"

**✅ Include Technology and Use Case:**
- Good: "Python async await database connection pooling"
- Good: "Docker multi-stage builds reduce image size"
- Good: "PostgreSQL JSONB query performance optimization"

**✅ Specify Information Type:**
- Good: "TypeScript generic types tutorial"
- Good: "Next.js middleware API reference"
- Good: "React error boundary implementation guide"

**✅ Natural Language, Full Sentences:**
- Good: "How to implement JWT authentication in Next.js API routes"
- Good: "What are the best practices for React state management in 2024"
- Good: "How does Python's asyncio event loop work"

**✅ Clear Intent and Context:**
- Good: "Troubleshoot 'Cannot read property map of undefined' error in React"
- Good: "Compare Redux Toolkit vs Zustand for React state management"
- Good: "Migrate from Express.js to FastAPI Python web framework"

## Poor Query Patterns

**❌ Too Broad:**
- Poor: "React"
- Poor: "Python"
- Poor: "API"

**Why:** These return too many irrelevant results. Add context and specificity.

**❌ Too Vague:**
- Poor: "error"
- Poor: "how to"
- Poor: "best practices"

**Why:** Missing context makes it impossible to find relevant information.

**❌ Missing Context:**
- Poor: "authentication" (what technology? what use case?)
- Poor: "state management" (which framework? what problem?)
- Poor: "database" (what type? what operation?)

**Why:** Without context, results will be generic and unhelpful.

**❌ Over 400 Characters:**
- Poor: Long paragraphs describing the entire problem
- Poor: Multiple questions combined into one query

**Why:** Will fail with error. Break into focused sub-queries.

## Breaking Complex Queries into Sub-Queries

When a query is complex or covers multiple topics, break it into smaller, focused queries and execute them in parallel.

**Example: Company Research**
- ❌ Too complex: "Competitors, financial performance, recent developments, and industry trends for company ABC"
- ✅ Better approach - separate queries:
  - "Competitors of company ABC"
  - "Financial performance of company ABC"
  - "Recent developments of company ABC"
  - "Latest industry trends related to ABC"

**Example: Technology Comparison**
- ❌ Too complex: "Compare Next.js vs Remix vs SvelteKit for SSR, performance, developer experience, and deployment"
- ✅ Better approach - separate queries:
  - "Next.js vs Remix server-side rendering comparison"
  - "SvelteKit performance benchmarks 2024"
  - "Next.js Remix SvelteKit developer experience comparison"
  - "Deployment options Next.js Remix SvelteKit"

**Benefits of breaking queries:**
- Each query stays under 400 characters
- More focused results per query
- Can execute queries in parallel for faster results
- Easier to identify which aspect needs more research

## Query Expansion Strategies

When initial results are insufficient, expand your query using these strategies:

**1. Synonym Expansion**
- Original: "React state management"
- Expanded: "React state management hooks useState useReducer patterns"
- Adds related terms that might appear in relevant content

**2. Decomposition**
- Complex: "Next.js authentication with JWT and refresh tokens"
- Decomposed:
  - "Next.js JWT authentication implementation"
  - "Next.js refresh token implementation"
  - "Next.js JWT refresh token flow"

**3. Progressive Broadening**
- Start narrow: "Next.js 14 App Router API routes"
- If insufficient, broaden: "Next.js App Router API routes"
- If still insufficient: "Next.js API routes"

**4. Context-Aware Expansion**
- Use terms from initial results to generate new queries
- If results mention "middleware", try: "Next.js middleware authentication"
- If results mention "JWT", try: "Next.js JWT token validation"

**5. Adding Temporal Context**
- Add year for recent information: "React best practices 2024"
- Add "latest" or "recent": "Latest Next.js authentication patterns"
- Use time_range parameter for filtering

**6. Adding Information Type**
- "tutorial", "guide", "documentation", "API reference", "example"
- "best practices", "patterns", "troubleshooting", "comparison"
- Example: "TypeScript generics tutorial" vs "TypeScript generics API reference"

## Natural Language Best Practices

Tavily is optimized for natural language queries. Full sentences work better than keyword lists.

**✅ Prefer:**
- "How to implement authentication in Next.js API routes"
- "What are the best practices for React state management"
- "Troubleshoot 'Cannot read property map of undefined' error in React"

**❌ Avoid:**
- "Next.js auth API"
- "React state best practices"
- "React error map undefined"

**Why:** Natural language queries better capture intent and context, leading to more relevant results.

## Query Formulation Checklist

Before executing a search, verify:

- [ ] Query is under 400 characters
- [ ] Query is specific and contextual (not too broad)
- [ ] Query includes technology/framework name
- [ ] Query includes use case or problem context
- [ ] Query uses natural language (full sentences preferred)
- [ ] Query has clear intent (what information are you seeking?)
- [ ] If complex, can it be broken into sub-queries?
