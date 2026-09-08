// ABOUTME: Post-sign-in discovery orchestration: NIP-65 relay discovery with
// ABOUTME: fallback + bootstrap kind:10002, and the kind-0 profile existence
// ABOUTME: check. Extracted from AuthService (#4741, repository tier).

import 'dart:async';

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback invoked when NIP-65 relay discovery completes with a non-empty
/// list. NostrService uses this to add discovered relays to the current
/// client without blocking app startup.
typedef UserRelaysDiscoveredCallback = void Function(
  String pubkey,
  List<String> relayUrls,
);

/// Callback invoked when AuthService wants to publish a bootstrap kind:10002
/// relay list on behalf of the user (because indexer discovery returned empty).
///
/// The event is already signed. The implementer publishes it through the
/// active [NostrClient] to [targetRelays] and reports success/failure via the
/// returned future.
typedef BootstrapRelayListCallback = Future<bool> Function(
  Event event,
  List<String> targetRelays,
);

/// SharedPreferences key prefix for the per-pubkey one-shot flag that records
/// whether we have already published a bootstrap kind:10002 on this device.
const _kBootstrapKind10002Prefix = 'bootstrap_kind10002_published_';

/// Upper bound on how long to wait for the signer when producing the
/// bootstrap kind:10002 event. If the signer does not respond within this
/// window (hung Keycast RPC, unreachable Amber, etc.) we abandon the publish
/// and leave the flag unset so the next login retries. See #3174 / #3162.
const _kBootstrapSignTimeout = Duration(seconds: 10);

/// Orchestrates the post-sign-in discovery flows AuthService runs
/// fire-and-forget: NIP-65 relay discovery (with safe-fallback connection and
/// the one-shot bootstrap kind:10002 self-publish when the user has no
/// published list) and the kind-0 profile existence check.
///
/// Extracted from `AuthService` (#4741) as a repository-tier collaborator.
/// The facade retains ownership of the session fields the results land in
/// (`_userRelays`, `_hasExistingProfile`) — results are delivered through the
/// [onUserRelays]/[onHasExistingProfile] write-back callbacks so external
/// consumers keep reading them off `AuthService`. Live session state is read
/// at execution time through tear-offs ([isSessionCurrent],
/// [currentIdentity]) rather than captured, so an account switch mid-flight
/// is observed exactly as before the extraction.
class RelayDiscoveryOrchestrator {
  RelayDiscoveryOrchestrator({
    required RelayDiscoveryService relayDiscoveryService,
    required String primaryRelayUrl,
    required bool Function(String? targetPubkey) isSessionCurrent,
    required NostrIdentity? Function() currentIdentity,
    required void Function(List<DiscoveredRelay> relays) onUserRelays,
    required void Function(bool hasProfile) onHasExistingProfile,
    required UserRelaysDiscoveredCallback? Function()
    userRelaysDiscoveredCallback,
    required BootstrapRelayListCallback? Function() bootstrapRelayListCallback,
    String? profileCheckIndexerUrl,
    WebSocketChannelFactory? profileCheckChannelFactory,
  }) : _relayDiscoveryService = relayDiscoveryService,
       _primaryRelayUrl = primaryRelayUrl,
       _isSessionCurrent = isSessionCurrent,
       _currentIdentity = currentIdentity,
       _onUserRelays = onUserRelays,
       _onHasExistingProfile = onHasExistingProfile,
       _userRelaysDiscoveredCallback = userRelaysDiscoveredCallback,
       _bootstrapRelayListCallback = bootstrapRelayListCallback,
       _profileCheckIndexerUrl = profileCheckIndexerUrl,
       _profileCheckChannelFactory = profileCheckChannelFactory;

  final RelayDiscoveryService _relayDiscoveryService;
  final String _primaryRelayUrl;
  final bool Function(String? targetPubkey) _isSessionCurrent;
  final NostrIdentity? Function() _currentIdentity;
  final void Function(List<DiscoveredRelay> relays) _onUserRelays;
  final void Function(bool hasProfile) _onHasExistingProfile;
  final UserRelaysDiscoveredCallback? Function() _userRelaysDiscoveredCallback;
  final BootstrapRelayListCallback? Function() _bootstrapRelayListCallback;
  final String? _profileCheckIndexerUrl;

  /// Test seam: injects the WebSocket transport used by [checkExistingProfile].
  /// Null in production, where [RelayBase] falls back to the platform socket.
  final WebSocketChannelFactory? _profileCheckChannelFactory;

