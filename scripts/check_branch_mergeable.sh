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
        # Files hold NUL-delimited output: shell variables cannot preserve NULs.
        # Extraction failures keep the genuine-conflict failure below.
        if [ -n "$PUSHED_FROM" ] && git -C "$REPO_ROOT" rev-parse --verify --quiet "${PUSHED_FROM}^{commit}" >/dev/null; then
            paths_dir=$(mktemp -d) || exit 1
            trap 'rm -rf "$paths_dir"' EXIT
            git -C "$REPO_ROOT" merge-tree --write-tree --name-only --no-messages -z "$BASE_REF" "$PUSHED_TIP" > "$paths_dir/conflicts"
            paths_status=$?
            if [ "$paths_status" -eq 1 ] && git -C "$REPO_ROOT" diff --no-renames --name-only -z "$PUSHED_FROM" "$PUSHED_TIP" > "$paths_dir/pushed"; then
                conflicts=()
                overlap=false
                # The first NUL-delimited field is the merge tree OID.
                {
                    IFS= read -r -d '' tree_oid
                    while IFS= read -r -d '' path; do
                        conflicts+=("$path")
                        while IFS= read -r -d '' pushed_path; do
                            if [ "$path" = "$pushed_path" ]; then overlap=true; fi
                        done < "$paths_dir/pushed"
                    done
                } < "$paths_dir/conflicts"
                if [ "${#conflicts[@]}" -gt 0 ] && [ "$overlap" = false ]; then
                    echo "Warning: branch has merge conflicts with ${BASE_REF#origin/}, outside the pushed changes:"
                    printf '  %q\n' "${conflicts[@]}"
                    echo "Continuing; resolve these conflicts before merging or final handoff."
                    exit 0
                fi
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
