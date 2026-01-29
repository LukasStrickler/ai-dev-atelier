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

**Before starting:** Always analyze existing test environment and coverage first (Step 1 below).

## When to Use

| Situation | Action |
|-----------|--------|
| **New Feature** | Write test for first small behavior → Loop |
| **Bug Fix** | Write reproduction test (must fail) → Fix → Loop |
| **Refactoring** | Ensure tests pass → Refactor → Verify Green |
| **Legacy Code** | Add characterization tests before changing logic |
| **Existing Codebase** | Analyze coverage gaps → Add tests for critical untested paths |

### When NOT to Use
- **Exploratory Prototyping**: Timeboxed research (throwaway code)
- **Trivial Configuration**: Simple variable changes
- **Visual UI**: Use the `ui-animation` skill for animations and visual interactions

## The Iron Law

> **"You are not allowed to write any production code unless it is to make a failing unit test pass."** — Robert C. Martin

1. **No Production Code** without a failing test
2. **Fail Only Enough** to pass (minimal implementation, no extra features)
3. **Pass Only Enough** to pass (one logical change, no optimizations)

## Workflow

### Step 1: Analyze Existing Test Environment (REQUIRED FIRST)

**Do NOT assume anything.** Explore the codebase to understand what exists.

#### 1A: Discover Test Setup

**Exploration Checklist:**
- [ ] Search for existing test files: `glob("**/*.test.*")`, `glob("**/*.spec.*")`, `glob("**/test_*.py")`
- [ ] Check `package.json` for `scripts.test` field
- [ ] Check `Makefile` for test targets
- [ ] Check for `.test/` or `tests/` directories
- [ ] Review `.github/workflows/` for CI test commands
- [ ] Look for test config files: `vitest.config.*`, `jest.config.*`, `pytest.ini`, `pyproject.toml`

**If no test setup found:**
1. Search codebase for testing patterns: `grep("describe(", "it(", "test(", "def test_")`
2. Check README or CONTRIBUTING for testing instructions
3. Look for testing documentation in `.docs/` or `docs/`
4. If truly nothing exists, propose a minimal setup based on project language

**Framework Detection Guide:**

| Language | Config Files to Look For | Test Commands to Try |
|----------|--------------------------|----------------------|
| **Node.js** | `package.json`, `vitest.config.ts`, `jest.config.js` | `npm test`, `bun test`, `vitest` |
| **Python** | `pyproject.toml`, `pytest.ini`, `setup.py` | `pytest`, `python -m pytest` |
| **Go** | `go.mod`, `*_test.go` files | `go test ./...` |
| **Rust** | `Cargo.toml` | `cargo test` |
| **TypeScript** | `tsconfig.json`, `vitest.config.ts` | `vitest`, `npm test` |
| **Java** | `pom.xml`, `build.gradle` | `mvn test`, `gradle test` |

#### 1B: Analyze Existing Tests (If Tests Exist)

**When joining an existing codebase with tests:**

1. **Run the full test suite first**:
   ```bash
   npm test          # or project-specific command
   pytest --tb=short # Python with short traceback
   go test ./...     # Go
   ```

2. **Understand test organization**:
   - [ ] How are test files named? (`*.test.ts`, `*.spec.ts`, `test_*.py`)
   - [ ] Where do tests live? (colocated with source, separate `tests/` dir)
   - [ ] What testing patterns are used? (describe/it, test(), pytest fixtures)
   - [ ] Are there test utilities/helpers? (`tests/utils/`, `testHelpers.ts`)

3. **Check for test conventions in docs**:
   - [ ] `CONTRIBUTING.md` testing section
   - [ ] `docs/testing.md` or similar
   - [ ] Inline comments in test files

#### 1C: Analyze Coverage Gaps (CRITICAL)

**Before adding new code, understand what's already tested and what's not.**

**Coverage Analysis Checklist:**

1. **Run coverage report** (discover the command first):
   ```bash
   # Node.js/TypeScript
   npm test -- --coverage
   vitest --coverage
   
   # Python
   pytest --cov=src --cov-report=html
   coverage run -m pytest && coverage report
   
   # Go
   go test -coverprofile=coverage.out ./...
   go tool cover -html=coverage.out
   ```

