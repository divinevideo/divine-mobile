#!/usr/bin/env bash
# ABOUTME: Uploads screenshots to a new secret gist and prints <img> tags with raw URLs for a PR description.
# ABOUTME: Usage: bash publish_gist.sh [--dry-run] "<description>" shot1.png [shot2.png ...]
set -euo pipefail

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=true; shift; fi
DESCRIPTION="${1:?usage: publish_gist.sh [--dry-run] \"<description>\" shot.png ...}"
shift
[ "$#" -gt 0 ] || { echo "error: no screenshots given" >&2; exit 2; }

WORK=$(mktemp -d "${SCRATCH:?set SCRATCH to the scratch folder for this run, see SKILL.md}/gist.XXXXXX")
mkdir -p "$WORK/images"
# Files are copied flat by name, so a duplicate name would overwrite an
# earlier shot. APFS ignores case, so 01-Profile.png and 01-profile.png clash.
names=()
seen=" "
for shot in "$@"; do
  name=$(basename "$shot")
  [[ "$name" =~ ^[A-Za-z0-9._-]+\.png$ ]] \
    || { echo "error: $shot: name screenshots NN-state.png (letters, digits, . _ -)" >&2; exit 2; }
  folded=$(tr '[:upper:]' '[:lower:]' <<<"$name")
  case "$seen" in *" $folded "*) echo "error: two screenshots are named $name" >&2; exit 2 ;; esac
  seen="$seen$folded "
  names+=("$name")
  cp "$shot" "$WORK/images/$name"
  # Simulator shots are ~1200px wide; 600px keeps the PR readable and the gist small.
  sips --resampleWidth 600 "$WORK/images/$name" > /dev/null
done

if $DRY_RUN; then
  for name in "${names[@]}"; do echo "<img src=\"file://$WORK/images/$name\" width=\"240\">"; done
  exit 0
fi

printf '%s\n\nReal-app screenshots: iOS simulator, LOCAL Docker stack, throwaway accounts.\n' "$DESCRIPTION" > "$WORK/README.md"
GIST_URL=$(gh gist create "$WORK/README.md" --desc "$DESCRIPTION" | tail -1)
# Not GID: zsh reserves that name as a read-only integer.
GIST_ID=$(basename "$GIST_URL")
echo "GIST=$GIST_URL"

# From here a failure would strand a gist without images, and a rerun would
# create a second one, so delete it on the way out.
fail() {
  echo "error: $1" >&2
  if gh gist delete "$GIST_ID" --yes > /dev/null 2>&1; then
    echo "deleted the incomplete gist $GIST_ID" >&2
  else
    echo "could not delete gist $GIST_ID; delete it with: gh gist delete $GIST_ID --yes" >&2
  fi
  exit 1
}
trap 'fail "publishing stopped at line $LINENO"' ERR

git clone -q "https://gist.github.com/$GIST_ID.git" "$WORK/gist"
for name in "${names[@]}"; do cp "$WORK/images/$name" "$WORK/gist/"; done
git -C "$WORK/gist" add -- "${names[@]}"
# Anyone with an image URL can clone the gist, so commit as the account's
# noreply address rather than the local git name and email.
IDENTITY=$(gh api user --jq '"\(.login) \(.id)"')
LOGIN=${IDENTITY% *}
git -C "$WORK/gist" -c user.name="$LOGIN" -c user.email="${IDENTITY#* }+$LOGIN@users.noreply.github.com" \
  commit -q -m "Add screenshots"
# Git alone has no login for gist.github.com; use gh's.
git -C "$WORK/gist" -c credential.helper= -c credential.helper='!gh auth git-credential' push -q

# Print the tags only once every URL answers, so a failure never leaves tags
# pointing at the gist it just deleted.
tags=()
for name in "${names[@]}"; do
  # The API's raw_url carries the file's revision, so the image cannot change
  # under a reviewed PR. A URL built from the commit SHA answers 404.
  url=$(gh api "gists/$GIST_ID" --jq ".files[\"$name\"].raw_url")
  if [ -z "$url" ] || [ "$url" = "null" ]; then fail "gist $GIST_ID has no $name"; fi
  status=$(curl -s -o /dev/null -w '%{http_code}' -L --retry 3 --retry-delay 2 "$url")
  [ "$status" = "200" ] || fail "$url answered $status"
  tags+=("<img src=\"$url\" width=\"240\">")
done
printf '%s\n' "${tags[@]}"
