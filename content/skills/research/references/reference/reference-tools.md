# Research Tool Reference

Complete documentation for all MCP tools used in the research skill.

## Context Management Reminder

**REMINDER: Write-First Pattern**

When using these tools to read papers:
- **After reading 1-2 papers maximum:** Write evidence card immediately → Update `references.json` → SAVE
- **Never read 3+ papers before writing** (causes context overload and information loss)
- **Update `references.json` incrementally** after each evidence card write, not once at the end
- **Evidence cards serve as persistent knowledge store** - can be re-read when context resets

**Why:** Context windows are limited. Writing preserves knowledge even if context is compressed or reset.

## OpenAlex MCP Tools

### Paper Discovery

#### `search_works`
Search for academic papers with advanced filtering.

**Parameters:**
- `query` (string, required) - Search query with keywords, supports Boolean operators (AND, OR, NOT)
- `from_publication_year` (number, optional) - Filter works published from this year onwards
- `to_publication_year` (number, optional) - Filter works published up to this year
- `cited_by_count` (string, optional) - Filter by citation count (e.g., ">100", "<50")
- `is_oa` (boolean, optional) - Filter for open access works only
- `type` (string, optional) - Filter by work type: "article", "book", "dataset", etc.
- `sort` (string, optional) - Sort results: "relevance_score" (default), "cited_by_count", "publication_year"
- `page` (number, optional) - Page number for pagination (default: 1)
- `per_page` (number, optional) - Results per page, max 200 (default: 10)

**Use cases:**
- Initial paper discovery
- Finding papers by topic with constraints
- Filtering by citations, year, open access

**Examples:**
```javascript
// Find highly cited papers on microservices
search_works({
  query: "microservices architecture",
  cited_by_count: ">100",
  sort: "cited_by_count",
  per_page: 20
})

// Find recent open access papers
search_works({
  query: "distributed systems",
  from_publication_year: 2020,
  is_oa: true,
  sort: "publication_year"
})
```

#### `search_by_topic`
Search for works within specific research topics or domains.

**Parameters:**
- `topic` (string, required) - Topic name or keywords (e.g., "artificial intelligence", "climate change")
- `from_year` (number, optional) - Filter works from this year onwards
- `to_year` (number, optional) - Filter works up to this year
- `sort` (string, optional) - Sort by: "cited_by_count", "publication_year", "relevance_score" (default)
- `per_page` (number, optional) - Results per page (default: 10, max: 200)

**Use cases:**
- Domain-specific searches
- Exploring research areas
- Finding papers in specific fields

#### `autocomplete_search`
Fast autocomplete/typeahead search for works, authors, institutions, or other entities.

**Parameters:**
- `query` (string, required) - Partial search query
- `entity_type` (string, required) - Type of entity: "works", "authors", "institutions", "sources", "topics", "publishers", "funders"

**Use cases:**
- Quick lookups
- Finding exact entity names
- Autocomplete functionality

### Paper Details

#### `get_work`
Get complete details about a specific work by OpenAlex ID, DOI, or URL.

**Parameters:**
- `id` (string, required) - Work identifier (OpenAlex ID, DOI, or full URL)

**Returns:**
- Complete author list (first, middle, last authors with positions, institutions, ORCID, corresponding author flags)
- Full abstract (reconstructed)
- All topics
- Complete bibliographic data
- Funding/grants
- Keywords
- Reference lists

**Use cases:**
- Getting full paper metadata
- Accessing complete author information
- Finding all topics and keywords

#### `get_work_citations`
Get all works that cite a given work (forward citations).

**Parameters:**
- `id` (string, required) - Work identifier (OpenAlex ID, DOI, or URL)
- `page` (number, optional) - Page number for pagination
- `per_page` (number, optional) - Citations per page (default: 10, max: 200)
- `sort` (string, optional) - Sort by: "publication_year", "cited_by_count"

**Use cases:**
- Finding recent developments
- Understanding research impact
- Forward citation analysis

#### `get_work_references`
Get all works referenced/cited by a given work (backward citations).

**Parameters:**
- `id` (string, required) - Work identifier (OpenAlex ID, DOI, or URL)

**Use cases:**
- Finding foundational papers
- Understanding paper's foundations
- Backward citation analysis

#### `get_related_works`
Find works related to a given work based on shared topics, citations, and references.

**Parameters:**
- `id` (string, required) - Work identifier (OpenAlex ID, DOI, or URL)
- `per_page` (number, optional) - Number of related works to return (default: 10, max: 200)

