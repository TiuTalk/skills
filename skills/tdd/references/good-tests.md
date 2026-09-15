# Writing good tests and using doubles

Read when a test needs setup over ten lines, parameterized rows, an async probe, a UI query, or any double.

## Beck's Test Desiderata

Twelve properties of a good test. Treat them as sliders. Give one up only when you get a more valuable one back, and say which.

| Property | Meaning |
|---|---|
| Isolated | Same result in any order |
| Composable | Test each dimension of variability alone, then one wiring test |
| Deterministic | Same result every run |
| Fast | You run it without hesitation after a one-line change |
| Writable | Cheap to write relative to the code under test |
| Readable | A reader understands the behavior from the test alone |
| Behavioral | If the behavior changes, the result changes |
| Structure-insensitive | If only the structure changes, the result does not |
| Automated | No human step |
| Specific | A failure points at one cause |
| Predictive | All green means fit for production |
| Inspiring | Green inspires confidence |

Two tensions come up all the time:

- **Predictive vs. Fast.** Realistic tests are slower. Fix it with composition: for 4 computation variants × 5 output formats, write 4 + 5 + 1 wiring test, not 20 combined ones.
- **Behavioral vs. Structure-insensitive.** Interaction checks catch behavior changes but break on every refactor. "Interaction tests check how a system arrived at its result, whereas usually you should care only what the result is." (Google)

## Test behavior, not implementation

- Test through the public API or port of a module. A module can be one class or a facade over many.
- Do not test private methods or widen visibility for tests. If private logic needs its own tests, extract it into a type with its own public contract.
- Check state or output. Check calls only for commands with side effects.
- **Refactor check:** extract a class or inline a method without changing behavior. Any test that goes red is structure-sensitive.
- **UI:** test like a user. Query by role, then label, then text. Test IDs are the last resort.

```typescript
// Avoid: coupled to internal state
expect(wrapper.state("isOpen")).toBe(true);

// Prefer: observable behavior, also checks accessibility
await user.click(screen.getByRole("button", { name: /menu/i }));
expect(screen.getByRole("menu")).toBeVisible();
```

Why: Implementation-detail tests give false negatives (they break on a rename) and false positives (they pass when a handler is wired wrong).

## Structure: Arrange, Act, Assert

One Act per test. If Act-Assert repeats, split the test. Separate the three parts with blank lines, not comments.

```python
def test_gold_customer_gets_ten_percent_off():
    order = Order(customer=Customer(tier="gold"), items=[Item(price=100.00)])

    total = order.total()

    assert total == 90.00
```

- One concept per test, not literally one assert. Several asserts are fine when they check one outcome and each failure names what broke.
- Vary one thing at a time. Hold everything else constant.

Why: With two variables, a failure does not point to a cause. A test with many unlabeled asserts is "Assertion Roulette".

## Naming

Name the test after the behavior and its outcome, not after the method.

- `test_convert_rejects_unknown_currency_pair`
- `it("sends a reminder to an overdue customer")`
- `TestSum_NegativeFirstArg_ReturnsError`

Why: Someone reads the test in a year. A behavior name lets you challenge the premise when it fails: "should it, really?"

## Evident data, no logic in tests

- Derive expected values by hand or from the spec. Show the relationship in the literal.
  - Bad: `expected = price * (1 - discount_rate)` (shares the production bug)
  - Good: `assert total == 90.00`
- No conditionals or computed values in test bodies.
- Many input/output pairs: use the framework's parameterized or table-driven form. One literal row per case, each with a name.

```python
@pytest.mark.parametrize("tier, expected", [
    pytest.param("gold", 90.00, id="gold gets 10%"),
    pytest.param("silver", 95.00, id="silver gets 5%"),
    pytest.param("none", 100.00, id="no tier pays full price"),
])
def test_tier_discount(tier, expected):
    assert Order(customer=Customer(tier=tier), items=[Item(price=100.00)]).total() == expected
```

```go
func TestTierDiscount(t *testing.T) {
    cases := []struct{ name, tier string; want float64 }{
        {"gold gets 10%", "gold", 90.00},
        {"silver gets 5%", "silver", 95.00},
        {"no tier pays full price", "", 100.00},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got := NewOrder(Customer{Tier: tc.tier}, Item{Price: 100}).Total()
            if got != tc.want { t.Fatalf("total = %v, want %v", got, tc.want) }
        })
    }
}
```

- Prefer DAMP (Descriptive And Meaningful Phrases) over DRY. Accept duplication that lets a reader understand one test without jumping through helpers.

Why: "If you feel like you need to write a test to verify your test, something has gone wrong." (Google) The framework does the iteration, so each row reports as its own named test.

## Test Data Builders

When setup gets long, give every field a safe default and let each test set only what its outcome depends on. Use the project's existing factories if it has them.

```python
def test_overdue_customer_gets_reminder():
    customer = a_customer().with_overdue_balance(50).build()
    assert needs_reminder(customer)
```

Why: The data that matters stays visible. A new required field changes one builder, not every test. Avoid the "Object Mother": a shared catalogue of ready-made objects that many tests depend on. A change for one test then breaks others.

## Failure messages

Read the message while the test is red. If it would not tell a teammate what broke, improve it before going green. `AssertionError: False is not true` costs a debugging session. `expected total 90.00 for gold customer, got 100.00` does not. Use described assertions, custom matchers, or a readable `repr`/`toString`/`String()` on domain values.

## Determinism

