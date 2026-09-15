---
name: tdd
description: >
  Test-driven coding workflow for any language. Break the work into a list of behaviors, then
  drive each one through 🔴 RED → 🟢 GREEN → 🔵 REFACTOR with status checkpoints. Use it for
  every coding task: a feature, a bug fix, a refactor, a new function, endpoint, CLI, transform,
  or migration with logic, whether or not the user mentions tests. Always use it on "TDD",
  "test-first", "red green refactor", "one test at a time". Do NOT use it for config tweaks,
  docs, copy, CI files, test-infrastructure setup, running an existing suite, code review, or
  generated and vendored code (protobuf, OpenAPI clients).
---

# TDD — test-driven coding for any language

Write code in small, verified steps. A failing test states the expected behavior. The code makes it pass. A refactor keeps it clean. Repeat. No production code exists without a test that failed first.

## Phase 0: Pick the mode

No runner wins over every row, then Legacy. Otherwise, if two rows match, take the lower one. A flag, a branch, or a computed value is logic. Full loop is the default: print nothing for it. For any other row, print one line, e.g. `Mode: Legacy, characterize first`.

| Situation | Mode |
|---|---|
| No test runner in the project | **Stop.** Ask the user to approve a one-command setup, then continue with the matching row |
| Logic, rules, transforms, APIs, CLIs, libraries | **Full loop.** Phases 1-3 |
| Bug fix | **Full loop, one spec.** The smallest test that fails because of the defect, then the fix. At the end, name the spec the original list missed in one line |
| Legacy code with no tests | **Full loop** after a characterization test pins current behavior (`references/techniques.md`). When the change alters pinned output, update the approved file and quote the changed lines under 🟢 |
| Unclear requirement or feasibility | **Spike, then full loop.** Throwaway code to learn. It never stays in the diff. Then Phases 1-3 |
| Visual layout, CSS, markup | **Humble Object.** Test each decision (a flag, a class name, a format) through the public API or one user-level UI test. Do not assert CSS values. Leave the pixel check to the user, or screenshot with `playwright-cli` |
| Refactor with no behavior change | **Green loop.** Confirm the related spec files are green, refactor in small steps, run them after each step. No 🔴 phase |

## Phase 1: Understand and decompose

### 1. Learn how this project tests

Do this first, every session:

- Find the framework, test directory, file naming, and assertion style.
- Read two existing specs near the code you will change. Copy their shape: setup, factories or builders, how they touch the DB, how they handle external calls.
- Note the runner command for one test and for one spec file. Follow the project's own instructions (CLAUDE.md, README) if they exist.
- Read the code you will change and at least one caller.

### 2. Clarify

State your assumptions as short bullets and proceed. Ask with `AskUserQuestion` only when two readings of the request give different spec lists. Ask for one concrete example (input, exact output, what must not happen), never about implementation.

### 3. Break into specs

List behaviors, not implementation steps. Order them so each builds on the last. Spec 1 is a **tracer bullet**: the simplest case that runs the whole path from input to output.

```
Assumptions:
- Bank takes an optional `rates` dict keyed by (from, to)
- No rounding on converted amounts
Specs to implement:
1. [ ] same currency returns the same amount
2. [ ] USD -> GBP at a known rate
3. [ ] unknown currency pair raises a clear error
4. [ ] rate service timeout -> ConversionUnavailable
```

Print the assumptions and the list before you write the first test. Wait for the user to confirm, unless told to proceed without confirmation. For a list over 8 items or spanning 3+ modules, invoke `feature-dev:code-architect` first if it is installed.

Keep the list alive. Add cases the request needs as numbered items. Note needed refactors under the list as `Refactor: ...` and do them in the next 🔵 step. Report out-of-scope findings in one line at Phase 3.

## Phase 2: The loop

For each spec: 🔴 RED → 🟢 GREEN → 🔵 REFACTOR. Print these status lines. The only other lines: the Phase 0 mode line, the Phase 1 assumptions and spec list, `⚪ ALREADY GREEN`, `⚠️ PRE-EXISTING RED`, and the Phase 3 block.

```
Spec 2: USD -> GBP at a known rate
🔴 RED — USD -> GBP at a known rate
  AssertionError: expected Note(80.00, "GBP"), got None
🟢 GREEN — USD -> GBP at a known rate
🔵 REFACTOR — extracted Rate lookup
✅ Spec 2/4
```

