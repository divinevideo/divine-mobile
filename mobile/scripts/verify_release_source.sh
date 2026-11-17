#!/usr/bin/env bash
set -euo pipefail
if [ -z "${RELEASE_EXPECTED_SHA:-}" ]; then
  echo 'Direct Codemagic native starts are unsupported: start iOS TestFlight Release or Android Store Release in GitHub Actions on main so scoped credentials refresh.' >&2
  exit 1
fi
head_sha=$(git rev-parse HEAD)
if [ -n "${CM_TAG:-}" ]; then
  if [[ ! "$CM_TAG" =~ ^release-candidate/([0-9a-f]{40})$ ]] || [ "${BASH_REMATCH[1]}" != "$head_sha" ]; then
    echo 'Refusing release: candidate tag does not match the exact source.' >&2
    exit 1
  fi
  git fetch --quiet origin refs/heads/main:refs/remotes/origin/main
  git merge-base --is-ancestor "$head_sha" origin/main || { echo 'Candidate is not reachable from main.' >&2; exit 1; }
elif [ "${CM_BRANCH:-}" != main ]; then
  echo 'Store releases require main or an immutable release candidate tag.' >&2
  exit 1
fi
if [ -n "${RELEASE_EXPECTED_SHA:-}" ]; then
  [[ "$RELEASE_EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]] && [ "$head_sha" = "$RELEASE_EXPECTED_SHA" ] || {
    echo 'Refusing release: source differs from RELEASE_EXPECTED_SHA.' >&2; exit 1;
  }
fi
