---
name: brainstorm-prd
disable-model-invocation: true
description: Interviews the user one question at a time about a feature or large change, then writes a Product Requirements Document (PRD) to docs/prd/<feature>.md. The PRD captures the product-level what and why — problem, goals, user stories, acceptance criteria, constraints, risks — and avoids implementation details like class names, routes, libraries, or code paths. Invoked explicitly by name (/brainstorm-prd).
---

# brainstorm-prd — Interview and draft a PRD

Interview the user about a feature or large change, then write a PRD that captures the outcome. The PRD is a product artifact. It describes the problem, the users, what "done" looks like, and the decisions made.

## Phase 1 — Read the project context

Read the project first. Keep this brief.

- Read `CLAUDE.md` and any nested ones, if present.
- Skim the README, `docs/`, and main entry points to learn the project type.
- If the idea overlaps, replaces, or extends existing code, invoke the `feature-dev:code-explorer` agent strictly to inform your questions.

## Phase 2 — Interview the user

Reach shared understanding of what to build and why.

### Start

If the user gave the feature idea, acknowledge it in one line and ask your first question. If not, ask an open question: what feature or change do they want to think through.

### How to ask questions

- Ask one question at a time, forked on the previous answer. If they said "B2B", do not ask consumer-app questions. If they said "this replaces X", do not treat it as greenfield.
- Ask non-obvious questions. Go after edge cases, tradeoffs, failure modes, conflicts between users, what the system must not do, and what "good enough" means.
- Cover these angles by the end: the problem, who suffers from it today, what success looks like to the user, the interaction model, edge cases and failure modes, scope boundaries, dependencies, and risks.
- Open early, converge late. Save small-enumerable forks for later, once the space is explored.

### How to format questions

- Free text is the default. Ask in plain prose. Let the user answer in their own words.
- Use `AskUserQuestion` only for genuine small-enumerable forks: 2–4 discrete categorical answers, such as `sync` vs `async` or `in scope` vs `out of scope`. If you cannot enumerate the options cleanly, ask in free text.
- Do not label any option "Recommended". A label anchors the user and suppresses answers you did not list.
- Express your view in the question, not as a tool label. Frame it as a hypothesis the user can reject: *"My instinct is real-time matters more here because the feedback loop makes the feature useful — but batch is simpler. Which direction feels right, and why?"*

### What to avoid asking

These belong in a tech spec, not a PRD. Do not ask about them. If the user goes there, redirect.

- Class names, function names, module layout
- Specific libraries, frameworks, or databases (unless the product requirement constrains this — e.g. "must work offline")
- File paths, routes, API endpoint naming
- Implementation algorithms or data structures

To redirect, say: *"That's a great question for a tech spec — for the PRD I want to capture the product need behind it."*

### When to stop

Stop when you could write a PRD a teammate reads cold and understands:

- What problem this solves and why it matters
- What is in scope and what is out
- User stories with acceptance criteria
- The tradeoffs considered and the decisions made
- The main risks and edge cases

If unsure, ask one more question about the thinnest area. Do not drag the interview out once the picture is clear.

## Phase 3 — Recap and confirm

Before writing the file, show the user a recap in chat:

- A one-paragraph summary of the feature.
- The proposed PRD outline: section headings with 1–2 bullets each.
- The proposed filename: a kebab-cased slug, e.g. `docs/prd/user-onboarding-revamp.md`.

Ask whether this matches, or if anything needs to change. Make corrections. If a correction reveals a real gap, return to Phase 2 for a few more questions.

## Phase 4 — Write the PRD

Write the file after the user confirms.

### File handling

- Target path: `docs/prd/<kebab-feature-name>.md` relative to the project root.
- Create `docs/prd/` silently if it does not exist.
- If the target file already exists, stop and ask the user to:
  1. Overwrite
  2. Append as a revision under a dated heading
  3. Write to a different filename (ask for the new slug)

### PRD template

The template is `references/prd-template.md`. Read it before writing. Use it as the exact output structure.

Rules for filling it in:

- Fill every section from the interview. If a section has nothing, write `_None identified during interview._`.
- The `## Target users` section is conditional. Include it only when the interview surfaced more than one distinct user type that interacts with the feature differently. With one user type, fold it into Overview and omit the section.
- The Decisions log has a threshold. Log only forks where a real alternative was considered and rejected. Skip cosmetic choices. If you cannot name a real alternative, it is not a decision.

### Writing style for the PRD

- Write the PRD in ASD-STE100 (Simplified Technical English). One idea per sentence. Keep sentences under ~20 words. Use present tense and active voice. Use one word per meaning. No idioms, no metaphors. This applies to the document only; keep the interview conversational.
- Write in the user's voice and domain. Keep their nouns exactly. If they said "workspace", do not write "tenant". ASD-STE100 governs sentence structure, not their vocabulary.
- Be specific. *"Users should get clear feedback"* is weak. *"When a sync fails, show which records were affected and why"* is useful.
- Make acceptance criteria testable from the user's perspective. Given / When / Then is a fine default; plain bullets are fine when they read better.
- Keep the PRD short.

## Phase 5 — Hand off

After writing the file:

1. Tell the user the path where the PRD was saved.
2. Summarize in 2–3 bullets: what was decided, what is still open, and a suggested next step (e.g. *"to plan implementation, the `feature-dev:code-architect` agent is built for that"*).

Do not implement anything. This skill ends at the PRD.
