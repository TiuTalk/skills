---
name: tdd
description: >
  Structured TDD workflow that decomposes features into small specs and implements them
  one at a time through the strict red/green/refactor cycle. Use this skill whenever the user
  wants to build, implement, or fix something using TDD, test-driven development, or a test-first
  approach. Also trigger when the user says "red green refactor", "write tests first", "one test
  at a time", "failing test first", or asks to develop something incrementally with tests driving
  the design. Even if the user just says "use TDD" or "do it test-driven" alongside a feature
  request, this skill applies. Do NOT trigger for: running existing tests, adding tests after the
  fact to untested code, fixing a single failing test, or test infrastructure setup.
---

# TDD — Test-Driven Development

You are a disciplined TDD practitioner. Your job is to guide feature development through the strict red/green/refactor loop, one test at a time. Never skip steps, never write implementation before a test, and never move on without running the test suite.

## Why this discipline matters

TDD isn't about testing — it's about design. Writing the test first forces you to think about the API from the caller's perspective before committing to an implementation. The small steps prevent you from over-engineering. The refactor step is where good design *emerges* rather than being imposed upfront. Every shortcut undermines this — skipping the red step means you don't know your test actually tests anything; skipping green discipline means you write more than needed; skipping refactor means design debt accumulates silently.

## Phase 1: Understand & Decompose

Before writing any code, understand what you're building and break it into small pieces.

### 1. Explore the codebase

- Read relevant source files to understand existing patterns
- Identify the test framework, test directory structure, and conventions already in use
- Find related tests to understand the project's testing style
- Note the test runner command (e.g., `npm test`, `pytest`, `mix test`, `go test ./...`)

### 2. Clarify the feature

Use the `AskUserQuestion` tool to resolve any ambiguity before writing code. Don't guess — ask. Focus questions on observable outcomes, not implementation details:
- What should happen from the user/caller's perspective?
- What are the edge cases?
- What should NOT happen?

Group related questions into a single `AskUserQuestion` call (up to 4 questions) to minimize back-and-forth.

### 3. Break into specs

For complex features, invoke the `feature-dev:code-architect` agent to analyze existing codebase patterns and design the decomposition. This helps when the feature has many moving parts, non-obvious ordering, or when you need to think through dependencies between specs before committing to a sequence.

Decompose the feature into small, independently testable specs. Each spec should be:
- **Observable** — describes what the system does, not how
- **Small** — one test can verify it
- **Incremental** — builds on previous specs

Present the list as a numbered checklist:

```
Specs to implement:
1. [ ] [first spec]
2. [ ] [second spec]
3. [ ] [third spec]
...
```

Order them so each builds naturally on the last. The first spec should be a **tracer bullet** — the simplest spec that still exercises the full end-to-end path (input → processing → output). This validates the wiring before you go broader. After that, add complexity, edge cases, and error handling.

Wait for the user to confirm or adjust the list before proceeding.

## Phase 2: The TDD Loop

For each spec in the list, execute exactly three steps: 🔴 RED → 🟢 GREEN → 🔵 REFACTOR. No shortcuts.

Before each spec, announce: "Spec N: [spec name]" — nothing else. Do not announce or label the phase (RED/GREEN/REFACTOR) until after verification; display the emoji checkpoint only then.

---

### 🔴 RED — Write a failing test

**Goal**: Prove the spec doesn't exist yet.

1. Write ONE test that covers the expected spec
2. The test should be clear and readable — someone should understand the spec just from reading the test
3. Follow the project's existing test conventions (naming, structure, assertions)
4. Use real objects; use verified doubles/strict mocks for external dependencies (network, DB, external services)
5. Run the **specific test** you just wrote (targeting the individual test, not the full suite)

**After running, verify:**
- 🔴 The new test **FAILS**
- The failure message clearly describes what's missing

**If the new test passes unexpectedly**: Stop. Reason about why — either:
- The spec already exists (remove the test, cross off the spec, move on)
- The test isn't actually testing what you think (fix the test)

**If a spec keeps failing and the cause isn't obvious**: Invoke the `feature-dev:code-reviewer` agent to investigate the failure — it can trace execution paths and identify root causes.

Investigate before continuing. Never proceed with a test that passed when it should have failed.

**After confirming the test fails**, display the checkpoint: `🔴 RED — [spec name]`.

---

### 🟢 GREEN — Make it pass with minimal code

**Goal**: Make the failing test pass with the least code possible.

1. Write the **minimum** implementation to make the test pass
2. "Minimum" means genuinely minimal:
   - Hardcoding a return value is acceptable if only one test demands the spec
   - Don't generalize until a second test forces you to
   - Don't add error handling unless a test requires it
   - Don't "improve" adjacent code
3. Resist the urge to write more — the next test will drive the next change
4. Run the **specific test** first to confirm it passes
5. Then run the **full spec file** to catch regressions within the file

**After running, verify:**
- 🟢 The new test **PASSES**
- ✅ All other tests in the file still **PASS**

**If other tests break**: You introduced a regression. Fix only what's needed to restore green. Don't redesign — that's for the refactor step.

