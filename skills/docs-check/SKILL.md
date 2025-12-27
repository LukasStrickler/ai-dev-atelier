---
name: docs-check
description: Analyze git diff to identify code changes requiring documentation updates. Categorizes changes (database/schema, API endpoints, components, configuration, authentication) and suggests relevant documentation files to review. Use when: (1) After making code changes, (2) Before committing significant changes, (3) When adding new features or modifying APIs, (4) During PR preparation, (5) When working with database schemas, API routes, components, or configuration files, (6) To ensure documentation stays synchronized with code changes, (7) For documentation sync and maintenance, or (8) For pre-commit documentation checks. Triggers: "check docs", "docs check", "documentation check", "update docs", "sync documentation", "what docs need updating", "check if docs are up to date", "after code changes", "before committing".
---

# Documentation Check

## Tools

- `ada::docs:check` - Analyzes git diff and suggests documentation updates

## What It Detects

The tool categorizes changes and suggests relevant documentation files:

- **Database/Schema changes** → suggests `.docs/db/` files
- **API changes** → suggests `.docs/api/` and `.docs/workflow/` files
- **Component/UI changes** → suggests component documentation
- **Configuration changes** → suggests setup/install documentation
- **Authentication changes** → suggests auth documentation
- **Test changes** → suggests test documentation
- And more...

## Workflow

1. **Run check**: `npm run ada::docs:check` (or `-- --verbose` for details)
   - Analyzes git diff for code changes requiring documentation updates

2. **Review output**: Categorized changes with suggested documentation files

3. **Validate structure**: Read `docs/DOCUMENTATION_GUIDE.md` to verify existing docs follow standards

4. **Update documentation**: Use `skills/docs-write/SKILL.md` workflow, reference `docs/DOCUMENTATION_GUIDE.md` for requirements

5. **Verify**: Re-run check until all suggestions addressed

### Integration with Other Skills

- Run after `ada::code-review` to check if reviewed changes need documentation
- Run before `ada::code-quality` finalization to ensure docs are updated with code
- Use during PR preparation to ensure documentation is complete

## Examples

### Example 1: Basic Usage

```bash
npm run ada::docs:check
```

### Example 2: Verbose Mode

```bash
npm run ada::docs:check -- --verbose
```

## References

**REQUIRED READING**: Always load `docs/DOCUMENTATION_GUIDE.md` to:
1. **Validate existing documentation** - Check if suggested docs follow correct structure, style, and alignment
2. **Guide updates** - Reference standards when writing or updating documentation

The guide contains all standards, examples, patterns, and requirements. Do not make assumptions about documentation format, style, or structure - always reference the guide.

- **Documentation Guide**: `docs/DOCUMENTATION_GUIDE.md` - **REQUIRED**: Complete documentation standards, style, structure, and examples. Load this file to validate existing docs and guide updates.
- **docs-write skill**: `skills/docs-write/SKILL.md` - Complete workflow for writing/updating documentation

## Output

The tool outputs:
- Changed code files organized by category
- Suggested documentation files to review
- Guidance on what needs to be updated

## Best Practices

- Run this check before committing significant changes
- **Always load `docs/DOCUMENTATION_GUIDE.md`** to validate documentation structure and alignment
- Verify existing documentation follows guide standards (style, structure, format) - not just detect what needs updating
- Review the [Documentation Guide](docs/DOCUMENTATION_GUIDE.md) to understand what changes require documentation
- Update documentation in the same PR as code changes
- Fix structure/alignment issues when updating content
- Use the verbose mode for more detailed information