- Inject clocks and randomness.
- Build fresh state for each test. Run in random order to find leftovers.
- No shared mutable fixtures across tests.
- A flaky test is a defect. Fix the root cause in this session (clock, sleep, shared state, threads). Skip it only with the user's explicit agreement and say so in the summary. Never auto-retry until green.

Why: Once a team learns to ignore red, it ignores real failures too.

## Asynchronous and concurrent code

- Inject the executor or scheduler. Run it synchronously in unit tests.

```python
def test_order_confirmation_is_queued_and_sent():
    executor = DeterministicExecutor()
    mailer = SpyMailer()
    service = OrderService(executor=executor, mailer=mailer)

    service.place(order)
    executor.run_until_idle()

    assert mailer.sent == [("a@x.io", "Order confirmed")]
```

- At real async boundaries, assert with a probe: poll the observable state until it holds or a timeout expires, then fail with a clear message. Synchronize on events the system exposes, never on elapsed time.
- Put thread-safety checks in separate, named stress tests.
- Never use a bare `sleep`.

Why: `sleep(2)` is too slow when the system is fast and flaky when it is slow. A probe returns as soon as the condition holds.

## Test doubles

### Vocabulary

| Double | What it does | Verifies |
|---|---|---|
| Dummy | Passed but never used | — |
| Stub | Returns canned answers | State |
| Spy | Stub that records calls | Interaction |
| Mock | Pre-programmed expectations, fails on mismatch | Interaction |
| Fake | Working shortcut implementation (in-memory repository) | State |

Why: "mock" gets used for all five, which hides the real choice: state verification or interaction verification.

### When to use one

**Preference order:** real implementation → fake → stub → mock.

- **Real first.** The project's test database, sandbox, temp dir, or test HTTP server counts as real. Use whatever the existing specs use. Never mock the ORM, the repository, or a domain object to save time.
- **Doubles for what is slow, non-deterministic, or not owned:** a third-party API client, a payment gateway, an email provider, a clock, randomness.
- **Mock only types you own.** Wrap a third-party SDK in a thin adapter with one method per operation. Mock the adapter. Test the adapter against the real dependency in an integration test, or with the project's recorded-response tool (VCR, MSW, httptest).
  Why: You cannot redesign a third-party API from test feedback, so the mock just copies it, and it keeps passing when the real library behaves differently.
- **Stub queries, verify commands.** Stub collaborators that return data. Verify only collaborators that cause side effects.
  Why: Verifying a query over-specifies the test and can still pass wrong code.

```python
def test_reminder_sent_to_overdue_customer():
    customers = InMemoryCustomers([Customer(id=7, email="a@x.io", overdue=True)])  # fake, query side
    mailer = SpyMailer()                                                           # spy, command side

    send_overdue_reminders(customers, mailer)

    assert mailer.sent == [("a@x.io", "Payment overdue")]
```

- **Hand-written doubles for error paths.** A double that raises the failure you need is more readable than a framework expectation.

```python
class TimingOutRates:
    def rate(self, src, dst): raise TimeoutError("rate service")

def test_rate_timeout_gives_clear_error():
    with pytest.raises(ConversionUnavailable, match="rate service"):
        Bank(rates=TimingOutRates()).convert(Note(100, "USD"), "GBP")
```

- **Verified doubles.** Bind the double to the real type so a renamed method fails at test time: `instance_double` (RSpec), `create_autospec` (Python), `jest.Mocked<T>` (TypeScript), an interface (Go).
- **Contract-tested fakes.** Run one shared contract suite against the in-memory fake and the real implementation. "A fake must have its own tests." (Google)
- **Between services,** use consumer-driven contracts (e.g. Pact). A hand-written stub of another team's API drifts.
- **Pure core, I/O at the edges.** Read (impure), then decide (pure, tested with plain asserts), then write (impure). Pure functions need no doubles.

### Listen to the tests

Treat these as design feedback, not as test problems.

| Symptom | Likely design issue | Fix |
|---|---|---|
| 3+ doubles in one test | Class has too many responsibilities | Split the class. The doubles are diagnostic, not the disease |
| Mocking non-neighbors (`a.get_b().get_c()`) | Law of Demeter violation | Pass the needed value directly |
| Mocks returning mocks, or mocks with logic | Missing object in the design | Introduce the object |
| 30 lines of setup | Too many dependencies, or too much data | Inject clock, random, gateways. Use a builder for data |
| Test stubs a constructor or patches a module global | Hidden dependency | Inject it |
| Test asserts on a mutated input or global | Side effect where a result would do | Return a value |

**Counterweight:** do not add indirection only so a test can isolate something. Check each new seam: does it make the code clearer to a reader who ignores the tests? If not, test at a coarser level with real collaborators.

### Designing testable interfaces

1. **Inject dependencies, do not construct them.** A class that builds its own gateway from `os.environ` can only be tested by patching. A class that takes the gateway declares what it needs.
2. **Return results, do not mutate hidden state.** `discount_for(cart) -> Discount` is testable by its return. `apply_discount(cart)` forces the test to inspect the input.
3. **Keep the surface small.** Every public method invites a test, a caller, and a coupling. Test `add` and `total`, not `calculate_subtotal`, `calculate_tax`, `calculate_shipping`.
4. **One method per operation at a boundary.** `client.createIssue({repo, title})`, not `client.request("POST", "/repos/.../issues", body)`. Each stub then returns one shape, and a verified double checks each signature.
