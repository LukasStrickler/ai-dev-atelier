# Releasing AI Dev Atelier

This guide explains how to create releases for AI Dev Atelier.

## Overview

Releases are **manual only**. There is no automatic release on push or merge. This allows maintainers to:
- Merge multiple PRs before releasing
- Choose the right moment to release
- Control version numbers explicitly

## How It Works

1. **PRs are merged** with descriptive titles and appropriate labels
2. **Labels are auto-applied** based on file paths (workflow: `.github/workflows/labeler.yml`, config: `.github/labeler.yml`)
3. **When ready**, a maintainer triggers the release workflow manually
4. **Release notes are auto-generated** from merged PRs, grouped by label category

## Creating a Release

### Prerequisites

- You have push access to the repository
- All PRs you want included are merged to main
- You've decided on a version number (see [Version Numbering](#version-numbering))

### Steps

> Release notes use GitHub auto-generated notes with labels from `.github/release.yml`.

1. **Dry run first** (optional but recommended for major releases):

   ```bash
   gh workflow run release.yml -f version=1.0.0 -f dry_run=true
   ```

   Check the workflow run in GitHub Actions to see what would be released.

2. **Create the release**:

   ```bash
   gh workflow run release.yml -f version=1.0.0
   ```

3. **For pre-releases** (beta, rc):

   ```bash
   gh workflow run release.yml -f version=1.0.0-beta.1 -f prerelease=true
   ```

4. **Verify** the release at `https://github.com/LukasStrickler/ai-dev-atelier/releases`

## Version Numbering

We use [Semantic Versioning](https://semver.org/):

| Version | When to Use |
|---------|-------------|
| `MAJOR.0.0` | Breaking changes (skill API changes, removed features) |
| `x.MINOR.0` | New features, new skills (backward compatible) |
| `x.x.PATCH` | Bug fixes, documentation updates |
| `x.x.x-beta.N` | Pre-release for testing |
| `x.x.x-rc.N` | Release candidate |

### Examples

- `0.1.0` - Initial release
- `0.2.0` - Added new skill
- `0.2.1` - Fixed bug in existing skill
- `1.0.0` - First stable release / breaking changes
- `1.1.0-beta.1` - Testing new feature before stable release

## Release Notes Quality

Release notes are auto-generated from **PR titles and descriptions**. Good release notes require:

### Good PR Titles

| Bad | Good |
|-----|------|
| "Fix bug" | "Fix code-quality skill failing on empty files" |
| "Update docs" | "Add troubleshooting section to INSTALL.md" |
| "New feature" | "Add research skill for academic paper search" |

### Labels

Labels categorize PRs in release notes:

| Label | Release Notes Section |
|-------|----------------------|
| `breaking` | Breaking Changes |
| `skill` | Skills |
| `security` | Security |
| `feature` | Features |
| `bug` | Bug Fixes |
| `documentation` | Documentation |
| `chore` | Maintenance |

**Auto-applied** based on file paths (workflow: `.github/workflows/labeler.yml`, config: `.github/labeler.yml`):
- `content/skills/**` → `skill`
- `**/*.md`, `docs/**` → `documentation`
- `.github/**`, `.test/**`, config files → `chore`

**Manually applied** (add when creating PR):
- `feature` - New functionality
- `bug` - Bug fixes
- `security` - Security fixes
- `breaking` - Breaking changes

## For AI Agents

**CRITICAL**: AI agents must NEVER trigger releases without explicit user permission.

Acceptable agent behavior:
- Help prepare release (check what's merged, suggest version)
- Show the command to run
- Wait for user to confirm before executing

Unacceptable agent behavior:
- Running `gh workflow run release.yml` without explicit "yes, release it" from user
- Assuming a release should happen after merging PRs

Example interaction:

```text
User: "I think we're ready for a release"
Agent: "Based on merged PRs since v0.1.0, I suggest releasing v0.2.0.
        Changes include: [summary]

        Command: gh workflow run release.yml -f version=0.2.0

        Should I run this?"
User: "Yes"
Agent: [runs command]
```

## Troubleshooting

### Version already exists

```text
Error: Tag v1.0.0 already exists!
```

Choose a different version number, or delete the existing tag/release first (double-check the tag name before deleting):

```bash
gh release delete v1.0.0 --yes
git push origin --delete v1.0.0
```

### No changes since last release

If release notes are empty, no PRs were merged since the last release tag. Either:
- Merge some PRs first
- Check that the previous tag exists and is correct

### Wrong release notes

Release notes are generated from PRs, not commits. If a change was committed directly to main without a PR, it won't appear in release notes. Always use PRs for changes.

## Security: Release Block Hook

A PreToolUse hook (`content/hooks/release-block-hook.sh`) prevents AI agents from triggering releases without human approval.

### What It Blocks

| Category | Blocked Commands |
|----------|------------------|
| **Direct release** | `gh workflow run release.yml`, `gh release create` |
| **Alternative CLIs** | `hub release create` |
| **HTTP to GitHub API** | `curl`/`wget` to `/releases`, `/dispatches`, GraphQL `createRelease` |
| **gh api write ops** | `gh api /releases -X POST`, `gh api graphql` with release mutations |
| **Container escapes** | `docker run`/`podman exec` containing `gh workflow`/`release` |
| **Network tools** | `socat`/`ncat`/`nc`/`telnet`/`openssl` to `api.github.com` |
| **Job schedulers** | `at`/`batch`/`crontab` with release commands |
| **Unicode tricks** | Zero-width characters (U+200B, U+200C, U+200D, U+FEFF, U+00A0) |

### What It Allows

- `gh api /repos/.../releases` (GET requests for reading release info)
- `gh release list`, `gh release view` (read-only operations)
- Commands with `--help` flag
- Text processing commands that mention releases: `echo`, `grep`, `cat`, etc.

### No Bypass Available

**There is no bypass mechanism.** Bypass-style comments (e.g., `BYPASS_RELEASE`) are intentionally ignored by the hook. Releases are 100% human-controlled. AI agents must provide a copy-pastable command for the human to run manually.

### Known Limitations

The hook performs **static string matching** before command execution. It cannot block:

| Vector | Why Unblockable |
|--------|-----------------|
| Base64/hex encoded commands | Decoded at runtime |
| Variable expansion (`$cmd`) | Resolved after hook |
| File write → execute | Two-step attack |
| Python/Node HTTP clients | Not shell commands |
| Symlinked/renamed `gh` binary | Path not inspectable |

These are **architecturally unblockable** with static analysis. The hook provides defense-in-depth, not absolute prevention. The primary defense is the AI agent's instruction to wait for human approval.

### Testing

The hook has 259 test cases covering security vectors:

```bash
bash .test/tests/test-release-block.sh
```
