# TDD Examples

Practical examples for each TDD mode and advanced technique. Reference these when applying the workflows in SKILL.md.

---

## Mode Examples

### New Feature: Password Validation

Step-by-step TDD for a password validator with multiple rules.

```javascript
// Scenario List Before Starting:
// - [x] Empty password should fail
// - [ ] Short password (<8 chars) should fail
// - [ ] Password without uppercase should fail
// - [ ] Password without number should fail
// - [ ] Valid password should pass

// 🔴 RED - First scenario: empty password
test('empty password fails', () => {
  expect(validatePassword('')).toBe(false);
});
// Run: npm test → FAILS

// 🟢 GREEN - Minimal implementation
function validatePassword(password) {
  return password.length > 0;
}
// Run: npm test → PASSES

// 🔴 RED - Second scenario: short password
test('short password fails', () => {
  expect(validatePassword('abc')).toBe(false);
});
// Run: npm test → FAILS

// 🟢 GREEN - Update implementation
function validatePassword(password) {
  return password.length >= 8;
}
// Run: npm test → PASSES

// 🔵 REFACTOR - Extract constant
const MIN_PASSWORD_LENGTH = 8;
function validatePassword(password) {
  return password.length >= MIN_PASSWORD_LENGTH;
}
// Run: npm test → STILL PASSES

// 🔴 RED - Third scenario: missing uppercase
test('password without uppercase fails', () => {
  expect(validatePassword('password123')).toBe(false);
});
// Run: npm test → FAILS

// 🟢 GREEN - Add uppercase check
function validatePassword(password) {
  return password.length >= 8 && /[A-Z]/.test(password);
}
// Run: npm test → PASSES

// 🔵 REFACTOR - Improve readability
function validatePassword(password) {
  const hasValidLength = password.length >= MIN_PASSWORD_LENGTH;
  const hasUppercase = /[A-Z]/.test(password);
  return hasValidLength && hasUppercase;
}
// Run: npm test → STILL PASSES

// Continue pattern for remaining scenarios...
// Final implementation:
function validatePassword(password) {
  if (!password || typeof password !== 'string') return false;
  
  const hasValidLength = password.length >= MIN_PASSWORD_LENGTH;
  const hasUppercase = /[A-Z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  
  return hasValidLength && hasUppercase && hasNumber;
}
```

---

### Bug Fix: Empty Array Handling

Reproducing and fixing a bug with test-first approach.

```javascript
// Bug Report: calculateTotal(items) returns undefined when items array is empty.

// 🔴 RED - Reproduction test (MUST fail before fix)
test('returns 0 for empty array', () => {
  expect(calculateTotal([])).toBe(0);
});
// Run: npm test → FAILS (returns undefined)

// 🟢 GREEN - Fix the bug
function calculateTotal(items) {
  if (!items || items.length === 0) return 0;
  return items.reduce((sum, item) => sum + item.price, 0);
}
// Run: npm test → PASSES

// 🔵 REFACTOR - Extract validation
function isValidArray(arr) {
  return Array.isArray(arr) && arr.length > 0;
}

function calculateTotal(items) {
  if (!isValidArray(items)) return 0;
  return items.reduce((sum, item) => sum + item.price, 0);
}
// Run: npm test → STILL PASSES
```

---

### Legacy Code: Characterization Tests

Adding tests to untested code before modifying it.

```javascript
// Context: Existing calculateDiscount function with no tests.

// Step 1: ADD CHARACTERIZATION TESTS - Don't change code yet
test('characterization: calculates 10% discount for VIP', () => {
  expect(calculateDiscount(100, 'VIP')).toBe(10);
});

test('characterization: calculates 5% discount for regular', () => {
  expect(calculateDiscount(100, 'regular')).toBe(5);
});

test('characterization: returns 0 for unknown customer type', () => {
  expect(calculateDiscount(100, 'unknown')).toBe(0);
});
// Run: npm test → Captures CURRENT behavior

// Step 2: Now add new feature with TDD

// 🔴 RED - Test for new feature: VIP tier discount
test('VIP gold tier gets extra 5% discount', () => {
  expect(calculateDiscount(100, 'VIP', 'gold')).toBe(15);
});
// Run: npm test → FAILS

// 🟢 GREEN - Implement feature
const DISCOUNT_RATES = { 'VIP': 0.10, 'regular': 0.05 };
const TIER_BONUS = { 'VIP': { 'gold': 0.05 } };

function calculateDiscount(amount, customerType, tier = null) {
  if (!amount || amount <= 0) return 0;
  const baseDiscount = amount * (DISCOUNT_RATES[customerType] || 0);
  const tierBonus = TIER_BONUS[customerType]?.[tier] 
    ? amount * TIER_BONUS[customerType][tier] 
    : 0;
  return baseDiscount + tierBonus;
}
// Run: npm test → ALL TESTS PASS (characterization + new)
```

