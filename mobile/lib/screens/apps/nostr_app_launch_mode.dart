// ABOUTME: Decides whether a directory app opens in the system browser or the
// ABOUTME: in-app sandbox, and launches it accordingly.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Slugs of first-party apps that perform cross-origin login / OAuth
/// hand-offs and therefore cannot run inside the locked-down in-app
/// WebView sandbox — its origin allowlist blocks those navigations
/// (the verifier dead-ends at `login.divine.video` and the OAuth
/// providers). These open in the system browser instead.
///
/// Keyed by slug because the directory merges remote/cached entries over
/// preloaded ones by slug (see
/// `NostrAppDirectoryService._mergeWithPreloadedApps`), so the slug is the
/// identity that survives a remote override — a server-sent flag on the
/// preloaded entry would not. Both verifier spellings are accepted on
/// purpose: remote directory data and on-device caches may carry either
/// `verifier` or the older `verifyer`, and both resolve to the same worker.
/// The `verifyer`→`verifier` standardization is tracked in the verifier repo
/// (divinevideo/divine-identify-verification-service#16, #23); keep both here
/// regardless, since the alias is harmless and guards stale directory data.
const Set<String> kSystemBrowserAppSlugs = {'verifier', 'verifyer'};

/// Hosts the system-browser launch is allowed to open. The launch target
/// comes from directory JSON (`launch_url`), which a remote or cached entry
/// can override; pinning to these hosts stops a crafted entry from opening an
/// arbitrary URL under a trusted first-party tile. Both verifier spellings are
/// accepted for the same reason as [kSystemBrowserAppSlugs] — move the two
/// sets together.
const Set<String> _systemBrowserAppHosts = {
  'verifier.divine.video',
  'verifyer.divine.video',
};

/// Whether [app] must be opened in the system browser rather than the
/// in-app sandbox.
bool appRequiresSystemBrowser(NostrAppDirectoryEntry app) =>
    kSystemBrowserAppSlugs.contains(app.slug);

/// Whether [rawUrl] is a safe system-browser target: an `https` URL on a
/// pinned verifier host. Guards against a crafted directory `launch_url`.
@visibleForTesting
bool isAllowedSystemBrowserTarget(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  return uri != null &&
      uri.scheme == 'https' &&
      _systemBrowserAppHosts.contains(uri.host);
}

/// Opens [app] from the directory.
///
/// Apps that need cross-origin login/OAuth ([appRequiresSystemBrowser])
/// launch in the system browser, where cookies and provider redirects
/// work; everything else opens in the in-app sandbox. Shows a snackbar
/// when a system-browser launch fails or throws.
///
/// The directory entry points that call this are native-only — the Apps
/// Directory renders an unsupported message on web (`supportsNostrAppsSandbox`)
/// — so the system-browser branch always runs on a device, where
/// `LaunchMode.externalApplication` is correct.
Future<void> launchNostrApp(
  BuildContext context,
  NostrAppDirectoryEntry app,
) async {
  if (!appRequiresSystemBrowser(app)) {
    await context.push(
      NostrAppSandboxScreen.pathForAppId(app.id),
      extra: app,
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final errorText = context.l10n.relaySettingsCouldNotOpenBrowser;
  if (!isAllowedSystemBrowserTarget(app.launchUrl)) {
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(errorText, error: true),
    );
    return;
  }

  var launched = false;
  try {
    launched = await launchUrl(
      Uri.parse(app.launchUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (error) {
    UnifiedLogger.warning(
      'Failed to open ${app.name}: $error',
      name: 'launchNostrApp',
    );
  }
  if (!launched) {
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(errorText, error: true),
    );
  }
}
