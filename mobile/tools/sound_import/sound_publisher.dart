// ABOUTME: The maintainer's last step: signs the prepared sound events with the
// ABOUTME: publishing account's key and sends those the relays do not have yet.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nostr_sdk/event.dart';

import 'import_state.dart';

/// Reuses a cached signed event rather than creating a new event id on retry.
Map<String, dynamic> soundEventForPublish(
  Map<String, dynamic> unsigned,
  Map<String, dynamic>? cached, {
  required String expectedPubkey,
}) {
  if (cached == null) return unsigned;
  final unsignedHashes = fileHashesOf(unsigned['tags'] as List<dynamic>)
      .toList();
  final cachedHashes = fileHashesOf(cached['tags'] as List<dynamic>).toList();
  if (cached['pubkey'] != expectedPubkey ||
      unsignedHashes.length != 1 ||
      cachedHashes.length != 1 ||
      cachedHashes.single != unsignedHashes.single) {
    throw const FormatException(
      'Cached signed event does not match the publishing account and file. '
      'Use a separate work directory for a different account or import.',
    );
  }
  return cached;
}

/// Whether every full hash URL has a matching prepared record and upload server.
/// Pass the cached signed event when one exists, not its unsigned replacement.
bool isSoundPublishEligible(
  Map<String, dynamic> event,
  Iterable<ImportRecord> records, {
  required String expectedPubkey,
}) {
  final pubkey = event['pubkey'];
  if (pubkey != null && pubkey != '' && pubkey != expectedPubkey) return false;
  final tags = event['tags'] as List<dynamic>;
  final hashes = fileHashesOf(tags).toList();
  if (hashes.length != 1 ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(hashes.single)) {
    return false;
  }
  final sha = hashes.single;
  final urls = [
    for (final tag in tags.whereType<List<dynamic>>())
      if (tag.length >= 2 && tag[0] == 'url') tag[1],
  ];
  if (urls.isEmpty) return false;
  return urls.every(
    (url) => records.any(
      (record) =>
          record.status == ImportStatus.prepared &&
          record.outputSha256 == sha &&
          record.uploadedTo.any((server) => url == '$server/$sha'),
    ),
  );
}

/// How many file hashes one relay query asks about.
const _hashesPerQuery = 100;

/// One relay, spoken to directly over its WebSocket.
///
/// nostr_sdk's relay pool imports Flutter, which the plain Dart VM this tool
/// runs on cannot load.
class RelayConnection {
  RelayConnection._(this.url, this._socket) {
    _socket.listen(
      (message) {
        final decoded = jsonDecode(message as String);
        if (decoded is List<dynamic>) _messages.add(decoded);
      },
      onDone: _messages.close,
      onError: (Object _) => _messages.close(),
    );
  }

  /// Opens a connection to [url].
  static Future<RelayConnection> open(String url) async =>
      RelayConnection._(url, await WebSocket.connect(url));

  final String url;
  final WebSocket _socket;
  final _messages = StreamController<List<dynamic>>.broadcast();
  var _subscriptions = 0;

  /// The events matching [filter], until the relay says it sent them all.
  Future<List<Map<String, dynamic>>> query(
    Map<String, dynamic> filter, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final id = 'sound-import-${_subscriptions++}';
    final events = <Map<String, dynamic>>[];
    final done = _messages.stream
        .firstWhere((message) {
          if (message.length >= 3 &&
              message[0] == 'EVENT' &&
              message[1] == id &&
              message[2] is Map<String, dynamic>) {
            events.add(message[2] as Map<String, dynamic>);
          }
          return message.length >= 2 &&
              (message[0] == 'EOSE' || message[0] == 'CLOSED') &&
              message[1] == id;
        })
        .timeout(timeout);
    _socket.add(jsonEncode(['REQ', id, filter]));
    await done;
    _socket.add(jsonEncode(['CLOSE', id]));
    return events;
  }

  /// Sends [event] and waits for the relay to accept or refuse it.
  ///
  /// Returns the relay's reason when it refuses, null when it accepts.
  Future<String?> publish(
    Map<String, dynamic> event, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final answer = _messages.stream
        .firstWhere(
          (message) =>
              message.length >= 3 &&
              message[0] == 'OK' &&
              message[1] == event['id'],
        )
        .timeout(timeout);
    _socket.add(jsonEncode(['EVENT', event]));
    final ok = await answer;
    return ok[2] == true ? null : '${ok.length > 3 ? ok[3] : 'refused'}';
  }

  Future<void> close() => _socket.close();
}

/// The hashes among [sha256s] that [pubkey] already published a Kind 1063
/// for on [relay].
///
/// This is what makes publishing idempotent: run again, it skips every sound
/// the account already has.
Future<Set<String>> publishedHashes(
  RelayConnection relay, {
  required String pubkey,
  required List<String> sha256s,
}) async {
  final found = <String>{};
  for (var start = 0; start < sha256s.length; start += _hashesPerQuery) {
    final end = start + _hashesPerQuery > sha256s.length
        ? sha256s.length
        : start + _hashesPerQuery;
    final batch = sha256s.sublist(start, end);
    final events = await relay.query({
      'authors': [pubkey],
      'kinds': [1063],
      '#x': batch,
      'limit': batch.length,
    });
    for (final event in events) {
      found.addAll(fileHashesOf(event['tags'] as List<dynamic>));
    }
  }
  return found;
}

/// The `x` values of [tags].
Iterable<String> fileHashesOf(List<dynamic> tags) sync* {
  for (final tag in tags.whereType<List<dynamic>>()) {
    if (tag.length >= 2 && tag[0] == 'x' && tag[1] is String) {
      yield tag[1] as String;
    }
  }
}

/// [unsigned] signed by [privateKeyHex], whose public key is [pubkey], at
/// the `created_at` the events command gave it.
Map<String, dynamic> signUnsigned(
  Map<String, dynamic> unsigned, {
  required String pubkey,
  required String privateKeyHex,
}) {
  final event = Event(
    pubkey,
    unsigned['kind'] as int,
    [
      for (final tag in unsigned['tags'] as List<dynamic>)
        (tag as List<dynamic>).cast<String>(),
    ],
    unsigned['content'] as String,
    createdAt: unsigned['created_at'] as int,
  )..sign(privateKeyHex);
  return event.toJson();
}
