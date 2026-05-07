# Interface Design for Testability

The shape of a unit's interface determines how easy it is to test. If a test needs heavy setup, monkey-patching, or three layers of stubs, the interface — not the test — is usually the problem. These four principles make units testable as a side effect of being well-designed.

> Examples are Ruby/RSpec. Principles are language-neutral — adapt to your stack (constructor injection in Java/TS, function args in Python/Go, etc.).

---

## 1. Inject dependencies, don't construct them

A unit that builds its own collaborators is welded to them. You can't substitute a fake at the boundary, and you end up reaching for monkey-patches or `allow_any_instance_of` to test it.

**Bad** — collaborator constructed inside:
```ruby
class OrderProcessor
  def process(order)
    gateway = StripeGateway.new(ENV.fetch("STRIPE_KEY"))
    gateway.charge(order.total)
  end
end

# To test this, you have to stub the constructor or patch the env.
RSpec.describe OrderProcessor do
  it "charges the order total" do
    allow(StripeGateway).to receive(:new).and_return(instance_double(StripeGateway, charge: :ok))
    # ...brittle and indirect
  end
end
```

**Good** — collaborator passed in:
```ruby
class OrderProcessor
  def initialize(gateway)
    @gateway = gateway
  end

  def process(order)
    @gateway.charge(order.total)
  end
end

RSpec.describe OrderProcessor do
  it "charges the order total" do
    gateway = instance_double(StripeGateway, charge: :ok)
    processor = OrderProcessor.new(gateway)

    processor.process(order)

    expect(gateway).to have_received(:charge).with(order.total)
  end
end
```

**Why it matters**: Injection turns a hidden dependency into a visible parameter. The class declares what it needs, tests provide it directly, and substitution at the boundary becomes trivial.

---

## 2. Return results, don't mutate hidden state

A method that returns a value is testable by inspecting the return. A method that mutates input arguments, global state, or instance variables forces the test to reach inside the system to verify what happened.

**Bad** — mutates the argument:
```ruby
class DiscountApplier
  def apply(cart)
    cart.total -= cart.total * 0.2
  end
end

RSpec.describe DiscountApplier do
  it "applies a 20% discount" do
    cart = Cart.new(total: 100)
    DiscountApplier.new.apply(cart)

    # Test must inspect the mutated input
    expect(cart.total).to eq(80)
  end
end
```

**Good** — returns the result:
```ruby
class DiscountApplier
  def apply(cart)
    Discount.new(amount: cart.total * 0.2)
  end
end

RSpec.describe DiscountApplier do
  it "calculates a 20% discount" do
    cart = Cart.new(total: 100)

    discount = DiscountApplier.new.apply(cart)

    expect(discount.amount).to eq(20)
  end
end
```

**Why it matters**: Pure functions compose, are trivially testable, and don't surprise callers with hidden mutations. Reserve side effects for the layer that genuinely needs them (persistence, dispatch) and keep the logic pure.

When a side effect *is* the contract (e.g. sending an email, writing a row), assert on the dispatch via `have_received` on a mocked boundary — see `anti-patterns.md` §1.

---

## 3. Keep the surface area small

Every public method is something tests must cover and callers can couple to. Fewer methods and fewer parameters mean fewer test cases, simpler setup, and less risk of callers depending on internals.

**Bad** — wide surface, exposes internals:
```ruby
class ShoppingCart
  attr_accessor :items, :discounts, :tax_rate, :shipping_method

  def calculate_subtotal; end
  def calculate_discount; end
  def calculate_tax; end
  def calculate_shipping; end
  def calculate_total; end
end
```

Every accessor and intermediate calculation is a test target — and a coupling point. A caller that reads `cart.tax_rate` directly will break if you change how tax is stored.

**Good** — narrow surface, deep internals:
```ruby
class ShoppingCart
  def initialize(items:, tax_rate:, shipping:)
    @items = items
    @tax_rate = tax_rate
    @shipping = shipping
  end

  def add(item); end
  def total; end  # Encapsulates subtotal, discount, tax, shipping
end
```

Tests target `#add` and `#total`. The intermediate calculations stay private and can be reorganized freely.

**Why it matters**: A small interface is a contract you can keep. Each public method invites a test, a caller, and a coupling. Default to private; promote to public only when a real caller needs it.

---

## 4. Prefer specific operations over generic dispatchers

When wrapping an external boundary (HTTP API, queue, store), give each operation its own method. A single generic `request(endpoint, options)` shifts the dispatching logic into the test — every mock has to inspect arguments and branch on them.

**Bad** — one generic method, mocks need conditional logic:
```ruby
class GitHubClient
  def request(method, path, body = nil)
    # dispatches anything
  end
end

RSpec.describe RepoSyncer do
  it "fetches the repo and creates an issue" do
    client = instance_double(GitHubClient)

    # The mock has to branch on path/method to return the right shape
    allow(client).to receive(:request) do |method, path, body|
      case [method, path]
      when [:get, "/repos/acme/widgets"] then { name: "widgets" }
      when [:post, "/repos/acme/widgets/issues"] then { id: 42 }
      end
    end

    syncer = RepoSyncer.new(client)
    syncer.sync("acme/widgets")

    expect(client).to have_received(:request).twice
  end
end
```

**Good** — one method per operation, each mock is trivial:
```ruby
class GitHubClient
  def get_repo(full_name); end
  def create_issue(repo:, title:); end
end

RSpec.describe RepoSyncer do
  it "fetches the repo and creates an issue" do
    client = instance_double(GitHubClient, get_repo: { name: "widgets" }, create_issue: { id: 42 })
    syncer = RepoSyncer.new(client)

    syncer.sync("acme/widgets")

    expect(client).to have_received(:create_issue).with(repo: "acme/widgets", title: anything)
  end
end
```

**Why it matters**: One method per operation means each test stubs only what it uses, mocks return one shape (no conditional logic), and `instance_double` can verify each signature individually. It also makes the boundary self-documenting — the methods on the client *are* the list of operations the system performs.

---

## Quick reference

| Smell | Likely fix |
|---|---|
| Test stubs `Klass.new` or uses `allow_any_instance_of` | Inject the dependency instead of constructing it |
| Test asserts on a mutated input or global | Return a result instead of mutating |
| Class has many `attr_accessor` and intermediate-calculation methods | Collapse the surface, keep helpers private |
| Test setup needs 3+ collaborators wired together | Surface area too wide — split the class (see `anti-patterns.md` §3) |
| Mock for an external client uses a `case` on path/method | Replace generic dispatcher with one method per operation |

See also: `anti-patterns.md` for traps that show up when these principles are violated.
