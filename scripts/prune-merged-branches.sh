#!/usr/bin/env bash
# ABOUTME: Reports which local branches and worktrees look safe to prune.
# ABOUTME: Report-only until deletion has a separately reviewed implementation.
#
# Why the obvious approaches are wrong here
# -----------------------------------------
# 1. `git branch --merged main` reports 5 of 1185 branches. This repo
#    squash-merges, and a squash rewrites the commit, so a merged branch never
#    becomes an ancestor of main. Ancestry is not the signal.
#
# 2. "Empty diff against main" does not work either. `git diff main <branch>`
#    is symmetric: a branch that merged months ago still differs from today's
#    main by everything that landed since. It reports 2445 changed files for a
#    long-merged branch here.
#
# 3. Name matching destroys work. Deleting everything matching "7606" took out
#    `fix/7606-semantic-tokens` — unpushed local work on a parallel attempt.
#
# So the useful signal in a squash-merge repo is GitHub reporting a same-repo PR
# to main with this head ref merged. Everything else is KEEP.
#
# 4. A head-ref name match alone misses review worktrees. A worktree created to
#    review someone else's PR sits on a scratch branch (`pr-8511`, `pr-8634`)
#    whose name is the head ref of no PR at all, so the name lookup scores it
#    KEEP forever. For those, ask GitHub which PRs contain the worktree's tip
#    COMMIT — an exact SHA, so it needs no name inference. That is MERGED-TIP.
#
# 5. Vetoing on any ignored file makes the script report nothing, ever. Every
#    Flutter worktree carries build/, .dart_tool/ and a pile of generated
#    plugin registrants, so Veto 2 below used to fire on all of them and the
#    run always ended "0 likely prunable". Ignored paths that a toolchain step
#    recreates from tracked sources are not work; ignored paths it does not
#    (a .env, a scratch note, a patch) still are. Only the latter veto.
#
# The bias is deliberate. A false KEEP costs disk. A false DELETE costs work
# that exists nowhere else — an unpushed branch has no backup. Both additions
# above keep that asymmetry: MERGED-TIP still needs Veto 1 to pass, and an
# ignored path that is not on the regenerable list still vetoes.
#
# Usage:
#   bash scripts/prune-merged-branches.sh
#   bash scripts/prune-merged-branches.sh --help
#
# Requires: gh (authenticated), git, perl. Run from the repo root.

set -euo pipefail

