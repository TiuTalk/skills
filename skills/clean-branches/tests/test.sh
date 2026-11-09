#!/usr/bin/env bash
# Runs scan.sh and apply.sh against a throwaway repo. Only `gh` is faked.
set -uo pipefail

scripts="$(cd "$(dirname "$0")/../scripts" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
git config --global init.defaultBranch main
git config --global gtr.worktrees.dir .worktrees

mkdir "$tmp/bin"
printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = --json ] && fields=$2; shift; done\nexec jq "map({$fields})" "$GH_FIXTURE"\n' > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" GH_FIXTURE="$tmp/prs.json"

git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
cd "$tmp/repo" || exit 1
git commit -q --allow-empty -m init
git push -q -u origin main
git remote set-head origin main

new_branch() {
  git switch -q -c "$1" main
  git commit -q --allow-empty -m "$1"
  git switch -q main
}
pr() { printf '{"number":%s,"state":"%s","headRefName":"%s","headRefOid":"%s","isCrossRepository":%s,"baseRefName":"%s"}\n' "$1" "$2" "$3" "$4" "${5:-false}" "${6:-main}"; }
worktree_add_with_file() {
  new_branch "$1"
  git worktree add -q ".worktrees/$1" "$1"
  mkdir -p ".worktrees/$1/$(dirname "$2")"
  printf '%s' "$3" > ".worktrees/$1/$2"
}

new_branch merged-squash
new_branch merged-extra
merged_extra_pr="$(git rev-parse merged-extra)"
git switch -q merged-extra && git commit -q --allow-empty -m later && git switch -q main
new_branch closed-pr
new_branch open-pr
new_branch active
new_branch fork-same-name
new_branch reused-name

new_branch gone
git push -q -u origin gone
git clone -q "$tmp/origin.git" "$tmp/second-clone" 2>/dev/null
git -C "$tmp/second-clone" push -q origin --delete gone

new_branch in-default
new_branch wt-clean
new_branch wt-dirty
new_branch wt-locked
new_branch wt-moved
new_branch wt-gone-dir
git worktree add -q .worktrees/wt-clean wt-clean
git worktree add -q .worktrees/wt-dirty wt-dirty
git worktree add -q .worktrees/wt-locked wt-locked
git worktree add -q "$tmp/outside-gtr" wt-moved
git worktree add -q "$tmp/removed-dir" wt-gone-dir
rm -rf "$tmp/removed-dir"
touch .worktrees/wt-dirty/untracked.txt
git worktree lock .worktrees/wt-locked

new_branch feat/x
new_branch feat-x
git worktree add -q .worktrees/custom-slash feat/x
git worktree add -q .worktrees/feat-x feat-x

new_branch other-base
new_branch exact-tip
new_branch behind-pr
behind_pr_head="$(git commit-tree -p behind-pr -m "pushed from another machine" "behind-pr^{tree}")"
new_branch keep-dirty
git worktree add -q .worktrees/keep-dirty keep-dirty
touch .worktrees/keep-dirty/untracked.txt
new_branch wt-active-gone-dir
git worktree add -q "$tmp/active-gone-dir" wt-active-gone-dir
rm -rf "$tmp/active-gone-dir"

printf '.env\nnode_modules/\ncache/\n' >> .git/info/exclude
printf 'main' > .env
mkdir cache
printf 'main' > cache/shared
printf 'main' > cache/only-in-main
worktree_add_with_file ignored-same .env main
worktree_add_with_file ignored-differs .env local
worktree_add_with_file ignored-new-file cache/only-here local
worktree_add_with_file ignored-node-modules node_modules/pkg/index.js local
worktree_add_with_file ignored-main-extras cache/shared main

git merge -q --ff-only in-default
git commit -q --allow-empty -m "main moves on"
git branch fresh main
git push -q origin main