---

## Test Double Examples

### MSW (Mock Service Worker) for API Testing

```javascript
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  http.get('/api/users', () => {
    return HttpResponse.json([
      { id: 1, name: 'John' },
      { id: 2, name: 'Jane' }
    ]);
  }),
  
  http.post('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: 3, ...body }, { status: 201 });
  }),
  
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'User' });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test('fetches users list', async () => {
  const users = await fetchUsers();
  expect(users).toHaveLength(2);
  expect(users[0].name).toBe('John');
});

test('handles server error', async () => {
  server.use(
    http.get('/api/users', () => {
      return new HttpResponse(null, { status: 500 });
    })
  );
  
  await expect(fetchUsers()).rejects.toThrow('Server error');
});
```

### Fake vs Mock Decision

```javascript
// ❌ OVER-MOCKING - Brittle, tests implementation details
test('saves user with mock', () => {
  const mockDb = { insert: jest.fn().mockResolvedValue({ id: 1 }) };
  const service = new UserService(mockDb);
  
  await service.createUser({ name: 'John' });
  
  expect(mockDb.insert).toHaveBeenCalledWith('users', { name: 'John' });
  // Breaks if we rename 'insert' to 'create' even if behavior is same
});

// ✅ FAKE - Tests behavior, not implementation
class FakeUserDb {
  users = [];
  
  async insert(table, data) {
    const user = { id: this.users.length + 1, ...data };
    this.users.push(user);
    return user;
  }
  
  async findById(id) {
    return this.users.find(u => u.id === id);
  }
}

test('saves user with fake', async () => {
  const fakeDb = new FakeUserDb();
  const service = new UserService(fakeDb);
  
  const user = await service.createUser({ name: 'John' });
  
  expect(user.id).toBeDefined();
  expect(await fakeDb.findById(user.id)).toEqual({ id: 1, name: 'John' });
  // Tests BEHAVIOR - works regardless of internal implementation
});
```

---

## Hermetic Testing Examples

### Testcontainers (Database Isolation)

```javascript
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import { Pool } from 'pg';

describe('UserRepository Integration', () => {
  let container;
  let pool;

  beforeAll(async () => {
    // Spin up isolated Postgres for this test suite
    container = await new PostgreSqlContainer('postgres:16-alpine')
      .withDatabase('test_db')
      .withStartupTimeout(120_000)
      .start();
    
    pool = new Pool({ connectionString: container.getConnectionUri() });
    
    // Run migrations
    await pool.query(`
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL
      )
    `);
  }, 180_000);

  afterAll(async () => {
    await pool.end();
    await container.stop();
  });

  beforeEach(async () => {
    // Clean slate for each test
    await pool.query('TRUNCATE users RESTART IDENTITY CASCADE');
  });

  test('creates and retrieves user', async () => {
    const repo = new UserRepository(pool);
    
    const created = await repo.create({ name: 'John', email: 'john@example.com' });
    expect(created.id).toBe(1);
    
    const found = await repo.findById(1);
    expect(found.name).toBe('John');
  });

  test('enforces unique email constraint', async () => {
    const repo = new UserRepository(pool);
    
    await repo.create({ name: 'John', email: 'john@example.com' });
    
    await expect(
      repo.create({ name: 'Jane', email: 'john@example.com' })
    ).rejects.toThrow(/unique/i);
  });
});
```

### Transactional Rollback (Faster Alternative)

```javascript
describe('UserService with Transaction Rollback', () => {
  let pool;
  let client;

  beforeAll(async () => {
    pool = new Pool({ connectionString: process.env.TEST_DATABASE_URL });
  });

  afterAll(async () => {
    await pool.end();
  });

  beforeEach(async () => {
    client = await pool.connect();
    await client.query('BEGIN'); // Start transaction
  });

  afterEach(async () => {
    await client.query('ROLLBACK'); // Undo all changes
    client.release();
  });

  test('creates user within transaction', async () => {
    const repo = new UserRepository(client);
    const user = await repo.create({ name: 'Test' });
    expect(user.id).toBeDefined();
    // After test: ROLLBACK undoes this insert
  });
});
```

