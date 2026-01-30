# TDD Examples

This document provides practical examples of Test-Driven Development in action across different scenarios.

## Example 1: Simple Function (Happy Path)

**Requirement**: Implement a function that adds two numbers.

```javascript
// 🔴 RED - Write failing test first
test('adds two numbers', () => {
  expect(add(2, 3)).toBe(5);
});

// Run: npm test → FAILS (add is not defined)
```

```javascript
// 🟢 GREEN - Minimal implementation
function add(a, b) {
  return a + b;
}

// Run: npm test → PASSES
```

```javascript
// 🔵 REFACTOR - Improve if needed
// In this case, function is already minimal. No refactoring needed.

// Run: npm test → STILL PASSES
```

## Example 2: Bug Fix with Reproduction Test

**Bug Report**: `calculateTotal(items)` returns wrong result when items array is empty.

```javascript
// 🔴 RED - Reproduction test
test('returns 0 for empty array', () => {
  expect(calculateTotal([])).toBe(0);
});

// Run: npm test → FAILS (returns undefined or wrong value)
```

```javascript
// 🟢 GREEN - Fix the bug
function calculateTotal(items) {
  if (!items || items.length === 0) return 0;
  return items.reduce((sum, item) => sum + item.price, 0);
}

// Run: npm test → PASSES
```

```javascript
// 🔵 REFACTOR - Extract validation helper
function calculateTotal(items) {
  if (!isValidArray(items)) return 0;
  return items.reduce((sum, item) => sum + item.price, 0);
}

function isValidArray(items) {
  return Array.isArray(items) && items.length >= 0;
}

// Run: npm test → STILL PASSES
```

## Example 3: New Feature with Multiple Scenarios

**Requirement**: Implement password validation with complexity rules.

**Scenario List Before Starting:**
- [x] Empty password should fail
- [ ] Short password (< 8 chars) should fail
- [ ] Password without uppercase should fail
- [ ] Password without number should fail
- [ ] Valid password should pass

```javascript
// 🔴 RED - First scenario: empty password
test('empty password fails', () => {
  expect(validatePassword('')).toBe(false);
});

// Run: npm test → FAILS
```

```javascript
// 🟢 GREEN - Minimal implementation
function validatePassword(password) {
  return password.length > 0;
}

// Run: npm test → PASSES
```

```javascript
// 🔵 REFACTOR - No changes needed yet
// Move to next scenario
```

```javascript
// 🔴 RED - Second scenario: short password
test('short password fails', () => {
  expect(validatePassword('abc')).toBe(false);
});

// Run: npm test → FAILS (current implementation passes)
```

```javascript
// 🟢 GREEN - Update implementation
function validatePassword(password) {
  return password.length >= 8;
}

// Run: npm test → PASSES both tests
```

```javascript
// 🔵 REFACTOR - Extract constant
const MIN_PASSWORD_LENGTH = 8;

function validatePassword(password) {
  return password.length >= MIN_PASSWORD_LENGTH;
}

// Run: npm test → STILL PASSES
```

```javascript
// 🔴 RED - Third scenario: missing uppercase
test('password without uppercase fails', () => {
  expect(validatePassword('password123')).toBe(false);
});

// Run: npm test → FAILS
```

```javascript
// 🟢 GREEN - Add uppercase check
function validatePassword(password) {
  return password.length >= 8 && /[A-Z]/.test(password);
}

// Run: npm test → PASSES all tests
```

```javascript
// 🔵 REFACTOR - Improve readability
function validatePassword(password) {
  const hasValidLength = password.length >= MIN_PASSWORD_LENGTH;
  const hasUppercase = /[A-Z]/.test(password);

  return hasValidLength && hasUppercase;
}

// Run: npm test → STILL PASSES
```

```javascript
// 🔴 RED - Fourth scenario: missing number
test('password without number fails', () => {
  expect(validatePassword('Password')).toBe(false);
});

// Run: npm test → FAILS
```

```javascript
// 🟢 GREEN - Add number check
function validatePassword(password) {
  return password.length >= MIN_PASSWORD_LENGTH
    && /[A-Z]/.test(password)
    && /[0-9]/.test(password);
}

// Run: npm test → PASSES all tests
```

```javascript
// 🔵 REFACTOR - Extract regex patterns
const hasUppercase = /[A-Z]/;
const hasNumber = /[0-9]/;

function validatePassword(password) {
  const hasValidLength = password.length >= MIN_PASSWORD_LENGTH;

  return hasValidLength
    && hasUppercase.test(password)
    && hasNumber.test(password);
}

// Run: npm test → STILL PASSES
```

```javascript
// 🔴 RED - Final scenario: valid password
test('valid password passes', () => {
  expect(validatePassword('Password123')).toBe(true);
});

// Run: npm test → PASSES
```

