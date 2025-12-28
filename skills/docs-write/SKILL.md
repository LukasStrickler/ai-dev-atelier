---
name: docs-write
description: "Write or update documentation (tutorial, how-to, reference, explanation) with clear style, structure, visuals, API/ADR/runbook patterns. Use when: (1) Creating or updating docs after code changes, (2) During PR preparation or addressing review feedback, (3) Adding new features that need documentation, (4) Updating API endpoints, database schemas, or configuration, (5) Creating ADRs or runbooks, (6) Adding or updating diagrams and visual documentation, (7) When documentation needs to be written or revised, (8) For tutorial creation, how-to guides, or technical writing, or (9) For documentation standards compliance and structure. Triggers: write docs, update documentation, create documentation, write tutorial, document API, write ADR, create runbook, add documentation, document this, write how-to."
---

# Docs Write

## Quick Checklist

- Audience and doc type (tutorial/how-to/reference/explanation)
- Clear style, active voice, consistent terms
- Structure: headings, skimmable, examples first
- Include visuals when helpful (mermaid inline; puml when reused)
- API: auth, requests/responses, errors, breaking changes
- ADR/runbook: context, decision/steps, rollback, contacts
- Cross-links and filenames; run docs-check after edits

## Workflow

### Writing Documentation

**IMPORTANT**: Before writing documentation, read `docs/DOCUMENTATION_GUIDE.md` to understand all standards, patterns, and requirements. Do not make assumptions about documentation style, structure, or content - always reference the guide for specific details.

1. **Read the full guide first**: Load `docs/DOCUMENTATION_GUIDE.md` to understand complete documentation standards
   - This ensures you have all context about style, structure, doc types, and examples
   - Do not proceed with writing until the guide is loaded in context

2. **Determine doc type**: Read `docs/DOCUMENTATION_GUIDE.md` section "Doc Types (Divio)" to choose tutorial, how-to, reference, or explanation
   - Tutorial: Learning-oriented, step-by-step for beginners
   - How-to: Goal-oriented, task-focused
   - Reference: Fact-oriented, API/technical details
   - Explanation: Understanding-oriented, concepts and context

3. **Review style guidelines**: Read `docs/DOCUMENTATION_GUIDE.md` sections:
   - "Style and Voice" - Active voice, clear language, consistent terminology
   - "Structure and Skimmability" - Headings, examples first, clear organization
   - Reference the guide for exact formatting, terminology, and style requirements

4. **Draft content**: Use the checklist above, include code examples, and follow the structure guidelines from the guide

5. **Add visuals if needed**: Read `docs/DOCUMENTATION_GUIDE.md` section "Visuals and Diagrams"
   - Use Mermaid for inline diagrams (ER diagrams, sequence diagrams)
   - Use PlantUML (.puml files) for diagrams referenced from multiple docs
   - See examples in the guide for exact syntax - do not guess

6. **For API documentation**: Read `docs/DOCUMENTATION_GUIDE.md` section "API Documentation"
   - Document authentication, request/response formats, error codes
   - Include examples for all endpoints (see guide for format)
   - Document breaking changes prominently

7. **For ADRs/Runbooks**: Read `docs/DOCUMENTATION_GUIDE.md` section "ADRs and Runbooks"
   - ADRs: Context, decision, consequences
   - Runbooks: Steps, rollback procedures, contacts
   - Follow exact templates from the guide

8. **Review and finalize**: Read `docs/DOCUMENTATION_GUIDE.md` section "Templates and Checklists"
   - Verify all checklist items are addressed
   - Add cross-references to related documentation
   - Ensure consistent terminology (check guide for exact terms)

9. **Verify**: Run `bash skills/docs-check/scripts/check-docs.sh` to ensure documentation is complete

## Reference Files

**REQUIRED**: Always read `docs/DOCUMENTATION_GUIDE.md` before writing documentation. The guide contains all standards, examples, and requirements. Do not make assumptions - load the guide and reference specific sections.

Read these sections from `docs/DOCUMENTATION_GUIDE.md` as needed:

- **Style and Voice** (`#style-and-voice`) - Writing style, active voice, terminology
- **Structure and Skimmability** (`#structure-and-skimmability`) - Organization, headings, examples
- **Doc Types (Divio)** (`#doc-types-divio`) - Tutorial, how-to, reference, explanation types
- **API Documentation** (`#api-documentation`) - API docs patterns, examples, error handling
- **ADRs and Runbooks** (`#adrs-and-runbooks`) - Decision records and operational procedures
- **Visuals and Diagrams** (`#visuals-and-diagrams`) - Mermaid and PlantUML usage
- **Templates and Checklists** (`#templates-and-checklists`) - Documentation checklists
- **When to Document** (`#when-to-document`) - What changes require documentation

**Full guide**: `docs/DOCUMENTATION_GUIDE.md` - Complete documentation standards and best practices

## Integration with Other Skills

- Use after `ada::docs:check` flags required updates.
- Combine with `ada::code-review` outcomes to address documentation feedback.
- Run `ada::code-quality` after docs updates if code touched.

## Examples

- New feature: choose how-to; add overview, steps, examples, and links; add diagram if complex.
- API change: document auth, requests/responses, errors, breaking changes; link to workflows.
- Schema change: update schema doc and ER diagram; link from API/feature docs if impacted.
