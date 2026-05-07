---
name: brainstorm-prd
description: Invoked explicitly by name (/brainstorm-prd). Walks the user through an adaptive, one-question-at-a-time interview about a feature or large change, then writes a Product Requirements Document (PRD) to docs/prd/<feature>.md. The PRD captures the product-level what and why — problem, goals, user stories, acceptance criteria, constraints, risks — and deliberately avoids implementation details like class names, routes, libraries, or code paths. Only trigger on explicit invocation, not on general feature-planning requests.
---

# brainstorm-prd — Interview & draft a PRD

Your job is to help the user think through a feature or large change by interviewing them thoroughly, then write a Product Requirements Document capturing the outcome. The PRD is a **product artifact**, not a tech spec — it describes the problem, the users, what "done" looks like, and the decisions made along the way. It does **not** prescribe how to build it.

## Why this shape

The user is trying to reach clarity on a fuzzy idea. The fastest way to get there is a conversation that surfaces the non-obvious tradeoffs — not a form, and not you guessing the answers. Forking the next question based on the previous answer is how a good product manager interviews. Writing the PRD at the end is how that conversation gets captured so future-you, future-them, or a teammate can pick it up cold.

The PRD is intentionally scoped to **product concerns**. Leaving implementation out keeps the document stable across engineering decisions, and lets the team revisit architecture independently from "what are we building and why."

## Phase 1 — Ground yourself in the project (briefly)

Before asking anything, take a quick look at the project so your questions are grounded in reality, not generic.

- Read `CLAUDE.md` (and any nested ones) if present, to understand conventions and constraints the user already wrote down.
- Skim the top-level structure (README, `docs/`, main entry points) to understand what kind of project this is.
- If the user's idea sounds like it might overlap with, replace, or extend something that already exists, invoke the `feature-dev:code-explorer` agent to understand the existing feature's behavior — **strictly to inform your questions**. Never use the exploration to propose where code should live, what classes to name, what libraries to use, or how to wire things up. That's a tech-spec concern and belongs elsewhere.

Keep this pass about context-gathering, not analysis. The moment you catch yourself building a mental model of the architecture — tracing call paths, reasoning about data flow, picking favorite files — stop and start asking questions instead. Architecture is a tech-spec concern; your job here is to know just enough about the project to ask sharp product questions.

## Phase 2 — Interview the user

This is the core of the skill. The goal is to reach shared understanding of **what** should be built and **why**, not **how**.

### Start

If the user gave you the feature idea when invoking the skill, acknowledge it in one line and ask your first real question. If they didn't, your first question is an open one: what feature or change are they trying to think through.

### How to ask questions

**What makes a good question:**

- **One question at a time.** Don't batch unrelated questions together; the point is to branch based on each answer.
- **Fork on every answer.** The next question should be informed by the last one. If they said "B2B", don't ask the same questions you'd ask about a consumer app. If they said "this is replacing X", don't keep asking as if it's greenfield.
- **Ask non-obvious questions.** Skip the boilerplate unless the answers are genuinely unclear. Go after the things the user probably hasn't thought through yet: edge cases, tradeoffs, failure modes, what happens when two users do conflicting things, what the system should *not* do, how this interacts with existing features, what "good enough" looks like vs. "ideal."
- **Cover multiple angles over the course of the interview.** By the end you should have touched: the problem being solved, who suffers from it today, what "success" looks like from the user's POV, the interaction model (not visual design), edge cases & failure modes, scope boundaries (what's deliberately out), dependencies on other work or teams, and risks that could derail it.
- **Open early, converge late.** Start with open exploration. Save small-enumerable forks for later in the interview, once the space has been explored and the remaining decisions are genuinely closed.
- **Resolve dependencies between decisions.** If answer A changes which questions are worth asking, follow that branch to its end before switching topics. Don't bounce around — it makes the interview feel scattered and the user loses the thread.

**How to format questions:**