{
  pr 1 MERGED merged-squash "$(git rev-parse merged-squash)"
  pr 2 MERGED merged-extra "$merged_extra_pr"
  pr 3 CLOSED closed-pr "$(git rev-parse closed-pr)"
  pr 4 OPEN open-pr "$(git rev-parse open-pr)"
  pr 5 MERGED fork-same-name "$(git rev-parse fork-same-name)" true
  pr 7 MERGED reused-name "$(git rev-parse reused-name)"
  pr 6 OPEN reused-name "$(git rev-parse reused-name)"
  pr 20 CLOSED exact-tip 0000000000000000000000000000000000000000
  pr 21 MERGED exact-tip "$(git rev-parse exact-tip)"
  pr 22 MERGED behind-pr "$behind_pr_head"
  pr 8 MERGED wt-clean "$(git rev-parse wt-clean)"
  pr 9 MERGED wt-dirty "$(git rev-parse wt-dirty)"
  pr 10 MERGED wt-locked "$(git rev-parse wt-locked)"
  pr 11 MERGED wt-moved "$(git rev-parse wt-moved)"
  pr 12 MERGED wt-gone-dir "$(git rev-parse wt-gone-dir)"
  pr 13 MERGED feat/x "$(git rev-parse feat/x)"
  pr 14 MERGED other-base "$(git rev-parse other-base)" false release
  pr 15 MERGED ignored-same "$(git rev-parse ignored-same)"
  pr 16 MERGED ignored-differs "$(git rev-parse ignored-differs)"
  pr 17 MERGED ignored-new-file "$(git rev-parse ignored-new-file)"
  pr 18 MERGED ignored-node-modules "$(git rev-parse ignored-node-modules)"
  pr 19 MERGED ignored-main-extras "$(git rev-parse ignored-main-extras)"
} | jq -s . > "$GH_FIXTURE"

expect_row() {
  local got
  got="$(awk -F'\t' -v b="$2" '$3 == b { print $1 " " $2 }' <<<"$1")"
  if [[ "$got" == "$3" ]]; then echo "ok   $2: $got"; else echo "FAIL $2: got '$got', want '$3'"; failures=$((failures + 1)); fi
}
expect_worktree_row() {
  local got
  got="$(awk -F'\t' -v w="$2" '$7 == w { print $1 " " $2 }' <<<"$1")"
  if [[ "$got" == "$3" ]]; then echo "ok   $2: $got"; else echo "FAIL $2: got '$got', want '$3'"; failures=$((failures + 1)); fi
}
expect_ignored_column() {
  local got
  got="$(awk -F'\t' -v b="$2" '$3 == b { print $8 }' <<<"$1")"
  if [[ "$got" == "$3" ]]; then echo "ok   $2 ignored: $got"; else echo "FAIL $2 ignored: got '$got', want '$3'"; failures=$((failures + 1)); fi
}
expect() {
  if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}

scan="$("$scripts/scan.sh")"
expect_row "$scan" merged-squash "safe merged-pr"
expect_row "$scan" in-default "safe in-default"
expect_row "$scan" merged-extra "review merged-pr-extra-commits"
expect_row "$scan" closed-pr "review closed-pr"
expect_row "$scan" gone "review upstream-gone"
expect_row "$scan" open-pr "keep open-pr"
expect_row "$scan" reused-name "keep open-pr"
expect_row "$scan" active "keep active"
expect_row "$scan" fork-same-name "keep active"
expect_row "$scan" fresh "keep no-commits"
expect_row "$scan" main ""
expect_row "$scan" wt-clean "safe merged-pr"
expect_row "$scan" wt-moved "safe merged-pr"
expect_row "$scan" wt-gone-dir "safe merged-pr"
expect_row "$scan" wt-dirty "blocked dirty-worktree"
expect_row "$scan" wt-locked "blocked locked-worktree"
expect_row "$scan" other-base "review merged-into-other-base"
expect_row "$scan" ignored-same "safe merged-pr"
expect_row "$scan" ignored-differs "review ignored-files"
expect_ignored_column "$scan" ignored-differs ".env"
expect_row "$scan" ignored-new-file "review ignored-files"
expect_ignored_column "$scan" ignored-new-file "cache/"
expect_row "$scan" ignored-node-modules "safe merged-pr"
expect_row "$scan" ignored-main-extras "safe merged-pr"
expect_ignored_column "$scan" merged-squash "-"
expect_row "$scan" exact-tip "safe merged-pr"
expect_row "$scan" behind-pr "safe merged-pr"
expect_row "$scan" keep-dirty "keep active"

