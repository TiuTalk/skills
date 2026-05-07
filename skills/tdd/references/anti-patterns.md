# TDD Anti-Patterns

Common traps that break the TDD feedback loop. When you catch yourself doing any of these, stop and correct course.

## 1. Asserting on Mock Calls When You Can Assert on Output

Using `have_received` to verify a collaborator was called, when you could instead assert on the return value or observable result. `have_received` tests wiring, not correctness.

**Bad** — asserting on the call instead of the result:
```ruby
RSpec.describe PricingService do
  it "applies discount to order total" do
    calculator = instance_double(DiscountCalculator, apply: 80.0)
    service = PricingService.new(calculator)

    service.price(order)

    # Wrong: verifying the call was made, not what came out
    expect(calculator).to have_received(:apply).with(order, 0.2)
  end
end
```

**Good** — asserting on observable output:
```ruby
RSpec.describe PricingService do
  it "applies discount to order total" do
    calculator = instance_double(DiscountCalculator, apply: 80.0)
    service = PricingService.new(calculator)

    result = service.price(order)

    # Right: assert on what the system produces
    expect(result.total).to eq(80.0)
  end
end
```

**Good** — `have_received` IS correct for side effects:
```ruby
RSpec.describe SignupService do
  it "sends welcome email on signup" do
    mailer = instance_double(Mailer)
    allow(mailer).to receive(:send_welcome)
    service = SignupService.new(mailer)

    service.signup("user@test.com")

    # Correct: email dispatch IS the observable outcome here
    expect(mailer).to have_received(:send_welcome).with("user@test.com")
  end
end
```

**Why it matters**: When a collaborator returns a value, assert on what your unit does with that value — not that the call was made. Reserve `have_received` for genuine fire-and-forget side effects where the dispatch itself is the contract.

---

## 2. Test-Only Methods in Production Code

Adding methods like `reset!`, `internal_state`, or `test_hook` to production code solely for test access.

**Bad**:
```ruby
class ShoppingCart
  def initialize
    @items = []
  end

  def add(item)
    @items << item
  end

  # Exists ONLY for tests — pollutes production API
  def items_for_testing
    @items
  end

  def reset!
    @items = []
  end
end
```

**Good**:
```ruby
class ShoppingCart
  def initialize
    @items = []
  end

  def add(item)
    @items << item
  end

  def total
    @items.sum(&:price)
  end

  def item_count
    @items.length
  end
end

# Test through the public interface
RSpec.describe ShoppingCart do
  it "updates total when items are added" do
    cart = ShoppingCart.new
    cart.add(Item.new(name: "Book", price: 10))

    expect(cart.total).to eq(10)
    expect(cart.item_count).to eq(1)
  end
end
```

**Why it matters**: If you need test-only methods, your public API is missing something or your test is testing the wrong thing.

---

## 3. Mocking a Design Problem Away

When a test requires 3+ doubles, the instinct is to simplify the test. The correct response is to simplify the design. A class with many injected collaborators has too many responsibilities — the doubles just make it visible.

**Bad** — 5 doubles reveal a bloated class:
```ruby
RSpec.describe OrderService do
  it "processes an order" do
    db        = instance_double(OrderRepository)
    cache     = instance_double(CacheStore)
    logger    = instance_double(Logger)
    metrics   = instance_double(MetricsClient)
    validator = instance_double(OrderValidator, valid?: true)

    allow(db).to receive(:save)
    allow(cache).to receive(:invalidate)
    allow(logger).to receive(:info)
    allow(metrics).to receive(:increment)

    service = OrderService.new(db, cache, logger, metrics, validator)
    result = service.process(order)

    expect(result.status).to eq("confirmed")
  end
end
```

**Good** — split responsibilities, each class has 1-2 collaborators:
```ruby
# Core logic tested in isolation
RSpec.describe OrderProcessor do
  it "confirms a valid order" do
    validator = instance_double(OrderValidator, valid?: true)
    processor = OrderProcessor.new(validator)

    result = processor.process(order)

    expect(result.status).to eq("confirmed")
  end
end

# Persistence tested separately
RSpec.describe OrderRepository do
  it "saves and retrieves an order" do
    repo = OrderRepository.new(db_connection)
    repo.save(order)

    expect(repo.find(order.id)).to eq(order)
  end
end
```