usage() {
  sed -n '/^# Usage:/,/^# Requires:/s/^# \{0,1\}//p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

GH="${GH:-gh}"
BASE="${BASE:-origin/main}"
REPO="${REPO:-${GITHUB_REPOSITORY:-divinevideo/divine-mobile}}"
MERGED_PR_LIMIT="${MERGED_PR_LIMIT:-100000}"

command -v "$GH" >/dev/null || { echo "$GH not found" >&2; exit 2; }
git rev-parse --git-dir >/dev/null || exit 2

echo "Fetching origin..."
git fetch origin --prune --quiet
git rev-parse --verify --quiet "$BASE" >/dev/null || {
  echo "$BASE not found" >&2; exit 2
}

# Shallow is fine for the signals used here: the GitHub lookups need no local
# history, and the worktree checks inspect only the current checkout state.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "Note: shallow repository. Classification is unaffected."
fi

echo "Loading merged PR head refs from GitHub..."
MERGED_REFS="$(mktemp)"
WORKTREE_FIELDS="$(mktemp)"
trap 'rm -f "$MERGED_REFS" "$WORKTREE_FIELDS"' EXIT

"$GH" pr list --state merged --limit "$MERGED_PR_LIMIT" \
  --json headRefName,isCrossRepository,baseRefName \
  --jq '.[] | select(.isCrossRepository == false and .baseRefName == "main") | .headRefName' \
  | sort -u > "$MERGED_REFS"
echo "  $(wc -l < "$MERGED_REFS" | tr -d ' ') merged head refs known"

git worktree list --porcelain -z > "$WORKTREE_FIELDS"

worktree_for() {
  WANT="refs/heads/$1" perl -0ne '
    chomp;
    if (/^worktree (.*)\z/s) { $path = $1; next }
    if (/^branch (.*)\z/s && $1 eq $ENV{"WANT"}) { print $path; exit }
  ' "$WORKTREE_FIELDS"
}

commit_exists_on_github() {
  "$GH" api -X GET "repos/$REPO/commits/$1" >/dev/null 2>&1
}

# A merged-to-main PR containing this exact commit. Used only for branches
# whose NAME matches no merged head ref, so review worktrees are still seen.
merged_pr_contains_commit() {
  "$GH" api -X GET "repos/$REPO/commits/$1/pulls" \
    --jq '[.[] | select(.merged_at != null) | select(.base.ref == "main")] | length' \
    2>/dev/null | grep -qxE '[1-9][0-9]*'
}

# Ignored paths any Flutter toolchain step recreates from tracked sources.
# `flutter pub get` plus a build regenerates every one, so a worktree holding
# only these holds no work. Anything absent from this list vetoes, which is
# also how a git-quoted or unusual path fails: safely, toward KEEP.
REGENERABLE_DIR='build|\.dart_tool|\.gradle|\.symlinks|ephemeral|Pods|DerivedData|xcuserdata|\.swiftpm|coverage'
REGENERABLE_FILE='\.DS_Store|\.flutter-plugins|\.flutter-plugins-dependencies|\.packages|local\.properties|Generated\.xcconfig|flutter_export_environment\.sh|Flutter\.podspec|gradlew|gradlew\.bat|gradle-wrapper\.jar|generated_plugins\.cmake|GeneratedPluginRegistrant\.(java|h|m|swift)|generated_plugin_registrant\.(cc|h|dart)'
REGENERABLE_RE="(^|/)(${REGENERABLE_DIR})/|(^|/)(${REGENERABLE_FILE})\$"

# Paths in a worktree that exist in no commit anywhere: every uncommitted or
# untracked entry, plus ignored entries that are not toolchain output.
worktree_blocking_paths() {
  git -C "$1" status --porcelain --ignored=matching 2>/dev/null \
    | while IFS= read -r line; do
        [ -n "$line" ] || continue
        path=${line#??}
        path=${path# }
        case "$line" in
          '!!'*)
            printf '%s\n' "$path" | grep -qE "$REGENERABLE_RE" || printf '%s\n' "$path"
            ;;
          *) printf '%s\n' "$path" ;;
        esac
      done
}

CURRENT="$(git rev-parse --abbrev-ref HEAD)"

printf '\n%-14s %-50s %s\n' "VERDICT" "BRANCH" "WORKTREE"
printf '%s\n' "--------------------------------------------------------------------------------"

merged=0; keep=0
while IFS= read -r branch; do
  case "$branch" in main|master) continue ;; esac
  [ "$branch" = "$CURRENT" ] && continue

  wt="$(worktree_for "$branch")"
  tip="$(git rev-parse "$branch")"

  if grep -qxF -- "$branch" "$MERGED_REFS"; then
    verdict="MERGED-PR"
  elif [ -n "$wt" ] && [ -d "$wt" ] \
    && ! git merge-base --is-ancestor "$tip" "$BASE" \
    && merged_pr_contains_commit "$tip"; then
    # Only worktree branches get this lookup: it is one API call per branch,
    # and a branch with no worktree costs a ref, not 4GB of build output. Tips
    # already on main belong to fresh worktrees, not squashed-away PR heads.
    verdict="MERGED-TIP"
  else
    verdict="KEEP"
  fi

  # Vetoes are applied even to MERGED-PR and MERGED-TIP branches.
  case "$verdict" in MERGED-*) prunable=yes ;; *) prunable=no ;; esac

  # Veto 1: the local tip must exist in GitHub's repository object database.
  # This catches unpushed work and branch-name reuse after an older PR merged.
  if [ "$prunable" = yes ]; then
    if ! commit_exists_on_github "$tip"; then
      verdict="KEEP-LOCAL"
      prunable=no
    fi
  fi

  # Veto 2: uncommitted, untracked, or non-regenerable ignored work in the
  # branch's worktree exists in no commit anywhere, merged PR or not.
  if [ "$prunable" = yes ] && [ -n "$wt" ] && [ -d "$wt" ]; then
    if [ -n "$(worktree_blocking_paths "$wt")" ]; then
      verdict="KEEP-DIRTY"
      prunable=no
    fi
  fi

  printf '%-14s %-50s %s\n' "$verdict" "$branch" "${wt:-—}"
  if [ "$prunable" = yes ]; then
    merged=$((merged + 1))
  else
    keep=$((keep + 1))
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/ | sort)

printf '\n%s likely prunable (merged PR to main, local tip on GitHub, clean) / %s kept.\n' "$merged" "$keep"
echo
echo "Report only. This script does not delete branches or worktrees."
echo "  MERGED-PR   head ref of a merged same-repo PR to main."
echo "  MERGED-TIP  no head-ref match, but a merged PR to main contains the"
echo "              worktree tip. Only branches with a worktree get this check."
echo "  KEEP        no merged PR signal at all."
echo "  KEEP-LOCAL  local tip is not in GitHub's object database (unpushed)."
echo "  KEEP-DIRTY  worktree holds uncommitted, untracked, or non-regenerable"
echo "              ignored files. Toolchain output (build/, .dart_tool/,"
echo "              generated registrants) does not count. Review these by hand."