---

## Property-Based Testing Examples

### JavaScript/TypeScript with fast-check

```javascript
import fc from 'fast-check';

// Instead of example-based tests:
test('add positive', () => expect(add(2, 3)).toBe(5));
test('add negative', () => expect(add(-2, -3)).toBe(-5));
test('add zero', () => expect(add(0, 5)).toBe(5));

// Use property-based tests:
test('addition is commutative', () => {
  fc.assert(fc.property(
    fc.integer(), fc.integer(),
    (a, b) => add(a, b) === add(b, a)
  ));
});

test('addition has identity element (zero)', () => {
  fc.assert(fc.property(
    fc.integer(),
    (a) => add(a, 0) === a
  ));
});

test('addition is associative', () => {
  fc.assert(fc.property(
    fc.integer(), fc.integer(), fc.integer(),
    (a, b, c) => add(add(a, b), c) === add(a, add(b, c))
  ));
});

// Testing with complex objects
test('user serialization round-trips', () => {
  const userArbitrary = fc.record({
    id: fc.uuid(),
    name: fc.string({ minLength: 1, maxLength: 100 }),
    email: fc.emailAddress(),
    age: fc.integer({ min: 0, max: 150 })
  });

  fc.assert(fc.property(userArbitrary, (user) => {
    const serialized = JSON.stringify(user);
    const deserialized = JSON.parse(serialized);
    return deepEqual(user, deserialized);
  }));
});
```

### Python with Hypothesis

```python
from hypothesis import given, strategies as st

@given(st.integers(), st.integers())
def test_addition_commutative(a, b):
    assert add(a, b) == add(b, a)

@given(st.lists(st.integers()))
def test_sort_is_idempotent(xs):
    assert sorted(sorted(xs)) == sorted(xs)

@given(st.lists(st.integers()))
def test_sort_preserves_length(xs):
    assert len(sorted(xs)) == len(xs)

# State machine testing
from hypothesis.stateful import RuleBasedStateMachine, rule, invariant

class SetStateMachine(RuleBasedStateMachine):
    def __init__(self):
        super().__init__()
        self.model = set()
        self.impl = MySetImplementation()
    
    @rule(value=st.integers())
    def add(self, value):
        self.model.add(value)
        self.impl.add(value)
    
    @rule(value=st.integers())
    def remove(self, value):
        self.model.discard(value)
        self.impl.remove(value)
    
    @invariant()
    def sets_match(self):
        assert set(self.impl) == self.model

TestSet = SetStateMachine.TestCase
```

---

## Mutation Testing Examples

### Stryker (JavaScript/TypeScript)

```bash
# Install
npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner

# stryker.config.json
{
  "packageManager": "npm",
  "testRunner": "vitest",
  "coverageAnalysis": "perTest",
  "mutate": ["src/**/*.ts", "!src/**/*.test.ts"],
  "reporters": ["html", "clear-text", "progress"]
}

# Run
npx stryker run
```

**Interpreting Results:**
```
Mutation testing report:
─────────────────────────
File            Mutants  Killed  Survived  Score
src/calc.ts     45       42      3         93.3%
src/validate.ts 23       23      0         100%
─────────────────────────
Total           68       65      3         95.6%

Survived mutants (investigate these):
1. src/calc.ts:15 - Changed > to >= (boundary mutation)
2. src/calc.ts:23 - Removed return statement
3. src/calc.ts:31 - Changed + to -
```

**Fix surviving mutants by adding edge case tests:**
```javascript
// Mutant: Changed > to >= at line 15
// Original: if (amount > 0)
// Mutant:   if (amount >= 0)

// Add test for boundary:
test('rejects zero amount', () => {
  expect(processPayment(0)).toBe(false);
});
```

---

## Flaky Test Examples

### Identifying Flaky Patterns

