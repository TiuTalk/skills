---
name: handoff
description: Write a handoff document that lets a fresh Claude Code session resume this work with full context, instead of relying on /compact. Use when the user runs /handoff or explicitly asks to hand off, pass the work to a new session, or checkpoint progress before clearing. When the user only mentions the context getting long or degraded, suggest running /handoff rather than firing it automatically.
---

Write one Markdown file that a fresh session can read to continue this work as if it never lost context. The next session starts blank: it cannot see this conversation. Everything it needs must be in the file. Write for a competent stranger, not for yourself. Compaction drops detail and blurs attention; a deliberate handoff keeps the exact state, the reasoning, and the next move.

The test for every line: include only what the next session cannot recover on its own. It can re-read the code, the files, and the git history; it cannot recover your reasoning, the approaches you rejected, session-only state (env changes, running processes), and what the user told you. Spend the doc there. Do not restate what a `grep` would show.

## Steps

1. Gather machine state first. Do not trust memory for facts you can check. Run these and read the output:
   - `git rev-parse --git-dir` — confirm you are in a git repo. If it fails, skip every git step below, still write the file, and note "not a git repo" in the snapshot.
   - `git rev-parse --show-toplevel` and `git rev-parse --abbrev-ref HEAD` — repo root and branch.
   - `git status --short` — dirty files.
   - `git diff --stat` — scope of uncommitted change.
   - `git log --oneline -10` — recent commits.
   - `git stash list` — parked work that `git status` hides.
   - When a remote exists (`git remote` is non-empty): `git log --branches --not --remotes --oneline -20` — commits not yet pushed. No remote: write "no remote, all commits local" and skip this.
   - Read your current TodoList if one exists.
   - Recall this session, not from git: env changes made (installs, migrations, exported vars, external logins), background processes started (dev server, watcher, and their ports), and constraints the user stated (what they forbade, deferred, or corrected).
2. Derive one absolute target dir, then ensure it exists and stays git-ignored. Shell state does not persist between Bash calls, so substitute the real absolute path into each command below; do not rely on a `$VAR`.
   - In a repo: read `git rev-parse --show-toplevel`. If its basename is `.claude`, the dir is `<toplevel>/handoffs`; otherwise `<toplevel>/.claude/handoffs`. This avoids a `.claude/.claude/handoffs` nest.
   - Not a repo: use `<cwd>/.claude/handoffs` and skip the ignore steps below.
   - `mkdir -p <abs-dir>`.
   - Keep it ignored without a committed entry. Run `git check-ignore -q <abs-dir>/x`. If it exits nonzero: for the normal `.claude/handoffs` case, ensure the global excludes file holds the single line `.claude/handoffs/` — find it with `git config --global core.excludesfile` (default `~/.config/git/ignore`; create that file if the config is unset, git uses it by default). For the repo whose root IS `.claude`, add `handoffs/` to that repo's `.git/info/exclude` instead, never globally: a global `handoffs/` would hide every `handoffs` dir on the machine. Never edit the repo's own tracked `.gitignore`.
3. Run `date -u +%Y%m%d-%H%M%S` once and reuse that one string for both the filename `<UTC>` and the "Written" field, so they never disagree. Write to `<abs-dir>/<UTC>-<slug>.md`, where `<slug>` is 2-4 kebab words naming the task.
4. Fill the template below. Two rules for empty sections:
   - Always keep, writing "None": `Goal`, `Done`, `Next`, `Verify`, `State snapshot`. The reader must know these were considered.
   - Omit entirely when empty: `Open questions`, `Status`, `Mental model`, `User constraints and preferences`, `Environment and processes`, `Key files`, `Decisions and rationale`, `Traps and gotchas`. A "None" line here is pure filler.
5. Print the exact line to paste into the fresh session, with the real absolute path already substituted (never a `<path>` placeholder). Format it as a fenced code block so it is one-click copyable. Example output: `` `Read /Users/x/.claude/handoffs/20260101-000000-my-task.md, re-run git status and git log --oneline -5, reconcile against the State snapshot, then continue.` ``

## Template

Use this exact structure:

```markdown
# Handoff: [task in one line]

**Written:** [UTC from `date -u`] · **Repo:** [toplevel path] · **Branch:** [branch] · **Model:** [model name from your system prompt, or omit]

## Goal
[What we are ultimately trying to achieve. The definition of done. 1-3 sentences.]

## Open questions
[Anything unresolved the user must decide before or during the next step. Omit the section if none.]

## Status
[Only what is unknown, in-flight, or blocked right now. Proof of what works lives in Done and Verify; do not repeat it here. Omit the section if nothing is open.]

## Mental model
[3-5 sentences: why the state looks the way it does. The reasoning a fresh session cannot recover from code or git alone. Highest-value section; spend real words here.]

## Done
- [Concrete completed step, with the file or commit that proves it]

## Next
1. [The very next action, specific enough to start on. Name the file, the command, the check.]

## Verify
[The exact command(s) that prove the current state works (test, build, curl), and their last-known result.]

## User constraints and preferences
- [Explicit instruction, rejected suggestion, or scope exclusion the user stated this session]

## Environment and processes
- [Env changes this session: installs, migrations, vars, logins. "None" if untouched.]
- [Background processes that should be running: command, port, how to restart.]

## Key files
- `path/to/file` — [why it matters, what to know about it]

## Decisions and rationale
- [Choice made and WHY, so the next session does not relitigate or undo it]

## Traps and gotchas
- [Non-obvious constraint, failing approach already ruled out, flaky command, ordering dependency]

## State snapshot
- Uncommitted: [git status --short, or "clean"]
- Recent commits: [git log --oneline -5]
- Stashes / unpushed: [git stash list and unpushed commits, or "none"]
- External: [open PRs, CI status, moved tickets, or "none"]
```

## Rules

- Facts over vibes: paste real git output, real file paths, real error text. A stranger cannot verify a paraphrase.
- Rationale and traps are the highest-value content. Spend words on why you rejected an approach, not on what the approach was.
- State each fact once. `Done` lists what changed (file or commit). The why lives only in `Decisions and rationale`. Do not retell the same fix across `Done`, `Decisions`, and `Traps`; reference it.
- User constraints are the most-violated thing on resume. Record every "don't touch X" and "skip Y for now" the user said.
- Do not include secrets, tokens, or full file dumps. Link by path and line instead.
- Keep it tight. One screen of signal beats five screens of restatement.
- The file is git-ignored on purpose: it is a scratch checkpoint, not project documentation.