git config status.showUntrackedFiles no
expect_row "$("$scripts/scan.sh")" wt-dirty "blocked dirty-worktree"
git config --unset status.showUntrackedFiles

current="$(cd .worktrees/wt-clean && "$scripts/scan.sh")"
expect_row "$current" wt-clean "blocked current-worktree"

git switch -q merged-squash
main_checkout="$("$scripts/scan.sh")"
expect_row "$main_checkout" merged-squash "blocked current-worktree"
linked="$(cd .worktrees/wt-clean && "$scripts/scan.sh")"
expect_row "$linked" merged-squash "blocked main-worktree"
(cd .worktrees/wt-clean && "$scripts/apply.sh" "merged-squash@$(git rev-parse merged-squash)" >/dev/null 2>&1)
expect "apply refuses a branch checked out in the main worktree" "[[ $? != 0 ]] && git rev-parse -q --verify refs/heads/merged-squash >/dev/null"
git switch -q main

mkdir .worktrees/wt-clean/subdir
expect_row "$(cd .worktrees/wt-clean/subdir && "$scripts/scan.sh")" wt-clean "blocked current-worktree"
rmdir .worktrees/wt-clean/subdir

spec() { echo "$1@$(git rev-parse "$1")"; }

merged_squash_sha="$(git rev-parse merged-squash)"
wt_clean_path="$PWD/.worktrees/wt-clean"
applied="$("$scripts/apply.sh" "$(spec merged-squash)" "$(spec wt-clean)" "$(spec wt-moved)" "$(spec wt-gone-dir)")"
expect "apply exits 0 on clean input" "[[ $? == 0 ]]"
expect "apply prints each deleted branch with its sha" "grep -Fxq 'deleted merged-squash $merged_squash_sha' <<<\"\$applied\""
expect "apply prints each removed worktree" "grep -Fxq 'removed worktree $wt_clean_path' <<<\"\$applied\""
expect "apply deletes branch with no worktree" "! git rev-parse -q --verify refs/heads/merged-squash >/dev/null"
expect "apply removes gtr worktree and branch" "[[ ! -d .worktrees/wt-clean ]] && ! git rev-parse -q --verify refs/heads/wt-clean >/dev/null"
expect "apply removes worktree outside gtr dir" "[[ ! -d $tmp/outside-gtr ]] && ! git rev-parse -q --verify refs/heads/wt-moved >/dev/null"
expect "apply clears worktree with missing dir" "! git rev-parse -q --verify refs/heads/wt-gone-dir >/dev/null"
expect "apply keeps the record of an unapproved missing worktree" "git worktree list --porcelain | grep -q 'active-gone-dir'"

feat_x_sha="$(git rev-parse feat-x)"
"$scripts/apply.sh" "$(spec feat/x)" >/dev/null 2>&1
expect "apply removes the approved worktree when gtr resolves the name to another folder" "[[ ! -d .worktrees/custom-slash ]] && ! git rev-parse -q --verify refs/heads/feat/x >/dev/null"
expect "apply keeps the worktree of the similar branch name" "[[ -d .worktrees/feat-x && $feat_x_sha == \$(git rev-parse feat-x) ]]"

closed_sha="$(git rev-parse closed-pr)"
git switch -q closed-pr && git commit -q --allow-empty -m moved && git switch -q main
"$scripts/apply.sh" "closed-pr@$closed_sha" >/dev/null 2>&1
expect "apply fails when branch moved after scan" "[[ $? != 0 ]]"
expect "apply keeps branch that moved after scan" "git rev-parse -q --verify refs/heads/closed-pr >/dev/null"

"$scripts/apply.sh" "$(spec wt-dirty)" >/dev/null 2>&1
expect "apply fails on dirty worktree" "[[ $? != 0 ]]"
expect "apply keeps dirty worktree and files" "[[ -f .worktrees/wt-dirty/untracked.txt ]] && git rev-parse -q --verify refs/heads/wt-dirty >/dev/null"

"$scripts/apply.sh" "$(spec wt-locked)" >/dev/null 2>&1
expect "apply fails on locked worktree" "[[ $? != 0 ]]"
expect "apply keeps locked worktree" "[[ -d .worktrees/wt-locked ]] && git rev-parse -q --verify refs/heads/wt-locked >/dev/null"

