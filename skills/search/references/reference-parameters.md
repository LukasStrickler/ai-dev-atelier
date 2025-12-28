# Tavily Parameter Reference

Complete reference for all Tavily MCP tool parameters.

## tavily_search Parameters

### Required
- `query` (string, required) - The search query to execute

### Search Depth
- `search_depth` (enum: "basic", "advanced", "fast", "ultra-fast", default: "basic")
  - `"basic"` (1 credit) - Fast, one snippet per URL
  - `"advanced"` (2 credits) - Multiple relevant chunks per URL, higher relevance
    - Note: `chunks_per_source` is NOT available in search - it's only in extract/crawl
  - `"fast"` (beta, 1 credit) - Optimized for low latency
  - `"ultra-fast"` (beta, 1 credit) - Strictly optimized for latency

### Results & Content
- `maxResults` (integer, default: 5, max: 20) - Maximum number of search results to return
- `include_answer` (boolean or "basic" or "advanced", default: false) - Include LLM-generated answer
  - `true` or `"basic"` - Quick answer
  - `"advanced"` - Detailed answer
- `include_raw_content` (boolean or "markdown" or "text", default: false) - Full extracted content (use two-step extraction instead when possible)
- `include_favicon` (boolean, default: false) - Include favicon URLs for better UI
- `include_images` (boolean, default: false) - Include query-related images
- `include_image_descriptions` (boolean, default: false) - Include descriptions for images

### Domain Filtering
- `include_domains` (array of strings, max: 300) - Trusted sources (limit to 3-5 relevant domains)
  - Examples: `["stackoverflow.com", "github.com", "docs.python.org"]`
  - Minimize list size for better relevance
- `exclude_domains` (array of strings, max: 150) - Filter low-quality sources (use sparingly)
  - Only exclude truly irrelevant domains
  - Examples: `["espn.com"]` when searching for tech topics

### Time Filtering
- `time_range` (enum: "day", "week", "month", "year", "d", "w", "m", "y") - Filter results by time range
- `start_date` (string, format: "YYYY-MM-DD") - Filter results after this date
- `end_date` (string, format: "YYYY-MM-DD") - Filter results before this date

### Topic & Region
- `topic` (enum: "general", "news", "finance", default: "general")
  - `"general"` - Broad searches
  - `"news"` - Real-time updates, includes `published_date` metadata
  - `"finance"` - Financial information
- `country` (string) - Boost results from specific country (only with `topic: "general"`)

### Auto-Optimization
- `auto_parameters` (boolean, default: false) - Automatically optimize search parameters based on query intent
  - May set `search_depth` to `"advanced"` (2 credits)
  - Override with explicit `search_depth: "basic"` to control cost
  - Manual parameters override automatic ones

### Usage Tracking
- `include_usage` (boolean, default: false) - Include credit usage information in response

## tavily_extract Parameters

### Required
- `urls` (array of strings, required) - URLs to extract content from

### Extraction Options
- `extract_depth` (enum: "basic", "advanced", default: "basic")
  - `"basic"` (1 credit per 5 successful extractions) - Standard extraction
  - `"advanced"` (2 credits per 5 successful extractions) - For tables, embedded content, complex pages
- `format` (enum: "markdown", "text", default: "markdown")
  - `"markdown"` - Preserves structure and code blocks
  - `"text"` - Plain text (may increase latency)

### Content Reranking
- `query` (string, optional) - Rerank content chunks by relevance to this query (enables `chunks_per_source`)
- `chunks_per_source` (integer, 1-5, default: 3) - Number of relevant chunks per URL (only when `query` provided)

### Additional Options
- `include_images` (boolean, default: false) - Include extracted images
- `include_favicon` (boolean, default: false) - Include favicon URLs
- `timeout` (number, 1-60 seconds) - Custom timeout (default: 10s for basic, 30s for advanced)
- `include_usage` (boolean, default: false) - Include credit usage information in response

## tavily_crawl Parameters

### Required
- `url` (string, required) - The root URL to begin the crawl

### Crawl Configuration
- `max_depth` (integer, 1-5, default: 1) - Max depth of crawl (start shallow, increase if needed)
  - Each level increases crawl time exponentially
  - Start with 1, increase only if necessary
- `max_breadth` (integer, default: 20, min: 1) - Max links to follow per page level
  - Control horizontal expansion
  - Increase for sites with many links per page
- `limit` (integer, default: 50, min: 1) - Total links to process before stopping
  - Set appropriate limit to prevent excessive crawling
  - Adjust based on site size and needs

### Path & Domain Filtering
- `select_paths` (array of strings, regex patterns) - Select only URLs with specific path patterns
  - Example: `["/docs/.*", "/api/.*"]`
- `exclude_paths` (array of strings, regex patterns) - Exclude URLs with specific path patterns
  - Example: `["/private/.*", "/admin/.*"]`
- `select_domains` (array of strings, regex patterns) - Restrict to specific domains/subdomains
  - Example: `["^docs\\.example\\.com$"]`
- `exclude_domains` (array of strings, regex patterns) - Exclude specific domains
- `allow_external` (boolean, default: true) - Include external domain links in results

### Content Extraction
- `instructions` (string, optional) - Natural language guidance for crawler
  - Increases cost to 2 credits per 10 pages (instead of 1)
  - Example: "Find all pages about the Python SDK"
  - Enables `chunks_per_source` parameter
- `chunks_per_source` (integer, 1-5, default: 3) - Number of relevant chunks per source (only when `instructions` provided)
- `extract_depth` (enum: "basic", "advanced", default: "basic")
  - `"basic"` - Standard extraction
  - `"advanced"` - For tables, structured data
- `format` (enum: "markdown", "text", default: "markdown")

### Additional Options
- `include_images` (boolean, default: false) - Include images in crawl results
- `include_favicon` (boolean, default: false) - Include favicon URLs
- `timeout` (number, 10-150 seconds, default: 150) - Maximum crawl time
- `include_usage` (boolean, default: false) - Include credit usage information in response

## tavily_map Parameters

### Required
- `url` (string, required) - The root URL to begin the mapping

### Mapping Configuration
- `max_depth` (integer, 1-5, default: 1) - Max depth of mapping (start shallow, increase if needed)
- `max_breadth` (integer, default: 20, min: 1) - Max links to follow per page level
- `limit` (integer, default: 50, min: 1) - Total links to discover before stopping

### Path & Domain Filtering
- `select_paths` (array of strings, regex patterns) - Select only URLs with specific path patterns
- `exclude_paths` (array of strings, regex patterns) - Exclude URLs with specific path patterns
- `select_domains` (array of strings, regex patterns) - Restrict to specific domains/subdomains
- `exclude_domains` (array of strings, regex patterns) - Exclude specific domains
- `allow_external` (boolean, default: true) - Include external domain links in results

### Additional Options
- `instructions` (string, optional) - Natural language guidance (increases cost to 2 credits per 10 pages)
- `timeout` (number, 10-150 seconds, default: 150) - Maximum mapping time
- `include_usage` (boolean, default: false) - Include credit usage information in response

## Context7 Parameters

- `mode: "code"` - API references, code examples, implementation details
- `mode: "info"` - Conceptual guides, architecture, best practices
- `topic` - Narrow down large documentation sets
- `page` - Get more content if initial results insufficient

