#!/usr/bin/env bash
# ABOUTME: Guards the divine-supporters client configuration for a shipping build.
# ABOUTME: The feature is always on; this checks the Worker URL it will talk to.
#
# The supporter feature is no longer behind a flag. `supporterApiBaseUrl` in
# mobile/lib/providers/supporter_providers.dart carries a compiled default, so
# an ordinary build ships a working supporter flow with no build configuration
# at all.
#
# Two ways that can still break, both silent without this check:
#   - Someone passes --dart-define=SUPPORTERS_API_BASE_URL= (empty). An empty
#     value makes supporterApiClientProvider return null, which hides the
#     supporter tile and redirects its route. That looks exactly like the
#     feature was never built.
#   - Someone edits the compiled default to something that is not an absolute
#     https URL.
#
# Runs as a Codemagic build step in every workflow that ships an artifact.
set -euo pipefail

providers="mobile/lib/providers/supporter_providers.dart"
[ -f "$providers" ] || providers="lib/providers/supporter_providers.dart"

# A stale FF_DIVINE_SUPPORTERS in the Codemagic environment group is now inert.
# Warn rather than fail: the build is correct, the leftover variable is not.
if [ -n "${FF_DIVINE_SUPPORTERS:-}" ]; then
  echo "WARNING: FF_DIVINE_SUPPORTERS is set to '${FF_DIVINE_SUPPORTERS}' but no" >&2
  echo "  longer does anything — the supporter feature is always on. Remove it" >&2
  echo "  from the Codemagic environment group to avoid implying it still" >&2
  echo "  controls something." >&2
fi

# An override is allowed (staging, QA), but it must be a usable https URL.
if [ -n "${SUPPORTERS_API_BASE_URL+x}" ] && [ -z "${SUPPORTERS_API_BASE_URL:-}" ]; then
  echo "ERROR: SUPPORTERS_API_BASE_URL is set but empty." >&2
  echo "  An empty value disables the supporter client entirely: the settings" >&2
  echo "  tile disappears and the route redirects. Unset it to use the" >&2
  echo "  compiled default, or give it an absolute https URL." >&2
  exit 1
fi

if [ -n "${SUPPORTERS_API_BASE_URL:-}" ]; then
  case "$SUPPORTERS_API_BASE_URL" in
    https://*) ;;
    *)
      echo "ERROR: SUPPORTERS_API_BASE_URL must be an absolute https URL." >&2
      echo "  Got: $SUPPORTERS_API_BASE_URL" >&2
      exit 1
      ;;
  esac
fi

# The compiled default is what ships when nothing overrides it, so it has to
# be a real https URL too.
if ! grep -q "defaultValue: 'https://" "$providers"; then
  echo "ERROR: $providers no longer carries an https compiled default for" >&2
  echo "  SUPPORTERS_API_BASE_URL. Without it every build ships with the" >&2
  echo "  supporter client disabled." >&2
  exit 1
fi

exit 0
