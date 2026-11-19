// ABOUTME: Publishes and fetches encrypted kind-30078 sync index events.
// ABOUTME: Filters foreign app-data events out of the shared kind.

import 'package:creator_sync/src/exceptions.dart';
import 'package:creator_sync/src/replaceable_event_order.dart';
import 'package:creator_sync/src/sync_cipher.dart';
import 'package:creator_sync/src/sync_clock.dart';
import 'package:creator_sync/src/sync_index_entry.dart';
import 'package:creator_sync/src/sync_item_ref.dart';
import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:nostr_sdk/signer/signer_failure.dart';
import 'package:unified_logger/unified_logger.dart';

/// One decrypted sync index event fetched from a relay.
@immutable
class RemoteSyncRecord {
  /// Creates a [RemoteSyncRecord].
  const RemoteSyncRecord({
    required this.ref,
    required this.entry,
    required this.createdAt,
  });

  /// Which item this record describes.
  final SyncItemRef ref;

  /// The decrypted payload.
  final SyncIndexEntry entry;

  /// The event's `created_at`, used for last-write-wins comparison.
  final int createdAt;
}

/// Reads and writes the encrypted sync index on Nostr.
class SyncIndexClient {
  /// Creates a [SyncIndexClient].
  SyncIndexClient({
    required NostrClient client,
    required NostrSigner signer,
    required SyncCipher cipher,
  }) : _client = client,
       _signer = signer,
       _cipher = cipher;

  final NostrClient _client;
  final NostrSigner _signer;
  final SyncCipher _cipher;

  /// How long a tombstone lives before relays may reap it (NIP-40).
  static const Duration tombstoneLifetime = Duration(days: 90);

  static const String _logName = 'SyncIndexClient';