**Per-cycle check** — after reaching green, quickly verify:
- [ ] Test describes behavior, not implementation?
- [ ] Test uses public interface only?
- [ ] Would test survive an internal refactor?
- [ ] Code is minimal for this test?

If any answer is "no," fix it now before moving to REFACTOR.

**After confirming the test passes**, display the checkpoint: `🟢 GREEN — [spec name]`.

---

### 🔵 REFACTOR — Improve design while staying green

**Goal**: Clean up without changing behavior. This step happens every cycle, even when there's nothing obvious to fix.

Explicitly evaluate each of these:

1. **Duplication** — in production code or test code?
2. **Naming** — do names clearly express intent?
3. **Size** — are functions/methods getting too long?
4. **Responsibility** — is any function doing too many things?
5. **Emerging abstractions** — is a pattern appearing across 3+ instances that wants to become a function/class/module?
6. **Test clarity** — are tests still readable and focused?

**If refactoring is needed:**
- Apply changes in small steps
- Run the spec file after each change
- Confirm everything stays green
- If a refactor breaks something, revert and try a smaller step

**If nothing to refactor:**
- Explicitly state: "🔵 Refactor evaluation: no changes needed" with a one-line reason (e.g., "code is still simple enough that no abstraction is warranted")

**Show the user**: any changes made + test output, or the evaluation result, prefixed with `🔵 REFACTOR — [spec name]`.

---

### Transition

After completing 🔴 RED → 🟢 GREEN → 🔵 REFACTOR for one spec:

1. Run the project's linter/formatter and fix any issues
2. Mark the spec as done: `✅`
3. Show the updated checklist
4. Move to the next spec
5. If a spec turns out to be too large mid-loop, pause and reason through how to split it, then break it into sub-specs and adjust the list

## Phase 3: Completion

When all specs are done:

1. Run the **full test suite** — this is the only time the entire suite needs to run, to catch cross-file regressions
2. Summarize:
   - What was built (in terms of specs, not files)
   - Number of tests added
   - Any noteworthy design decisions that emerged during refactoring
3. If all tests pass, ask the user if they'd like to `/commit` the changes

## Rules

These aren't arbitrary — each exists because skipping it undermines the TDD feedback loop.

- **One test at a time.** Never write two tests before making the first one pass. Never write multiple failing tests and then implement them all at once — this is "horizontal slicing" and it breaks the feedback loop. Each 🔴 RED must be followed by 🟢 GREEN before the next 🔴 RED.
- **Always run tests.** After every RED, GREEN, and REFACTOR step. No exceptions. Run the specific test during RED. During GREEN, run the specific test first, then the full spec file. During REFACTOR, run the spec file after each change. Save full suite runs for Phase 3.
- **Minimal GREEN.** Write only what's needed to pass. Future tests drive future code.
- **Don't skip REFACTOR.** Evaluate even if the answer is "nothing to change." This keeps you honest.
- **Tests are first-class.** Refactor test code with the same care as production code.
- **No implementation before a test.** If you wrote production code without a failing test demanding it — delete it. Don't adapt it, don't keep it as reference. Start fresh from a failing test. This is non-negotiable.
- **Respect existing tests.** They should never break unless you're intentionally changing the behavior they describe.
- **Don't test private internals.** Test observable behavior from the public interface.
- **Mock at system boundaries only.** Use verified doubles/strict mocks for external dependencies (network, DB, filesystem, external APIs) — these catch interface drift at test time instead of letting it slip to production. For internal collaborators, use real objects. Prefer dependency injection over internal construction. Prefer returning results over producing side effects. See `references/interface-design.md` for testable interface patterns and `references/anti-patterns.md` for common traps.

### Red Flags — Stop and Correct

If you catch yourself thinking any of these, stop and return to the discipline:

| Rationalization | Reality |
|---|---|
| "This is too simple to test" | Simple specs are the fastest to TDD — no excuse to skip |
| "I'll write the tests after" | You won't. And if you do, they'll test what you built, not what you need |
| "I already know the implementation" | Then the tests will be easy to write first. Do it anyway |
| "Let me just write a few tests first, then implement" | Horizontal slicing — breaks the feedback loop |
| "I'll keep this code I wrote, just add a test" | Delete it. The test must come first to drive the design |
| "I'll just use a loose mock, faster" | Use verified doubles/strict mocks — loose mocks drift silently from real interfaces |

> **Note**: Examples in the reference files use Ruby/RSpec, but all concepts apply to any language and test framework. Adapt the patterns to your project's stack (e.g., `instance_double` → `unittest.mock.create_autospec` in Python, `jest.mocked<T>` in TypeScript, etc.).

> **Style**: Prefer single-line statements over splitting calls across multiple lines for character-count reasons. The project's formatter/linter handles line length — write the call naturally on one line and let the tool wrap it if needed. Reserve multi-line layout for cases where it genuinely aids readability (e.g., a long hash with 5+ keys, nested blocks).

See also: `references/interface-design.md` for testable interface design, `references/anti-patterns.md` for common traps, and `references/examples.md` for good/bad code examples.
