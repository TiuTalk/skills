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

Ask these questions in order. Stop at the first yes. A flag, a branch, or a computed value is logic.

1. **No test runner in the project?** Print `⛔ STOP` and ask the user to approve a one-command setup. After the setup, start this list again.
2. **Refactor with no behavior change?** **Green loop.** Confirm the related spec files are green. Refactor in small steps. Run them after each step and print `🔵 1/3 extracted Rate class · 8 passed`. No 🔴 phase.
3. **Only visual layout, CSS, or markup?** **Humble Object.** Test each decision (a flag, a class name, a format) through the public API or one user-level UI test. Do not assert CSS values. Leave the pixel check to the user, or screenshot with `playwright-cli`.
4. **Requirement or feasibility unclear?** **Spike**, then go to 5. Throwaway code to learn. It never stays in the diff.
5. **Everything else:** **Full loop**, Phases 1-3. For a bug fix, write one spec: the smallest test that fails because of the defect, then the fix. At the end, name the spec the original list missed in one line.

**Modifier: the code you change has no tests.** Write a characterization test first (`references/techniques.md`), then continue with the mode. When the change alters pinned output, update the approved file and quote the changed lines under 🟢. For a bug fix, the change to pinned output at the defect is the expected red.

Full loop with no modifier prints nothing. Otherwise print one line, e.g. `Mode: Green loop · characterize first`.

## Phase 1: Understand and decompose

### 1. Learn how this project tests

Do this first, every session:

- Find the framework, test directory, file naming, and assertion style.
- Read two existing specs near the code you will change. Copy their shape: setup, factories or builders, how they touch the DB, how they handle external calls.
- Note the runner command for one test and for one spec file, in its quiet or failures-only form (`pytest -q --tb=short`, `rspec --format progress`, `go test -run X`, `vitest --reporter=dot`). Use that form on every run. Follow the project's own instructions (CLAUDE.md, README) if they exist.
- Read the code you will change and at least one caller.

### 2. Clarify

State your assumptions as short bullets and proceed. Ask with `AskUserQuestion` only when two readings of the request give different spec lists. Ask for one concrete example (input, exact output, what must not happen), never about implementation.

### 3. Break into specs

If the request spans 3+ modules, invoke the architect agent before you write the list, if one is installed. Write the list from its output.

List behaviors, not implementation steps. Order them so each builds on the last. Spec 1 is a **tracer bullet**: the simplest case that runs the whole path from input to output.

```
Assumptions:
- Bank takes an optional `rates` dict keyed by (from, to)
- No rounding on converted amounts

Specs to implement:
1. [ ] same currency returns the same amount
2. [ ] USD -> GBP at a known rate
3. [ ] unknown currency pair raises UnknownPair
4. [ ] rate service timeout -> ConversionUnavailable
```

If two specs need the same code change, offer to merge them in one line under the list. Print the assumptions and the list before you write the first test. Wait for the user to confirm, unless told to proceed without confirmation.

Keep the list alive. Add cases the request needs as numbered items. Note needed refactors under the list as `Refactor: ...` and do them in the next 🔵 step. Report out-of-scope findings in one line at Phase 3.

## Phase 2: The loop

For each spec: 🔴 RED → 🟢 GREEN → 🔵 REFACTOR. Print these status lines:

```
Spec 2/4: USD -> GBP at a known rate
🔴 test_convert_usd_to_gbp (tests/test_bank.py:31)
  AssertionError: expected Note(80.00, "GBP"), got None
🟢 bank.py (Fake It)
🔵 extracted Rate lookup
✅ Spec 2/4
```

The only other lines: the Phase 0 mode line, the Phase 1 assumptions and spec list, `⚪ ALREADY GREEN`, `🔵 PREP REFACTOR — [what]`, `🧪 SPIKE — [what to learn]`, `⛔ STOP`, and the Phase 3 block.

Print `⛔ STOP` whenever you need the user, then wait for the reply:

```
⛔ STOP — Spec 3/4: 3 attempts failed. Code restored, test kept red.
  KeyError: ('USD', 'XYZ')
  Reply: "drop 3", or state the fix
```

- Print each line as plain text right after the test run that verifies it, one line per step. No prose around it, no batching at the end.
- Write each status line as a text message before your next tool call. A test run without its status line after it means you skipped a step.
- The code fences in this document only mark examples. Never wrap status lines in fences.
- Under 🔴, quote the one failure line. Under 🟢 and 🔵, no runner output unless something failed.
- Print 🔵 only when the code or tests changed. Nothing to refactor: skip the line.
- One spec per cycle, one ✅ per line. Never mark two specs done together.
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

