---
name: tdd
description: "Strict Red-Green-Refactor workflow for robust, self-documenting code. Discovers project test setup via codebase exploration before assuming frameworks. Use when: (1) Implementing new features with test-first approach, (2) Fixing bugs with reproduction tests, (3) Refactoring existing code with test safety net, (4) Adding tests to legacy code, (5) Ensuring code quality before committing, (6) When tests exist but workflow unclear, or (7) When establishing testing practices in a new project. Triggers: test, tdd, red-green-refactor, failing test, test first, test-driven, write tests, add tests, run tests."
metadata:
  author: ai-dev-atelier
  version: "1.0"
---

# Test-Driven Development (TDD)

Strict Red-Green-Refactor workflow for robust, self-documenting, production-ready code.

## Quick Start

**The TDD Loop:**
1. 🔴 **RED**: Write a failing test. Verify it fails for expected reason.
2. 🟢 **GREEN**: Write minimal code to pass. Verify it passes.
3. 🔵 **REFACTOR**: Clean up code and tests. Verify it still passes.

## The Three Rules (Robert C. Martin)

1. **No Production Code** without a failing test
2. **Write Only Enough Test to Fail** (compilation errors count as failure)
3. **Write Only Enough Code to Pass** (one logical change, no optimizations)

## Step 1: Explore Test Environment (REQUIRED)

**Do NOT assume anything.** Explore the codebase to understand what exists.

**Exploration Checklist:**
- [ ] Search for existing test files: `glob("**/*.test.*")`, `glob("**/*.spec.*")`, `glob("**/test_*.py")`
- [ ] Check `package.json` for `scripts.test` field or `Makefile` for test targets
- [ ] Review `.github/workflows/` for CI test commands
- [ ] Look for config files: `vitest.config.*`, `jest.config.*`, `pytest.ini`, `go.mod`, `Cargo.toml`
- [ ] If no setup found: Check `README.md`, `CONTRIBUTING.md`, or `.docs/`

**Framework Detection:**

| Language | Look For | Try Command |
|----------|----------|-------------|
| **Node.js** | `package.json`, `vitest/jest.config` | `npm test`, `bun test` |
| **Python** | `pyproject.toml`, `pytest.ini` | `pytest` |
| **Go** | `go.mod`, `*_test.go` | `go test ./...` |
| **Rust** | `Cargo.toml` | `cargo test` |

## Step 2: Select Mode

| Mode | Entry Condition | FIRST Action Before Loop |
|------|-----------------|--------------------------:|
| **New Feature** | Adding functionality | Read existing module tests |
| **Bug Fix** | Reproducing issue | Write failing reproduction test |
| **Refactor** | Cleaning code | Ensure ≥80% coverage first |
| **Legacy** | No tests exist | Add characterization tests first |

→ **Tie-breaker:** If coverage <20% or tests are absent, ALWAYS use **Legacy Mode** first.
→ After mode's FIRST action, enter Core Loop (Step 3).

---

### Mode: New Feature

**Context:** Codebase exists with tests. Adding new functionality.

**Workflow:**
1. Read existing tests for the module you'll modify
2. Run those specific tests to confirm green baseline
3. Check coverage for that module
4. → Enter Core Loop for new behavior

**Verification:** Run full test suite after each GREEN phase. If existing tests break → you changed behavior.

**Commits:** `test(module): add test for X` → `feat(module): implement X`

---

### Mode: Bug Fix

**Context:** Bug reported. Need to fix without breaking other things.

**Workflow:**
1. Write failing reproduction test FIRST (MUST fail before fix)
2. Confirm failure matches bug behavior (assertion error, not syntax/import error)
3. Write minimal fix - ONLY what's needed
4. → Run full test suite

**Verification:** Bug test passes + all other tests still pass. If other tests fail → fix has side effects.

**Commits:** `test(cart): add failing test for bug #123` → `fix(cart): validate quantity is positive (#123)`

---

### Mode: Refactor

**Context:** Code works but needs cleanup. Tests already exist.

**Workflow:**
1. Run coverage on the **specific function/block** you'll refactor
2. If coverage <80% **for that function** → add characterization tests first
3. Refactor in small steps (ONE change → run tests → repeat)
4. → Never change behavior during refactor

**Verification:** If tests fail → you changed behavior. Either revert or make behavior change a SEPARATE commit.

**Commits:** `refactor(utils): extract validation helper` (tests stay green throughout)

---

### Mode: Legacy Code

**Context:** Existing code with NO tests. Need to modify safely.

**Workflow:**
1. **Find Seams** - Identify insertion points. Two types: **Sensing Seams** (observe behavior via returns/logs) and **Separation Seams** (isolate dependencies to run code in harness).
2. **Break Dependencies** - If code is too tightly coupled, use:
   - **Sprout Method**: Create new tested code in a new method, call it from the old code.
   - **Wrap Method**: Rename old method, create new tested method with same name that calls the old one + new logic.
3. Add characterization tests BEFORE changing anything (capture current behavior).
4. Build safety net: happy path + error cases + boundary conditions.
5. Only then apply TDD for your changes.
6. → Focus on code paths YOU will touch (not 100% file coverage).

**Verification:** Characterization tests pass before AND after your changes.

**Commits:** `test(payment): add characterization tests` → `feat(payment): add refund support`

---

## Step 3: The Core TDD Loop

### Step 0: Scenario List (Canon TDD)
Before writing any test, list all behaviors/scenarios you need to cover:
- [ ] Happy path cases
- [ ] Edge cases and boundary conditions  
- [ ] Error/failure cases
- [ ] **Pessimism Phase**: List 3 ways this could fail (network, null input, invalid state)