"$scripts/apply.sh" "$(spec open-pr)" >/dev/null 2>&1
expect "apply refuses a keep row" "[[ $? != 0 ]] && git rev-parse -q --verify refs/heads/open-pr >/dev/null"

git switch -q active
"$scripts/apply.sh" "$(spec main)" >/dev/null 2>&1
expect "apply refuses the default branch" "[[ $? != 0 ]] && git rev-parse -q --verify refs/heads/main >/dev/null"
git switch -q main

git switch -q in-default
"$scripts/apply.sh" "$(spec in-default)" >/dev/null 2>&1
expect "apply refuses the current checkout" "[[ $? != 0 ]] && git rev-parse -q --verify refs/heads/in-default >/dev/null"
git switch -q main

mixed="$("$scripts/apply.sh" "$(spec wt-dirty)" "$(spec ignored-same)" 2>/dev/null)"
expect "apply exits non-zero when one item in a batch fails" "[[ $? != 0 ]]"
expect "apply continues after a refused item" "grep -q '^deleted ignored-same ' <<<\"\$mixed\" && ! git rev-parse -q --verify refs/heads/ignored-same >/dev/null"
expect "apply prints no deleted line for a refused item" "! grep -q '^deleted wt-dirty ' <<<\"\$mixed\""

if git gtr list --porcelain >/dev/null 2>&1; then
  git branch hook-test main~1
  git worktree add -q .worktrees/hook-test hook-test
  git config gtr.hook.preRemove "touch $tmp/hook-ran"
  "$scripts/apply.sh" "$(spec hook-test)" >/dev/null 2>&1
  expect "apply runs gtr hooks when gtr resolves the approved worktree" "[[ -f $tmp/hook-ran ]]"
  git config --unset gtr.hook.preRemove
else
  echo "SKIP gtr hook test: git-gtr is not installed"
fi

printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/git-gtr"
chmod +x "$tmp/bin/git-gtr"
git branch plain-dirty main~1
git worktree add -q "$tmp/plain-dirty" plain-dirty
touch "$tmp/plain-dirty/untracked.txt"
"$scripts/apply.sh" "$(spec plain-dirty)" >/dev/null 2>&1
expect "apply keeps a dirty worktree without gtr" "[[ $? != 0 && -f $tmp/plain-dirty/untracked.txt ]]"
git branch plain-locked main~1
git worktree add -q "$tmp/plain-locked" plain-locked
git worktree lock "$tmp/plain-locked"
"$scripts/apply.sh" "$(spec plain-locked)" >/dev/null 2>&1
expect "apply keeps a locked worktree without gtr" "[[ $? != 0 && -d $tmp/plain-locked ]]"
git branch no-gtr main~1
git worktree add -q "$tmp/no-gtr" no-gtr
"$scripts/apply.sh" "$(spec no-gtr)" >/dev/null
expect "apply removes worktree when gtr is not available" "[[ $? == 0 && ! -d $tmp/no-gtr ]]"
rm "$tmp/bin/git-gtr"

git worktree add -q "$tmp/detached-plain" --detach main
git worktree add -q "$tmp/detached-unique" --detach main
(cd "$tmp/detached-unique" && git commit -q --allow-empty -m unique)
rm -rf "$tmp/detached-plain" "$tmp/detached-unique"
pruning="$("$scripts/scan.sh")"
expect_worktree_row "$pruning" "$tmp/detached-plain" "safe prunable-worktree"
expect_worktree_row "$pruning" "$tmp/detached-unique" "review prunable-worktree-unique-commits"
expect "scan gives the sha of a detached worktree with unique commits" "awk -F'\t' -v w=$tmp/detached-unique '\$7 == w { print \$4 }' <<<\"\$pruning\" | grep -Eq '^[0-9a-f]{40}$'"

"$scripts/apply.sh" "--prune=$tmp/detached-plain" >/dev/null
expect "apply --prune clears the approved missing worktree" "[[ $? == 0 ]] && ! git worktree list --porcelain | grep -q detached-plain"
expect "apply --prune keeps the other missing worktree" "git worktree list --porcelain | grep -q detached-unique"

