// ABOUTME: Service for discovering user relays via NIP-65 (kind 10002)
// ABOUTME: Queries indexer relays via direct WebSocket to find relay lists
// ABOUTME: Caches discovered relay lists by npub for quick access

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Configuration for indexer relays used to discover user relay lists
class IndexerRelayConfig {
  /// Well-known indexer relays that maintain broad coverage of kind 10002 events
  /// These are specialized indexers that index and serve NIP-65 relay lists
  static const List<String> defaultIndexers = [
    'wss://purplepag.es', // Purple Pages - primary NIP-65 indexer
    'wss://user.kindpag.es', // Kind Pages - specialized user metadata indexer
    // NOTE: relay.damus.io was here but returns 503 sporadically, slowing
    // discovery. relay.nos.social actively crawls kind 10002 via
    // nos-event-service, giving it broad NIP-65 coverage.
    'wss://relay.nos.social',
  ];

  /// Additional relays named in the user's NIP-17 kind-10050 DM inbox list,
  /// on top of divine's own relay, so DM writes retain redundancy.
  static const List<String> dmInboxTaggedRelays = [
    'wss://nos.lol',
    'wss://relay.primal.net',
  ];

  /// Relays the user's NIP-17 kind-10050 DM inbox list is published to, on
  /// top of divine's own relay, so a third-party sender can find it.
  ///
  /// NIP-17 §Relays: clients "SHOULD spread them to as many relays as
  /// viable". Viable is measured, not assumed — [dmInboxDiscoveryRelays]
  /// includes the two DM-capable fallback relays plus purplepag.es, the indexer
  /// outbox-model clients query for a user's lists. `user.kindpag.es` and
  /// `relay.nos.social` are intentionally not used as discovery-only targets
  /// because they reject kind 10050 in the current relay measurements.
  ///
  /// Publishing here is best-effort and never gates the publish; see
  /// `DmRepository.ensureDmRelayListPublished`. Adding an entry means having
  /// checked it accepts kind 10050.
  static const List<String> dmInboxDiscoveryRelays = [
    ...dmInboxTaggedRelays,
    'wss://purplepag.es',
  ];

  /// Read-only indexers used to locate another user's kind-10050 DM inbox.
  ///
  /// This is intentionally not [dmInboxDiscoveryRelays]. That set is selected
  /// for accepting writes of Divine's own list; this set is selected for broad
  /// third-party read coverage. Purple Pages served the indexer-only inbox in
  /// the #7317 reproduction. Keep the set small because every entry is a cold
  /// connection on a DM send when it is not already pooled.
  static const List<String> dmInboxLookupRelays = ['wss://purplepag.es'];

  /// Safe fallback relay set for users without a discoverable NIP-65 relay
  /// list (kind 10002).
  ///
  /// Imported accounts that have never published a relay list — or whose
  /// relay list is hosted on a non-indexed relay — would otherwise stay
  /// connected only to the Divine relay, which makes NIP-17 DMs invisible
  /// to peers writing on other relays. This list is added to the user's
  /// connected pool whenever NIP-65 discovery returns empty or fails, so
  /// DM reachability degrades gracefully instead of silently breaking.
  ///
  /// These are general-purpose public Nostr relays that accept gift wraps
  /// (kind 1059). The set is intentionally small to bound bandwidth and
  /// keep first-connect latency reasonable. Users can still override this
  /// by adding their own relays via Settings → Relays.
  ///
  /// NOTE: relay.damus.io was removed from [defaultIndexers] because it
  /// returns 503 sporadically (see comment above). It is acceptable here
  /// because fallback connections are fire-and-forget — a single relay's
  /// transient 503 does not block the others, and [RelayPool.add] will
  /// retry on reconnect. If it proves persistently unreliable, replace it
  /// with another general-purpose relay that accepts kind 1059.
  ///
  /// See #2931.
  static const List<String> safeFallbackRelays = [
    'wss://relay.nos.social',
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net',
  ];
}

/// Represents a discovered relay with read/write permissions
class DiscoveredRelay {
  const DiscoveredRelay({
    required this.url,
    this.read = true,
    this.write = true,
  });

