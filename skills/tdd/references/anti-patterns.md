# Antipatterns and phase examples

Read when a red flag fires and the fix is not in Rules. Most antipatterns break one Test Desiderata property. Name the lost property, then pick the fix.

## Catalog

| Name | Symptom | Why it hurts | Fix |
|---|---|---|---|
| **All tests first / horizontal slicing** | 5+ red tests before any code | The first green changes decisions, so every test needs rework | One test, make it pass, then the next |
| **The Liar** | Test passes but checks nothing: missing `await`, aliased objects, tautology | False confidence. Breaks *Behavioral* | Watch every new test fail |
| **Unreadable failures** | `False is not true`, `expected true` | Every failure needs a debugging session. Breaks *Specific* | Read the message while red. Described assertions, matchers, readable `repr` |
| **Weakened assertions** | Assertion removed, loosened, or test skipped to reach green | A green bar that proves nothing | Fix the code, not the oracle |
| **Pasted expected values** | Expected value copied from actual output | Pins current bugs | Derive values by hand or from the spec |
| **Assertion-free test** | No assert; passes if nothing throws | Coverage with no verification | Assert the outcome, or assert the exception |
| **Config value test** | `expect(config.x).to eq(true)` | Passes when the setting is ignored | Assert the behavior the setting enables, at the application layer |
| **Testing a dependency's internals** | Asserting how a gem or library works inside | Breaks on upgrade. Verifies nothing you own | Test your code's outcome. If the effect is entirely inside the dependency, do not test it |
| **Bug fixed without a failing test** | Defect fixed, no test added | Diagnosis unproven. The defect can return | Regression test first |
| **Skipped refactor** | Tested but tangled code | "Messy aggregation of code fragments" | Refactor on green every cycle that needs it |
| **Refactoring while red** | Structural edits while a test fails | Cannot tell which change broke what | Two hats: make it run, then make it right |
| **Test and code changed in one step** | Both edited together during a refactor | No stable oracle for that step | One side at a time, on green |
| **Premature abstraction** | Helpers and layers after one use | Indirection that later tests may prove wrong | Wait for the third instance |
| **Mirrored structure** | One test class per production class; tests break on extract or rename | Blocks refactoring. Breaks *Structure-insensitive* | New test only for new behavior. Test through the public API |
| **The Inspector** | Reflection, test-only getters, private methods made public | Breaks on internal change | Test via the public API. Extract a type if private logic needs its own tests |
| **The Mockery** | The test mainly proves the mocks work | Coupled to call patterns | Real collaborators. Doubles only at owned boundaries |
| **Mocking the project's own infrastructure** | `Repo`, the ORM, or the repository mocked to "keep it fast" | The real path is never exercised | Use the project's test DB or sandbox like the existing specs do |
| **Mocking what you don't own** | `stripe.PaymentIntent.create` mocked directly | Passes when the real library differs | Thin adapter you own, integration test for the adapter |
| **Verifying queries** | `verify(repo.read(id))` | Over-specified. Wrong code can still pass | Stub queries, verify only commands |
| **Excessive setup / The Stranger** | Long setup, mock chains, mocks of non-neighbors | Hidden coupling | Fewer dependencies, Law of Demeter, builders |
| **Object Mother sprawl** | Shared fixture objects used by many tests | One change breaks others | Builders with defaults |
| **The Giant / The Free Ride** | One test checks many behaviors; new asserts bolted onto old tests | First failure hides the rest | One behavior per test, named for it |
| **Logic in tests** | Conditionals, copied formulas | Shares the production bug | Literal values. Parameterized rows |
| **The Nitpicker / big snapshots** | Full-output compares regenerated without review | Breaks on noise | Partial matchers. Small, named snapshots |
| **Flaky tests** | Pass or fail with no code change | People learn to ignore red | Fix the root cause: clock, sleeps, shared state, threads |
| **Generous Leftovers / The Sequencer** | Passes alone, fails in the suite or in another order | Breaks *Isolated* | Fresh state per test. Random order |
| **The Slow Poke** | Suite takes minutes | Runs get rare, steps get large | Small fast tests in the inner loop. E2E in later CI stages |
| **Coverage as a goal** | Mandated % drives low-value tests | Coverage correlates weakly with fault detection | Use coverage to find gaps, mutation testing to check strength |
| **Obsolete tests** | Tests for requirements that no longer exist | Red that means nothing | Change tests first when requirements change |
| **Test-induced design damage** | Layers that exist only for mocking | Needless indirection | Test at a coarser level |
| **Head against the wall** | Third, fourth, fifth blind fix attempt on the same red | Tokens burned, cause hidden | Two attempts, revert, web-search the error, then explorer/reviewer agents or ask the user |

## Examples by antipattern

### Asserting on a call when you can assert on the result

```python
# Bad: verifies wiring, not correctness
def test_applies_discount():
    calculator = Mock(apply=Mock(return_value=80.0))
    PricingService(calculator).price(order)
    calculator.apply.assert_called_with(order, 0.2)

# Good: real collaborator, assert on what the system produces
def test_applies_discount():
    result = PricingService(DiscountCalculator(rate=0.2)).price(order)
    assert result.total == 80.0

# Good: a call IS the outcome for a command with a side effect
def test_sends_welcome_email_on_signup():
    mailer = SpyMailer()
    SignupService(mailer).signup("user@test.com")
    assert mailer.sent == [("user@test.com", "welcome")]
```