2. **Identify untested critical paths**:
   - [ ] Look for files with 0% or low coverage
   - [ ] Check error handling paths (often untested)
   - [ ] Check edge cases (null, empty, boundary values)
   - [ ] Identify public API functions without tests

3. **Prioritize by risk**:
   | Priority | What to Test First |
   |----------|-------------------|
   | **P0 - Critical** | Authentication, authorization, payment, data validation |
   | **P1 - High** | Core business logic, public API endpoints |
   | **P2 - Medium** | Helper utilities, data transformations |
   | **P3 - Low** | Configuration, constants, simple getters |

4. **Search for untested code patterns**:
   ```bash
   # Find functions that might lack tests
   grep -r "export function" src/ | wc -l    # Count exported functions
   grep -r "describe\|it\|test" tests/ | wc -l  # Count test cases
   
   # Look for complex logic (often under-tested)
   grep -rn "if.*else\|switch\|try.*catch" src/
   ```

**Key Principle:** Find what the project already uses. Match existing patterns. Don't introduce new frameworks without approval.

## Scenario-Specific Workflows

### Scenario A: Adding a New Feature to Existing Code

**Context:** Codebase exists with tests. You need to add new functionality.

**Workflow:**

1. **Understand the area you're changing**:
   - [ ] Read existing tests for the module you'll modify
   - [ ] Run those specific tests: `npm test -- --grep "ModuleName"`
   - [ ] Check coverage for that module specifically

2. **Write test for new behavior FIRST**:
   ```
   RED:    test("should validate email format", ...)  → FAILS (feature doesn't exist)
   GREEN:  Add minimal validation logic              → PASSES
   REFACTOR: Clean up, extract helper if needed     → STILL PASSES
   ```

3. **Ensure no regressions**:
   - Run full test suite after each GREEN phase
   - If existing tests break, you changed behavior (fix or discuss)

4. **Follow existing test patterns**:
   ```typescript
   // If existing tests look like this:
   describe("UserService", () => {
     it("should create user with valid data", () => { ... });
   });
   
   // Add your test in the same style:
   describe("UserService", () => {
     it("should validate email format", () => { ... });  // NEW
   });
   ```

### Scenario B: Fixing a Bug

**Context:** Bug reported. Need to fix without breaking other things.

**Workflow:**

1. **Reproduce the bug with a failing test FIRST**:
   ```typescript
   // This test MUST fail before you write any fix
   it("should not allow negative quantities (BUG-123)", () => {
     const result = addToCart({ quantity: -5 });
     expect(result.error).toBe("Quantity must be positive");
   });
   ```

2. **Run the test - confirm it FAILS for the right reason**:
   - Should fail on assertion, not syntax/import error
   - The failure should match the bug behavior

3. **Write minimal fix**:
   - Change ONLY what's needed to make test pass
   - Don't refactor yet, don't fix "other things you noticed"

4. **Run full test suite**:
   - Your bug fix test passes
   - All other tests still pass
   - If other tests fail, your fix has side effects (investigate)

5. **Commit pattern**:
   ```
   test(cart): add failing test for negative quantity bug (#123)
   fix(cart): validate quantity is positive (#123)
   ```

### Scenario C: Refactoring Existing Code

**Context:** Code works but needs cleanup. Tests already exist.

**Workflow:**

1. **Ensure comprehensive test coverage FIRST**:
   - [ ] Run coverage on the code you'll refactor
   - [ ] If coverage < 80%, add characterization tests first
   - [ ] Tests should capture current behavior (even if "wrong")

2. **Characterization tests for poorly-tested code**:
   ```typescript
   // Capture CURRENT behavior, even if unexpected
   it("handles null input by returning empty array", () => {
     // This documents what the code DOES, not what it SHOULD do
     expect(processData(null)).toEqual([]);
   });
   ```

3. **Refactor in small steps**:
   - Make ONE change
   - Run tests
   - If GREEN, continue
   - If RED, undo and try smaller change

4. **Never change behavior during refactor**:
   - If tests fail, you changed behavior
   - Either: revert and refactor differently
   - Or: make behavior change a SEPARATE commit with new tests

### Scenario D: Working with Legacy Code (No Tests)

**Context:** Existing code with no tests. Need to modify it safely.

**Workflow:**

