import 'dart:convert';
import 'dart:math' as math;

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// An expected failure to synchronize private badge settings.
class BadgeDismissalSyncException implements Exception {
  const BadgeDismissalSyncException(this.message);
  final String message;

  @override
  String toString() => 'BadgeDismissalSyncException: $message';
}

typedef _Decision = ({bool hidden, int updatedAt});

/// Account-owned badge decisions, encrypted to self using NIP-44/NIP-78.
///
/// Per-badge timestamps let devices reconcile concurrent snapshots, including
/// undos. The signed cache preserves acknowledged decisions across restarts
/// and relay indexing delays; it must not expire while a relay is behind.
class BadgeDismissalSync {
  BadgeDismissalSync({
    required NostrClient client,
    required SharedPreferences preferences,
    required NostrSigner Function() signer,
  }) : _client = client,
       _preferences = preferences,
       _signer = signer;

  static const _dTag = 'divine:badge-dismissals';
  static const _decodedEventLimit = 8;
  final NostrClient _client;
  final SharedPreferences _preferences;
  final NostrSigner Function() _signer;
  final _decoded = <String, Map<String, _Decision>>{};
  Future<void> _pending = Future<void>.value();

  Future<Set<String>> load(String pubkey, Set<String> local) =>
      _serialize(() async {
        try {
          return await _reconcile(pubkey, local);
        } on Object catch (_) {
          // Never log decrypted settings or remote payloads. A read failure
          // must not prevent viewing badges or overwrite unreadable state.
          Log.warning(
            'Badge decisions unavailable; retaining local choices',
            name: 'BadgeDismissalSync',
            category: LogCategory.relay,
          );
          return local;
        }
      });

  /// Mutations require a complete readable snapshot and relay confirmation.
  /// An offline or refused mutation leaves the previous choice intact.
  Future<Set<String>> setHidden(
    String pubkey,
    Set<String> local,
    String coordinate, {
    required bool hidden,
  }) => _serialize(
    () => _reconcile(pubkey, local, coordinate: coordinate, hidden: hidden),
  );

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Set<String>> _reconcile(
    String pubkey,
    Set<String> local, {
    String? coordinate,
    bool? hidden,
  }) async {
    final signer = _signer();
    if (await signer.getPublicKey() != pubkey) {
      throw const BadgeDismissalSyncException('Signer does not match account');
    }
    final result = await _client.queryEventsDetailed(
      [
        Filter(
          authors: [pubkey],
          kinds: [EventKind.appSpecificData],
          d: [_dTag],
        ),
      ],
      useCache: false,
      requireAllRelaysSettled: true,
    );
    final complete = !result.noRelays && !result.timedOut;
    if (!complete && coordinate != null) {
      throw const BadgeDismissalSyncException(
        'Incomplete badge decisions read',
      );
    }

    final cachedJson = _preferences.getString(_cacheKey(pubkey));
    final cached = cachedJson == null
        ? const <Event>[]
        : (jsonDecode(cachedJson) as List<dynamic>).map(
            (value) => Event.fromJson(value as Map<String, dynamic>),
          );
    final candidates = {
      for (final event in [...result.events, ...cached])
        if (_belongsTo(event, pubkey)) event.id: event,
    }.values.toList()..sort(_compareNewestFirst);
    final latest = candidates.isEmpty ? null : candidates.first;
    final decisions = <String, _Decision>{
      // Old local dismissals have no timestamp. A known account decision,
      // including an undo, takes precedence over this one-time migration.
      for (final legacy in local) legacy: (hidden: true, updatedAt: 0),
    };
    Map<String, _Decision>? latestDecisions;
    final snapshots = <String, Map<String, _Decision>>{};
    for (final event in candidates) {
      final entries = await _decode(signer, pubkey, event);
      latestDecisions ??= entries;
      snapshots[event.id] = entries;
      _merge(decisions, entries);
    }

    if (coordinate != null && decisions[coordinate]?.hidden != hidden) {
      if (hidden! || decisions.containsKey(coordinate)) {
        decisions[coordinate] = (
          hidden: hidden,
          updatedAt: math.max(
            DateTime.now().millisecondsSinceEpoch,
            (decisions[coordinate]?.updatedAt ?? 0) + 1,
          ),
        );
      }
    }

    if (complete && !_sameDecisions(decisions, latestDecisions ?? const {})) {
      final signed = await _publish(signer, pubkey, decisions, latest);
      await _cache(pubkey, [signed]);
      _remember(signed.id, decisions);
    } else if (latest != null) {
      // An incomplete read cannot publish a consolidated snapshot. Retain
      // each signed source needed for a current decision, including undos.
      final retained = <Event>[latest];
      final missing = decisions.keys.toSet();
      for (final event in candidates) {
        final contributed = snapshots[event.id]!.entries
            .where(
              (entry) =>
                  missing.contains(entry.key) &&
                  decisions[entry.key] == entry.value,
            )
            .map((entry) => entry.key)
            .toList();
        if (contributed.isEmpty) continue;
        if (event.id != latest.id) retained.add(event);
        missing.removeAll(contributed);
      }
      await _cache(pubkey, retained);
    }
    return {
      for (final entry in decisions.entries)
        if (entry.value.hidden) entry.key,
    };
  }