**If the test passes on first run:** stop. Never continue on an unverified red. Prove the test can fail:

1. Comment out the production code that makes the behavior: the code an earlier 🟢 wrote beyond its test, or the guard that already existed. If no single line makes it, comment out the whole body of the function under test.
2. Run the new test and the related spec files.
3. Run `git restore <production file>`. `git diff <production file>` must be empty.
4. Act on the result:
   - The new test stayed green: the test is a Liar. Fix the test.
   - An earlier 🟢 in this run wrote the code: keep the test. Use Fake It for the next 🟢 only.
     ```
     Spec 2/4: USD -> GBP at a known rate
     🔴 test_convert_usd_to_gbp (tests/test_bank.py:31) · commented out code from Spec 1
       AssertionError: expected Note(80.00, "GBP"), got Note(100.00, "USD")
     🟢 bank.py (code restored)
     ✅ Spec 2/4
     ```
   - The behavior existed before this run, and only the new test went red: keep the test. Print `⚪ ALREADY GREEN — Spec 3/4: test kept`.
   - The behavior existed before this run, and other tests went red too: delete the new test. Print `⚪ ALREADY GREEN — Spec 3/4: covered by test_unknown_pair, test deleted`.

Characterization tests are exempt: they pin behavior that already exists.

---

### 🟢 GREEN — make it pass with the smallest step your confidence allows

| Gear | When | Move |
|---|---|---|
| **Fake It** | Unsure of the implementation | Return the constant the test expects. Replace constants with variables in 🔵, while green |
| **Triangulate** | Unsure of the right abstraction | Add a second example that *forces* generality, then generalize |
| **Obvious Implementation** | You know the code, and every line is required by the current spec: branches, guards, error paths, data structures | Type the real thing. If a later spec would then pass without new code, use Fake It instead. Downshift if red surprises you |

1. Write only what this test demands. Code for a later spec waits for that spec's 🔴. No error handling, validation, or options that no test asks for. Do not touch adjacent code.
2. Run only that test.
3. **Two attempts, then recover once.** The first implementation is attempt 1. One more production edit and test run is attempt 2. If the test is still red:
   1. In parallel: run the reviewer agent on the failed diff, run the explorer agent on the failure line, and web-search the exact error message.
   2. Run `git restore <production files>`. Keep the red test.
   3. Make one more attempt with the three reports.
   4. Still red: run `git restore <production files>` and print `⛔ STOP` with the failure line and what you tried. Never a fourth try.
4. Park new ideas on the spec list.

**Verify:** the new test passes.

---

### 🔵 REFACTOR — improve the design while green

Evaluate every cycle: duplication (in code and tests), naming, function size, a pattern in 3+ places that wants a name, test readability. "Duplication is a hint, not a command."

- Refactor only on green. Change code **or** tests in one step, never both. Run the test after every change.
- If the **next** spec looks hard to pass, refactor first, before writing its test: "make the change easy, then make the easy change." Print `🔵 PREP REFACTOR — [what]`.
- Do not add tests for classes you extract. The existing behavior tests cover them. If an extracted class needs its own contract, add a spec for it to the list.
- If a refactor breaks something, revert and take a smaller step.

---

### Transition

1. Run the linter and formatter on the files this run changed.
2. Run the whole spec file once. If a test is red:
   - The test is in a file this run created: this change broke it. Fix it within the GREEN attempt limits.
   - The test is in an existing file: check whether it was red before this run. Use one command, so the stash always returns: `git stash push -q -m tdd-check -- <touched tracked files> && { <run test>; git stash pop -q --index; }`. `git stash list` must show no `tdd-check` entry.
     - Green without the change: this change broke it. Fix it within the GREEN attempt limits.
     - Still red: print `⛔ STOP — [test] was red before this run`, the failure line, and `Reply: "ignore", "add as spec", or "stop"`.
3. Print `✅ Spec N/M`.
4. Run `git add <files this spec touched>`. The index now holds the last green state, and `git restore` returns to it.
5. If a spec turns out too large, split it, update the list, and print the list. Move on.

## Phase 3: Completion

Never run the full suite. It can take hours; CI runs it.