1. **Add characterization tests BEFORE changing anything**:
   ```typescript
   describe("LegacyPaymentProcessor", () => {
     it("processes payment with current behavior", () => {
       // Test what it DOES, not what you think it SHOULD do
       const result = processPayment({ amount: 100 });
       expect(result).toMatchSnapshot(); // Capture current output
     });
   });
   ```

2. **Build safety net around the area you'll change**:
   - [ ] Test happy path
   - [ ] Test error cases (null, empty, invalid input)
   - [ ] Test boundary conditions

3. **Only then apply TDD for your changes**:
   - Write failing test for new behavior
   - Implement
   - Refactor

4. **Coverage target for legacy code**:
   - Don't aim for 100% immediately
   - Focus on the code paths YOU will touch
   - Leave unrelated legacy code for later

## Coverage Analysis Deep Dive

### Finding Critical Untested Code

**Step 1: Generate coverage report**
```bash
# Most frameworks output HTML report
npm test -- --coverage --coverageReporters=html
open coverage/index.html
```

**Step 2: Identify high-risk gaps**

| Risk Indicator | How to Find | Priority |
|----------------|-------------|----------|
| **0% coverage files** | Coverage report red files | Check if critical |
| **Uncovered branches** | Yellow highlighting in report | Often error paths |
| **Complex functions** | High cyclomatic complexity | Likely has bugs |
| **Public API without tests** | `grep "export" | compare to tests` | User-facing risk |
| **Error handlers** | `grep "catch\|throw\|error"` | Often untested |

**Step 3: Prioritize what to test**

```
Priority Matrix:
                    High Business Impact    Low Business Impact
High Complexity     P0 - Test immediately   P2 - Test when touched
Low Complexity      P1 - Test soon          P3 - Test if time permits
```

**Step 4: Create coverage improvement plan**
```markdown
## Coverage Gaps to Address

### P0 - Critical (This Sprint)
- [ ] `src/auth/validateToken.ts` - 0% coverage, handles auth
- [ ] `src/payment/processRefund.ts` - no error path tests

### P1 - High (Next Sprint)  
- [ ] `src/api/userController.ts` - missing edge cases
- [ ] `src/utils/validation.ts` - boundary conditions untested
```

### Continuous Coverage Monitoring

**In CI/CD, enforce coverage doesn't decrease:**
```yaml
# Example: GitHub Actions
- name: Check coverage threshold
  run: |
    npm test -- --coverage --coverageThreshold='{"global":{"branches":80}}'
```

**Coverage ratchet pattern:**
- Never allow coverage to decrease
- New code must have tests
- Gradually improve legacy coverage

## The TDD Phases (Detailed)

### Step 2: 🔴 The Red Phase

1. **Create or Select Test File**: Follow project's existing test file patterns
2. **Write ONE Test**: Focus on **one small behavior or edge case**
3. **Run Test**: Execute your test runner (detected in Step 1)
4. **VERIFY RED**: Ensure it **FAILS for the expected reason** (assertion error, not syntax error)

**Verification Questions:**
- [ ] Did I write more than one test? (Should be NO)
- [ ] Did I verify the failure reason? (Should be YES)
- [ ] Can I explain why this test should fail? (Should be YES)

**If test passes immediately** → **STOP and investigate.** Test is broken or feature already exists.

**Red Phase Anti-Patterns:**
- ❌ Writing implementation code while test is failing
- ❌ Writing multiple tests before implementing
- ❌ Writing full solution with optimizations

### Step 3: 🟢 The Green Phase

1. **Write Minimal Code**: Implement **just enough** logic to satisfy the test
2. **Do NOT** implement "perfect" solution yet
3. **Do NOT** add extra features "while you're there"
4. **Run Test**: Execute test runner
5. **VERIFY GREEN**: Ensure the test **passes**

**Verification Questions:**
- [ ] Can I delete this code and have tests still pass? (Dead code check)
- [ ] Is this the simplest solution? (Should be YES)

**Green Phase Anti-Patterns:**
- ❌ Over-engineering with abstractions or design patterns
- ❌ Adding unrelated code while fixing

### Step 4: 🔵 The Refactor Phase

1. **Analyze**: Look for duplication, messy logic, unclear naming
2. **Improve**: Clean up implementation **without changing behavior**
3. **Run Test**: Execute test runner
4. **VERIFY GREEN**: Ensure **no regressions**

**Refactoring Heuristics:**
- Extract helper methods
- Consolidate similar logic
- Improve names for clarity
- Remove magic numbers and strings

