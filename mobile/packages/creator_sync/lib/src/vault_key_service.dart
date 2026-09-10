// ABOUTME: Owns the per-account sync vault key lifecycle.
// ABOUTME: Wraps with NIP-44 to self; never forks when the relay is down.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:creator_sync/src/exceptions.dart';
import 'package:creator_sync/src/replaceable_event_order.dart';
import 'package:creator_sync/src/sync_clock.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

/// The `d` tag identifying the wrapped vault key event.
///
/// Shares the `divine:sync:` prefix with synced items but is NOT an item.
/// Item parsing matches the three item prefixes explicitly so this event
/// can never be reconciled as a phantom entry.
const String vaultKeyDTag = 'divine:sync:vault-key';

/// Device-local persistence for the unwrapped vault key.
///
/// Implemented in the app layer over secure storage; kept as an interface
/// so this package stays free of Flutter dependencies.
abstract interface class VaultKeyCache {
  /// Returns the base64 vault key for [pubkeyHex], or null if absent.
  Future<String?> read(String pubkeyHex);

  /// Persists [base64Key] for [pubkeyHex].
  Future<void> write(String pubkeyHex, String base64Key);
}

/// Obtains the account's sync vault key, creating it only when provably
/// absent.
class VaultKeyService {
  /// Creates a [VaultKeyService].
  VaultKeyService({
    required NostrSigner signer,
    required NostrClient client,
    required VaultKeyCache cache,
    Random? random,
    Future<void> Function(Duration)? settleDelay,
  }) : _signer = signer,
       _client = client,
       _cache = cache,
       _random = random ?? Random.secure(),
       _settleDelay = settleDelay ?? Future<void>.delayed;

  final NostrSigner _signer;
  final NostrClient _client;
  final VaultKeyCache _cache;
  final Random _random;

  /// Injected so tests can drive the read-back loop without real waits.
  final Future<void> Function(Duration) _settleDelay;

  static const int _keyLengthBytes = 32;

  /// How long to wait between read-back attempts after publishing a key.
  ///
  /// A relay that answers `OK` has accepted the event into an in-memory
  /// queue and commits it afterwards, so a query issued immediately after
  /// publishing can still legitimately come back empty.
  static const Duration settleInterval = Duration(milliseconds: 250);

  /// How many times to read a freshly published vault key back before
  /// giving up on it.
  ///
  /// Together with [settleInterval] this bounds the wait at five seconds,
  /// the same budget the two-device E2E harness already found sufficient
  /// against local_stack's relay.
  static const int settleAttempts = 20;

  Future<SecretKey>? _inFlight;

