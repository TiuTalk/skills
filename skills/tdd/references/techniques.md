# Techniques and reasoning

Read when Phase 0 picks Spike, Legacy, or Humble Object, when one test forces a whole algorithm, or for the sources behind the rules.

## Step size

```python
# Fake It
def test_sum_2_3(): assert add(2, 3) == 5
def add(a, b): return 5

# Triangulate: a second example forces generality
def test_sum_1_1(): assert add(1, 1) == 2
def add(a, b): return a + b
```

Pick a second example that *forces* a change. `add(4, 1) == 5` does not.

- Keep increments small: a few lines, a test run every minute or two.
- Predict the result before each run. A wrong prediction teaches you something at once.
- If a test forces a whole algorithm at once, look for a simpler test first (Martin's Transformation Priority Premise: constant → scalar → conditional → loop).
- Revert instead of editing further. Cap fix attempts at two, then revert.

Why: Beck triangulates "only when I'm really, really unsure about the correct abstraction." Obvious Implementation is second gear; "be prepared to downshift." A small diff limits where a mistake can be.

## Outside-in vs. inside-out

- **Outside-in (double loop):** write a failing acceptance test for the feature first. It stays red while many short unit cycles run inside it. Start with a **walking skeleton**: the thinnest slice that builds, deploys, and runs end to end.
  Why: The outer test defines "done" in user terms and stops gold-plating.
- **Inside-out:** build and test the domain with real objects first, then add the delivery layer.
  Why: Tests stay coupled to state, and refactoring stays cheap.
- **Recommendation:** outside-in at the feature boundary, real objects inside the domain, doubles only at owned ports.

## Fixing a bug

Steps are in SKILL.md, Phase 0 and Rules. The regression test names the bug:

```python
def test_convert_rounds_half_up_not_banker():  # bug #412: 0.125 GBP shown as 0.12
    bank = Bank(rates={("USD", "GBP"): 0.125}, commission=0)
    assert bank.convert(Note(1, "USD"), "GBP").display() == "0.13"
```

Why: The failing test proves you reproduced the defect. A test that passes before the fix means the diagnosis is wrong. One test is enough: a second, lower-level test of the same case goes green with the same fix and never fails first. Name the missed spec in the Phase 3 notes instead.

## Spike

When the requirement or the feasibility is unclear, write throwaway code to learn. Rules:

1. Say "spike" before you start. No tests, no cleanup.
2. Learn what you needed: the API shape, the data, whether it is possible.
3. Delete the spike. `git stash drop` or `git checkout -- .`. It never stays in the diff.
4. Write the spec list from what you learned. Start Phase 1.

Why: TDD needs a concrete expected outcome to assert. Tests written on top of guesses encode the guesses. Keeping spike code means untested code with no oracle.

## Legacy code with no tests

Do not start test-first on code you cannot safely touch. Feathers' algorithm:

1. Identify the change points.
2. Find the test points.
3. Break dependencies (find or create a **seam**: a place where you can alter behavior without editing there).
4. Write characterization tests.
5. Make the change and refactor.

- **Characterization or approval tests** pin current behavior, bugs included. This is the one place where copying actual output into the expected value is correct, and where a loop that generates inputs is fine.

```python
def test_update_quality_golden_master(approved):
    items = [Item(n, s, q) for n in NAMES for s in (-1, 0, 5, 11) for q in (0, 1, 49, 50)]
    for _ in range(30): GildedRose(items).update_quality()
    assert render(items) == approved("gilded_rose.txt")
```

- **Sprout Method or Class:** write the new logic test-first in new code and call it from the legacy method.
- **Wrap Method:** rename the old method, add a new one with the old name that delegates and adds the new behavior before or after.

Why: New code gets full TDD today. The untested region stops growing.

## Humble Object

For a boundary that is hard to test (GUI, framework callback, hardware, CSS): move every decision (formatting, state, validation, which class to apply) into plain code you can test. Keep the boundary object so thin that a visual or manual check is enough.

Why: The logic gets fast tests. Only a thin layer needs slower checks. Nobody test-drives "fiddle with the CSS until it looks right."

## Scaffolding tests

You may write fine-grained tests while building a complex internal part. Delete them once a behavior-level test covers the logic, and say which test replaces each.

Why: They help you take small steps. Kept, they lock in the implementation.

## Complements

- **Property-based testing** (Hypothesis, fast-check, gopter): add it after examples have driven the design. Common properties: round trip (`decode(encode(x)) == x`), invariants, idempotence, "matches a naive oracle" (`fast_sort(xs) == sorted(xs)`). When a property finds a failing input, add it as a literal example test.
- **Mutation testing** (mutmut, Stryker, PIT): run it on the diff. A surviving mutant marks a step that was too big or an Obvious Implementation that went beyond the tests.
  Why: Coverage shows a line ran, not that a test would notice if it were wrong.
- **Data pipelines:** test transforms with small fixed input rows and expected output rows before touching real data.

## Why these rules

Sources behind SKILL.md, for when you need the reasoning.

- **Canon TDD (Beck, 2023):** write a test list, write one test, make it pass, refactor (optional), repeat. Not: all tests first, one test per method, a coverage target.
- **Goal state (Beck):** everything that worked still works, the new behavior works, the system is ready for the next change, and you feel confident about all three. "Keep testing & coding until your fear for the behavior of the code has been transmuted into boredom."
- **Why test first:** "Thinking about the test first forces us to think about the interface to the code first" (Fowler). The test and the code are two derivations of the answer; their agreement carries information. The red step is the only cheap check that the test can fail (Seemann: "If you haven't seen it fail, you don't know if you've avoided a tautology").
- **One test at a time:** "What happens when you get to test #6 & you haven't seen anything pass yet? Depression and/or boredom." (Beck)
- **Two hats (Beck, via Fowler):** add behavior or restructure code, never both at once. If a test goes red while you mix them, you cannot tell which change caused it.
- **Behavior, not structure (Cooper, *TDD, Where Did It All Go Wrong*):** a new behavior triggers a new test; a new method or class does not. Tests that encode implementation break during refactoring, which removes the refactor step.
- **Hard-to-test code is design feedback:** "difficult-to-write unit tests are the canary in the bad interface coal mine" (Beck). Freeman and Pryce: "Listen to the tests."
- **Refactor step:** "The most common way that I hear to screw up TDD is neglecting the third step... we just end up with a messy aggregation of code fragments." (Fowler) "Duplication is a hint, not a command." (Beck)
- **Evident data:** "You are writing tests for a reader, not just the computer." Pasting actual output "defeats double checking, which creates much of the validation value of TDD." (Beck)
- **Doubles:** "emphasizing state testing is more scalable; it reduces test brittleness" (Google). "Mock Objects is misnamed. It is really a technique for identifying types in a system based on the roles that objects play." (Freeman, Pryce et al.)
- **Agents:** deleted or disabled tests in an agent's diff are a stop sign (Beck, *Augmented Coding*). Agent commits add mocks more often than human commits (36% vs 26%, arXiv 2602.00409), hence the explicit mocking rules.
- **Evidence:** industrial case studies report 40-90% lower pre-release defect density at 15-35% more initial time (Nagappan et al. 2008). A meta-analysis found a small positive effect on quality and no clear productivity effect (Rafique and Misic 2013). Short, uniform cycles predicted quality and productivity (Fucci et al. 2017). Most "TDD failed" stories describe practices Beck calls mistakes: all tests first, per-method tests, mock everything.