- Print each line as plain text right after the test run that verifies it, one line per step. No prose around it, no batching at the end.
- Write each status line as a text message before your next tool call. A test run without its status line after it means you skipped a step.
- The code fences in this document only mark examples. Never wrap status lines in fences.
- Under 🔴, quote the one failure line. Under 🟢 and 🔵, no runner output unless something failed.
- Print 🔵 only when the code or tests changed. Nothing to refactor: skip the line.
- Print the full spec list at Phase 1, when you add or split an item, and at Phase 3. Not after every spec.
- Lint and formatter output only on failure.

---

### 🔴 RED — write one failing test

1. Write the assertion first. Ask "suppose it worked, how would I tell?" Then write the setup it needs.
2. Write ONE test, named after the behavior and its outcome. Follow the project's conventions from Phase 1.
3. Use literal expected values derived by hand: `Note(80.00, "GBP")`, never `100 * 0.80`. Pick inputs that make the result easy to check by eye, and put the relationship in the test name.
4. Use real objects. Doubles only per the Rules.
5. Run only that test.

**Verify:** the test fails because the behavior is missing. A missing class, function, or import counts. A typo in the test does not. The failure message must say what is missing; if it reads like `False is not true`, improve it now.

**If the test passes on first run:** stop. Never continue on an unverified red.

- If an earlier 🟢 in this run wrote the code, it wrote more than its test demanded. Remove the part this test covers, run the test, see red, restore it. Use Fake It for the rest of the list:
  ```
  🔴 RED — quality floor at 0 (removed early code from Spec 1)
    assert -1 == 0
  🟢 GREEN — quality floor at 0 (code restored)
  ```
- If the behavior existed before this run and one line of production code makes the behavior (a guard, a condition), break that line, run the test, see red, restore it:
  ```
  🔴 RED — quality never below 0 (broke guard to verify)
    assert -1 == 0
  🟢 GREEN — quality never below 0 (guard restored)
  ```
- If no one-line break exists, delete the test and cross the item off: `⚪ ALREADY GREEN — [spec]: deleted, behavior exists`.
- If the test cannot fail at all, fix the test.
- Characterization tests are exempt: they pin behavior that already exists.

---

### 🟢 GREEN — make it pass with the smallest step your confidence allows

| Gear | When | Move |
|---|---|---|
| **Fake It** | Unsure of the implementation | Return the constant the test expects. Replace constants with variables in 🔵, while green |
| **Triangulate** | Unsure of the right abstraction | Add a second example that *forces* generality, then generalize |
| **Obvious Implementation** | You know the code, and no later spec on the list needs it | Type the real thing. Downshift if red surprises you |

1. Write only what this test demands. Code for a later spec waits for that spec's 🔴. No error handling, validation, or options that no test asks for. Do not touch adjacent code.
2. Run only that test.
3. **Unexpected error:** web-search the exact message before the second attempt.
4. **Two fix attempts, then stop.** An attempt is a production edit followed by a test run. Revert the production code to the last green state and keep the red test. Then invoke `feature-dev:code-explorer` or `feature-dev:code-reviewer` on the failure if installed, or ask the user how to proceed. Never a third blind try.
5. Park new ideas on the spec list.

**Verify:** the new test passes.

---

### 🔵 REFACTOR — improve the design while green

Evaluate every cycle: duplication (in code and tests), naming, function size, a pattern in 3+ places that wants a name, test readability. "Duplication is a hint, not a command."

- Refactor only on green. Change code **or** tests in one step, never both. Run the test after every change.
- If the **next** spec looks hard to pass, refactor first, before writing its test: "make the change easy, then make the easy change." Announce it as a preparatory refactor.
- Do not add tests for classes you extract. The existing behavior tests cover them.
- If a refactor breaks something, revert and take a smaller step.

---

### Transition

Run the linter and formatter. Run the whole spec file once. If this change broke a test, fix it before moving on. If a test was already red before this run (rerun it with your change stashed), do not fix it. Print `⚠️ PRE-EXISTING RED — [test] (red before this change, not fixed)`. Print `✅ Spec N/M`. If a spec turns out too large, split it, update the list, and print the list. Move on.

## Phase 3: Completion

Never run the full suite. It can take hours; CI runs it.

1. Run the **related spec files** once: every spec file this run edited, plus the spec file that matches each production file it changed, by the project's naming convention (`app/models/bank.rb` → `spec/models/bank_spec.rb`).
2. Print the result line and the final spec list, all `[x]`. After each item, quote the failure line its 🔴 showed. Mark a break-to-verify red `(broke guard)` and an `⚪ ALREADY GREEN` item `(already green)`.
3. Only when there is one, add one line each: a design decision from refactoring, an out-of-scope finding, the spec a bug fix shows the original list missed. Skip a line that has nothing to say ("Out of scope: none").
4. Repeat each pre-existing red on its own line: `⚠️ Pre-existing red: [test]`.
5. If green, or the only reds are pre-existing, end with `Ready to /commit?`. No other summary, and nothing after it.

