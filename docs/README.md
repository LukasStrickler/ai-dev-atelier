# Documentation

Documentation resources for AI Dev Atelier, including standards, guides, and best practices.

## Overview

This directory contains documentation guides and standards for maintaining project documentation in sync with code changes.

## Documentation Guide

The [Documentation Guide](./DOCUMENTATION_GUIDE.md) provides comprehensive best practices for:

- **Core Principles**: Focused, visual, updated, consistent documentation
- **Directory Structure**: Recommended `.docs/` organization
- **Visual Documentation**: Using Mermaid (inline) and PlantUML (separate files)
- **When to Document**: Guidelines for what changes require documentation
- **Code Comments vs Documentation**: When to use each
- **Docs-as-Code**: Best practices for maintaining documentation

## Skills That Use Documentation

The following skills help maintain documentation:

- **[docs-check](../skills/docs-check/SKILL.md)** - Analyzes git diff to identify code changes requiring documentation updates
- **[code-review](../skills/code-review/SKILL.md)** - Reviews code and can identify when documentation should be updated

## Tools

Use `npm run ada::docs:check` to automatically detect when code changes require documentation updates.

## Quick Reference

### Documentation Checklist

Before creating a PR:

- [ ] Run `npm run ada::docs:check` to identify needed updates
- [ ] Review changed files and determine documentation impact
- [ ] Update relevant documentation files
- [ ] Update diagrams if schemas/workflows changed
- [ ] Ensure setup instructions are accurate
- [ ] Verify README reflects current features
- [ ] Check that all links work

### Common Documentation Tasks

- **Adding a feature**: Update README, add API docs if needed, create workflow diagrams
- **Changing schema**: Update schema docs, update ER diagrams, update migration docs
- **Modifying API**: Update API docs, update workflow diagrams, document breaking changes

## See Also

- [Skills Documentation](../skills/README.md) - AI agent skills (includes scripts)
- [Setup Guide](../SETUP.md) - Installation guide




