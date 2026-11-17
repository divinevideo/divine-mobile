#!/usr/bin/env bash
# Fetches and creates private Shorebird release provenance records.
set -euo pipefail

# Keep private ledger authentication separate from public release publishing.
if [ -n "${PROVENANCE_TOKEN:-}" ]; then
  export GH_TOKEN="$PROVENANCE_TOKEN"
fi

repository="${SHOREBIRD_PROVENANCE_REPOSITORY:-divinevideo/divine-release-provenance}"
command="${1:-}"
platform="${2:-}"
release_version="${3:-}"
local_path="${4:-}"

if [[ ! "$platform" =~ ^(android|ios)$ ]] || [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] || [ -z "$local_path" ]; then
  echo "usage: shorebird_provenance_store.sh fetch|create android|ios RELEASE_VERSION LOCAL_PATH" >&2
  exit 1
fi

remote_path="releases/$platform/$release_version.json"

case "$command" in
  fetch)
    commit_count=$(gh api --method GET "repos/$repository/commits" \
      -f "path=$remote_path" -f per_page=2 --jq length) || {
      echo "ERROR: could not verify private provenance history for $platform release $release_version" >&2
      exit 1
    }
    if [ "$commit_count" != "1" ]; then
      echo "ERROR: provenance history is not create-only for $platform release $release_version" >&2
      exit 1
    fi
    encoded=$(gh api "repos/$repository/contents/$remote_path" --jq .content) || {
      echo "ERROR: no private provenance exists for $platform release $release_version" >&2
      exit 1
    }
    printf '%s' "$encoded" | ruby -rbase64 -e 'print Base64.decode64(STDIN.read)' > "$local_path"
    chmod 600 "$local_path"
    ;;
  create)
    [ -f "$local_path" ] || { echo "ERROR: provenance file is missing: $local_path" >&2; exit 1; }
    if gh api "repos/$repository/contents/$remote_path" >/dev/null 2>&1; then
      echo "ERROR: provenance already exists for $platform release $release_version; refusing to overwrite it" >&2
      exit 1
    fi
    content=$(base64 < "$local_path" | tr -d '\n')
    gh api --method PUT "repos/$repository/contents/$remote_path" \
      -f message="Record $platform Shorebird release $release_version" \
      -f content="$content" >/dev/null
    ;;
  *)
    echo "usage: shorebird_provenance_store.sh fetch|create android|ios RELEASE_VERSION LOCAL_PATH" >&2
    exit 1
    ;;
esac
