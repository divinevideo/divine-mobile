#!/usr/bin/env bash
# Fails the web build when any file in the built site exceeds the per-file size
# Cloudflare Pages accepts, and warns while one is merely close to it (#9269).
#
# Cloudflare Pages rejects an upload containing a file over 25 MiB. Nothing in
# `flutter build web` knows that, so before this guard existed the only signal
# was wrangler refusing a deploy. Preview uploads happen in a later workflow,
# while production builds and deploys only after a change reaches main. A
# change that inflated main.dart.js therefore shipped with every required PR
# check green, and app.divine.video silently stopped receiving updates for a
# day while every PR preview failed too. The required Mobile CI build now
# checks the production bundle on pull requests and merge-queue heads.
#
# `GoogleFonts.asMap()` is the shape that did it: a const map over the whole
# google_fonts catalogue, so referencing it retains all ~1700 font descriptors
# and defeats the package's per-font tree shaking. main.dart.js went from
# comfortably under the limit to 27.9 MiB.
#
# The warning threshold exists because the hard limit alone gives no notice:
# the bundle can creep to 24.9 MiB with CI green and then break on the next
# commit. There is no baseline file -- the ceiling is Cloudflare's, not ours.
#
# Under GitHub Actions the warning and the failure are also emitted as
# workflow-command annotations, so they show on the run summary and the pull
# request's checks tab rather than only inside the log of a green step. The
# largest file is always reported, so the trend is visible in every run.
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

# Prints a GitHub Actions annotation ($1 = warning|error, $2 = message) when
# running under Actions; a no-op elsewhere. `%` is the command escape, so it
# is encoded rather than left to be read as one.
annotate() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::$1 title=Web bundle file size::${2//%/%25}"
  fi
}

fail=0
warned=0
scanned=0
largest_size=0
largest_rel=""
file_list="$(mktemp)"
trap 'rm -f "$file_list"' EXIT

if ! find -L "$site_dir" -type f -print0 > "$file_list"; then
  echo "❌ Could not scan $site_dir for files."
  exit 1
fi

# `wc -c` rather than `stat`: the size flags differ between BSD and GNU stat,
# and GNU's `-f` reports the filesystem instead of erroring, so a portable
# invocation is easier to get right than to detect.
while IFS= read -r -d '' file; do
  scanned=$((scanned + 1))
  size="$(wc -c < "$file" | tr -d ' ')"
  rel="${file#"$site_dir"/}"
  if [ "$size" -gt "$largest_size" ]; then
    largest_size="$size"
    largest_rel="$rel"
  fi
  if [ "$size" -gt "$LIMIT_BYTES" ]; then
    message="$rel is $(mib "$size") ($size bytes), over Cloudflare Pages' $(mib "$LIMIT_BYTES") ($LIMIT_BYTES bytes) per-file limit."
    echo "❌ $message"
    annotate error "$message"
    fail=1
  elif [ "$size" -gt "$WARN_BYTES" ]; then
    message="$rel is $(mib "$size"), within 10% of the $(mib "$LIMIT_BYTES") per-file limit."
    echo "⚠️  $message"
    annotate warning "$message"
    warned=1
  fi
done < "$file_list"

if [ "$scanned" -eq 0 ]; then
  echo "❌ $site_dir contains no files. Build the web site before running this guard."
  exit 1
fi

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
else
  echo "✅ Every file in $site_dir is under Cloudflare Pages' $(mib "$LIMIT_BYTES") per-file limit."
fi
if [ -n "$largest_rel" ]; then
  echo "   Largest file: $largest_rel at $(mib "$largest_size"), $((largest_size * 100 / LIMIT_BYTES))% of the limit."
fi
