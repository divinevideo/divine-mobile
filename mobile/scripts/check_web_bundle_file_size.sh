#!/usr/bin/env bash
# Fails the web build when any file in the built site exceeds the per-file size
# Cloudflare Pages accepts, and warns while one is merely close to it (#9269).
#
# Cloudflare Pages rejects an upload containing a file over 25 MiB. Nothing in
# `flutter build web` knows that, so before this guard existed the only signal
# was wrangler refusing the deploy -- and that runs in a *separate* workflow
# after the build: on the PR-preview deploy (which needs the build artifact
# first) and on the production deploy (which runs on main, after merge). So a
# change that inflated main.dart.js shipped with every check green, and
# app.divine.video silently stopped receiving updates for a day while every PR
# preview failed too. Checking in the build job puts the failure on the PR that
# causes it.
#
# `GoogleFonts.asMap()` is the shape that did it: a const map over the whole
# google_fonts catalogue, so referencing it retains all ~1700 font descriptors
# and defeats the package's per-font tree shaking. main.dart.js went from
# comfortably under the limit to 27.9 MiB.
#
# The warning threshold exists because the hard limit alone gives no notice:
# the bundle can creep to 24.9 MiB with CI green and then break on the next
# commit. There is no baseline file -- the ceiling is Cloudflare's, not ours.
set -euo pipefail

# Cloudflare Pages' documented per-file limit.
readonly LIMIT_BYTES=$((25 * 1024 * 1024))
# Warn from 90% of the limit, so growth is visible before it blocks a deploy.
readonly WARN_BYTES=$((LIMIT_BYTES * 90 / 100))

site_dir="${1:-build/web}"

if [ ! -d "$site_dir" ]; then
  echo "❌ $site_dir does not exist. Build the web site before running this guard."
  exit 1
fi

mib() { awk -v b="$1" 'BEGIN { printf "%.1f MiB", b / 1048576 }'; }

fail=0
warned=0

# `wc -c` rather than `stat`: the size flags differ between BSD and GNU stat,
# and GNU's `-f` reports the filesystem instead of erroring, so a portable
# invocation is easier to get right than to detect.
while IFS= read -r file; do
  size="$(wc -c < "$file" | tr -d ' ')"
  rel="${file#"$site_dir"/}"
  if [ "$size" -gt "$LIMIT_BYTES" ]; then
    echo "❌ $rel is $(mib "$size"), over Cloudflare Pages' $(mib "$LIMIT_BYTES") per-file limit."
    fail=1
  elif [ "$size" -gt "$WARN_BYTES" ]; then
    echo "⚠️  $rel is $(mib "$size"), within 10% of the $(mib "$LIMIT_BYTES") per-file limit."
    warned=1
  fi
done < <(find "$site_dir" -type f)

if [ "$fail" -ne 0 ]; then
  echo
  echo "   Cloudflare Pages will reject this site, so the deploy that follows"
  echo "   this build cannot succeed. Shrink the file rather than raising the"
  echo "   limit -- it is Cloudflare's, not ours."
  echo
  echo "   For main.dart.js, the usual cause is a reference that defeats tree"
  echo "   shaking over a large generated package. Inspect what the bundle"
  echo "   retains with:"
  echo "     flutter build web --release --analyze-size"
  exit 1
fi

if [ "$warned" -ne 0 ]; then
  echo "✅ Every file in $site_dir is under Cloudflare Pages' $(mib "$LIMIT_BYTES") per-file limit, but see the warning above."
  exit 0
fi

echo "✅ Every file in $site_dir is under Cloudflare Pages' $(mib "$LIMIT_BYTES") per-file limit."
