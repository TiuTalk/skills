#!/usr/bin/env bash
# Prints one tab-separated row per local branch: tier, reason, branch, sha, age, pr, worktree, ignored.
# Changes nothing except remote-tracking refs (fetch --prune).
set -euo pipefail

git remote get-url origin >/dev/null 2>&1 || { echo "error: no origin remote. clean-branches needs a remote named origin." >&2; exit 1; }
git fetch --prune --quiet origin

default_ref="$(git symbolic-ref --quiet refs/remotes/origin/HEAD || true)"
if [[ -z "$default_ref" ]] || ! git rev-parse --quiet --verify "$default_ref^{commit}" >/dev/null; then
  git remote set-head origin --auto >/dev/null
  default_ref="$(git symbolic-ref refs/remotes/origin/HEAD)"
fi
default_branch="${default_ref#refs/remotes/origin/}"
default_tip="$(git rev-parse "$default_ref")"
current_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

declare -A wt_path wt_state
main_root=""
path=""
locked=""
prunable=""
branch=""
head=""

flush_worktree() {
  [[ -n "$path" ]] || return 0
  [[ -n "$main_root" ]] || main_root="$path"
  local state=clean
  if [[ -n "$locked" ]]; then state=locked
  elif [[ -n "$prunable" ]]; then state=missing
  elif [[ -n "$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null)" ]]; then state=dirty
  fi
  if [[ -n "$branch" ]]; then
    wt_path["$branch"]="$path"
    wt_state["$branch"]="$state"
  elif [[ "$state" == missing ]]; then
    if [[ -n "$(git for-each-ref --contains "$head" 2>/dev/null)" ]]; then
      printf 'safe\tprunable-worktree\t-\t%s\t-\t-\t%s\t-\n' "$head" "$path"
    else
      printf 'review\tprunable-worktree-unique-commits\t-\t%s\t-\t-\t%s\t-\n' "$head" "$path"
    fi
  fi
}

# Ignored files that exist only in this worktree. Removing the worktree deletes them.
unique_ignored_files() {
  local worktree="$1" entry path differences
  while IFS= read -r -d '' entry; do
    [[ "$entry" == '!! '* ]] || continue
    path="${entry#!! }"
    [[ "/${path%/}" == */node_modules ]] && continue
    differences="$(diff -rq --no-dereference -- "$worktree/$path" "$main_root/$path" 2>&1 || true)"
    if [[ -n "$differences" ]] && grep -Fqv -- "Only in $main_root/${path%/}" <<<"$differences"; then
      printf '%s\n' "${path//[[:cntrl:]]/?}"
    fi
  done < <(git -C "$worktree" status --porcelain --ignored --untracked-files=normal -z 2>/dev/null)
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*) path="${line#worktree }" ;;
    "HEAD "*) head="${line#HEAD }" ;;
    "branch refs/heads/"*) branch="${line#branch refs/heads/}" ;;
    locked*) locked=1 ;;
    prunable*) prunable=1 ;;
    "")
      flush_worktree
      path="" locked="" prunable="" branch="" head=""
      ;;
  esac
done < <(git worktree list --porcelain)
flush_worktree

prs='[]'
if pr_json="$(gh pr list --state all --limit 1000 --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName 2>/dev/null)" && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$pr_json"; then
  prs="$pr_json"
  if [[ "$(jq length <<<"$prs")" -ge 1000 ]]; then
    echo "warning: PR data incomplete. gh returned its 1000-PR limit, so older PRs are not checked." >&2
  fi
else
  echo "warning: PR data unavailable. Results use git signals only." >&2
fi

while IFS=$'\t' read -r name tip age track; do
  [[ "$name" == "$default_branch" ]] && continue

  # A reused branch name can have an old merged PR and a new open PR. Open wins, then the PR for this exact tip, then the newest.
  pr="$(jq -c --arg name "$name" --arg tip "$tip" '
    map(select(.headRefName == $name and (.isCrossRepository | not)))
    | (map(select(.state == "OPEN")) + map(select(.headRefOid == $tip)) + .)[0] // empty
  ' <<<"$prs")"
  pr_state="" pr_oid="" pr_base="" pr_number="-"
  if [[ -n "$pr" ]]; then
    pr_state="$(jq -r .state <<<"$pr")"
    pr_oid="$(jq -r .headRefOid <<<"$pr")"
    pr_base="$(jq -r .baseRefName <<<"$pr")"
    pr_number="#$(jq -r .number <<<"$pr")"
  fi

  if [[ "$pr_state" == OPEN ]]; then tier=keep reason=open-pr
  elif [[ "$tip" == "$default_tip" ]]; then tier=keep reason=no-commits
  elif git merge-base --is-ancestor "$tip" "$default_ref"; then tier=safe reason=in-default
  elif [[ "$pr_state" == MERGED && "$pr_base" != "$default_branch" ]]; then tier=review reason=merged-into-other-base
  elif [[ "$pr_state" == MERGED ]]; then
    if [[ "$tip" == "$pr_oid" ]] || git merge-base --is-ancestor "$tip" "$pr_oid" 2>/dev/null; then tier=safe reason=merged-pr
    else tier=review reason=merged-pr-extra-commits
    fi
  elif [[ "$pr_state" == CLOSED ]]; then tier=review reason=closed-pr
  elif [[ "$track" == *gone* ]]; then tier=review reason=upstream-gone
  else tier=keep reason=active
  fi

  worktree="${wt_path[$name]:--}"
  ignored=-
  if [[ "$tier" != keep && "$worktree" != - ]]; then
    if [[ "$worktree" == "$current_root" ]]; then tier=blocked reason=current-worktree
    elif [[ "$worktree" == "$main_root" ]]; then tier=blocked reason=main-worktree
    elif [[ "${wt_state[$name]}" == locked ]]; then tier=blocked reason=locked-worktree
    elif [[ "${wt_state[$name]}" == dirty ]]; then tier=blocked reason=dirty-worktree
    elif [[ "${wt_state[$name]}" != missing ]]; then
      mapfile -t unique_files < <(unique_ignored_files "$worktree")
      if ((${#unique_files[@]})); then
        ignored="$(IFS=,; echo "${unique_files[*]:0:5}")"
        ((${#unique_files[@]} > 5)) && ignored+=",+$((${#unique_files[@]} - 5)) more"
        [[ "$tier" == safe ]] && tier=review reason=ignored-files
      fi
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$tier" "$reason" "$name" "$tip" "$age" "$pr_number" "$worktree" "$ignored"
done < <(git for-each-ref refs/heads --format='%(refname:lstrip=2)%09%(objectname)%09%(committerdate:relative)%09%(upstream:track)')