  factory DiscoveredRelay.fromJson(Map<String, dynamic> json) {
    return DiscoveredRelay(
      url: json['url'] as String,
      read: json['read'] as bool? ?? true,
      write: json['write'] as bool? ?? true,
    );
  }

  final String url;
  final bool read;
  final bool write;

  Map<String, dynamic> toJson() => {'url': url, 'read': read, 'write': write};

  @override
  String toString() => 'DiscoveredRelay(url: $url, read: $read, write: $write)';
}

/// Result of relay discovery operation
class RelayDiscoveryResult {
  const RelayDiscoveryResult({
    required this.success,
    required this.relays,
    this.errorMessage,
    this.foundOnIndexer,
  });

  factory RelayDiscoveryResult.success(
    List<DiscoveredRelay> relays,
    String? indexer,
  ) {
    return RelayDiscoveryResult(
      success: true,
      relays: relays,
      foundOnIndexer: indexer,
    );
  }

  factory RelayDiscoveryResult.failure(String error) {
    return RelayDiscoveryResult(
      success: false,
      relays: [],
      errorMessage: error,
    );
  }

  final bool success;
  final List<DiscoveredRelay> relays;
  final String? errorMessage;
  final String? foundOnIndexer;

  bool get hasRelays => relays.isNotEmpty;
}

/// Service for discovering and caching user relay lists via NIP-65.
///
/// Uses direct WebSocket connections to indexer relays - no NostrClient needed.
/// This eliminates temp client overhead and avoids relay pool / storage
/// side-effects that caused discovery to fail silently.
class RelayDiscoveryService {
  RelayDiscoveryService({List<String>? indexerRelays})
    : _indexerRelays = indexerRelays ?? IndexerRelayConfig.defaultIndexers;

  final List<String> _indexerRelays;
  static const String _cachePrefix = 'relay_discovery_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// SharedPreferences key for the relay-discovery cache owned by [npub].
  static String cacheStorageKey(String npub) => '$_cachePrefix$npub';