  /// Runs a signer call, turning a signer that timed out or could not be
  /// reached into the [SyncIndexException] callers already treat as a
  /// transient failure to retry on the next trigger.
  ///
  /// A remote signer reports these by throwing rather than returning null,
  /// so without this a Keycast timeout or DNS failure escaped untyped and
  /// every caller's catch-all filed it as a crash. Anything else the signer
  /// throws propagates unchanged.
  Future<T> _askSigner<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Object catch (e) {
      if (!isUnreachableSignerFailure(e)) rethrow;
      throw SyncIndexException('signer unavailable: ${e.runtimeType}');
    }
  }

  /// Publishes [entry] as the addressable event for [ref].
  ///
  /// Returns the `created_at` stamped on the event so the caller can
  /// record the authoritative value rather than re-deriving it.
  ///
  /// Throws [SyncIndexException] when signing fails, the signer times out or
  /// cannot be reached, or no relay accepts.
  Future<int> publish(
    SyncItemRef ref,
    SyncIndexEntry entry, {
    int? latestKnownRemote,
  }) async {
    final pubkey = await _askSigner(_signer.getPublicKey);
    if (pubkey == null || pubkey.isEmpty) {
      throw SyncIndexException('cannot publish while signed out');
    }

    final createdAt = SyncClock.nowSeconds(
      latestKnownRemote: latestKnownRemote,
    );
    final tags = <List<String>>[
      ['d', ref.dTag],
      if (entry.deleted)
        ['expiration', '${createdAt + tombstoneLifetime.inSeconds}'],
    ];

    final event = Event(
      pubkey,
      EventKind.appSpecificData,
      tags,
      await _cipher.seal(entry.toPayloadJson()),
      createdAt: createdAt,
    );

    final signed = await _askSigner(() => _signer.signEvent(event));
    if (signed == null) {
      throw SyncIndexException('signer refused to sign ${ref.dTag}');
    }

    // publishEventAwaitOk, not publishEvent: the latter resolves once a
    // relay's socket took the frame, so an `OK false` — wrong kind for the
    // relay's allowlist, a clamped created_at, an oversized payload, a rate
    // limit — reads as success. The caller records applied state off this
    // result and then suppresses the retry while the hash matches, so a
    // publish counted here but refused by the relay never publishes again.
    final outcome = await _client.publishEventAwaitOk(signed);
    if (!outcome.acceptedByAny) {
      throw SyncIndexException('no relay accepted ${ref.dTag}');
    }
    return createdAt;
  }

  /// Fetches every known record of [kind] for the signed-in account.
  ///
  /// Pass [since] to fetch incrementally. Records that fail to decrypt or
  /// parse are skipped rather than aborting the whole reconcile — one bad
  /// event must not strand the rest of the library. This applies per item:
  /// if the *newest* event for a given item fails to decrypt or parse,
  /// that item is dropped from the result entirely for this fetch, even
  /// if an older, readable event for the same item also came back. This
  /// is a deliberate last-write-wins choice — falling back to an older
  /// record could resurrect an item the newest event tombstoned — but it
  /// means the caller cannot distinguish "no record" from "newest record
  /// unreadable".
  ///
  /// Throws [SyncIndexException] when signed out, the signer times out or
  /// cannot be reached, or the query fails.
  Future<List<RemoteSyncRecord>> fetch(SyncItemKind kind, {int? since}) async {
    final pubkey = await _askSigner(_signer.getPublicKey);
    if (pubkey == null || pubkey.isEmpty) {
      throw SyncIndexException('cannot fetch while signed out');
    }

    // Settled on every relay, or a relay still silent after the pool's
    // settle window or one that ended the read with CLOSED is dropped and
    // the rest reads as the whole library: reconcile would then publish
    // over records it never saw.
    final List<Event> events;
    try {
      final result = await _client.queryEventsDetailed([
        Filter(
          kinds: [EventKind.appSpecificData],
          authors: [pubkey],
          since: since,
        ),
      ], requireAllRelaysSettled: true);
      if (result.noRelays || result.timedOut) {
        throw SyncIndexException(
          'sync index query could not reach a relay '
          '(noRelays: ${result.noRelays}, timedOut: ${result.timedOut})',
        );
      }
      events = result.events;
    } on SyncIndexException {
      rethrow;
    } catch (e) {
      throw SyncIndexException('sync index query failed: ${e.runtimeType}');
    }

    // Relay filters cannot prefix-match d tags, and relays are untrusted:
    // a broad kind+author query can come back with events of the wrong
    // kind, a different author, or a d tag outside the creator-sync
    // allowlist (this package's own vault-key event, or app-specific data
    // any other app stores for this account under the same kind).
    // Trust only events that actually carry this event's own kind, this
    // account's pubkey, and an allowlisted d tag for [kind] before
    // treating one as a candidate; keep only the newest candidate per
    // item so an untrustworthy or stale decoy can never shadow the
    // genuine record.
    final newest = <SyncItemRef, Event>{};
    for (final event in events) {
      if (event.kind != EventKind.appSpecificData || event.pubkey != pubkey) {
        continue;
      }
      final ref = SyncItemRef.tryParse(event.dTagValue);
      if (ref == null || ref.kind != kind) continue;

      // NIP-01 precedence, not created_at alone: two devices editing the
      // same item can stamp the same second, and resolving that by relay
      // response order lets each device keep a different version and stay
      // disagreeing across every later reconcile.
      final existing = newest[ref];
      if (existing == null || replacesUnderNip01(event, existing)) {
        newest[ref] = event;
      }
    }

    final records = <RemoteSyncRecord>[];
    for (final entry in newest.entries) {
      final ref = entry.key;
      try {
        records.add(
          RemoteSyncRecord(
            ref: ref,
            entry: SyncIndexEntry.fromPayloadJson(
              await _cipher.open(entry.value.content),
            ),
            createdAt: entry.value.createdAt,
          ),
        );
      } on SyncDecryptException catch (e) {
        Log.warning(
          'skipping undecryptable sync record ${ref.dTag}: ${e.message}',
          name: _logName,
          category: LogCategory.relay,
        );
      } on FormatException catch (e) {
        Log.warning(
          'skipping malformed sync record ${ref.dTag}: ${e.message}',
          name: _logName,
          category: LogCategory.relay,
        );
      }
    }
    return records;
  }
}
