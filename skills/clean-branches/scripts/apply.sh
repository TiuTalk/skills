#!/usr/bin/env bash
# Usage: apply.sh [--prune=<path>] <branch>@<sha> ...
# Deletes each approved item only if a new scan still lists it as safe or review. Never forces a worktree removal.
set -uo pipefail

failed=0

fail() {
  echo "failed: $1: $2" >&2
  failed=1
}

scan_rows="$("$(dirname "$0")/scan.sh")" || { echo "failed: scan did not complete" >&2; exit 1; }

deletable_branch() {
  BRANCH="$1" SHA="$2" awk -F'\t' '$3 == ENVIRON["BRANCH"] && $4 == ENVIRON["SHA"] && ($1 == "safe" || $1 == "review") { found = 1 } END { exit !found }' <<<"$scan_rows"
}

prunable_path() {
  TARGET="$1" awk -F'\t' '$7 == ENVIRON["TARGET"] && $2 ~ /^prunable-worktree/ { found = 1 } END { exit !found }' <<<"$scan_rows"
}

worktree_of() {
  git worktree list --porcelain | awk -v ref="branch refs/heads/$1" '/^worktree /{ path = substr($0, 10) } $0 == ref { print path; exit }'
}

remove_worktree() {
  local branch="$1" path="$2"
  # gtr looks up the folder named after the branch first, which can be another branch's worktree.
  if [[ -e "$path" && "$(git gtr go "$branch" 2>/dev/null)" == "$path" ]]; then
    # Goes through gtr so that gtr.hook.preRemove and postRemove run.
    git gtr rm "$branch" --yes >/dev/null
  else
    git worktree remove -- "$path"
  fi
}

delete_branch() {
  local branch="${1%@*}" sha="${1##*@}" path

  [[ "$1" == *@* ]] || { fail "$1" "expected <branch>@<sha>"; return; }
  deletable_branch "$branch" "$sha" || { fail "$branch" "the scan does not list it as safe or review at $sha. Scan again."; return; }

  path="$(worktree_of "$branch")"
  if [[ -n "$path" ]]; then
    remove_worktree "$branch" "$path" || { fail "$branch" "worktree not removed: $path"; return; }
    [[ -z "$(worktree_of "$branch")" ]] || { fail "$branch" "worktree not removed: $path"; return; }
    echo "removed worktree $path"
  fi

  # -D because a squash-merged branch is not an ancestor of the default branch.
  if git branch -D -- "$branch" >/dev/null; then
    echo "deleted $branch $sha"
  else
    fail "$branch" "branch not deleted"
  fi
}

prune_worktree() {
  prunable_path "$1" || { fail "$1" "the scan does not list it as a prunable worktree. Scan again."; return; }
  if git worktree remove -- "$1"; then
    echo "pruned worktree $1"
  else
    fail "$1" "worktree record not removed"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --prune=*) prune_worktree "${arg#--prune=}" ;;
    *) delete_branch "$arg" ;;
  esac
done

exit "$failed"
