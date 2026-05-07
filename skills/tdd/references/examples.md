# TDD Phase Examples

Concrete good/bad examples for each phase of the red/green/refactor cycle.

## 🔴 RED — Writing the Failing Test

### Good: Clear name, one behavior, minimal setup

```ruby
RSpec.describe TaskStore do
  describe "#filter" do
    it "returns empty array when no tasks match the filter" do
      store = TaskStore.new
      store.add(Task.new(title: "Buy milk", status: :done))

      result = store.filter(status: :pending)

      expect(result).to eq([])
    end
  end
end
```

### Bad: Vague name, tests multiple things, heavy mocks

```ruby
RSpec.describe TaskStore do
  it "works" do
    db = double("DB")
    logger = double("Logger")
    allow(logger).to receive(:info)
    store = TaskStore.new(db, logger)

    # Testing too many things at once
    store.add(Task.new(title: "A", status: :done))
    store.add(Task.new(title: "B", status: :pending))
    store.add(Task.new(title: "C", status: :pending))

    expect(store.filter(status: :pending).length).to eq(2)
    expect(store.filter(status: :done).length).to eq(1)
    expect(store.filter(status: :cancelled).length).to eq(0)
    expect(logger).to have_received(:info)
  end
end
```

**What's wrong**: Name doesn't describe the spec. Multiple assertions test multiple behaviors. Mocks add noise. This should be 3 separate tests built incrementally.

---

## 🟢 GREEN — Minimal Implementation

### Good: Hardcode when one test demands it

**First test**: "returns empty array when no tasks match"

```ruby
# Only one test exists and it expects [] — hardcode it
def filter(status:)
  []
end
```

Yes, hardcoding `[]` is valid GREEN. The next test ("returns matching tasks") will force the real implementation.

**When a second test forces generalization**:

```ruby
class TaskStore
  def initialize
    @tasks = []
  end

  def add(task)
    @tasks << task
  end

  def filter(status:)
    @tasks.select { |t| t.status == status }
  end
end
```

### Bad: Over-engineering on first GREEN

```ruby
class TaskStore
  def initialize
    @tasks = []
    @callbacks = Hash.new { |h, k| h[k] = [] }
  end

  def add(task)
    validate!(task)                          # No test requires validation yet
    @tasks << task
    emit("task:added", task)                 # No test requires events yet
  end

  def filter(**criteria)
    @tasks
      .select { |t| matches_criteria?(t, criteria) }
      .sort_by(&:created_at)                 # No test requires sorting
  end

  private

  def matches_criteria?(task, criteria)
    criteria.all? { |k, v| task.send(k) == v }  # Generic matching — YAGNI
  end

  def validate!(task) = # ...
  def emit(event, data) = # ...
end
```

**What's wrong**: Validation, events, sorting, and generic matching — none of this is demanded by a test. Write only what the current failing test requires.

---

## 🔵 REFACTOR — Improving Design

### Good: Extract duplication after 3rd instance

After three tests for `filter` with different statuses:

```ruby
# Before refactor — duplication in tests
RSpec.describe TaskStore do
  describe "#filter" do
    it "filters pending tasks" do
      store = TaskStore.new
      store.add(Task.new("A", :pending))
      store.add(Task.new("B", :done))

      expect(store.filter(status: :pending)).to eq([Task.new("A", :pending)])
    end

    it "filters done tasks" do
      store = TaskStore.new
      store.add(Task.new("A", :pending))
      store.add(Task.new("B", :done))

      expect(store.filter(status: :done)).to eq([Task.new("B", :done)])
    end
  end
end

# After refactor — extract shared setup
RSpec.describe TaskStore do
  describe "#filter" do
    let(:store) do
      TaskStore.new.tap do |s|
        s.add(Task.new("A", :pending))
        s.add(Task.new("B", :done))
      end
    end

    it "filters pending tasks" do
      expect(store.filter(status: :pending)).to eq([Task.new("A", :pending)])
    end

    it "filters done tasks" do
      expect(store.filter(status: :done)).to eq([Task.new("B", :done)])
    end
  end
end
```

### Bad: Premature abstraction after 1st instance

```ruby
# After just ONE test, creating abstractions "for reuse"
def build_store(*items)
  TaskStore.new.tap { |s| items.each { |i| s.add(i) } }
end

def assert_filter(store, criteria, expected)
  expect(store.filter(**criteria)).to eq(expected)
end
```

**What's wrong**: One test doesn't justify a helper. Wait until the pattern appears 3+ times. Premature abstractions obscure what the test actually does and make debugging harder.

---

## Key Principles

| Phase | Do | Don't |
|---|---|---|
| 🔴 RED | One test, one behavior, descriptive name | Multiple assertions, vague names, heavy mocks |
| 🟢 GREEN | Minimum code to pass, hardcode if one test | Add features no test demands, generalize early |
| 🔵 REFACTOR | Extract after 3+ instances, keep tests readable | Abstract after 1 instance, refactor "just in case" |