```javascript
// ❌ FLAKY - Depends on timing
test('debounce calls function after delay', async () => {
  const fn = jest.fn();
  const debounced = debounce(fn, 100);
  
  debounced();
  await sleep(150); // Race condition!
  
  expect(fn).toHaveBeenCalled();
});

// ✅ STABLE - Use fake timers
test('debounce calls function after delay', () => {
  jest.useFakeTimers();
  const fn = jest.fn();
  const debounced = debounce(fn, 100);
  
  debounced();
  expect(fn).not.toHaveBeenCalled();
  
  jest.advanceTimersByTime(100);
  expect(fn).toHaveBeenCalledTimes(1);
  
  jest.useRealTimers();
});

// ❌ FLAKY - Random order dependency
test('processes items', async () => {
  const results = await Promise.all([
    processItem(1),
    processItem(2),
    processItem(3)
  ]);
  
  expect(results).toEqual([1, 2, 3]); // Order not guaranteed!
});

// ✅ STABLE - Don't depend on order
test('processes items', async () => {
  const results = await Promise.all([
    processItem(1),
    processItem(2),
    processItem(3)
  ]);
  
  expect(results).toHaveLength(3);
  expect(results).toContain(1);
  expect(results).toContain(2);
  expect(results).toContain(3);
});
```

### Quarantine Pattern

```javascript
// vitest.config.ts
export default defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
    exclude: ['src/**/*.flaky.test.ts'], // Quarantine
  }
});

// Separate config for flaky tests (run separately, don't block CI)
// vitest.config.flaky.ts
export default defineConfig({
  test: {
    include: ['src/**/*.flaky.test.ts'],
    retry: 3,
  }
});
```

---

## Contract Testing Examples

### Pact (Consumer-Driven Contracts)

```javascript
// Consumer side (frontend/client)
import { PactV3, MatchersV3 } from '@pact-foundation/pact';

const provider = new PactV3({
  consumer: 'WebApp',
  provider: 'UserService',
});

describe('User API Contract', () => {
  test('get user by id', async () => {
    await provider
      .given('user 1 exists')
      .uponReceiving('a request for user 1')
      .withRequest({
        method: 'GET',
        path: '/users/1',
      })
      .willRespondWith({
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          id: MatchersV3.integer(1),
          name: MatchersV3.string('John'),
          email: MatchersV3.email(),
        },
      })
      .executeTest(async (mockServer) => {
        const client = new UserClient(mockServer.url);
        const user = await client.getUser(1);
        
        expect(user.id).toBe(1);
        expect(user.name).toBeDefined();
      });
  });
});

// Provider side (backend) - verifies the contract
import { Verifier } from '@pact-foundation/pact';

describe('Provider Verification', () => {
  test('validates consumer contracts', async () => {
    const verifier = new Verifier({
      providerBaseUrl: 'http://localhost:3000',
      pactUrls: ['./pacts/webapp-userservice.json'],
      stateHandlers: {
        'user 1 exists': async () => {
          await db.users.create({ id: 1, name: 'John', email: 'john@test.com' });
        },
      },
    });
    
    await verifier.verifyProvider();
  });
});
```

---

## Snapshot Testing Examples

### When Snapshots Are Appropriate

```javascript
// ✅ GOOD - UI component structure
test('Button renders correctly', () => {
  const { container } = render(
    <Button variant="primary" size="lg">Click me</Button>
  );
  expect(container.firstChild).toMatchSnapshot();
});

// ✅ GOOD - API response shape (not values)
test('user response has correct shape', () => {
  const response = transformUserResponse(rawApiData);
  expect(response).toMatchSnapshot();
});

// ✅ GOOD - Error message format
test('validation error format', () => {
  const errors = validate({ email: 'invalid' });
  expect(errors).toMatchSnapshot();
});
```

### When to Avoid Snapshots

```javascript
// ❌ BAD - Testing behavior, not structure
test('calculates total', () => {
  expect(calculateTotal([10, 20, 30])).toMatchSnapshot();
  // Use: expect(...).toBe(60)
});

// ❌ BAD - Dynamic content
test('shows current time', () => {
  const { container } = render(<Clock />);
  expect(container).toMatchSnapshot(); // Fails every second!
});

// ❌ BAD - Entire page (too broad)
test('home page', () => {
  const { container } = render(<HomePage />);
  expect(container).toMatchSnapshot(); // Any change breaks this
});
```

### Inline Snapshots for Small Values

```javascript
test('formats currency', () => {
  expect(formatCurrency(1234.56)).toMatchInlineSnapshot(`"$1,234.56"`);
  expect(formatCurrency(0)).toMatchInlineSnapshot(`"$0.00"`);
  expect(formatCurrency(-99.99)).toMatchInlineSnapshot(`"-$99.99"`);
});
```