- **Free text is the default.** Ask in plain prose and let the user answer in their own words. This is how real PM interviews work, and it's how you capture the user's voice, vocabulary, and unprompted priorities — all of which end up in the PRD. Open exploration ("what's the hardest part of this?"), user-voice capture ("who exactly is this for?"), surfacing assumptions ("what are you worried will go wrong?"), and generative questions ("what edge cases come to mind?") all belong in free text.
- **Use `AskUserQuestion` only for genuine small-enumerable forks.** If the decision space is truly 2–4 discrete categorical answers — `sync` vs `async`, `web` / `mobile` / `both`, `in scope` vs `out of scope` — a menu is faster than typing. If you can't enumerate the option space cleanly, it's not a menu question; ask it in free text.
- **Don't label options as "Recommended".** A Recommended label is a social anchor — it tips the user toward your view and quietly suppresses answers you didn't list. In a brainstorm where the plan is being generated from scratch, your recommendations are usually shallow priors, not genuine insight. Let the user pick unprimed.
- **Express your views in the question framing, not as a tool label.** You should still have opinions — hedging and "it depends" are failure modes. The remedy is to frame your view as a hypothesis the user can push back on: *"My instinct is real-time matters more here because the feedback loop is what makes the feature useful — but batch is simpler to build. Which direction feels right to you, and what's pushing you that way?"* This gives the user your reasoning without labeling one answer as the authoritative one.

### What to avoid asking

These belong in a tech spec, not a PRD. Don't ask about them, and if the user pulls the conversation there, gently steer back:

- Class names, function names, module layout
- Specific libraries, frameworks, or databases (unless the *product* requirement constrains this — e.g. "must work offline")
- File paths, routes, API endpoint naming
- Implementation algorithms or data structures

If the user wants to discuss implementation, say something like *"that's a great question for a tech spec — for the PRD I want to capture the product need behind it"* and redirect.

### When to stop

You decide. The interview is done when you could confidently write a PRD that a teammate could read cold and understand:

- What problem this solves and why it matters
- What's in scope and what's explicitly out
- Concrete user stories with acceptance criteria
- The tradeoffs considered and the decisions made, with reasoning
- The main risks and edge cases

If you're unsure whether you have enough, err on the side of one more question about whatever feels thinnest. But don't drag the interview out once the picture is clear — the user's patience is a resource.

## Phase 3 — Recap and confirm

Before writing anything to disk, show the user a condensed recap in chat:

- A one-paragraph summary of the feature as you understand it
- The proposed PRD outline (section headings + 1–2 bullets each)
- The proposed filename: a kebab-cased slug from the feature topic, e.g. `docs/prd/user-onboarding-revamp.md`

Ask whether this matches what they had in mind, or if anything needs adjusting before you write the file.

Make any corrections the user asks for. If the correction reveals a real gap, loop back into Phase 2 for a few more questions rather than writing a PRD you already know is wrong.

## Phase 4 — Write the PRD

Once the user confirms, write the file.

### File handling

- Target path: `docs/prd/<kebab-feature-name>.md` relative to the project root.
- If `docs/prd/` doesn't exist, create it silently.
- If the target file **already exists**, stop and ask the user whether to:
  1. Overwrite
  2. Append (treat the new PRD as a revision under a dated heading)
  3. Write to a different filename (ask for the new slug)

### PRD template

The PRD template lives in `references/prd-template.md`. Read it before writing, and use it as the exact structure for the output.

Rules for filling it in:

- **Fill every section** from the interview. If a section genuinely has nothing in it, write `_None identified during interview._` so the absence is explicit, not accidental.
- **The `## Target users` section is conditional.** Include it only when the interview surfaced more than one distinct user type who interacts with the feature differently (e.g. an admin who configures it and an end user who consumes it). When there's only one user type, fold it into Overview and omit the section entirely — don't write a section that just says "end users."
- **The Decisions log has a threshold.** Only log forks where a reasonable alternative was genuinely considered and rejected — the kind of thing where a future reader would ask "wait, why did we do it this way?" Skip ergonomic or cosmetic choices (filename, section order, wording tweaks, defaults nobody pushed back on). If you can't name a real alternative that was on the table, it's not a decision — it's just a choice, and it doesn't belong here.

### Writing style for the PRD itself

- Write in the user's voice and domain, not generic PM-speak. If they called it a "workspace", don't quietly rename it to "tenant."
- Be specific. *"Users should get clear feedback"* is weak; *"When a sync fails, show which records were affected and why"* is useful.
- Acceptance criteria should be testable from a user's perspective. Given / When / Then is a fine default but plain bullets are fine if they read more naturally.
- Keep the document shorter than you think. PRDs rot when they're long.

## Phase 5 — Hand off

After writing the file:

1. Tell the user the path where the PRD was saved.
2. Summarize in 2–3 bullets: what was decided, what's still open, and a suggested next step (e.g. *"when you're ready to plan implementation, the `feature-dev:code-architect` agent is built for that"*).

Do not start implementing anything. This skill ends at the PRD.