  /// Discover user relays via NIP-65 using direct WebSocket to indexers.
  ///
  /// Always runs discovery (with 24h cache to avoid redundant indexer queries).
  /// Discovered relays are ADDED to the main client's existing connections,
  /// so user's manual relay edits are preserved (addRelay skips duplicates).
  /// The relays Divine advertises in its kind-10050 inbox list are also added
  /// when discovery succeeds, because the active session must read every relay
  /// it promises to senders. They are not reported through [onUserRelays].
  ///
  /// When discovery returns empty or fails (e.g. imported account that
  /// never published a kind 10002 list), [IndexerRelayConfig.safeFallbackRelays]
  /// is added to the client's connected pool so DM reachability degrades
  /// gracefully instead of leaving the client connected only to the Divine
  /// relay. The fallback set is NOT reported via [onUserRelays] — the facade's
  /// getter continues to report only the user's own published relays so
  /// embedded Nostr apps querying via the bridge see accurate data. See #2931.
  Future<void> discoverUserRelays(String npub, String? targetPubkey) async {
    try {
      final result = await _relayDiscoveryService.discoverRelays(npub);
      if (!_isSessionCurrent(targetPubkey)) {
        Log.info(
          'Ignoring relay discovery result for stale session',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );
        return;
      }

      if (result.success && result.hasRelays) {
        _onUserRelays(result.relays);

        Log.info(
          '✅ Discovered ${result.relays.length} user relays from '
          '${result.foundOnIndexer ?? "cache"}',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );

        // Log relay details
        for (final relay in result.relays) {
          Log.info(
            '  - ${relay.url} (read: ${relay.read}, write: ${relay.write})',
            name: 'RelayDiscoveryOrchestrator',
            category: LogCategory.auth,
          );
        }

        // Notify NostrService so it can add these relays to the current client
        final urls = result.relays.map((r) => r.url).toList();
        _userRelaysDiscoveredCallback()?.call(targetPubkey ?? npub, urls);
        connectToDmInboxRelays(targetPubkey ?? npub);
      } else {
        _onUserRelays([]);

        Log.warning(
          '⚠️ No relay list found for user on any indexer — '
          'connecting to safe DM-friendly fallback relay set',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );
        connectToFallbackRelays(targetPubkey ?? npub);
        await publishBootstrapRelayList();
      }
    } catch (e) {
      if (!_isSessionCurrent(targetPubkey)) {
        Log.info(
          'Ignoring relay discovery failure for stale session',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );
        return;
      }
      _onUserRelays([]);

      Log.error(
        '❌ Relay discovery failed: $e — '
        'connecting to safe DM-friendly fallback relay set',
        name: 'RelayDiscoveryOrchestrator',
        category: LogCategory.auth,
      );
      connectToFallbackRelays(targetPubkey ?? npub);
      await publishBootstrapRelayList();
    }
  }

  /// Publish a bootstrap kind:10002 relay list for the signed-in user when
  /// indexer discovery returned empty.
  ///
  /// Divine/Keycast-provisioned accounts are created without a published
  /// NIP-65 relay list, which leaves them invisible to the indexers the
  /// mobile client queries (`purplepag.es`, `user.kindpag.es`,
  /// `relay.nos.social`). That in turn degrades reachability for every
  /// downstream publish operation (profile save, likes, comments) because
  /// the client can only connect to the fallback relay set. This method
  /// self-publishes a minimal kind:10002 pointing at the current
  /// environment's primary relay (injected from [EnvironmentConfig.relayUrl])
  /// so subsequent logins on this or any other client can discover it.
  ///
  /// Guards:
  /// - fires at most once per (device, pubkey): tracked via
  ///   [SharedPreferences] flag `bootstrap_kind10002_published_<hexpubkey>`.
  /// - no-op if no current identity (read-only / unauthenticated sessions).
  /// - no-op if no bootstrap callback has been registered.
  /// - flag is set ONLY on callback success, so failures (signer unreachable,
  ///   publish rejected) remain retriable on next login.
  ///
  /// The proper server-side fix lives in divinevideo/keycast#94; this is a
  /// client-side safety net + backfill for pre-existing accounts. See
  /// divinevideo/divine-mobile#3174.
  Future<void> publishBootstrapRelayList() async {
    final identity = _currentIdentity();
    if (identity == null) {
      return;
    }
    final callback = _bootstrapRelayListCallback();
    if (callback == null) {
      return;
    }
    final pubkeyHex = identity.pubkey;
    final flagKey = '$_kBootstrapKind10002Prefix$pubkeyHex';

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(flagKey) ?? false) {
        return;
      }

      final unsigned = Event(
        pubkeyHex,
        EventKind.relayListMetadata,
        <List<String>>[
          <String>['r', _primaryRelayUrl],
        ],
        '',
      );

      // Cap how long we wait for the signer. A hung Keycast RPC would
      // otherwise block first-login past the existing NIP-65 discovery
      // timeout. On timeout we leave the flag unset so the next login retries.
      final Event? signed;
      try {
        signed = await identity
            .signEvent(unsigned)
            .timeout(_kBootstrapSignTimeout);
      } on TimeoutException {
        Log.warning(
          'Bootstrap kind:10002: signer timed out after '
          '${_kBootstrapSignTimeout.inSeconds}s — will retry on next login',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );
        return;
      }

      if (signed == null || signed.sig.isEmpty) {
        Log.warning(
          'Bootstrap kind:10002: signer returned null / unsigned — will retry '
          'on next login',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );
        return;
      }