```
Related specs: 12 passed, 1 failed in 0.41s
1. [x] same currency returns the same amount — 🔴 AttributeError: 'Bank' object has no attribute 'convert'
2. [x] USD -> GBP at a known rate — 🔴 AssertionError: expected Note(80.00, "GBP"), got None
3. [x] unknown currency pair raises a clear error — 🔴 Failed: DID NOT RAISE UnknownPair
Out of scope: total() also rounds half-even in reports
⚠️ Pre-existing red: test_total_in_reports
Ready to /commit?
```

## Rules

- **No implementation before a test.** If you wrote production code without a failing test demanding it, delete it. Do not adapt it or keep it as reference. Start again from a failing test.
  Why: Code and tests written in the same pass agree by default, bugs included.
- **One test at a time.** Each 🔴 gets its 🟢 before the next 🔴.
  Why: Ten red tests are a long way from green, and the first green changes decisions.
- **Never delete, weaken, skip, or disable a test to reach green.** Fix the code, not the oracle. Two exceptions, stated in the output: a test for a requirement the user changed, and approved characterization output the change alters (quote the changed lines). If you think a test is wrong, say so with evidence and let the user decide.
  Why: A green bar only has value if it means the behavior works.
- **Requirements change: tests change first.** Edit or delete the test, watch it go red, then change the code. When an old test goes red, ask "should it, really?"
  Why: The suite must describe current behavior, not history.
- **Never paste actual output into the expected value.** Exception: characterization tests on legacy code.
  Why: It pins current bugs as correct.
- **Test through the public API or port** (the interface the module exposes to callers). No private methods, test-only getters, or reflection. Test outcomes at the application layer, never a config value or a dependency's internals.
  Why: Refactoring moves structure behind the API. Structure-coupled tests remove the refactor step.
- **Real objects first.** Doubles only for what is slow, non-deterministic, or not owned: a third-party API client, a payment gateway, a clock. The project's test DB, sandbox, temp dir, or test server counts as real. Stub collaborators that return data; verify calls only on collaborators with side effects. Before adding any double, read `references/good-tests.md`.
  Why: State tests survive refactors. Mocked internals pass while production breaks.
- **Inject clocks, randomness, and executors. Fresh state per test. Poll observable state with a timeout instead of `sleep`.**
  Why: A flaky test teaches everyone to ignore red.
- **No logic in tests.** No conditionals, arithmetic in expected values (`6 - 2`, `100 * 0.80`), or copied formulas. A table-driven runner loop is fine. Prefer readable duplication over helpers that hide the data.
  Why: A copied formula shares the production bug.
- **Show evidence.** Under 🔴, the failure line. In Phase 3, the related specs result line. Never "tests pass" without a run.

### Red flags — stop and correct

| Rationalization | Reality |
|---|---|
| "This is too simple to test" | Simple specs take seconds. Fake It and move on |
| "I'll write the tests after" | Tests written after agree with the code, bugs included |
| "I already know the implementation" | The test still comes first. Obvious Implementation only when no later spec needs the code |
| "I'll keep this code and add a test" | Delete it. The test must come first to drive the design |
| "The test is wrong, I'll loosen it" | Say so, show evidence, let the user decide |
| "I'll write all five tests now" | Horizontal slicing. Five reds mean large steps and no feedback |
| "One more try, I almost have it" | Two attempts, then revert and get help |
| "I'll mock the repository to keep it fast" | The project's test DB is real. Mock only what you do not own |
| "I'll assert the config value" | Assert the behavior the config enables |
| "I'll show the status at the end" | Print each line right after its test run |
| "I'll write the whole rule now, the next specs need it" | Write only what this test demands. The next spec's 🔴 drives the rest |

## References

- `references/good-tests.md` — read when a test needs setup over three lines, parameterized rows, an async probe, a UI query, or any double.
- `references/techniques.md` — read when Phase 0 picks Spike, Legacy, or Humble Object, when one test forces a whole algorithm, or for the reasoning and sources behind the rules.
- `references/anti-patterns.md` — read when a red flag fires and the fix is not in Rules. Includes good/bad code per phase.

Examples use Python, TypeScript, and Go. Adapt them to the stack in front of you.