**Use cases:**
- Expanding paper set
- Finding similar papers
- Discovering alternative approaches

#### `get_citation_network`
Get a citation network for a work including both citing works (forward) and referenced works (backward).

**Parameters:**
- `id` (string, required) - Work identifier (OpenAlex ID, DOI, or URL)
- `depth` (number, optional) - Network depth: 1 = immediate citations/references only, 2 = second-order connections (default: 1)
- `max_citing` (number, optional) - Maximum number of citing works to include (default: 50)
- `max_references` (number, optional) - Maximum number of referenced works to include (default: 50)

**Use cases:**
- Building comprehensive citation networks
- Understanding research relationships
- Finding foundational and recent papers

### Author & Institution

#### `search_authors`
Search for authors/researchers with filters.

**Parameters:**
- `query` (string, required) - Author name or search query
- `works_count` (string, optional) - Filter by number of works (e.g., ">50")
- `cited_by_count` (string, optional) - Filter by citation count (e.g., ">1000")
- `institution` (string, optional) - Filter by institution name or ID
- `per_page` (number, optional) - Results per page (default: 10, max: 200)

**Use cases:**
- Finding experts in a field
- Searching for specific researchers
- Finding authors at institutions

#### `get_author_works`
Get all publications by a specific author over time.

**Parameters:**
- `author_id` (string, required) - Author identifier (OpenAlex ID, ORCID, or URL)
- `from_year` (number, optional) - Get works from this year onwards
- `to_year` (number, optional) - Get works up to this year
- `sort` (string, optional) - Sort by: "publication_year", "cited_by_count"
- `per_page` (number, optional) - Works per page (default: 10, max: 200)

**Use cases:**
- Analyzing author's research trajectory
- Finding all papers by an expert
- Understanding author's contributions

#### `get_author_collaborators`
Analyze an author's co-authorship network.

**Parameters:**
- `author_id` (string, required) - Author identifier (OpenAlex ID, ORCID, or URL)
- `min_collaborations` (number, optional) - Minimum number of co-authored papers to include (default: 1)

**Use cases:**
- Finding frequent collaborators
- Understanding research networks
- Discovering related researchers

#### `search_institutions`
Search for academic institutions with filters.

**Parameters:**
- `query` (string, required) - Institution name or search query
- `country_code` (string, optional) - Filter by ISO 3166-1 alpha-2 country code (e.g., "US", "GB", "CN")
- `type` (string, optional) - Institution type: "education", "healthcare", "company", "archive", "nonprofit", "government", "facility", "other"
- `works_count` (string, optional) - Filter by number of works (e.g., ">1000")
- `per_page` (number, optional) - Results per page (default: 10, max: 200)

**Use cases:**
- Finding leading institutions
- Searching by country
- Finding institutions by type

### Analysis Tools

#### `get_top_cited_works`
Find the most highly cited works in a research area or matching specific criteria.

**Parameters:**
- `query` (string, optional) - Search query to filter works
- `topic` (string, optional) - Filter by research topic
- `from_year` (number, optional) - Consider works from this year onwards
- `to_year` (number, optional) - Consider works up to this year
- `min_citations` (number, optional) - Minimum citation count threshold (default: 50)
- `per_page` (number, optional) - Number of top works to return (default: 10, max: 200)

**Use cases:**
- Finding influential papers
- Starting literature reviews
- Identifying seminal works

#### `analyze_topic_trends`
Analyze publication trends over time for specific topics or queries.

**Parameters:**
- `query` (string, required) - Search query or topic to analyze
- `from_year` (number, optional) - Start year for trend analysis
- `to_year` (number, optional) - End year for trend analysis

**Use cases:**
- Understanding research evolution
- Identifying growing fields
- Temporal analysis

#### `compare_research_areas`
Compare publication volume and citation metrics across different research topics or queries.

**Parameters:**
- `topics` (array, required) - Array of topics/queries to compare (2-5 recommended)
- `from_year` (number, optional) - Compare from this year onwards
- `to_year` (number, optional) - Compare up to this year

**Use cases:**
- Comparing research areas
- Understanding relative activity
- Cross-field analysis

#### `get_trending_topics`
Discover emerging and trending research topics based on recent publication activity.

**Parameters:**
- `min_works` (number, optional) - Minimum number of recent works for a topic to be considered trending (default: 100)
- `time_period_years` (number, optional) - Consider works from the last N years (default: 3)
- `per_page` (number, optional) - Number of trending topics to return (default: 10)

