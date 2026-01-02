# Git Commit Examples

Extended examples organized by commit type and scenario.

## Features (feat)

### Simple Feature

```text
feat(ui): add dark mode toggle

Add toggle switch in settings panel.
Persists preference to localStorage.
```

### Feature with Multiple Changes

```text
feat(auth): add Google OAuth login

Implement OAuth 2.0 flow for Google sign-in:
- Add OAuth callback endpoint
- Create login button component
- Store tokens securely in session
- Add user profile sync on first login

Closes #142
```

### Feature with Breaking Change

```text
feat(api)!: change pagination to cursor-based

BREAKING CHANGE: Offset-based pagination removed.

Replace ?page=2&limit=10 with ?cursor=abc123&limit=10.
Response now includes `next_cursor` field.

Migration: Use `next_cursor` from response for subsequent requests.
Offset parameters will return 400 Bad Request.

See docs/pagination-migration.md for examples.
```

## Bug Fixes (fix)

### Simple Fix

```text
fix(form): prevent form submission on Enter key

Users accidentally submitted incomplete forms.
Add explicit submit button requirement.
```

### Fix with Root Cause Analysis

```text
fix(api): resolve memory leak in WebSocket handler

Connections were not being cleaned up on client disconnect.
Event listeners accumulated over time, causing OOM after ~24h.

Root cause: Missing removeEventListener in cleanup function.
Add proper cleanup in connection close handler.

Fixes #892
```

### Fix with Regression Test

```text
fix(cart): prevent negative item quantities

Validation was only client-side. Users bypassed via API.
Add server-side validation with proper error response.

Added regression test: cart.negative-quantity.test.ts

Fixes #234
```

### Security Fix

```text
fix(auth): sanitize redirect URL parameter

Open redirect vulnerability in OAuth callback.
Attacker could redirect users to malicious sites.

Add allowlist validation for redirect domains.
Log and block unauthorized redirect attempts.

Security: CVE-2024-XXXX
Fixes #901
```

## Refactoring (refactor)

### Simple Refactor

```text
refactor(utils): rename getUserById to findUser

Align with naming convention used elsewhere.
No behavior change.
```

### Extract Function

```text
refactor(api): extract error handling to middleware

Error handling was duplicated across 12 route handlers.
Consolidate into single error middleware.

Reduces code duplication and ensures consistent error responses.
```

### Restructure Module

```text
refactor(auth): split auth module into submodules

auth.ts was 800+ lines and hard to navigate.

Split into:
- auth/login.ts
- auth/logout.ts
- auth/refresh.ts
- auth/middleware.ts
- auth/types.ts

No behavior changes. All tests pass.
```

## Performance (perf)

### Database Optimization

```text
perf(db): add index on users.email column

Login queries were doing full table scans.
Average login time: 450ms -> 12ms.

Added compound index on (email, deleted_at).
```

### Algorithm Improvement

```text
perf(search): switch to binary search for sorted results

Linear search was O(n) on sorted arrays.
Binary search reduces to O(log n).

Benchmark: 10k items search 23ms -> 0.4ms
```

## Documentation (docs)

### API Documentation

```text
docs(api): add authentication endpoint examples

Add curl examples for:
- Login with password
- Login with OAuth
- Token refresh
- Logout

Include error response examples.
```

### README Update

```text
docs(readme): add Docker installation instructions

Users were confused about container setup.
Add step-by-step Docker Compose guide.
```

## Tests (test)

### Add Missing Tests

```text
test(auth): add integration tests for login flow

Cover scenarios:
- Valid credentials
- Invalid password
- Locked account
- Rate limiting
- Session creation
```

### Fix Flaky Test

```text
test(api): fix race condition in async test

Test was flaky due to timing dependency.
Add proper async/await and increase timeout.
Mock external service for deterministic results.
```

## Build and CI (build, ci)

### Dependency Update

```text
build(deps): update React to 18.2.0

Security patch for XSS vulnerability.
No breaking changes in minor version.
```

### CI Pipeline Change

```text
ci: add security scanning to PR workflow

Run Snyk vulnerability scan on all PRs.
Block merge if high severity issues found.
```

### Build Configuration

```text
build(webpack): enable tree shaking for production

Bundle size reduced from 2.4MB to 1.1MB.
No runtime behavior changes.
```

## Chores (chore)

### Configuration Update

```text
chore: update .gitignore for IDE files

Add patterns for VS Code and JetBrains IDEs.
Prevents accidental commits of local settings.
```

### Cleanup

```text
chore: remove deprecated helper functions

Functions were marked deprecated 6 months ago.
No remaining usages in codebase.
```

## Style (style)

### Formatting

```text
style: apply Prettier formatting to src/

Ran prettier --write on all source files.
No logic changes.
```

### Linting Fixes

```text
style(api): fix ESLint warnings in handlers

- Remove unused imports
- Fix spacing issues
- Add missing semicolons
```

## Convention Matching Examples

### Matching JIRA-style Prefixes

If project uses `[JIRA-123] message` format:

```text
[AUTH-456] Add password reset flow

[UI-789] Fix button alignment on mobile

[API-234] Handle timeout in payment gateway
```

### Matching Component Prefixes

If project uses `Component: message` format:

```text
Button: Add loading state variant

UserService: Fix null pointer on empty response

AuthMiddleware: Add rate limiting
```

### Matching Emoji Prefixes (Gitmoji)

If project uses emoji prefixes:

```text
✨ Add user profile page

🐛 Fix login redirect loop

♻️ Refactor database connection pool

📝 Update API documentation
```

## Multi-line Body Formatting

### Bullet Points

```text
feat(dashboard): add analytics widgets

Add three new widgets to main dashboard:
- Active users (real-time count)
- Revenue chart (last 30 days)
- Top products (by sales volume)

Each widget is independently refreshable.
Data updates every 60 seconds.

Closes #567
```

### Paragraphs

```text
fix(sync): resolve data corruption on concurrent writes

The sync engine was not properly handling concurrent writes
from multiple clients. When two clients modified the same
record within the same second, the conflict resolution
algorithm would sometimes discard both changes.

This fix introduces vector clocks for proper ordering and
a three-way merge for conflicting changes. In cases where
automatic merge is not possible, the most recent change
wins and a conflict record is created for manual review.

Tested with 100 concurrent clients over 24 hours with
zero data loss.

Fixes #1234
```

## Edge Cases

### Revert Commit

```text
revert: feat(api): add rate limiting

This reverts commit abc1234.

Rate limiting was causing issues for legitimate
high-volume API users. Reverting while we
implement a more nuanced approach with user tiers.

Refs: #890
```

### Merge Conflict Resolution

```text
fix(merge): resolve conflicts in user service

Conflicts arose from parallel feature branches.
Kept changes from feature-auth, integrated
with changes from feature-profile.

Both features now work together correctly.
```

### Work in Progress (AVOID - but if needed)

```text
wip: initial structure for payment module

NOT FOR MERGE - work in progress.

Basic file structure and interfaces only.
Implementation coming in follow-up commits.
```

**Note:** Avoid WIP commits in main branches. Use feature branches and
squash before merge.
