// ABOUTME: Helpers for resolving API base URLs from Nostr relay WebSocket URLs.
// ABOUTME: Includes pinned notification endpoint and relay identity helpers.

import 'package:nostr_client/nostr_client.dart' as nostr_client;
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;

/// The relay-URL admission policy lives in `nostr_sdk` so package-layer
/// callers can share it without importing app code, and is re-exported here
/// so app-layer callers keep a single import.
///
/// These are re-exports, not wrappers: a wrapper would be a second
/// declaration of the same name, and any library importing both this file and
/// the `nostr_sdk` barrel would fail with `ambiguous_import`.
export 'package:nostr_sdk/nostr_sdk.dart'
    show
        RelayListCaps,
        admitRemoteSuppliedRelays,
        isLoopbackHost,
        isPrivateOrLinkLocalHost,
        isRelayUrlAllowed,
        isRemoteSuppliedRelayUrlAllowed,
        isSignerCallbackRelayUrlAllowed;

const _divineRelayHost = 'relay.divine.video';

/// Relay hosts operated by Divine across all environments.
///
/// Matches the `EnvironmentConfig.relayUrl` hosts. Loopback (the `local`
/// environment relay) is covered separately via `isLoopbackHost`.
const _divineHostedRelayHosts = <String>{
  'relay.divine.video',
  'relay.staging.divine.video',
  'relay.poc.dvines.org',
};

/// True when [url]'s host is a Divine-operated relay host or a loopback host
/// (the `local` environment relay). Malformed URLs return false.
bool isDivineHostedRelayUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  if (host == null || host.isEmpty) return false;
  return _divineHostedRelayHosts.contains(host) ||
      nostr_sdk.isLoopbackHost(host);
}

/// True if [configuredRelays] includes a relay the user added beyond the
/// Divine-operated relays, loopback, and the app's own [defaultRelayUrls].
///
/// Every account — including a brand-new one — is auto-seeded with NIP-65
/// indexer relays and DM-reachability fallback relays. Those are app plumbing,
/// not relays the user chose, so they must be passed in via [defaultRelayUrls]
/// and excluded; otherwise a fresh Divine-only account would falsely register
/// as "using non-Divine relays".
bool usesUserChosenRelay(
  Iterable<String> configuredRelays, {
  required Iterable<String> defaultRelayUrls,
}) {
  final allowedHosts = <String>{
    ..._divineHostedRelayHosts,
    for (final url in defaultRelayUrls)
      if (Uri.tryParse(url)?.host.toLowerCase() case final String host
          when host.isNotEmpty)
        host,
  };
  return configuredRelays.any((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;
    if (allowedHosts.contains(host) || nostr_sdk.isLoopbackHost(host)) {
      return false;
    }
    return true;
  });
}

/// Normalizes a relay URL for identity comparison in UI state.
///
/// Delegates to the connection-layer normalizer so Settings identity checks
/// cannot drift from persisted relay identity.
String? normalizeRelayUrlForComparison(String url) =>
    nostr_client.normalizeRelayUrl(url);

/// True when [a] and [b] identify the same relay endpoint.
bool relayUrlsEquivalent(String a, String b) {
  final normalizedA = normalizeRelayUrlForComparison(a);
  final normalizedB = normalizeRelayUrlForComparison(b);
  return normalizedA != null &&
      normalizedB != null &&
      normalizedA == normalizedB;
}

/// Convert a relay WebSocket URL to an HTTP(S) base URL.
///
/// Examples:
/// - `wss://relay.divine.video` -> `https://relay.divine.video`
/// - `ws://localhost:8080` -> `http://localhost:8080`
String relayWsToHttpBase(String relayUrl) {
  if (relayUrl.startsWith('wss://')) {
    return relayUrl.replaceFirst('wss://', 'https://');
  }
  if (relayUrl.startsWith('ws://')) {
    return relayUrl.replaceFirst('ws://', 'http://');
  }
  return relayUrl;
}

/// Resolve a pinned REST API base URL from configured relays.
///
/// This never falls through to an arbitrary configured relay.
/// If the environment fallback host is configured,
/// that host wins first so staging/local builds do not drift to a persisted
/// production relay. If neither the fallback host nor pinned relay host is
/// configured, it returns the provided environment fallback instead.
String resolvePinnedApiBaseUrlFromRelays({
  required List<String> configuredRelays,
  required String fallbackBaseUrl,
  String pinnedRelayHost = _divineRelayHost,
}) {
  final fallbackHost = Uri.tryParse(fallbackBaseUrl)?.host.toLowerCase();
  if (fallbackHost != null && fallbackHost.isNotEmpty) {
    final fallbackRelay = configuredRelays.where((url) {
      final host = Uri.tryParse(url)?.host.toLowerCase();
      return host == fallbackHost;
    });
    if (fallbackRelay.isNotEmpty) {
      return relayWsToHttpBase(fallbackRelay.first);
    }
  }

  final pinnedRelay = configuredRelays.where((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == pinnedRelayHost.toLowerCase();
  });

  if (pinnedRelay.isEmpty) {
    return fallbackBaseUrl;
  }

  return relayWsToHttpBase(pinnedRelay.first);
}
