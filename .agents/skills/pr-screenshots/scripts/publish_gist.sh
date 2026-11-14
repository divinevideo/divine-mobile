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
for shot in "$@"; do
  cp "$shot" "$WORK/images/"
  # Simulator shots are ~1200px wide; 600px keeps the PR readable and the gist small.
  sips --resampleWidth 600 "$WORK/images/$(basename "$shot")" > /dev/null
done

if $DRY_RUN; then
  for shot in "$WORK"/images/*.png; do echo "<img src=\"file://$shot\" width=\"240\">"; done
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

OWNER=$(gh api user --jq .login)
git clone -q "https://gist.github.com/$GIST_ID.git" "$WORK/gist"
cp "$WORK"/images/*.png "$WORK/gist/"
(cd "$WORK/gist" && git add ./*.png)
git -C "$WORK/gist" commit -q -m "Add screenshots"
# Git alone has no login for gist.github.com; use gh's.
git -C "$WORK/gist" -c credential.helper= -c credential.helper='!gh auth git-credential' push -q

for shot in "$WORK"/images/*.png; do
  file=$(basename "$shot")
  url="https://gist.githubusercontent.com/$OWNER/$GIST_ID/raw/$file"
  status=$(curl -s -o /dev/null -w '%{http_code}' -L "$url")
  [ "$status" = "200" ] || fail "$url answered $status"
  echo "<img src=\"$url\" width=\"240\">"
done