"$scripts/apply.sh" "--prune=$PWD" >/dev/null 2>&1
expect "apply --prune refuses a path with no prunable row" "[[ $? != 0 && -d $PWD/.git ]]"

echo '[' > "$GH_FIXTURE"
no_gh="$("$scripts/scan.sh" 2>"$tmp/stderr")"
expect "scan warns when PR data is unavailable" "grep -q 'PR data unavailable' $tmp/stderr"
expect_row "$no_gh" open-pr "keep active"

jq -n '[range(1000) | {number: ., state: "CLOSED", headRefName: "old-\(.)", headRefOid: "0", isCrossRepository: false, baseRefName: "main"}]' > "$GH_FIXTURE"
"$scripts/scan.sh" >/dev/null 2>"$tmp/stderr"
expect "scan warns when PR data reaches the limit" "grep -q 'PR data incomplete' $tmp/stderr"

new_repo() {
  git init -q --bare -b "$2" "$tmp/$1.git"
  git clone -q "$tmp/$1.git" "$tmp/$1" 2>/dev/null
  cd "$tmp/$1" || exit 1
  git commit -q --allow-empty -m init
  git push -q -u origin "$2"
  git remote set-head origin "$2"
  git commit -q --allow-empty -m "$2 moves on"
  git push -q origin "$2"
}
echo '[]' > "$GH_FIXTURE"

new_repo ambiguous trunk
git branch origin/trunk trunk~1
git branch old-work trunk~1
git switch -q -c elsewhere
ambiguous="$("$scripts/scan.sh")"
expect_row "$ambiguous" trunk ""
expect_row "$ambiguous" old-work "safe in-default"
"$scripts/apply.sh" "trunk@$(git rev-parse trunk)" >/dev/null 2>&1
expect "apply refuses a default branch not named main when origin/<default> is also a local branch" "[[ $? != 0 ]] && git rev-parse -q --verify refs/heads/trunk >/dev/null"

new_repo renamed old
git branch -q -m old-local 2>/dev/null
git branch old-name-work old-local~1
git -C "$tmp/renamed.git" branch -m old new
renamed="$("$scripts/scan.sh" 2>/dev/null)"
expect "scan succeeds after the default branch is renamed" "[[ $? == 0 ]]"
expect_row "$renamed" old-name-work "safe in-default"

mkdir "$tmp/no-remote"
cd "$tmp/no-remote" || exit 1
git init -q
git commit -q --allow-empty -m init
no_remote="$("$scripts/scan.sh" 2>"$tmp/stderr")"
expect "scan fails without an origin remote" "[[ $? != 0 && -z '$no_remote' ]]"
expect "scan names the missing origin remote" "grep -q 'no origin remote' $tmp/stderr"

git clone -q --bare "$tmp/ambiguous.git" "$tmp/bare-clone.git"
cd "$tmp/bare-clone.git" || exit 1
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git branch bare-old trunk~1
bare="$("$scripts/scan.sh" 2>/dev/null)"
expect "scan succeeds in a bare clone with a fetch refspec" "[[ $? == 0 ]]"
expect_row "$bare" bare-old "safe in-default"

new_repo remote-moves main
git branch merged-elsewhere
git switch -q merged-elsewhere
git commit -q --allow-empty -m merged-elsewhere
git push -q origin merged-elsewhere
git switch -q main
git clone -q "$tmp/remote-moves.git" "$tmp/remote-moves-second" 2>/dev/null
git -C "$tmp/remote-moves-second" merge -q --no-ff -m merge origin/merged-elsewhere
git -C "$tmp/remote-moves-second" push -q origin main
expect_row "$("$scripts/scan.sh")" merged-elsewhere "safe in-default"

new_repo numeric-name main
git branch 1 main~1
git worktree add -q .worktrees/1 1
"$scripts/apply.sh" "1@$(git rev-parse 1)" >/dev/null 2>&1
expect "apply removes the worktree of a branch named 1" "[[ $? == 0 && ! -d .worktrees/1 ]] && ! git rev-parse -q --verify refs/heads/1 >/dev/null"

echo
if ((failures)); then echo "$failures failed"; exit 1; fi
echo "all passed"
