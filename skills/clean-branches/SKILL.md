---
name: clean-branches
description: >-
  Find and delete stale local git branches and worktrees in the current repo,
  based on the git remote, merged branches, and merged or closed GitHub PRs. It
  always asks for confirmation before it deletes. Use this whenever the user
  wants to clean up, prune, or tidy branches or worktrees, asks which branches
  are stale, merged, or safe to delete, or says things like "my .worktrees
  folder is full" or "get rid of old branches", even if they do not name a
  tool. Handles squash merges, which `git branch --merged` misses. Does not
  delete remote branches.
---

# Clean Branches

This skill deletes local branches and worktrees only. Remote branches and PRs stay, because other people can depend on them.

Scan first, confirm, then apply. The scripts make the decisions that lose work if they are wrong, so use them and do not classify branches by hand.

## 1. Scan

Run from anywhere in the repo:

```bash
<skill-dir>/scripts/scan.sh
```

The output has one tab-separated row per branch: `tier`, `reason`, `branch`, `sha`, `age`, `pr`, `worktree`, `ignored`. A `-` means no value. `ignored` lists ignored files that exist only in that worktree, up to 5. Removing the worktree deletes them. Each worktree's `node_modules` is not listed.

If the scan exits non-zero, report its stderr and stop. A bare clone needs a fetch refspec that creates `refs/remotes/origin/*`.

If stderr says `PR data unavailable` or `PR data incomplete`, tell the user. In that state a branch with an open PR can show as `upstream-gone`, so give those rows more attention.

| Tier | Reason | Meaning |
|---|---|---|
| `safe` | `merged-pr` | PR merged. The local tip has no commits outside the PR. |
| `safe` | `in-default` | The default branch contains the tip. This includes a branch with no commits of its own. |
| `safe` | `prunable-worktree` | The directory of a detached worktree is gone, and a ref contains its HEAD. Only git's record of it remains. |
| `review` | `prunable-worktree-unique-commits` | The directory of a detached worktree is gone, and no ref contains its HEAD. Removing the record leaves the commits unreachable. |
| `review` | `ignored-files` | Otherwise `safe`, but the worktree holds ignored files that are missing from the main checkout or differ from it. Git cannot restore them. |
| `review` | `merged-into-other-base` | PR merged into a branch that is not the default branch. The commits can be absent from the default branch. |
| `review` | `merged-pr-extra-commits` | PR merged, but the local tip differs from the PR head. The local commits can be unique. |
| `review` | `closed-pr` | PR closed without merge. The commits are not in the default branch. |
| `review` | `upstream-gone` | The remote branch is gone and the scan found no PR from this repo. No proof of merge. |
| `blocked` | `dirty-worktree`, `locked-worktree`, `current-worktree`, `main-worktree` | Stale, but the worktree cannot be removed now. The row does not show `review` risk, which appears in a later scan. |
| `keep` | `open-pr` | The branch has an open PR. |
| `keep` | `no-commits` | The tip equals the default branch tip. |
| `keep` | `active` | No signal that the branch is stale. |

The default branch never appears. The scan does not report a detached worktree whose directory exists, or a directory that git does not list as a worktree. Tell the user this if they asked about worktree folders.

## 2. Show the plan

If no row has tier `safe`, `review`, or `blocked`, say that nothing is stale and stop.

Show one table for each of `safe`, `review`, and `blocked`, in that order, with branch, SHA (first 8 characters), reason, age, PR, worktree, and ignored files. Show `keep` as a count. For each `blocked` row, state the fix (for example: commit or stash the changes in `<path>`, or `git worktree unlock <path>`), and say to scan again after the fix.

Stop after the plan, with no question, in these cases:
- No row has tier `safe` or `review`, because nothing can be deleted now.
- The user only asked what is stale and did not ask to delete or clean up. Offer the cleanup as the next step.

## 3. Confirm

Ask with `AskUserQuestion` before every deletion. Do this in auto mode too, and when the original request said to clean up, because the request came before the user saw the list. Without that tool, for example in a headless run, show the plan and stop without deleting.

The dialog can hide earlier text, so name the branches in the question. Offer only the options that apply:

- **Safe only (Recommended)**: the `safe` rows.
- **Safe and review**: the `safe` and `review` rows. Name the `review` rows and their ignored files in the description, because their commits and files can exist only on this machine.
- **Pick branches**: ask a second question with `multiSelect`, or ask for the names as text if there are more than 4. Offer only `safe` and `review` rows, because `apply.sh` refuses all others.
- **Cancel**: delete nothing.

## 4. Apply

Pass only the rows the user approved. Use the full SHA from the scan. Pass each approved `prunable-worktree` or `prunable-worktree-unique-commits` row as `--prune=<worktree>`.

```bash
<skill-dir>/scripts/apply.sh [--prune=<worktree>] <branch>@<sha> ...
```

Do not add force flags and do not run `git worktree remove --force` when the script reports a failure. The script scans again and refuses each item that is no longer `safe` or `review` at the same SHA. This includes a branch that moved, and a worktree that is now dirty or locked. A worktree with an initialized submodule also fails, and the user must remove it by hand. Report the cause. If a branch moved, scan again and confirm again.

## 5. Report

Show a table with one row for each deleted branch or worktree: name, worktree path, and why it was stale. Build the rows from the `apply.sh` output, so a failed delete does not appear as deleted. Write the why in plain words from the scan reason and PR number, for example "PR #12 merged". Show failures in a second table with the cause.

For each deleted `review` branch and each pruned `prunable-worktree-unique-commits` row, give the restore command with the full SHA. Use a new branch name for a pruned row:

```bash
git branch <branch> <sha>
```

The command works until git garbage-collects the unreachable commits.