**Rule of thumb**: 3+ doubles in one test = look at the class under test, not the test. The doubles are diagnostic, not the disease.

---

## 4. Bare Doubles That Drift From Real Interfaces

A bare `double` with stubbed methods has no connection to the real class. If the real method is renamed or its signature changes, the test stays green while production breaks. `instance_double` binds the stub to the real class at load time.

**Bad** — bare double, no interface verification:
```ruby
RSpec.describe NotificationService do
  it "notifies user on order completion" do
    # This double has no idea what UserNotifier actually looks like
    notifier = double("UserNotifier", notify: true)
    service = NotificationService.new(notifier)

    service.complete(order)

    expect(notifier).to have_received(:notify).with(order.user_id)
  end
end
```

If `UserNotifier#notify` is renamed to `#dispatch` or gains a required argument, this test stays green. Production breaks silently.

**Good** — `instance_double` verifies against the real class:
```ruby
RSpec.describe NotificationService do
  it "notifies user on order completion" do
    # Fails at load time if :notify doesn't exist on UserNotifier with this arity
    notifier = instance_double(UserNotifier)
    allow(notifier).to receive(:notify)
    service = NotificationService.new(notifier)

    service.complete(order)

    expect(notifier).to have_received(:notify).with(order.user_id)
  end
end
```

**Why it matters**: `instance_double` turns interface drift from a silent production failure into a loud test failure. It costs nothing extra to use.

---

## 5. Horizontal Slicing (Batch Tests)

Writing all tests first, then all implementation. This breaks the feedback loop — you lose the "one test drives one change" rhythm.

**Bad sequence**:
```
Write test 1 (RED)
Write test 2 (RED)
Write test 3 (RED)
Implement everything (GREEN × 3)
Refactor once
```

**Good sequence**:
```
Write test 1 (RED) → Implement (GREEN) → Refactor
Write test 2 (RED) → Implement (GREEN) → Refactor
Write test 3 (RED) → Implement (GREEN) → Refactor
```

**Why it matters**: Multiple failing tests create pressure to write large implementation chunks. You lose the small-step discipline and the ability to catch regressions between specs. Each RED must be followed by GREEN before the next RED.

---

## 6. Implementation-Detail Tests

Tests coupled to internal structure break on every refactor, even when behavior is preserved.

**Bad**:
```ruby
RSpec.describe User do
  it "validates and normalizes" do
    user = User.new("alice", "alice@test.com")

    # Coupled to private method names — breaks on any internal rename
    expect(user.send(:validate_email_format)).to be true
    expect(user.send(:normalize_name)).to eq("Alice")
  end
end
```

**Good**:
```ruby
RSpec.describe User do
  it "normalizes name on creation" do
    user = User.new("alice", "alice@test.com")

    # Tests observable result — survives any internal refactor
    expect(user.name).to eq("Alice")
    expect(user.email).to eq("alice@test.com")
  end

  it "rejects invalid email" do
    expect { User.new("alice", "not-an-email") }
      .to raise_error(ArgumentError, /invalid email/)
  end
end
```

**Why it matters**: The test should survive any internal refactor that preserves behavior. If renaming a private method breaks your tests, they're testing the wrong thing.

---

## Quick Reference: Red Flags

Stop and reconsider if you notice:

| Red flag | Likely problem |
|---|---|
| Test name describes *how*, not *what* | Implementation-detail test |
| `have_received` on a call that has a return value | Asserting on wiring, not behavior (#1) |
| Bare `double` instead of `instance_double` | Interface drift risk (#4) |
| 3+ doubles in one test | Design smell — too many responsibilities (#3) |
| Test setup > 10 lines | Test doing too much or missing an abstraction |
| Test breaks when you rename a private method | Coupled to internals |
| Production method only called from tests | Test-only method |
| Multiple tests failing at once (outside initial RED) | Horizontal slicing or regression |