      final targetRelays = <String>[
        _primaryRelayUrl,
        ...IndexerRelayConfig.defaultIndexers,
      ];

      final published = await callback(signed, targetRelays);
      if (!published) {
        Log.warning(
          'Bootstrap kind:10002: NostrClient reported no relay accepted the '
          'event — will retry on next login',
          name: 'RelayDiscoveryOrchestrator',
          category: LogCategory.auth,
        );
        return;
      }

      await prefs.setBool(flagKey, true);
      Log.info(
        '✅ Published bootstrap kind:10002 for ${pubkeyForLogs(pubkeyHex)} to '
        '${targetRelays.length} relays',
        name: 'RelayDiscoveryOrchestrator',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Bootstrap kind:10002 publish failed: $e — will retry on next login',
        name: 'RelayDiscoveryOrchestrator',
        category: LogCategory.auth,
      );
    }
  }

  /// Notify the NostrService callback to connect the client to
  /// [IndexerRelayConfig.safeFallbackRelays].
  ///
  /// Used when NIP-65 discovery returns empty or fails. Without this, the
  /// client stays connected only to the Divine relay, which silently
  /// breaks NIP-17 DM delivery for peers writing on other relays.
  ///
  /// Intentionally does NOT report via [onUserRelays]: that field semantically
  /// represents the user's *own* published relay list (kind 10002) and is
  /// surfaced to embedded Nostr apps via the bridge. The fallback set is a
  /// reachability mechanism, not a relay list the user has chosen. See #2931.
  void connectToFallbackRelays(String targetPubkey) {
    Log.info(
      'Fallback relays: '
      '${IndexerRelayConfig.safeFallbackRelays.join(', ')}',
      name: 'RelayDiscoveryOrchestrator',
      category: LogCategory.auth,
    );
    _userRelaysDiscoveredCallback()?.call(
      targetPubkey,
      IndexerRelayConfig.safeFallbackRelays,
    );
  }

  /// Adds the relays Divine advertises in its kind-10050 inbox list to the
  /// active pool even when the user has a separate kind-10002 list. These are
  /// automatic reachability connections, not the user's published relay list.
  void connectToDmInboxRelays(String targetPubkey) {
    _userRelaysDiscoveredCallback()?.call(
      targetPubkey,
      IndexerRelayConfig.dmInboxTaggedRelays,
    );
  }

  /// Check if user has an existing profile (kind 0) on indexer relays.
  ///
  /// Uses a direct WebSocket connection to an indexer relay (purplepag.es
  /// indexes kind 0 events) to check for existing profiles. The outcome is
  /// reported via [onHasExistingProfile]; a null [pubkeyHex] (no key
  /// container) reports `false` without any network traffic.
  Future<void> checkExistingProfile(String? pubkeyHex) async {
    if (pubkeyHex == null) {
      _onHasExistingProfile(false);
      return;
    }

    Log.info(
      '👤 Checking for existing profile (kind 0)...',
      name: 'RelayDiscoveryOrchestrator',
      category: LogCategory.auth,
    );

    try {
      final indexerUrl =
          _profileCheckIndexerUrl ?? IndexerRelayConfig.defaultIndexers.first;

      final relayStatus = RelayStatus(indexerUrl);
      final relay = RelayBase(
        indexerUrl,
        relayStatus,
        channelFactory: _profileCheckChannelFactory,
      );
      final completer = Completer<bool>();
      final subscriptionId = 'pc_${DateTime.now().millisecondsSinceEpoch}';

      relay.onMessage = (relay, json) async {
        if (json.isEmpty) return;
        final messageType = json[0] as String;
        if (messageType == 'EVENT' && json.length >= 3) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        } else if (messageType == 'EOSE') {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
      };

      final filter = <String, dynamic>{
        'kinds': <int>[0],
        'authors': <String>[pubkeyHex],
        'limit': 1,
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await relay.connect();
      if (!connected) {
        _onHasExistingProfile(false);
        return;
      }

      bool hasProfile;
      try {
        hasProfile = await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => false,
        );
        _onHasExistingProfile(hasProfile);
        await relay.send(<dynamic>['CLOSE', subscriptionId]);
      } finally {
        try {
          await relay.disconnect();
        } catch (_) {
          // Intentional no-op: best-effort cleanup of the throwaway
          // profile-check connection. The result has already been reported;
          // a failing disconnect must not mask it or fail the check.
        }
      }

      Log.info(
        '${hasProfile ? "✅" : "📝"} Profile check: '
        'hasExistingProfile=$hasProfile',
        name: 'RelayDiscoveryOrchestrator',
        category: LogCategory.auth,
      );
    } catch (e) {
      _onHasExistingProfile(false);

      Log.warning(
        '⚠️ Profile check failed: $e - assuming no existing profile',
        name: 'RelayDiscoveryOrchestrator',
        category: LogCategory.auth,
      );
    }
  }
}