**Use cases:**
- Finding emerging research
- Discovering new fields
- Identifying hot topics

#### `analyze_geographic_distribution`
Analyze the geographical distribution of research activity for a topic or query.

**Parameters:**
- `query` (string, required) - Search query or topic to analyze
- `from_year` (number, optional) - Analyze from this year onwards
- `to_year` (number, optional) - Analyze up to this year

**Use cases:**
- Understanding global research distribution
- Finding leading countries/institutions
- Geographic analysis

## PDF Extractor MCP Tools

### `read_pdf`
Read content, metadata, and images from PDFs (local file or URL).

**Parameters:**
- `sources` (array, required) - Array of PDF sources, each with:
  - `path` (string, optional) - Path to local PDF file (absolute or relative)
  - `url` (string, optional) - URL of the PDF file
  - `pages` (string or array, optional) - Pages to extract (e.g., "1-10", [1, 3, 5], or "all")
- `include_full_text` (boolean, optional) - Include full text content (default: true if pages not specified)
- `include_metadata` (boolean, optional) - Include metadata and info objects (default: false)
- `include_page_count` (boolean, optional) - Include total number of pages (default: false)
- `include_images` (boolean, optional) - Extract and include embedded images as base64-encoded data (default: false)

**Returns:**
- Full text content (structured by pages)
- Metadata (title, authors, creation date, etc.)
- Page count
- Images (if requested, as base64)

**Use cases:**
- Extracting full text from papers
- Getting specific pages or sections
- Extracting metadata
- Getting images/diagrams from papers

**Examples:**
```javascript
// Extract full text from local PDF
read_pdf({
  sources: [{ path: ".ada/temp/research/downloads/paper.pdf" }],
  include_full_text: true,
  include_metadata: true
})

// Extract specific pages from URL
read_pdf({
  sources: [{
    url: "https://arxiv.org/pdf/1234.5678.pdf",
    pages: [1, 2, 3, 10, 11]
  }],
  include_full_text: true
})

// Extract from multiple PDFs
read_pdf({
  sources: [
    { path: "paper1.pdf" },
    { path: "paper2.pdf", pages: "1-5" }
  ],
  include_full_text: true
})
```

**Important Notes:**
- PDF content is returned directly in the tool response (injected into context)
- No need to save extracted text to files - use content directly for evidence cards
- Use `pages` parameter to extract only relevant sections for efficiency

## Paper-search MCP Tools (Optional)

### Search Tools

#### `search_papers`
Search academic papers from multiple sources including arXiv, Web of Science, PubMed, etc.

**Parameters:**
- `query` (string, required) - Search query string
- `platform` (string, optional) - Platform to search: "arxiv", "webofscience", "pubmed", "biorxiv", "medrxiv", "semantic", "iacr", "googlescholar", "scholar", "scihub", "sciencedirect", "springer", "scopus", "crossref", "all" (default: "crossref")
- `maxResults` (number, optional) - Maximum number of results (1-100, default: 10)
- `year` (string, optional) - Year filter (e.g., "2023", "2020-2023", "2020-")
- `author` (string, optional) - Author name filter
- `journal` (string, optional) - Journal name filter
- `category` (string, optional) - Category filter (e.g., "cs.AI" for arXiv)
- `sortBy` (string, optional) - Sort by: "relevance" (default), "date", "citations"
- `sortOrder` (string, optional) - Sort order: "asc" or "desc" (default: "desc")
- `fieldsOfStudy` (array, optional) - Fields of study filter (Semantic Scholar only)

**Use cases:**
- Multi-platform paper search
- Finding papers across different databases
- Comprehensive coverage

#### `search_arxiv`
Search arXiv specifically.

**Parameters:**
- `query` (string, required) - Search query
- `maxResults` (number, optional) - Maximum results (1-50, default: 10)
- `category` (string, optional) - arXiv category (e.g., "cs.AI", "physics.gen-ph")
- `author` (string, optional) - Author name filter
- `year` (string, optional) - Year filter
- `sortBy` (string, optional) - Sort by: "relevance", "date", "citations"
- `sortOrder` (string, optional) - "asc" or "desc"

**Use cases:**
- Finding preprints
- Computer science papers
- Physics/math papers

#### `search_pubmed`
Search PubMed/MEDLINE database.