  /// Discover relay list for a given npub.
  ///
  /// Steps:
  /// 1. Check cache for recent discovery
  /// 2. If not cached, open direct WebSocket connections to indexer relays
  /// 3. Query for kind 10002 (NIP-65 relay list)
  /// 4. Parse relay list from event tags
  /// 5. Cache result for future use
  /// 6. Return list of relays with read/write flags
  ///
  /// Does NOT require a NostrClient - uses direct WebSocket connections to
  /// indexer relays for a clean, self-contained query.
  Future<RelayDiscoveryResult> discoverRelays(String npub) async {
    Log.info(
      '🔍 Starting relay discovery for ${pubkeyForLogs(npub)}',
      name: 'RelayDiscoveryService',
      category: LogCategory.auth,
    );

    // Check cache first (only use if non-empty)
    final cached = await _getCachedRelays(npub);
    if (cached != null && cached.isNotEmpty) {
      Log.info(
        '✅ Found ${cached.length} cached relays for ${pubkeyForLogs(npub)}',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return RelayDiscoveryResult.success(cached, 'cache');
    }

    // Query indexers for kind 10002 (NIP-65 relay list)
    try {
      final pubkeyHex = _npubToHex(npub);
      if (pubkeyHex == null) {
        return RelayDiscoveryResult.failure('Invalid npub format');
      }

      Log.info(
        '🔍 Querying ${_indexerRelays.length} indexers for kind 10002...',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );

      // Query all indexers in parallel - return on first non-empty result
      final result = await _queryFirstSuccess(pubkeyHex);

      if (result != null) {
        final (relays, indexerUrl) = result;
        Log.info(
          '✅ Found ${relays.length} relays on indexer: $indexerUrl',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );

        await _cacheRelays(npub, relays);
        return RelayDiscoveryResult.success(relays, indexerUrl);
      }

      // No relay list found on any indexer
      Log.warning(
        '⚠️ No relay list found for ${pubkeyForLogs(npub)} on any indexer',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return RelayDiscoveryResult.failure('No relay list found');
    } catch (e) {
      Log.error(
        '❌ Relay discovery failed: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return RelayDiscoveryResult.failure('Discovery failed: $e');
    }
  }

  /// Query all indexers in parallel and return the first non-empty result.
  ///
  /// Uses a [Completer] to resolve as soon as any indexer returns relays,
  /// rather than waiting for all indexers to finish. If all indexers return
  /// empty or fail, returns null.
  ///
  // Losing queries complete naturally (EOSE or 10s timeout). Each direct
  // query owns and disposes its RelayBase, so no connection survives that
  // bound.
  Future<(List<DiscoveredRelay>, String)?> _queryFirstSuccess(
    String pubkeyHex,
  ) async {
    final completer = Completer<(List<DiscoveredRelay>, String)?>();
    var pendingCount = _indexerRelays.length;

    for (final indexerUrl in _indexerRelays) {
      unawaited(
        queryIndexerDirect(indexerUrl, pubkeyHex)
            .then((relays) {
              if (!completer.isCompleted && relays.isNotEmpty) {
                completer.complete((relays, indexerUrl));
              } else {
                pendingCount--;
                if (pendingCount == 0 && !completer.isCompleted) {
                  completer.complete(null);
                }
              }
            })
            .catchError((Object e) {
              Log.warning(
                '⚠️ Failed to query indexer $indexerUrl: $e',
                name: 'RelayDiscoveryService',
                category: LogCategory.auth,
              );
              pendingCount--;
              if (pendingCount == 0 && !completer.isCompleted) {
                completer.complete(null);
              }
            }),
      );
    }

    return completer.future;
  }

  /// Query a specific indexer relay for kind 10002 event via direct WebSocket.
  ///
  /// Opens a direct WebSocket connection to the indexer, sends a REQ for the
  /// user's kind 10002 event, waits for EVENT/EOSE, and disconnects.
  /// This is self-contained - no NostrClient or relay pool needed.
  @visibleForTesting
  Future<List<DiscoveredRelay>> queryIndexerDirect(
    String indexerUrl,
    String pubkeyHex,
  ) async {
    Log.info(
      '  Querying indexer: $indexerUrl',
      name: 'RelayDiscoveryService',
      category: LogCategory.auth,
    );

    final relayStatus = RelayStatus(indexerUrl);
    final relay = RelayBase(indexerUrl, relayStatus);
    final completer = Completer<List<DiscoveredRelay>>();
    Event? newestEvent;
    final subscriptionId = 'rd_${DateTime.now().millisecondsSinceEpoch}';

    // Set up message handler before connecting
    relay.onMessage = (relay, json) async {
      if (json.isEmpty) return;

      final messageType = json[0] as String;

      if (messageType == 'EVENT' && json.length >= 3) {
        final eventJson = json[2] as Map<String, dynamic>;
        final event = _authenticRelayList(eventJson, indexerUrl, pubkeyHex);
        if (event != null &&
            (newestEvent == null || event.createdAt > newestEvent!.createdAt)) {
          newestEvent = event;
        }
      } else if (messageType == 'EOSE') {
        // All stored events received - parse and complete
        if (!completer.isCompleted) {
          final event = newestEvent;
          if (event == null) {
            completer.complete(<DiscoveredRelay>[]);
          } else {
            // Newest wins. Frames arrive in whatever order the indexer feels
            // like sending them, so the first one through the socket is not
            // the current relay list.
            completer.complete(_parseRelayListFromEvent(event));
          }
        }
      } else if (messageType == 'NOTICE') {
        Log.warning(
          '  NOTICE from $indexerUrl: ${json.length > 1 ? json[1] : ""}',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );
      }
    };

    try {
      // Add the REQ message to pending (will be sent when connection opens)
      final filter = <String, dynamic>{
        'kinds': <int>[10002],
        'authors': <String>[pubkeyHex],
        'limit': 1,
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      // Connect - this opens WebSocket and sends the pending REQ
      final connected = await relay.connect();
      if (!connected) {
        Log.warning(
          '  Failed to connect to $indexerUrl',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );
        return [];
      }

      // Wait for EOSE (or timeout)
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.warning(
            '  Timeout querying indexer: $indexerUrl',
            name: 'RelayDiscoveryService',
            category: LogCategory.auth,
          );
          return <DiscoveredRelay>[];
        },
      );

      // Send CLOSE before disconnecting. skipReconnect because the socket is
      // about to be torn down either way: without it, a CLOSE sent after the
      // indexer already dropped the connection walks the reconnect backoff,
      // holding this method — and the relay it owns — open for minutes.
      await relay.send(<dynamic>[
        'CLOSE',
        subscriptionId,
      ], skipReconnect: true);

      Log.info(
        '  Got ${result.length} relays from $indexerUrl',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );

      return result;
    } catch (e) {
      Log.error(
        '  Error querying indexer $indexerUrl: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return [];
    } finally {
      try {
        await relay.disconnect();
      } catch (_) {
        // Intentional no-op: best-effort teardown of the throwaway indexer
        // connection. The relay list has already been returned or logged
        // above; a failing disconnect must not mask that result.
      }
      // Its own guard: a throw from disconnect must not skip the dispose,
      // which is what releases the socket's stream subscriptions.
      try {
        relay.dispose();
      } catch (_) {
        // Intentional no-op: this is the last statement that touches the
        // relay, so there is nothing left to protect and no caller above
        // that could act on a dispose failure.
      }
    }
  }

  /// Returns [eventJson] as an [Event] when it is genuinely [pubkeyHex]'s
  /// kind-10002, and null otherwise.
  ///
  /// This query runs on a bare [RelayBase] with its own `onMessage`, so the
  /// frame never passes through `RelayPool`, so it bypasses the normal
  /// subscription filter and signature checks. Nothing else stands between an
  /// indexer and the relay pool: what comes back here is adopted via
  /// `NostrClient.addRelays` and
  /// then used for every subsequent read and write. The indexers queried are
  /// third-party public relays, so "it answered our REQ" is not evidence the
  /// answer is the list we asked for — the id, the signature, the author and
  /// the kind all have to be checked here (#6585).
  ///
  /// A frame that fails is logged and dropped, not reported: a broken or
  /// hostile indexer is not something the user can act on, and routing it to
  /// Crashlytics would bury real defects (see `error_handling.md`).
  Event? _authenticRelayList(
    Map<String, dynamic> eventJson,
    String indexerUrl,
    String pubkeyHex,
  ) {
    void reject(String reason) {
      Log.warning(
        '  Rejecting kind-10002 frame from $indexerUrl: $reason',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
    }

    final Event event;
    try {
      event = Event.fromJson(eventJson);
    } on Object catch (e) {
      reject('unparseable ($e)');
      return null;
    }

    if (event.kind != 10002) {
      reject('kind ${event.kind}, expected 10002');
      return null;
    }
    if (event.pubkey != pubkeyHex) {
      reject('authored by ${event.pubkey}, asked for $pubkeyHex');
      return null;
    }
    // `isValid` recomputes the id; `isSigned` verifies the Schnorr signature.
    // Both are needed — the id check alone only proves internal consistency,
    // which anyone can produce.
    if (!event.isValid) {
      reject('event id does not match its contents');
      return null;
    }
    if (!event.isSigned) {
      reject('missing or invalid signature');
      return null;
    }
    return event;
  }

  /// Parse relay list from kind 10002 event JSON.
  ///
  /// NIP-65 format:
  /// Tags: [["r", "<relay-url>"], ["r", "<relay-url>", "read"],
  ///        ["r", "<relay-url>", "write"]]
  @visibleForTesting
  List<DiscoveredRelay> parseRelayListFromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as List<dynamic>? ?? const [];
    return _parseRelayListFromTags([
      for (final tag in tags)
        if (tag is List) [for (final value in tag) value.toString()],
    ]);
  }

  List<DiscoveredRelay> _parseRelayListFromEvent(Event event) =>
      _parseRelayListFromTags(event.tags);

  /// Admits a kind-10002's relays: host policy, duplicate collapse, then cap.
  ///
  /// The list belongs to the user but reaches us through a third-party
  /// indexer, so it is admitted on remote-supplied terms: `wss://` only, and
  /// never a private, loopback or link-local target (#3362, #6585).
  ///
  /// Duplicates collapse before the cap is counted, or a host named
  /// [RelayListCaps.nip65] times would spend the whole budget and drop every
  /// genuine relay after it. Markers are OR-ed rather than first-wins: NIP-65
  /// marks a relay per `r` tag, so a host carrying a `read` row and a `write`
  /// row is read *and* write. Keeping the pair instead would be lossy anyway —
  /// `RelayListRepository._markerFor` takes the first match and republishes
  /// the host as `read`-only, and the app bridge takes the last.
  ///
  /// Both the fresh parse and the cached read go through here, so the same
  /// event cannot answer differently depending on which one served it.
  List<DiscoveredRelay> _admitRelayList(Iterable<DiscoveredRelay> candidates) {
    final byHost = <String, DiscoveredRelay>{};
    var loggedCap = false;

    for (final candidate in candidates) {
      final url = candidate.url;
      if (!isRemoteSuppliedRelayUrlAllowed(url)) {
        Log.warning(
          '  Skipping disallowed relay URL: $url',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );
        continue;
      }

      // Compare hosts the way the rest of the app does, so `wss://a.example`
      // and `wss://a.example/` are one relay rather than two cap slots.
      final key = normalizeRelayUrlForComparison(url) ?? url;
      final existing = byHost[key];
      if (existing != null) {
        byHost[key] = DiscoveredRelay(
          url: existing.url,
          read: existing.read || candidate.read,
          write: existing.write || candidate.write,
        );
        continue;
      }

      if (byHost.length >= RelayListCaps.nip65) {
        if (!loggedCap) {
          Log.warning(
            '  kind-10002 lists more than ${RelayListCaps.nip65} relays; '
            'ignoring additional hosts',
            name: 'RelayDiscoveryService',
            category: LogCategory.auth,
          );
          loggedCap = true;
        }
        continue;
      }

      byHost[key] = candidate;
    }

    return byHost.values.toList();
  }

  List<DiscoveredRelay> _parseRelayListFromTags(List<List<String>> eventTags) {
    final relays = _admitRelayList([
      for (final tag in eventTags)
        if (tag.length >= 2 && tag[0] == 'r')
          DiscoveredRelay(
            url: tag[1],
            read: tag.length <= 2 || tag[2] == 'read',
            write: tag.length <= 2 || tag[2] == 'write',
          ),
    ]);

    Log.info(
      '  Parsed ${relays.length} relays from kind 10002 event',
      name: 'RelayDiscoveryService',
      category: LogCategory.auth,
    );

    return relays;
  }

  /// Cache relay list for a user
  Future<void> _cacheRelays(String npub, List<DiscoveredRelay> relays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = cacheStorageKey(npub);

      final cacheData = {
        'relays': relays.map((r) => r.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      Log.warning(
        'Failed to cache relays: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
    }
  }

  /// Get cached relay list if not expired
  Future<List<DiscoveredRelay>?> _getCachedRelays(String npub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = cacheStorageKey(npub);

      final cacheJson = prefs.getString(cacheKey);
      if (cacheJson == null) return null;

      final cacheData = json.decode(cacheJson) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;

      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheExpiry.inMilliseconds) {
        return null;
      }

      final relaysList = cacheData['relays'] as List<dynamic>;
      final cached = relaysList
          .map((r) => DiscoveredRelay.fromJson(r as Map<String, dynamic>))
          .toList();
      // Re-admit on read, on the same remote-supplied terms as a fresh
      // discovery. The cache holds a list that arrived over the network and
      // survives for 24h, so filtering only on write would leave a day-long
      // window in which an entry written by an older build — or by a build
      // before this rule existed — is adopted unchecked (#6585). A pre-#6585
      // build wrote under this same key with no author check and no cap, so
      // these rows can still be an unauthenticated indexer's.
      return _admitRelayList(cached);
    } catch (e) {
      Log.warning(
        'Failed to read cached relays: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Clear cached relays for a user
  Future<void> clearCache(String npub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = cacheStorageKey(npub);
      await prefs.remove(cacheKey);
    } catch (e) {
      Log.warning(
        'Failed to clear relay cache: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
    }
  }

  /// Convert npub to hex format
  String? _npubToHex(String npub) {
    try {
      return Nip19.decode(npub);
    } catch (e) {
      Log.error(
        'Failed to decode npub: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return null;
    }
  }
}