Check off scenarios one-by-one as you complete each RED-GREEN-REFACTOR cycle.

### 🔴 RED Phase
1. **Write ONE Test**: Focus on one small behavior or edge case.
2. **Use AAA Structure**: Arrange (setup) → Act (call) → Assert (verify).
3. **Run Test**: Execute test runner.
4. **VERIFY RED**: Ensure it **FAILS for the expected reason** (assertion error, not syntax/import error).

**Verification Questions:**
- [ ] Did I write more than one test? (Should be NO)
- [ ] Is the failure an assertion error? (Not `SyntaxError`/`ModuleNotFoundError`)
- [ ] Can I explain why this test should fail? (Should be YES)
- [ ] Does my test logic match the original requirement? (Cross-check before GREEN)

**If test passes immediately** → **STOP.** Test is broken or feature already exists.

### 🟢 GREEN Phase
1. **Write Minimal Code**: Just enough logic to satisfy the test.
2. **Do NOT** implement "perfect" solution or extra features.
3. **VERIFY GREEN**: Ensure the test **passes**.

**Verification Questions:**
- [ ] Can I delete this code and have tests still pass? (Dead code check)
- [ ] Is this the simplest solution? (Should be YES)

### 🔵 REFACTOR Phase
1. **Analyze**: Look for duplication, messy logic, unclear naming.
2. **Improve**: Clean up implementation **without changing behavior**.
3. **VERIFY GREEN**: Ensure **no regressions**.

**Refactoring Heuristics:**
- Extract helper methods and consolidate logic.
- Improve names for clarity.
- Remove magic numbers/strings.

### Repeat
Select the next small behavior and return to the RED Phase.

**Triangulation:** If your implementation is too specific (e.g., hardcoded value), write another test with different inputs to force a generalized solution.

## Stop Conditions

| Signal | Response |
|--------|----------|
| **Test passes immediately** | Check assertions, ensure test is running, or verify feature isn't already built |
| **Test fails for wrong reason** | Fix setup/imports. Red must be an assertion failure, not syntax error |
| **Flaky Test** | **STOP.** Fix non-determinism immediately. Do not proceed |
| **Slow Feedback** | If tests take >5s, optimize or mock external calls |
| **Coverage decreased** | Add tests for uncovered paths before proceeding |

## Test Pyramid

| Level | % of Tests | Scope | Speed | Examples |
|-------|------------|-------|-------|----------|
| **Unit** | 70-80% | Single function/class | Milliseconds | `add(a, b) returns sum` |
| **Integration** | 15-20% | Module interactions | Seconds | `User.create({name})` |
| **E2E** | 5-10% | Full application | Minutes | `GET /api/users` |

**Guidance:**
- Push testing **down the pyramid**.
- If error can be caught by unit test, **don't write integration test**.
- Prefer **fakes over mocks** when feasible for higher fidelity.
- Focus on test **quality** (SMURF: Sustainable, Maintainable, Useful, Resilient, Fast) not just ratios.

## Anti-Patterns

- ❌ **Mirror Blindness**: Same agent writes test AND code, replicating logic errors in both. **Mitigation:** (1) Summarize test intent in plain language before GREEN phase, (2) Use role isolation - have a separate review step or sub-agent verify test logic, (3) Clear context between RED and GREEN phases.
- ❌ **Happy Path Bias**: Only testing successful scenarios. Always include error cases in your Scenario List.
- ❌ **Refactoring While Red**: Changing structure while tests fail.
- ❌ **The Big Bang**: Large implementation without incremental tests.
- ❌ **The Mockery**: Over-mocking hides real integration bugs. Prefer fakes or real implementations when feasible.
- ❌ **The Inspector**: Testing private state, not behavior.
- ❌ **Coverage Theater**: Tests that don't assert meaningful behavior.
- ❌ **The Multi-Test Step**: Writing multiple tests before implementing.

## Hermetic Testing

- **Isolation**: Use unique temp directories/state for each test.
- **Reset**: Clean up state in `setUp`/`tearDown`.
- **Determinism**: Avoid time-based logic or shared mutable state.
- **Mocking**: Mock slow/unreliable external services (DB, Network).

## Coverage Basics

**When to Check:**
1. **Start of Task**: Identify gaps in existing code (`P0` critical paths).
2. **During Refactor**: Ensure safety net (aim for >80% locally).
3. **End of Task**: Verify no coverage regression.

**Risk Prioritization:**

| Priority | What to Test First |
|----------|-------------------|
| **P0 - Critical** | Auth, payments, data validation, error handling |
| **P1 - High** | Core business logic, public APIs |
| **P2 - Medium** | Helpers, transformers |
| **P3 - Low** | Config, constants, simple getters |

**Key Principle:** Find what the project already uses. Match existing patterns.

## Integration

| Task | Skill | Usage |
|------|-------|-------|
| **Committing** | `git-commit` | Use `test:` commits for RED, `feat:` for GREEN |
| **Code Quality** | `code-quality` | Run lint/format during Refactor phase |
| **Documentation** | `docs-check` | Check if behavior changes need docs |

## References

- [The Three Rules of TDD](https://butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd) - Robert C. Martin's foundational principles
- [Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html) - Martin Fowler on test distribution
- [Test Sizes](https://testing.googleblog.com/2010/12/test-sizes.html) - Google Testing Blog on categorization
- [Hermetic Servers](https://testing.googleblog.com/2012/10/hermetic-servers.html) - Google on isolated testing
- [Working Effectively with Legacy Code](https://www.oreilly.com/library/view/working-effectively-with/0131177052/) - Michael Feathers on characterization tests