### Test-only methods in production code

```python
# Bad
class ShoppingCart:
    def items_for_testing(self): return self._items
    def reset(self): self._items = []

# Good: test through the real public interface
def test_total_updates_when_items_are_added():
    cart = ShoppingCart()
    cart.add(Item(name="Book", price=10))
    assert cart.total() == 10
```

### Mocking a design problem away

```python
# Bad: five doubles reveal a bloated class
service = OrderService(db, cache, logger, metrics, validator)

# Good: split responsibilities, each with one or two collaborators
result = OrderProcessor(validator).process(order)
```

### Bare doubles that drift

```typescript
// Bad: no link to the real type; a renamed method stays green
const notifier = { notify: jest.fn() } as any;

// Good: typed against the real interface; a rename fails to compile
const notifier: jest.Mocked<UserNotifier> = { notify: jest.fn() };
```

### Implementation-detail tests

```python
# Bad: coupled to private names; breaks on any internal rename
assert user._normalize_name() == "Alice"

# Good: observable result; survives any internal refactor
assert User("alice", "alice@test.com").name == "Alice"
```

## Examples by phase

### 🔴 RED

Good: clear name, one behavior, minimal setup, evident data.

```python
def test_filter_returns_empty_when_no_task_matches():
    store = TaskStore()
    store.add(Task(title="Buy milk", status="done"))

    result = store.filter(status="pending")

    assert result == []
```

Bad: vague name, many behaviors, doubles that add noise.

```python
def test_works():
    db, logger = Mock(), Mock()
    store = TaskStore(db, logger)
    store.add(Task("A", "done")); store.add(Task("B", "pending")); store.add(Task("C", "pending"))

    assert len(store.filter(status="pending")) == 2
    assert len(store.filter(status="done")) == 1
    logger.info.assert_called()
```

Three behaviors in one test, plus logging. The first failure hides the rest. The doubles are not needed for a pure in-memory store. This is three specs, built one at a time.

Bad: pasted expected value.

```python
assert Order(items=[Item(price=19.99), Item(price=5.01)], tax=0.0825).total() == 27.0625
```

`27.0625` was copied from the output. Derive it by hand from the spec (25.00 plus 8.25% tax, rounded to cents) and assert the literal `27.06`.

### 🟢 GREEN

Good: Fake It when one test demands one value.

```python
class TaskStore:
    def filter(self, status):
        return []
```

The next spec ("returns matching tasks") forces the real implementation:

```python
class TaskStore:
    def __init__(self): self._tasks = []
    def add(self, task): self._tasks.append(task)
    def filter(self, status): return [t for t in self._tasks if t.status == status]
```

Bad: over-engineering on the first green.

```python
class TaskStore:
    def add(self, task):
        self._validate(task)                 # no test asks for validation
        self._tasks.append(task)
        self._emit("task:added", task)       # no test asks for events

    def filter(self, **criteria):            # no test asks for generic matching
        return sorted((t for t in self._tasks if self._matches(t, criteria)), key=lambda t: t.created_at)
```

None of it has a test, so none of it has an oracle.

Bad: weakening the test to get green.

```python
# Was: assert result == [Task("B", "pending")]
assert len(result) >= 0
```

The bar is green and proves nothing. Fix the code, or say the test is wrong and show evidence.

### 🔵 REFACTOR

Good: extract shared setup after the third repetition, using the project's fixture mechanism.

```python
@pytest.fixture
def store():
    s = TaskStore()
    s.add(Task("A", "pending"))
    s.add(Task("B", "done"))
    return s

def test_filter_pending(store): assert store.filter(status="pending") == [Task("A", "pending")]
def test_filter_done(store): assert store.filter(status="done") == [Task("B", "done")]
```

Good: preparatory refactor when the next spec looks hard. Next spec: "filter by status and assignee". On green, first change `filter` to take a predicate internally, run the tests, then write the new red test.

Bad: premature abstraction after one test.

```python
def build_store(*items): ...
def assert_filter(store, criteria, expected): ...
```

One test does not justify a helper. It hides what the test does. Wait for the third instance.

Bad: renaming `filter` to `where` in the code and in every test at once. If something goes red, there is no stable side to trust. Three steps: add `where` delegating to `filter` (green), switch the tests to `where` (green), delete `filter` (green).

## Red flags at a glance

| Red flag | Likely problem |
|---|---|
| Test name says *how*, not *what* | Implementation-detail test |
| Call verification on a method that returns a value | Asserting on wiring |
| Bare or untyped double | Interface drift |
| 3+ doubles in one test | Class with too many responsibilities |
| The ORM or repository is mocked | Project infrastructure treated as external |
| Setup longer than act and assert together | Missing builder, or too many dependencies |
| Test breaks on a private rename | Coupled to internals |
| Production method only called from tests | Test-only method |
| Several tests red at once outside the initial RED | Horizontal slicing or a regression |
| Test file edited to get to green | Weakened oracle. Stop and explain |
| Same red after two fix attempts | Revert and get help |