```javascript
// 🟢 GREEN - Already passes, no changes needed
// Implementation is complete
```

```javascript
// 🔵 REFACTOR - Final polish
function validatePassword(password) {
  if (!password || typeof password !== 'string') {
    return false;
  }

  const hasValidLength = password.length >= MIN_PASSWORD_LENGTH;
  const hasUppercase = /[A-Z]/.test(password);
  const hasNumber = /[0-9]/.test(password);

  return hasValidLength && hasUppercase && hasNumber;
}

// Run: npm test → STILL PASSES
```

## Example 4: Legacy Code with Characterization Tests

**Context**: Existing `calculateDiscount` function with no tests. Need to modify safely.

```javascript
// 🔵 ADD CHARACTERIZATION TESTS - Don't change code yet
test('characterization: calculates 10% discount for VIP', () => {
  const result = calculateDiscount(100, 'VIP');
  expect(result).toBe(10);
});

test('characterization: calculates 5% discount for regular', () => {
  const result = calculateDiscount(100, 'regular');
  expect(result).toBe(5);
});

test('characterization: returns 0 for unknown customer type', () => {
  const result = calculateDiscount(100, 'unknown');
  expect(result).toBe(0);
});

// Run: npm test → SOME FAIL, SOME PASS
// This captures CURRENT behavior (even if buggy)
```

Now you have a safety net. Make your changes with TDD:

```javascript
// 🔴 RED - Test for new feature: VIP tier discount
test('VIP tier gets extra 5% discount', () => {
  const result = calculateDiscount(100, 'VIP', 'gold');
  expect(result).toBe(15); // 10% base + 5% tier
});

// Run: npm test → FAILS
```

```javascript
// 🟢 GREEN - Implement feature
function calculateDiscount(amount, customerType, tier = null) {
  if (!amount || amount <= 0) return 0;

  const discountRate = {
    'VIP': 0.10,
    'regular': 0.05,
    'unknown': 0
  }[customerType] || 0;

  const baseDiscount = amount * discountRate;
  const tierBonus = customerType === 'VIP' && tier === 'gold'
    ? amount * 0.05
    : 0;

  return baseDiscount + tierBonus;
}

// Run: npm test → ALL TESTS PASS
```

```javascript
// 🔵 REFACTOR - Extract rate mapping
const DISCOUNT_RATES = {
  'VIP': 0.10,
  'regular': 0.05,
  'unknown': 0
};

const TIER_BONUS = {
  'VIP': {
    'gold': 0.05
  }
};

function calculateDiscount(amount, customerType, tier = null) {
  if (!amount || amount <= 0) return 0;

  const baseDiscount = amount * (DISCOUNT_RATES[customerType] || 0);
  const tierBonus = TIER_BONUS[customerType]?.[tier] ? amount * TIER_BONUS[customerType][tier] : 0;

  return baseDiscount + tierBonus;
}

// Run: npm test → STILL PASSES
```

## Key Takeaways

1. **Always write ONE test at a time** - Don't write multiple RED tests before going GREEN
2. **Verify RED properly** - Ensure test fails for the RIGHT reason (assertion, not syntax error)
3. **Minimal GREEN** - Write just enough to pass, don't over-engineer
4. **Refactor frequently** - Clean up after each GREEN, don't wait until end
5. **Characterization tests** - When working with legacy code, add tests FIRST before changing
6. **Scenario list** - Before starting, list ALL scenarios you need to cover

## Anti-Patterns to Avoid

### ❌ Mirror Blindness
Writing implementation details into tests:

```javascript
// BAD - Test replicates implementation
test('adds numbers by returning a + b', () => {
  expect(add(2, 3)).toBe(5);
});

// BETTER - Test describes behavior
test('adds two numbers and returns their sum', () => {
  expect(add(2, 3)).toBe(5);
});
```

### ❌ The Multi-Test Step
Writing all tests before any implementation:

```javascript
// BAD - Writing 5 tests before any code
test('scenario 1', () => { ... });
test('scenario 2', () => { ... });
test('scenario 3', () => { ... });
test('scenario 4', () => { ... });
test('scenario 5', () => { ... });
// Now implementing all 5 at once...

// BETTER - Write one test, implement it, move to next
test('scenario 1', () => { ... });
// Implement scenario 1
test('scenario 2', () => { ... });
// Implement scenario 2
```

### ❌ Happy Path Bias
Only testing success cases:

```javascript
// BAD - Only happy path
test('calculates discount correctly', () => { ... });

// BETTER - Include error cases
test('calculates discount correctly', () => { ... });
test('handles negative amount gracefully', () => { ... });
test('handles null input gracefully', () => { ... });
```
