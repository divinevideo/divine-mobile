import 'dart:convert';
import 'dart:math' as math;

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-owned badge decisions, encrypted to self using NIP-44/NIP-78.
///
/// Explicit false decisions preserve Undo when an older installation migrates
/// a local dismissal. The complete event is cached so acknowledged writes
/// survive relay indexing delays, including after restarting the app.
class BadgeDismissalSync {
  BadgeDismissalSync({
    required NostrClient client,
    required SharedPreferences preferences,
    required NostrSigner Function() signer,
  }) : _client = client,
       _preferences = preferences,
       _signer = signer;

  static const _dTag = 'divine:badge-dismissals';
  final NostrClient _client;
  final SharedPreferences _preferences;
  final NostrSigner Function() _signer;
  Future<void> _pending = Future<void>.value();

  Future<Set<String>> load(String pubkey, Set<String> local) =>
      _serialize(() => _reconcile(pubkey, local));

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
    // Keep later operations running after an earlier failure; its caller
    // still receives the original error through result.
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
      throw StateError('Badge dismissal signer does not match the account');
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
      throw StateError('Cannot sync badge decisions without a complete read');
    }

    final cachedJson = _preferences.getString(_cacheKey(pubkey));
    final cached = cachedJson == null
        ? null
        : Event.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
    final candidates =
        [
            ...result.events,
            if (cached != null) cached,
          ].where((event) => _belongsTo(event, pubkey)).toList()
          ..sort(_compareNewestFirst);
    final latest = candidates.isEmpty ? null : candidates.first;
    final decisions = latest == null
        ? <String, bool>{}
        : await _decode(signer, pubkey, latest);

    var changed = false;
    for (final legacy in local) {
      if (!decisions.containsKey(legacy)) {
        decisions[legacy] = true;
        changed = true;
      }
    }
    if (coordinate != null && decisions[coordinate] != hidden) {
      // Restoring an award never dismissed is a no-op.
      if (hidden! || decisions.containsKey(coordinate)) {
        decisions[coordinate] = hidden;
        changed = true;
      }
    }

    if (changed && complete) {
      final content = await signer.nip44Encrypt(
        pubkey,
        jsonEncode({'version': 1, 'decisions': decisions}),
      );
      if (content == null || content.isEmpty) {
        throw StateError('Could not encrypt badge decisions');
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event(
        pubkey,
        EventKind.appSpecificData,
        [
          ['d', _dTag],
        ],
        content,
        createdAt: math.max(now, (latest?.createdAt ?? 0) + 1),
      );
      final signed = await signer.signEvent(event);
      if (signed == null || !_belongsTo(signed, pubkey)) {
        throw StateError('Could not sign badge decisions');
      }
      final outcome = await _client.publishEventAwaitOk(signed);
      if (!outcome.acceptedByAny) {
        throw StateError('No relay confirmed the badge decisions');
      }
      await _cache(pubkey, signed);
    } else if (latest != null) {
      await _cache(pubkey, latest);
    }
    return {
      for (final entry in decisions.entries)
        if (entry.value) entry.key,
    };
  }

  Future<Map<String, bool>> _decode(
    NostrSigner signer,
    String pubkey,
    Event event,
  ) async {
    final plaintext = await signer.nip44Decrypt(pubkey, event.content);
    if (plaintext == null) {
      throw StateError('Could not decrypt badge decisions');
    }
    final payload = jsonDecode(plaintext);
    if (payload is! Map<String, dynamic> ||
        payload['version'] != 1 ||
        payload['decisions'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid badge decisions');
    }
    final decisions = payload['decisions'] as Map<String, dynamic>;
    if (decisions.values.any((value) => value is! bool)) {
      throw const FormatException('Invalid badge decision');
    }
    return decisions.cast<String, bool>();
  }

  Future<void> _cache(String pubkey, Event event) async {
    if (!await _preferences.setString(_cacheKey(pubkey), jsonEncode(event))) {
      throw StateError('Could not save badge decisions');
    }
  }

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