**Refactor Phase Anti-Patterns:**
- ❌ Changing behavior while refactoring
- ❌ Skipping test verification

### Step 5: Repeat

Select the next small behavior and return to Step 2.

## Stop Conditions

| Signal | Response |
|--------|----------|
| **Test passes immediately** | Check assertions, ensure test is running, or verify feature isn't already built |
| **Test fails for wrong reason** | Fix setup/imports. Red must be an assertion failure, not syntax error |
| **Flaky Test** | **STOP.** Fix non-determinism immediately. Do not proceed |
| **Slow Feedback** | If tests take >5s, optimize or mock external calls |
| **Coverage decreased** | Add tests for uncovered paths before proceeding |

### Flaky Tests

**Definition:** Tests that pass sometimes and fail others without code changes.

**Common Causes:**
- Shared mutable state (global variables, databases)
- Order-dependent execution
- Network calls to external services
- Time-based logic (`Date.now()`, timestamps)
- Race conditions (async operations)

**Detection:**
- Run test multiple times: `npm test --runInBand`, `pytest --count=5`
- Isolate flaky tests in separate runs

### Test Pyramid

| Level | % of Tests | Scope | Speed | Examples |
|-------|------------|-------|-------|----------|
| **Unit** | 70-80% | Single function/class | Milliseconds | `add(a, b) returns sum` |
| **Integration** | 15-20% | Module interactions | Seconds | `User.create({name})` |
| **E2E** | 5-10% | Full application | Minutes | `GET /api/users` |

**Guidance:**
- Push testing **down the pyramid** (unit → integration → E2E)
- If error can be caught by unit test, **don't write integration test**
- Use **mocks and fixtures** for external dependencies

### Anti-Patterns

**Key Anti-Patterns:**
- ❌ **Refactoring While Red**: Never change code structure while tests are failing
- ❌ **The Multi-Test Step**: Writing multiple tests before implementing
- ❌ **The Big Bang**: Implementing complex feature without tests
- ❌ **The Mockery**: Mocking internal implementation details
- ❌ **The Inspector**: Testing private state or method call sequences
- ❌ **The Liar**: Test passes but doesn't test intended requirement
- ❌ **Skipping Tests**: Running full suite to verify green, skipping flaky tests
- ❌ **Coverage Theater**: Adding tests that don't assert meaningful behavior

**Gate Questions:**
1. Am I refactoring to make the test pass? (Should be NO)
2. Did I write more than one failing test? (Should be NO)
3. Have I verified the failure reason? (Should be YES)
4. Can I delete this code and tests still pass? (Dead code check)
5. Is this the simplest solution? (Should be YES)
6. Did I check existing coverage before starting? (Should be YES)

## Integration

| Task | Skill | Usage |
|------|-------|-------|
| **Committing** | `git-commit` | Use `test: ...` commits for RED, `feat: ...` for GREEN |
| **Code Quality** | `code-quality` | Run linting/formatting during Refactor phase |
| **Documentation** | `docs-check` | Check if behavior changes require doc updates |

**Commit Pattern Example:**
1. `test(auth): add failing test for validation` (RED)
2. `feat(auth): implement auth logic` (GREEN)
3. `refactor(auth): simplify user validation` (REFACTOR)

### Additional Quality Practices

**Short Feedback Loops:**
- Keep test suites fast (<30s full suite, <5s single test)
- Run tests after every code change
- Use watch mode: `npm test --watch`, `pytest-watch`

**Hermetic Testing:**
- Use unique temp directories for each test
- Reset state in setUp/tearDown
- Avoid global state and shared mutable objects
- Order-independent execution

**External Dependencies:**
- Mock slow or unreliable external services
- Use in-memory databases for integration tests
- Fake network responses for HTTP API tests

## References

- [The Three Rules of TDD](https://butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd) - Robert C. Martin's foundational principles
- [Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html) - Martin Fowler on test distribution
- [Test Sizes](https://testing.googleblog.com/2010/12/test-sizes.html) - Google Testing Blog on categorization
- [Hermetic Servers](https://testing.googleblog.com/2012/10/hermetic-servers.html) - Google on isolated testing
- [Working Effectively with Legacy Code](https://www.oreilly.com/library/view/working-effectively-with/0131177052/) - Michael Feathers on characterization tests