  Future<Event> _publish(
    NostrSigner signer,
    String pubkey,
    Map<String, _Decision> decisions,
    Event? latest,
  ) async {
    final content = await signer.nip44Encrypt(
      pubkey,
      jsonEncode({
        'version': 1,
        'decisions': {
          for (final entry in decisions.entries)
            entry.key: {
              'hidden': entry.value.hidden,
              'updated_at': entry.value.updatedAt,
            },
        },
      }),
    );
    if (content == null || content.isEmpty) {
      throw const BadgeDismissalSyncException('Could not encrypt decisions');
    }
    final event = Event(
      pubkey,
      EventKind.appSpecificData,
      [
        ['d', _dTag],
      ],
      content,
      createdAt: math.max(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        (latest?.createdAt ?? 0) + 1,
      ),
    );
    final expectedId = event.id;
    final signed = await signer.signEvent(event);
    if (signed == null ||
        signed.id != expectedId ||
        !_belongsTo(signed, pubkey)) {
      throw const BadgeDismissalSyncException('Could not sign decisions');
    }
    final outcome = await _client.publishEventAwaitOk(signed);
    if (!outcome.acceptedByAny) {
      throw const BadgeDismissalSyncException('No relay confirmed decisions');
    }
    return signed;
  }

  Future<Map<String, _Decision>> _decode(
    NostrSigner signer,
    String pubkey,
    Event event,
  ) async {
    final known = _decoded[event.id];
    if (known != null) return known;
    final plaintext = await signer.nip44Decrypt(pubkey, event.content);
    if (plaintext == null) {
      throw const BadgeDismissalSyncException('Could not decrypt decisions');
    }
    final Object? payload;
    try {
      payload = jsonDecode(plaintext);
    } on FormatException {
      throw const FormatException('Invalid badge decisions');
    }
    if (payload is! Map<String, dynamic> ||
        payload['version'] != 1 ||
        payload['decisions'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid badge decisions');
    }
    final decisions = <String, _Decision>{};
    for (final entry
        in (payload['decisions'] as Map<String, dynamic>).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic> ||
          value['hidden'] is! bool ||
          value['updated_at'] is! int ||
          (value['updated_at'] as int) < 0) {
        throw const FormatException('Invalid badge decision');
      }
      decisions[entry.key] = (
        hidden: value['hidden'] as bool,
        updatedAt: value['updated_at'] as int,
      );
    }
    _remember(event.id, decisions);
    return decisions;
  }

  void _remember(String id, Map<String, _Decision> decisions) {
    _decoded[id] = Map.of(decisions);
    if (_decoded.length > _decodedEventLimit) {
      _decoded.remove(_decoded.keys.first);
    }
  }

  Future<void> _cache(String pubkey, List<Event> events) async {
    if (!await _preferences.setString(_cacheKey(pubkey), jsonEncode(events))) {
      throw const BadgeDismissalSyncException('Could not save decisions');
    }
  }

  static void _merge(
    Map<String, _Decision> target,
    Map<String, _Decision> source,
  ) {
    for (final entry in source.entries) {
      final previous = target[entry.key];
      final next = entry.value;
      // Concurrent writes tie deterministically: an undo wins a timestamp tie.
      if (previous == null ||
          next.updatedAt > previous.updatedAt ||
          (next.updatedAt == previous.updatedAt && !next.hidden)) {
        target[entry.key] = next;
      }
    }
  }

  static bool _sameDecisions(
    Map<String, _Decision> left,
    Map<String, _Decision> right,
  ) =>
      left.length == right.length &&
      left.entries.every((entry) => right[entry.key] == entry.value);

  static String _cacheKey(String pubkey) => 'badge_dismissal_event_$pubkey';

  static bool _belongsTo(Event event, String pubkey) =>
      event.pubkey == pubkey &&
      event.kind == EventKind.appSpecificData &&
      event.dTagValue == _dTag &&
      event.isValid &&
      event.isSigned;

  static int _compareNewestFirst(Event left, Event right) {
    final timestamp = right.createdAt.compareTo(left.createdAt);
    return timestamp != 0 ? timestamp : left.id.compareTo(right.id);
  }
}
