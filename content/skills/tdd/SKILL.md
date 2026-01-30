---
name: tdd
description: "Strict Red-Green-Refactor workflow for robust, self-documenting code. Discovers project test setup via codebase exploration before assuming frameworks. Use when: (1) Implementing new features with test-first approach, (2) Fixing bugs with reproduction tests, (3) Refactoring existing code with test safety net, (4) Adding tests to legacy code, (5) Ensuring code quality before committing, (6) When tests exist but workflow unclear, or (7) When establishing testing practices in a new project. Triggers: test, tdd, red-green-refactor, failing test, test first, test-driven, write tests, add tests, run tests."
metadata:
  author: ai-dev-atelier
  version: "1.0"
---

# Test-Driven Development (TDD)

Strict Red-Green-Refactor workflow for robust, self-documenting, production-ready code.

## Quick Navigation

| Situation | Go To |
|-----------|-------|
| New to this codebase | [Step 1: Explore Environment](#step-1-explore-test-environment) |
| Know the framework, starting work | [Step 2: Select Mode](#step-2-select-mode) |
| Need the core loop reference | [Step 3: Core TDD Loop](#step-3-the-core-tdd-loop) |
| Complex edge cases to cover | [Property-Based Testing](#property-based-testing) |
| Tests are flaky/unreliable | [Flaky Test Management](#flaky-test-management) |
| Need isolated test environment | [Hermetic Testing](#hermetic-testing) |
| Measuring test quality | [Mutation Testing](#mutation-testing) |

## The Three Rules (Robert C. Martin)

1. **No Production Code** without a failing test
2. **Write Only Enough Test to Fail** (compilation errors count)
3. **Write Only Enough Code to Pass** (no optimizations yet)

**The Loop:** 🔴 RED (write failing test) → 🟢 GREEN (minimal code to pass) → 🔵 REFACTOR (clean up) → Repeat

---

## Step 1: Explore Test Environment

**Do NOT assume anything.** Explore the codebase first.

**Checklist:**
- [ ] Search for test files: `glob("**/*.test.*")`, `glob("**/*.spec.*")`, `glob("**/test_*.py")`
- [ ] Check `package.json` scripts, `Makefile`, or CI workflows
- [ ] Look for config: `vitest.config.*`, `jest.config.*`, `pytest.ini`, `Cargo.toml`

**Framework Detection:**

| Language | Config Files | Test Command |
|----------|--------------|--------------|
| Node.js | `package.json`, `vitest.config.*` | `npm test`, `bun test` |
| Python | `pyproject.toml`, `pytest.ini` | `pytest` |
| Go | `go.mod`, `*_test.go` | `go test ./...` |
| Rust | `Cargo.toml` | `cargo test` |

---

## Step 2: Select Mode

| Mode | When | First Action |
|------|------|--------------|
| **New Feature** | Adding functionality | Read existing module tests, confirm green baseline |
| **Bug Fix** | Reproducing issue | Write failing reproduction test FIRST |
| **Refactor** | Cleaning code | Ensure ≥80% coverage on target code |
| **Legacy** | No tests exist | Add characterization tests before changing |

**Tie-breaker:** If coverage <20% or tests absent → use **Legacy Mode** first.

### Mode: New Feature
1. Read existing tests for the module
2. Run tests to confirm green baseline
3. Enter Core Loop for new behavior
4. **Commits:** `test(module): add test for X` → `feat(module): implement X`

### Mode: Bug Fix
1. Write failing reproduction test (MUST fail before fix)
2. Confirm failure is assertion error, not syntax error
3. Write minimal fix
4. Run full test suite
5. **Commits:** `test: add failing test for bug #123` → `fix: description (#123)`

### Mode: Refactor
1. Run coverage on the specific function you'll refactor
2. If coverage <80% → add characterization tests first
3. Refactor in small steps (ONE change → run tests → repeat)
4. Never change behavior during refactor

### Mode: Legacy Code
1. **Find Seams** - insertion points for tests (Sensing Seams, Separation Seams)
2. **Break Dependencies** - use Sprout Method or Wrap Method
3. Add characterization tests (capture current behavior)
4. Build safety net: happy path + error cases + boundaries
5. Then apply TDD for your changes

→ See `references/examples.md` for full code examples of each mode.

---

## Step 3: The Core TDD Loop

### Before Starting: Scenario List
List all behaviors to cover:
- [ ] Happy path cases
- [ ] Edge cases and boundaries
- [ ] Error/failure cases
- [ ] **Pessimism:** 3 ways this could fail (network, null, invalid state)

### 🔴 RED Phase
1. Write ONE test (single behavior or edge case)
2. Use AAA: Arrange → Act → Assert
3. Run test, **verify it FAILS for expected reason**

**Checks:**
- Is failure an assertion error? (Not `SyntaxError`/`ModuleNotFoundError`)
- Can I explain why this should fail?
- If test passes immediately → STOP. Test is broken or feature exists.

### 🟢 GREEN Phase
1. Write minimal code to pass
2. Do NOT implement "perfect" solution
3. **Verify test passes**

**Checks:**
- Is this the simplest solution?
- Can I delete any of this code and still pass?

### 🔵 REFACTOR Phase
1. Look for duplication, unclear names, magic values
2. Clean up **without changing behavior**
3. **Verify tests still pass**

### Repeat
Select next scenario, return to RED.

**Triangulation:** If implementation is too specific (hardcoded), write another test with different inputs to force generalization.

---

## Stop Conditions

| Signal | Response |
|--------|----------|
| Test passes immediately | Check assertions, verify feature isn't already built |
| Test fails for wrong reason | Fix setup/imports first |
| Flaky test | **STOP.** Fix non-determinism immediately |
| Slow feedback (>5s) | Optimize or mock external calls |
| Coverage decreased | Add tests for uncovered paths |

---

## Test Distribution: The Testing Trophy

The Testing Trophy (Kent C. Dodds) reflects modern testing reality: **integration tests give the best confidence-to-effort ratio**.

```
          _____________
         /   System    \      ← Few, slow, high confidence; brittle (E2E)
        /_______________\
       /                 \
      /    Integration    \   ← Real interactions between units — **BEST ROI** (Integration)
      \                   /
       \_________________/
         \    Unit     /      ← Fast & cheap but test in isolation (Unit) 
          \___________/
          /   Static  \       ← Typecheck, linting — typos/types (Static)
         /_____________\
```

### Layer Breakdown

| Layer | What | Tools | When |
|-------|------|-------|------|
| **Static** | Type errors, syntax, linting | TypeScript, ESLint | Always on, catches 50%+ of bugs for free |
| **Unit** | Pure functions, algorithms, utilities | vitest, jest, pytest | Isolated logic with no dependencies |
| **Integration** | **Components + hooks + services together** | Testing Library, MSW, Testcontainers | Real user flows, real(ish) data |
| **E2E** | Full app in browser | Playwright, Cypress | Critical paths only (login, checkout) |

### Why Integration Tests Win

**Unit tests** prove code works in isolation. **Integration tests** prove code works together.

| Concern | Unit Test | Integration Test |
|---------|-----------|------------------|
| Component renders | ✅ | ✅ |
| Component + hook works | ❌ | ✅ |
| Component + API works | ❌ | ✅ |
| User flow works | ❌ | ✅ |
| Catches real bugs | Sometimes | Usually |

**The insight**: Most bugs live in the **seams** between modules, not inside pure functions. Integration tests catch seam bugs; unit tests don't.

### Practical Guidance

1. **Start with integration tests** - Test the way users use your code
2. **Drop to unit tests** for complex algorithms or edge cases
3. **Use E2E sparingly** - Slow, flaky, expensive to maintain
4. **Let static analysis do the heavy lifting** - TypeScript catches more bugs than most unit tests
5. **Prefer fakes over mocks** - Fakes have real behavior; mocks just return canned data
6. **SMURF quality**: Sustainable, Maintainable, Useful, Resilient, Fast

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| **Mirror Blindness** | Same agent writes test AND code | State test intent before GREEN |
| **Happy Path Bias** | Only success scenarios | Include errors in Scenario List |
| **Refactoring While Red** | Changing structure with failing tests | Get to GREEN first |
| **The Mockery** | Over-mocking hides bugs | Prefer fakes or real implementations |
| **Coverage Theater** | Tests without meaningful assertions | Assert behavior, not lines |
| **Multi-Test Step** | Multiple tests before implementing | One test at a time |
| **Verification Trap** 🤖 | AI tests *what code does* not *what it should do* | State intent in plain language; separate agent review |
| **Test Exploitation** 🤖 | LLMs exploit weak assertions or overload operators | Use PBT alongside examples; strict equality |
| **Assertion Omission** 🤖 | Missing edge cases (null, undefined, boundaries) | Scenario list with errors; `test.each` |
| **Hallucinated Mock** 🤖 | AI generates fake mocks without proper setup | Testcontainers for integration; real Fakes for unit |

**Critical**: Verify tests by (1) running them, (2) having separate agent review, (3) never trusting generated tests blindly.

---

## Advanced Techniques

Use these techniques at specific points in your workflow:

| Technique | Use During | Purpose |
|-----------|------------|---------|
| Test Doubles | 🔴 RED phase | Isolate dependencies when writing tests |
| Property-Based Testing | 🔴 RED phase | Cover edge cases for complex logic |
| Contract Testing | 🔴 RED phase | Define API expectations between services |
| Snapshot Testing | 🔴 RED phase | Capture UI/response structure |
| Hermetic Testing | 🔵 Setup | Ensure test isolation and determinism |
| Mutation Testing | ✅ After GREEN | Validate test suite effectiveness |
| Coverage Analysis | ✅ After GREEN | Find untested code paths |
| Flaky Test Management | 🔧 Maintenance | Fix unreliable tests blocking CI |

---

### Test Doubles (Use: Writing Tests with Dependencies)

**When:** Your code depends on something slow, unreliable, or complex (DB, API, filesystem).

| Type | Purpose | When |
|------|---------|------|
| **Stub** | Returns canned answers | Need specific return values |
| **Mock** | Verifies interactions | Need to verify calls made |
| **Fake** | Simplified implementation | Need real behavior without cost |
| **Spy** | Records calls | Need to observe without changing |

**Decision:** Dependency slow/unreliable? → Fake (complex) or Stub (simple). Need to verify calls? → Mock/Spy. Otherwise → real implementation.

→ See `references/examples.md` → [Test Double Examples](#test-double-examples)

---

### Hermetic Testing (Use: Test Environment Setup)

**When:** Setting up test infrastructure. Tests must be isolated and deterministic.

**Principles:**
- **Isolation**: Unique temp directories/state per test
- **Reset**: Clean up in setUp/tearDown
- **Determinism**: No time-based logic or shared mutable state

**Database Strategies:**

| Strategy | Speed | Fidelity | Use When |
|----------|-------|----------|----------|
| In-memory (SQLite) | Fast | Low | Unit tests, simple queries |
| Testcontainers | Medium | High | Integration tests |
| Transactional Rollback | Fast | High | Tests sharing schema (80x faster than TRUNCATE) |

→ See `references/examples.md` → [Hermetic Testing Examples](#hermetic-testing-examples)

---

### Property-Based Testing (Use: Writing Tests for Complex Logic)

**When:** Writing tests for algorithms, state machines, serialization, or code with many edge cases.

**Tools:** fast-check (JS/TS), Hypothesis (Python), proptest (Rust)

**Properties to Test:**
- Commutativity: `f(a, b) == f(b, a)`
- Associativity: `f(f(a, b), c) == f(a, f(b, c))`
- Identity: `f(a, identity) == a`
- Round-trip: `decode(encode(x)) == x`
- Metamorphic: If input changes by X, output changes by Y (useful when you don't know expected output)

**How:** Replace multiple example-based tests with one property test that generates random inputs.

**Critical:** Always log the **seed** on failure. Without it, you cannot reproduce the failing case.

→ See `references/examples.md` → [Property-Based Testing Examples](#property-based-testing-examples)

---

### Mutation Testing (Use: Validating Test Quality)

**When:** After tests pass, to verify they actually catch bugs. Use for critical code (auth, payments) or before major refactors.

**Tools:** Stryker (JS/TS), PIT (Java), mutmut (Python)

**How:** Tool mutates your code (e.g., changes `>` to `>=`). If tests still pass → your tests are weak.

**Interpretation:**
- **>80% mutation score** = good test suite
- **Survived mutants** = tests don't catch those changes → add tests for these

**Equivalent Mutant Problem:** Some mutants change syntax but not behavior (e.g., `i < 10` → `i != 10` in a loop where i only increments). These can't be killed—100% score is often impossible. Focus on surviving mutants in *critical paths*, not chasing perfect scores.

**When NOT to use:** Tool-generated code (OpenAPI clients, Protobuf stubs, ORM models), simple DTOs/getters, legacy code with slow tests, or CI pipelines that must finish in <5 minutes. Use `--incremental --since main` for PR-focused runs. Note: This does NOT mean skip mutation testing on code you (the agent) wrote—always validate your own work.

→ See `references/examples.md` → [Mutation Testing Examples](#mutation-testing-examples)

---

### Flaky Test Management (Use: CI/CD Maintenance)

**When:** Tests fail intermittently, blocking CI or eroding trust in the test suite.

**Root Causes:**

| Cause | Fix |
|-------|-----|
| Timing (`setTimeout`, races) | Fake timers, await properly |
| Shared state | Isolate per test |
| Randomness | Seed or mock |
| Network | Use MSW or fakes |
| Order dependency | Make tests independent |
| Parallel transaction conflicts | Isolate DB connections per worker |

**How:** Detect (`--repeat 10`) → Quarantine (separate suite) → Fix root cause → Restore

**Quarantine Rules:**
- **Issue-linked**: Every quarantined test MUST link to a tracking issue. Prevents "quarantine-and-forget."
- **Mute, don't skip**: Prefer muting (runs but doesn't fail build) over skipping. You still collect failure data.
- **Reintroduction criteria**: Test must pass N consecutive runs (e.g., 100) on main before leaving quarantine.

→ See `references/examples.md` → [Flaky Test Examples](#flaky-test-examples)

---

### Contract Testing (Use: Writing Tests for Service Boundaries)

**When:** Writing tests for code that calls or exposes APIs. Prevents integration breakage.

**How (Pact):** Consumer defines expected interactions → Contract published → Provider verifies → CI fails if contract broken.

→ See `references/examples.md` → [Contract Testing Examples](#contract-testing-examples)

---

### Coverage Analysis (Use: Finding Gaps After Tests Pass)

**When:** After writing tests, to find untested code paths. NOT a goal in itself.

| Metric | Measures | Threshold |
|--------|----------|-----------|
| Line | Lines executed | 70-80% |
| Branch | Decision paths | 60-70% |
| Mutation | Test effectiveness | >80% |

**Risk-Based Prioritization:** P0 (auth, payments) → P1 (core logic) → P2 (helpers) → P3 (config)

**Warning:** High coverage ≠ good tests. Tests must assert meaningful behavior.

---

### Snapshot Testing (Use: Writing Tests for UI/Output Structure)

**When:** Writing tests for UI components, API responses, or error message formats.

**Appropriate:** UI structure, API response shapes, error formats.
**Avoid:** Behavior testing, dynamic content, entire pages.

**How:** Capture output once, verify it doesn't change unexpectedly. Always review diffs carefully.

→ See `references/examples.md` → [Snapshot Testing Examples](#snapshot-testing-examples)

---

## Integration with Other Skills

| Task | Skill | Usage |
|------|-------|-------|
| Committing | `git-commit` | `test:` for RED, `feat:` for GREEN |
| Code Quality | `code-quality` | Run during REFACTOR phase |
| Documentation | `docs-check` | Check if behavior changes need docs |

---

## References

**Foundational:**
- [Three Rules of TDD](https://butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd) - Robert C. Martin
- [Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html) - Martin Fowler
- [Testing Trophy](https://kentcdodds.com/blog/write-tests) - Kent C. Dodds
- [Working Effectively with Legacy Code](https://www.oreilly.com/library/view/working-effectively-with/0131177052/) - Michael Feathers

**Tools:** [Testcontainers](https://testcontainers.com/) | [fast-check](https://fast-check.dev/) | [Stryker](https://stryker-mutator.io/) | [MSW](https://mswjs.io/) | [Pact](https://pact.io/)