1. Run the **related spec files** once: every spec file this run edited, plus the spec file that matches each production file it changed, by the project's naming convention (`app/models/bank.rb` → `spec/models/bank_spec.rb`).
2. If a test this run broke is red, fix it within the GREEN attempt limits. Still red: `⛔ STOP`.
3. Run the reviewer agent on this run's diff. Turn each finding that changes behavior into a new spec and run the loop. Fix each style or naming finding in one 🔵 step. If you changed code, run the related spec files again.
4. Print the result line, a `Files:` line, and the final spec list, all `[x]`. Mark an item only when its red was not normal: `(written early)`, `(already green)`, or `(covered by [test], test deleted)`.
5. Only when there is one, add one line each: a design decision from refactoring, an out-of-scope finding, the spec a bug fix shows the original list missed. Skip a line that has nothing to say ("Out of scope: none").
6. Print each ignored pre-existing red on its own line: `⚠️ Pre-existing red: [test] (ignored)`.
7. End with `Ready to /commit?`. Nothing after it.

```
Related specs: 12 passed, 1 failed in 0.41s
Files: bank.py, tests/test_bank.py
1. [x] same currency returns the same amount
2. [x] USD -> GBP at a known rate (written early)
3. [x] unknown currency pair raises UnknownPair (already green)
4. [x] rate service timeout -> ConversionUnavailable
Out of scope: total() also rounds half-even in reports
⚠️ Pre-existing red: test_total_in_reports (ignored)
Ready to /commit?
```

## Rules

- **No implementation before a test.** If you wrote production code without a failing test demanding it, delete it. Do not adapt it or keep it as reference. Start again from a failing test.
  Why: Code and tests written in the same pass agree by default, bugs included.
- **One test at a time.** Each 🔴 gets its 🟢 before the next 🔴.
  Why: Ten red tests are a long way from green, and the first green changes decisions.
- **Never delete, weaken, skip, or disable a test to reach green.** Fix the code, not the oracle. Three exceptions, stated in the output: a test for a requirement the user changed, approved characterization output the change alters (quote the changed lines), and a new test that duplicates an existing one (`⚪ ALREADY GREEN`). If you think a test is wrong, print `⛔ STOP` with the evidence and let the user decide.
  Why: A green bar only has value if it means the behavior works.
- **Requirements change: tests change first.** Edit or delete the test, watch it go red, then change the code. When an old test goes red, ask "should it, really?"
  Why: The suite must describe current behavior, not history.
- **Never paste actual output into the expected value.** Exception: characterization tests on legacy code.
  Why: It pins current bugs as correct.
- **Test through the public API or port** (the interface the module exposes to callers). No private methods, test-only getters, or reflection. Test outcomes at the application layer, never a config value or a dependency's internals.
  Why: Refactoring moves structure behind the API. Structure-coupled tests remove the refactor step.
- **Real objects first.** Doubles only for what is slow, non-deterministic, or not owned: a third-party API client, a payment gateway, a clock. The project's test DB, sandbox, temp dir, or test server counts as real. Stub collaborators that return data; verify calls only on collaborators with side effects.
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
| "I already know the implementation" | The test still comes first. Obvious Implementation only when every line serves the current spec |
| "I'll keep this code and add a test" | Delete it. The test must come first to drive the design |
| "The test is wrong, I'll loosen it" | Print `⛔ STOP` with the evidence, let the user decide |
| "I'll write all five tests now" | Horizontal slicing. Five reds mean large steps and no feedback |
| "One more try, I almost have it" | Two attempts, recover once, then `⛔ STOP` |
| "I'll mark both specs done, one change covers them" | One spec per cycle. Offer merges at the spec list |
| "I'll mock the repository to keep it fast" | The project's test DB is real. Mock only what you do not own |
| "I'll assert the config value" | Assert the behavior the config enables |
| "I'll show the status at the end" | Print each line right after its test run |
| "I'll write the whole rule now, the next specs need it" | Write only what this test demands. The next spec's 🔴 drives the rest |

## References

Read each reference at most once per session.

- `references/good-tests.md` — read when a test needs setup over ten lines, parameterized rows, an async probe, a UI query, or any double.
- `references/techniques.md` — read when Phase 0 picks Spike, Humble Object, or the characterization modifier, when one test forces a whole algorithm, or for the reasoning and sources behind the rules.
- `references/anti-patterns.md` — read when a red flag fires and the fix is not in Rules. Includes good/bad code per phase.

Examples use Python, TypeScript, and Go. Adapt them to the stack in front of you.
