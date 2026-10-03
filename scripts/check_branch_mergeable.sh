#!/usr/bin/env bash
#
# Reports whether a pushed tip merges into a base ref without conflicts.
# Usage: check_branch_mergeable.sh [base-ref [pushed-from [pushed-tip]]]
# A known push baseline permits changes outside conflicted paths, with a warning.
#
#   exit 0 — clean, conflict outside pushed paths, or merge could not be computed
#   exit 1 — invalid pushed tip, or conflicts touched by push/no usable baseline
#
# `git merge-tree --write-tree` answers with three distinct exit codes: 0 for a
# clean merge, 1 for conflicts, and 128 for a fatal error. Treating "not 0" as
# "conflicts" mislabels the third case, and the usual third case is a shallow
# clone: with the base and the branch grafted at different boundaries there is
# no common ancestor, so merge-tree exits 128 with "refusing to merge unrelated
# histories". That is not a conflict, and the advice for a conflict — merge or
# rebase — cannot fix it.
#
# A base ref that does not resolve at all is a fourth case merge-tree does not
# separate from a real conflict: it exits 1 with "not something we can merge",
# not 128, so it is checked before merge-tree ever runs rather than folded
# into the exit-code switch below.
#
# An unanswerable check is not evidence of a problem, so it warns rather than
# blocks: GitHub's own mergeability status and CI remain authoritative. This
# mirrors the surrounding hook, which already tolerates a failed `git fetch`.
set -uo pipefail

BASE_REF="${1:-origin/main}"
PUSHED_FROM="${2:-}"
PUSHED_TIP="${3:-HEAD}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Prints the conflicted-file section of merging the given tip into BASE_REF,
# one C-quoted line per entry, and returns merge-tree's status (1: conflicts).
conflicted_entries() {
    local tip="$1"
    shift
    git -C "$REPO_ROOT" merge-tree --write-tree --no-messages "$@" "$BASE_REF" "$tip" | sed 1d
}

if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "${PUSHED_TIP}^{commit}" >/dev/null; then
    echo "Cannot resolve pushed tip: $PUSHED_TIP"
    exit 1
fi

# A base ref that does not resolve at all — origin/main renamed, deleted, or
# never fetched — is a fourth unanswerable case merge-tree does not surface as
# 128. It fails as exit 1 with "not something we can merge", indistinguishable
# from a real conflict unless checked first. Absence is not conflict evidence
# either, so this gets the same warn-and-continue treatment as exit 128.
if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null; then
    echo ""
    echo "Could not check for merge conflicts: '$BASE_REF' does not resolve to a"
    echo "commit (renamed, deleted, or never fetched)."
    echo ""
    echo "Continuing; GitHub reports mergeability on the pull request."
    exit 0
fi

stderr=$(git -C "$REPO_ROOT" merge-tree --write-tree "$BASE_REF" "$PUSHED_TIP" 2>&1 >/dev/null)
status=$?

case "$status" in
    0)
        echo "No merge conflicts with ${BASE_REF#origin/}"
        ;;
    1)
        # The push is outside the conflicts when merging before and after it
        # gives the same conflicted entries: the same paths, with the same mode
        # and blob at every stage. Pushed file names are not enough, because a
        # conflict on a file the base renamed is reported under the base's new
        # name while the branch edits the old one. Any failure keeps the block.
        if [ -n "$PUSHED_FROM" ] && git -C "$REPO_ROOT" rev-parse --verify --quiet "${PUSHED_FROM}^{commit}" >/dev/null; then
            before=$(conflicted_entries "$PUSHED_FROM")
            before_status=$?
            after=$(conflicted_entries "$PUSHED_TIP")
            after_status=$?
            conflicts=$(conflicted_entries "$PUSHED_TIP" --name-only)
            conflicts_status=$?
            if [ "$before_status" -eq 1 ] && [ "$after_status" -eq 1 ] \
                && [ "$conflicts_status" -eq 1 ] && [ "$before" = "$after" ]; then
                echo "Warning: branch has merge conflicts with ${BASE_REF#origin/}, outside the pushed changes:"
                printf '%s\n' "$conflicts" | sed 's/^/  /'
                echo "Continuing; resolve these conflicts before merging or final handoff."
                exit 0
            fi
        fi
        echo ""
        echo "Branch has merge conflicts with ${BASE_REF#origin/}!"
        echo ""
        echo "Resolve conflicts before pushing:"
        echo "  git fetch origin ${BASE_REF#origin/}"
        echo "  git rebase $BASE_REF"
        exit 1
        ;;
    *)
        echo ""
        echo "Could not check for merge conflicts (git exit $status)."
        [ -n "$stderr" ] && echo "  $stderr"
        if [ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository)" = "true" ]; then
            echo ""
            echo "This clone is shallow, so $BASE_REF and HEAD may share no visible"
            echo "ancestor. Deepen it to restore the check:"
            echo "  git fetch --deepen=500 origin ${BASE_REF#origin/}"
        fi
        echo ""
        echo "Continuing; GitHub reports mergeability on the pull request."
        ;;
esac
