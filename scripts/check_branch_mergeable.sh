#!/usr/bin/env bash
#
# Reports whether HEAD merges into a base ref without conflicts.
#
#   exit 0 — merges cleanly, or the question could not be answered
#   exit 1 — genuine merge conflicts
#
# `git merge-tree --write-tree` answers with three distinct exit codes: 0 for a
# clean merge, 1 for conflicts, and 128 for a fatal error. Treating "not 0" as
# "conflicts" mislabels the third case, and the usual third case is a shallow
# clone: with the base and the branch grafted at different boundaries there is
# no common ancestor, so merge-tree exits 128 with "refusing to merge unrelated
# histories". That is not a conflict, and the advice for a conflict — merge or
# rebase — cannot fix it.
#
# An unanswerable check is not evidence of a problem, so it warns rather than
# blocks: GitHub's own mergeability status and CI remain authoritative. This
# mirrors the surrounding hook, which already tolerates a failed `git fetch`.
set -uo pipefail

BASE_REF="${1:-origin/main}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

stderr=$(git -C "$REPO_ROOT" merge-tree --write-tree "$BASE_REF" HEAD 2>&1 >/dev/null)
status=$?

case "$status" in
    0)
        echo "No merge conflicts with ${BASE_REF#origin/}"
        ;;
    1)
        echo ""
        echo "Branch has merge conflicts with ${BASE_REF#origin/}!"
        echo ""
        echo "Resolve conflicts before pushing:"
        echo "  git fetch origin ${BASE_REF#origin/}"
        echo "  git rebase $BASE_REF   # or: git merge $BASE_REF"
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