  /// Returns the vault key for the signed-in account.
  ///
  /// Resolution order: device cache, then the remote wrapped-key event,
  /// then generate-and-publish.
  ///
  /// Throws [VaultKeyUnavailableException] when signed out, when the
  /// remote lookup fails or cannot be confirmed empty, when the signer
  /// cannot unwrap an existing key, or when a decoded key is malformed.
  /// It deliberately does NOT generate a replacement in those cases:
  /// publishing a second vault key would replace the first and render
  /// every previously synced item permanently unreadable.
  ///
  /// Two guards keep that from happening, one per axis:
  ///
  /// * Within this process, concurrent calls share one in-flight
  ///   resolution, so two callers racing on a cold cache can't both
  ///   observe "no remote key" and each generate a distinct replacement.
  /// * Across devices, a freshly generated key is never cached until the
  ///   relays have served it back — see [_adoptSettled]. Two devices that
  ///   both saw an empty relay therefore converge on whichever event the
  ///   relays retained, instead of each keeping the one it minted.
  Future<SecretKey> obtain() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _obtain();
    _inFlight = future;
    // `future.whenComplete(...)` would return a *new* future that
    // re-propagates any error, and unawaited-discarding that new future
    // would leave it with no error listener at all — reported as an
    // unhandled async error. `then(onError:)` instead swallows the error
    // into a future that only ever completes successfully, so it's safe
    // to discard without ever surfacing an unhandled-error report. The
    // original [future] still carries its own result/error to the caller.
    unawaited(
      future.then(
        (_) => _forgetInFlight(future),
        onError: (_) => _forgetInFlight(future),
      ),
    );
    return future;
  }

  void _forgetInFlight(Future<SecretKey> future) {
    if (identical(_inFlight, future)) {
      _inFlight = null;
    }
  }

  Future<SecretKey> _obtain() async {
    final pubkey = await _signer.getPublicKey();
    if (pubkey == null || pubkey.isEmpty) {
      throw VaultKeyUnavailableException('no signed-in account');
    }

    final cached = await _cache.read(pubkey);
    if (cached != null) {
      return _decodeKey(cached);
    }

    final remote = await _fetchRemote(pubkey);
    if (remote != null) {
      return _adopt(pubkey, remote);
    }

    return _generateAndPublish(pubkey);
  }

  /// Unwraps [event] and makes it this device's vault key.
  Future<SecretKey> _adopt(String pubkey, Event event) async {
    final raw = await _unwrap(pubkey, event);
    // Decode and validate before touching the cache: a write here that
    // turned out to be garbage would poison the cache permanently, since
    // every later obtain() would then short-circuit on it.
    final key = _decodeKey(raw);
    await _cache.write(pubkey, raw);
    return key;
  }

  SecretKey _decodeKey(String base64Key) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(base64Key);
    } on FormatException catch (e) {
      throw VaultKeyUnavailableException(
        'vault key is not valid base64: ${e.message}',
      );
    }
    if (bytes.length != _keyLengthBytes) {
      throw VaultKeyUnavailableException(
        'vault key is ${bytes.length} bytes, expected $_keyLengthBytes',
      );
    }
    return SecretKey(bytes);
  }

  /// Returns the newest genuine vault key event for [pubkey], or `null`
  /// only when the relay pool was reachable and confirmed there is none.
  ///
  /// A query that never reached a relay or timed out cannot distinguish
  /// "no vault key exists" from "we could not ask" — treating the former
  /// as the answer would let [obtain] generate a second key over a first
  /// one it never actually saw. [NostrClient.queryEvents] discards that
  /// distinction (it collapses a failed lookup to an empty list), so this
  /// uses [NostrClient.queryEventsDetailed] and fails closed on
  /// `noRelays`/`timedOut` instead.
  Future<Event?> _fetchRemote(String pubkey) async {
    final ({
      List<Event> events,
      bool timedOut,
      bool noRelays,
      bool anyRelayAnswered,
      List<String> unsettledRelays,
    })
    result;
    try {
      result = await _client.queryEventsDetailed(
        [
          Filter(
            kinds: [EventKind.appSpecificData],
            authors: [pubkey],
            d: [vaultKeyDTag],
          ),
        ],
        // A local cache hit answers "did we see one before", not "does one
        // exist on the relay right now" — only a live relay answer counts
        // as confirmation the vault key is absent.
        useCache: false,
      );
    } catch (e) {
      throw VaultKeyUnavailableException(
        'could not determine whether a vault key exists: ${e.runtimeType}',
      );
    }

    if (result.noRelays || result.timedOut) {
      throw VaultKeyUnavailableException(
        'could not determine whether a vault key exists '
        '(noRelays: ${result.noRelays}, timedOut: ${result.timedOut})',
      );
    }

    // Relays are untrusted and can return anything for a broad kind+author
    // filter; only trust events that actually carry this event's own
    // kind, this account's pubkey, and this event's d tag before treating
    // one as the vault key — otherwise a newer foreign-author decoy
    // sharing the d tag would shadow the genuine key in the sort below.
    final matches = result.events
        .where(
          (event) =>
              event.kind == EventKind.appSpecificData &&
              event.pubkey == pubkey &&
              event.dTagValue == vaultKeyDTag,
        )
        .toList();
    // NIP-01 precedence, not created_at alone: two devices that raced to
    // mint a key can stamp the same second, and picking by relay response
    // order would let each keep a different one — the fork this whole
    // class exists to prevent.
    sortByNip01Precedence(matches);

    return matches.isEmpty ? null : matches.first;
  }

  Future<String> _unwrap(String pubkey, Event event) async {
    final String? raw;
    try {
      raw = await _signer.nip44Decrypt(pubkey, event.content);
    } catch (e) {
      throw VaultKeyUnavailableException(
        'signer refused to unwrap: ${e.runtimeType}',
      );
    }
    if (raw == null || raw.isEmpty) {
      throw VaultKeyUnavailableException('signer returned an empty key');
    }
    return raw;
  }

  Future<SecretKey> _generateAndPublish(String pubkey) async {
    final bytes = Uint8List.fromList(
      List<int>.generate(_keyLengthBytes, (_) => _random.nextInt(256)),
    );
    final raw = base64Encode(bytes);

    final String? wrapped;
    try {
      wrapped = await _signer.nip44Encrypt(pubkey, raw);
    } catch (e) {
      throw VaultKeyUnavailableException(
        'signer refused to wrap: ${e.runtimeType}',
      );
    }
    if (wrapped == null || wrapped.isEmpty) {
      throw VaultKeyUnavailableException('signer returned an empty wrap');
    }

    final event = Event(
      pubkey,
      EventKind.appSpecificData,
      const [
        ['d', vaultKeyDTag],
      ],
      wrapped,
      createdAt: SyncClock.nowSeconds(),
    );

    final signed = await _signer.signEvent(event);
    if (signed == null) {
      throw VaultKeyUnavailableException('signer refused to sign key event');
    }

    final result = await _client.publishEvent(signed);
    if (!result.isSuccess) {
      throw VaultKeyUnavailableException(
        'vault key event was not accepted by any relay',
      );
    }

    return _adoptSettled(pubkey);
  }

  /// Reads the vault key back off the relays after publishing one, and
  /// adopts whichever event they actually retained.
  ///
  /// Caching the key just minted would be wrong even though this device
  /// published it. A second device with a cold cache can query at the same
  /// moment, get the same genuine "no vault key" answer, and publish its
  /// own — and since these are addressable events, the relays keep exactly
  /// one of the two. The device whose key lost would go on sealing every
  /// item under a key no other device can open, and would never find out,
  /// because from then on [obtain] short-circuits on its own cache. Reading
  /// back first makes both devices converge on the retained event before
  /// either one seals anything.
  ///
  /// [NostrClient.publishEvent] resolves once the pool accepted the frame,
  /// and Divine's relay commits to storage after acknowledging, so the
  /// first read-back can legitimately return nothing; it is retried up to
  /// [settleAttempts] times [settleInterval] apart.
  ///
  /// Throws [VaultKeyUnavailableException] when the read-back never
  /// produces a usable key — the relays stayed empty, became unreachable,
  /// or returned an event this signer cannot unwrap. Failing here is safe
  /// precisely because nothing was cached: no item was sealed under the
  /// discarded key, so a later [obtain] can find the published event and
  /// adopt it, or mint again from scratch, without orphaning anything.
  Future<SecretKey> _adoptSettled(String pubkey) async {
    for (var attempt = 0; attempt < settleAttempts; attempt++) {
      final settled = await _fetchRemote(pubkey);
      if (settled != null) return _adopt(pubkey, settled);
      if (attempt < settleAttempts - 1) {
        await _settleDelay(settleInterval);
      }
    }
    throw VaultKeyUnavailableException(
      'published vault key did not come back from the relays within '
      '$settleAttempts attempts',
    );
  }
}
