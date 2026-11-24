#!/usr/bin/env bash
# Moves Flutter's built CanvasKit directory under canvaskit/<engineRevision>/
# and rewrites build/web/flutter_bootstrap.js to point canvasKitBaseUrl at that
# versioned path.
#
# mobile/web/_headers serves /canvaskit/* and /*.wasm with
# `max-age=31536000, immutable`. Without the engine revision in the URL, a
# returning browser keeps the previous Flutter release's canvaskit.js /
# canvaskit.wasm next to a newly deployed main.dart.js for up to a year.
#
# Local `flutter run` and plain `flutter build web` keep using unversioned
# `canvaskit/` from mobile/web/flutter_bootstrap.js; CI and deploy workflows
# invoke this script before uploading to Cloudflare Pages.
set -euo pipefail

site_dir="${1:-build/web}"
bootstrap="$site_dir/flutter_bootstrap.js"
canvaskit_dir="$site_dir/canvaskit"

if [ ! -f "$bootstrap" ]; then
  echo "❌ $bootstrap does not exist. Build the web site before running this script."
  exit 1
fi

if [ ! -d "$canvaskit_dir" ]; then
  echo "❌ $canvaskit_dir does not exist. Build the web site before running this script."
  exit 1
fi

engine_revision="$(
  python3 - "$bootstrap" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    contents = handle.read()

match = re.search(r'"engineRevision"\s*:\s*"([0-9a-f]{40})"', contents)
if not match:
    sys.stderr.write(
        f"❌ Could not find a 40-hex engineRevision in {sys.argv[1]}.\n"
    )
    sys.exit(1)

print(match.group(1))
PY
)"

versioned_dir="$canvaskit_dir/$engine_revision"

if [ -f "$versioned_dir/canvaskit.js" ] && [ ! -f "$canvaskit_dir/canvaskit.js" ]; then
  echo "ℹ️  CanvasKit is already versioned at $versioned_dir."
else
  staging_dir="$site_dir/canvaskit.staging.$$"
  rm -rf "$staging_dir"
  mv "$canvaskit_dir" "$staging_dir"
  mkdir -p "$canvaskit_dir"
  mv "$staging_dir" "$versioned_dir"
fi

python3 - "$bootstrap" "$engine_revision" <<'PY'
import sys

bootstrap_path, engine_revision = sys.argv[1], sys.argv[2]
unversioned = "canvasKitBaseUrl: 'canvaskit/'"
versioned = f"canvasKitBaseUrl: 'canvaskit/{engine_revision}/'"

with open(bootstrap_path, encoding="utf-8") as handle:
    contents = handle.read()

if versioned in contents and unversioned not in contents:
    sys.exit(0)

count = contents.count(unversioned)
if count != 1:
    sys.stderr.write(
        f"❌ Expected exactly 1 occurrence of {unversioned!r} in "
        f"{bootstrap_path}, found {count}.\n"
    )
    sys.exit(1)

updated = contents.replace(unversioned, versioned, 1)
with open(bootstrap_path, "w", encoding="utf-8") as handle:
    handle.write(updated)
PY

if [ ! -f "$versioned_dir/canvaskit.js" ] || [ ! -f "$versioned_dir/canvaskit.wasm" ]; then
  echo "❌ Versioned CanvasKit files missing under $versioned_dir."
  exit 1
fi

if [ -f "$canvaskit_dir/canvaskit.js" ] || [ -f "$canvaskit_dir/canvaskit.wasm" ]; then
  echo "❌ Unversioned CanvasKit files still exist directly under $canvaskit_dir."
  exit 1
fi

echo "✅ Versioned CanvasKit under canvaskit/$engine_revision/ in $site_dir."