**Parameters:**
- `query` (string, required) - Search query
- `maxResults` (number, optional) - Maximum results (1-100, default: 10)
- `year` (string, optional) - Year filter
- `author` (string, optional) - Author name filter
- `journal` (string, optional) - Journal name filter
- `publicationType` (array, optional) - Publication types (e.g., ["Journal Article", "Review"])
- `sortBy` (string, optional) - Sort by: "relevance" or "date"

**Use cases:**
- Biomedical literature
- Medical research
- Health sciences

#### `search_semantic_scholar`
Search Semantic Scholar with citation data.

**Parameters:**
- `query` (string, required) - Search query
- `maxResults` (number, optional) - Maximum results (1-100, default: 10)
- `year` (string, optional) - Year filter
- `fieldsOfStudy` (array, optional) - Fields of study (e.g., ["Computer Science", "Biology"])

**Use cases:**
- Papers with citation data
- Computer science papers
- Multi-disciplinary search

#### `search_crossref`
Search Crossref database (free, extensive coverage).

**Parameters:**
- `query` (string, required) - Search query
- `maxResults` (number, optional) - Maximum results (1-100, default: 10)
- `year` (string, optional) - Year filter
- `author` (string, optional) - Author name filter
- `sortBy` (string, optional) - Sort by: "relevance", "date", "citations"
- `sortOrder` (string, optional) - "asc" or "desc"

**Use cases:**
- Broad paper search
- Finding papers across publishers
- Free comprehensive search

#### `get_paper_by_doi`
Retrieve paper information using DOI.

**Parameters:**
- `doi` (string, required) - DOI (Digital Object Identifier)
- `platform` (string, optional) - Platform to search: "arxiv", "webofscience", "all" (default: "all")

**Use cases:**
- Getting paper by known DOI
- Verifying paper information
- Cross-platform lookup

### Download Tools

#### `download_paper`
Download PDF file of an academic paper.

**Parameters:**
- `paperId` (string, required) - Paper ID (e.g., arXiv ID, DOI for Sci-Hub)
- `platform` (string, required) - Platform: "arxiv", "biorxiv", "medrxiv", "semantic", "iacr", "scihub", "springer", "wiley"
- `savePath` (string, optional) - Directory to save the PDF file

**Use cases:**
- Automated PDF download
- Downloading from supported platforms
- Batch downloading

#### `search_scihub`
Search and download papers from Sci-Hub using DOI or paper URL.

**Parameters:**
- `doiOrUrl` (string, required) - DOI (e.g., "10.1038/nature12373") or full paper URL
- `downloadPdf` (boolean, optional) - Whether to download the PDF file (default: false)
- `savePath` (string, optional) - Directory to save the PDF file (if downloadPdf is true)

**Use cases:**
- Accessing paywalled papers
- Downloading via Sci-Hub
- **Note**: Check Terms of Service and legal considerations

## Built-in Web Search Tools (When Available)

Some agents provide built-in web search tools. Use them in addition to MCP tools for:
- Finding preprints and early versions of papers
- Discovering related web resources and blog posts
- Cross-referencing academic findings with current practices
- Finding supplementary materials and datasets

**When to use:**
- Level 1-3: In parallel with OpenAlex searches
- Finding web resources related to papers
- Discovering current implementations or discussions

## Tool Selection Guide

### For Paper Discovery
- **OpenAlex `search_works`**: Primary tool for academic paper discovery
- **OpenAlex `get_top_cited_works`**: Finding influential papers
- **Paper-search `search_papers`**: Multi-platform search (if available)
- **Built-in web search**: Finding preprints and web resources

### For Expanding Paper Set
- **OpenAlex `get_related_works`**: Similar papers
- **OpenAlex `get_work_citations`**: Recent developments
- **OpenAlex `get_work_references`**: Foundational papers
- **OpenAlex `get_citation_network`**: Comprehensive citation network

### For PDF Extraction
- **PDF Extractor `read_pdf`**: Extract content directly to context
- **No file saving needed**: Use content immediately for evidence cards

### For Paper Download
- **Paper-search `download_paper`**: Automated download from supported platforms
- **Manual download**: For paywalled papers or unsupported sources

## Best Practices

1. **Start with OpenAlex**: Most comprehensive and free
2. **Use citation networks**: Follow citations and references to find related papers
3. **Extract directly to context**: No need to save PDF text to files
4. **Parallel searches**: Use multiple tools simultaneously for comprehensive coverage
5. **Filter appropriately**: Use year, citations, open access filters to focus results
6. **Check multiple sources**: Cross-reference across platforms when possible

