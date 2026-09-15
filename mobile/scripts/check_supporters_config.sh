#!/usr/bin/env bash
# ABOUTME: Guards the divine-supporters client configuration for a shipping build.
# ABOUTME: The feature is always on; this checks the Worker URL it will talk to.
#
# The supporter feature is not behind a flag. `supporterApiBaseUrl` in
# mobile/lib/providers/supporter_providers.dart carries a compiled default, and
# no build step passes a supporter `--dart-define`, so an ordinary build ships a
# working supporter flow with no configuration at all.
#
# What can still break, and why each is silent without this check:
#   - The compiled default stops being an absolute https URL, or grows a query
#     or fragment. SupporterApiClient resolves paths against this base, so a
#     query or fragment corrupts every request.
#   - Someone reintroduces `--dart-define=SUPPORTERS_API_BASE_URL=$VAR` for a
#     staging or QA build. Both that form and the Shorebird `ENV.fetch(name, '')`
#     path substitute an *empty string* when the variable is unset, and an empty
#     base URL makes supporterApiClientProvider null — the settings tile
#     disappears and the route redirects, which looks exactly like the feature
#     was never built.
#
# A leftover environment-group variable that no build passes to Dart is inert.
# It is reported, never fatal: a stale variable must not fail a store build.
#
# Runs as a Codemagic build step in every workflow that ships an artifact.
set -euo pipefail

providers="mobile/lib/providers/supporter_providers.dart"
[ -f "$providers" ] || providers="lib/providers/supporter_providers.dart"

fail=0

note_inert_variable() {
  echo "NOTE: $1 is set in this environment but no build step passes it to" >&2
  echo "  Dart, so it has no effect. Remove it from the environment group to" >&2
  echo "  avoid implying it still configures something." >&2
}

[ -n "${FF_DIVINE_SUPPORTERS:-}" ] && note_inert_variable FF_DIVINE_SUPPORTERS
[ -n "${SUPPORTERS_API_BASE_URL:-}" ] && note_inert_variable SUPPORTERS_API_BASE_URL

# Validate the compiled default: it is what every build actually ships.
default_url=$(sed -n "s/.*defaultValue: '\([^']*\)'.*/\1/p" "$providers" | head -1)

if [ -z "$default_url" ]; then
  echo "ERROR: $providers has no compiled default for SUPPORTERS_API_BASE_URL." >&2
  echo "  Without it, a build with no dart-define ships the supporter client" >&2
  echo "  disabled: no settings tile, and the route redirects." >&2
  exit 1
fi

case "$default_url" in
  https://*) ;;
  *)
    echo "ERROR: the compiled SUPPORTERS_API_BASE_URL default is not https." >&2
    echo "  Got: $default_url" >&2
    fail=1
    ;;
esac

case "$default_url" in
  *\?* | *"#"*)
    echo "ERROR: the compiled SUPPORTERS_API_BASE_URL default carries a query" >&2
    echo "  or fragment. SupporterApiClient resolves request paths against this" >&2
    echo "  base, so either one corrupts every request it makes." >&2
    echo "  Got: $default_url" >&2
    fail=1
    ;;
esac

exit "$fail"
