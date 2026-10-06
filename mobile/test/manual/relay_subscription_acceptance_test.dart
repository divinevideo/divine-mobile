// ABOUTME: Relay subscription/pagination/#t/deletion acceptance tests for kind
// ABOUTME: 34236, run against the local funnelcake-relay WebSocket on port 47777.
//
// Requires the local Docker stack (port 47777).
// Run: flutter test test/manual/relay_subscription_acceptance_test.dart
// Start stack: mise run local_up (from repo root)
//
// Covers the acceptance criteria from issue #3054:
//   - A REQ subscription returns the expected kind-34236 events for a filter
//   - until + limit pagination yields distinct, reverse-chronological pages
//     with no gaps or duplicates (client dedupes by event id)
//   - a #t (vine tag) filter returns only events tagged with the requested value
//   - a kind-5 deletion removes the event from subsequent subscriptions
//
// The WebSocket/signing helpers are inlined rather than imported from
// integration_test/helpers/relay_helpers.dart: that file pulls in
// package:flutter/material, dart:ui, and a Blossom blob-upload path, none of
// which this protocol-level test needs. Mirrors the self-contained shape of
// nip98_relay_acceptance_test.dart (#5111).

// Permanent: a manual, Docker-dependent real-network acceptance test whose
// setUpAll opens a real Socket.connect probe to localhost:47777. File-level
// @Tags are dropped inside the merged VGV bundle, so 'integration' alone
// cannot keep this file out of CI (#5340 regression, #5738); the skip tag
// runs it as a separate suite, which --exclude-tags integration then skips.
@Tags(['skip_very_good_optimization', 'integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/observe_until.dart';

// Local-stack constants (funnelcake-proxy maps the relay WebSocket to host
// port 47777; nginx forwards "/" to funnelcake-relay:7777 with an upgrade).
const _localHost = 'localhost';
const _localRelayPort = 47777;
const _wsUrl = 'ws://$_localHost:$_localRelayPort';
const _localStackUnavailableMessage =
    'Local stack is not running. Start with `mise run local_up`, then rerun '
    '`flutter test test/manual/relay_subscription_acceptance_test.dart`.';

const _videoKind = 34236;
const _deletionKind = 5;
const _testTimeout = Timeout(Duration(seconds: 60));

void main() {
  late bool stackAvailable;

  setUpAll(() async {
    stackAvailable = await _isPortOpen(_localHost, _localRelayPort);
  });

  group('relay kind-34236 subscription', () {
    test(
      'REQ returns the published event for a kinds+authors filter',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubKey = getPublicKey(privKey);
        final nonce = _nonce();

        final event = _buildVideoEvent(
          privateKey: privKey,
          dTag: 'sub-$nonce',
          createdAt: _nowSeconds(),
          topic: 'vine-sub-$nonce',
        );
        final eventId = await _publish(event);

        final results = await _queryUntil(
          {
            'kinds': [_videoKind],
            'authors': [pubKey],
            'limit': 10,
          },
          (events) => events.any((e) => e.id == eventId),
        );

        expect(results, isNotEmpty);
        final ids = results.map((e) => e.id).toSet();
        expect(ids, contains(eventId));
        expect(results.every((e) => e.kind == _videoKind), isTrue);
      },
      timeout: _testTimeout,
    );
  });

  group('relay kind-34236 pagination (until + limit)', () {
    test(
      'drains distinct, reverse-chronological pages without duplicates',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubKey = getPublicKey(privKey);
        final nonce = _nonce();

        // Publish 5 events with strictly decreasing, distinct created_at so the
        // newest-first ordering and page boundaries are deterministic.
        const total = 5;
        final base = _nowSeconds();
        final publishedIds = <String>[];
        for (var i = 0; i < total; i++) {
          final event = _buildVideoEvent(
            privateKey: privKey,
            dTag: 'page-$nonce-$i',
            createdAt: base - i * 60,
            topic: 'vine-page-$nonce',
          );
          publishedIds.add(await _publish(event));
        }

        // Wait until all published events are queryable before walking pages,
        // so the paged reads see a consistent stored set.
        await _queryUntil(
          {
            'kinds': [_videoKind],
            'authors': [pubKey],
            'limit': 50,
          },
          (events) {
            final ids = events.map((e) => e.id).toSet();
            return publishedIds.every(ids.contains);
          },
        );

        // Walk pages of size 2 using until = oldest created_at of the previous
        // page. until is inclusive, so the boundary event reappears; the client
        // dedupes by id (the NIP-01-correct cursor pattern).
        const pageSize = 2;
        final seen = <String>{};
        final collected = <Event>[];
        int? until;
        for (var page = 0; page < total + 2; page++) {
          final results = await _query({
            'kinds': [_videoKind],
            'authors': [pubKey],
            'limit': pageSize,
            'until': ?until,
          });
          if (results.isEmpty) break;

          for (final e in results) {
            if (seen.add(e.id)) collected.add(e);
          }
          until = results.last.createdAt;
          if (collected.length >= total) break;
        }

        // Every published event surfaced exactly once.
        expect(collected, hasLength(total));
        expect(
          collected.map((e) => e.id).toSet(),
          equals(publishedIds.toSet()),
        );

        // No duplicates and strictly reverse-chronological.
        expect(collected.map((e) => e.id).toSet(), hasLength(collected.length));
        for (var i = 1; i < collected.length; i++) {
          expect(
            collected[i].createdAt,
            lessThanOrEqualTo(collected[i - 1].createdAt),
          );
        }
      },
      timeout: _testTimeout,
    );
  });

  group('relay kind-34236 #t filter', () {
    test('returns only events tagged with the requested value', () async {
      if (_skipIfStackUnavailable(stackAvailable)) return;

      final privKey = generatePrivateKey();
      final nonce = _nonce();
      final topicA = 'vine-a-$nonce';
      final topicB = 'vine-b-$nonce';
      final now = _nowSeconds();

      final idA1 = await _publish(
        _buildVideoEvent(
          privateKey: privKey,
          dTag: 'tag-$nonce-a1',
          createdAt: now,
          topic: topicA,
        ),
      );
      final idA2 = await _publish(
        _buildVideoEvent(
          privateKey: privKey,
          dTag: 'tag-$nonce-a2',
          createdAt: now - 30,
          topic: topicA,
        ),
      );
      final idB = await _publish(
        _buildVideoEvent(
          privateKey: privKey,
          dTag: 'tag-$nonce-b1',
          createdAt: now - 60,
          topic: topicB,
        ),
      );

      // topicA is unique per run, so the #t filter alone scopes the result to
      // exactly the two topicA events regardless of seeded data.
      final results = await _queryUntil(
        {
          'kinds': [_videoKind],
          '#t': [topicA],
        },
        (events) => events.length >= 2,
      );

      final ids = results.map((e) => e.id).toSet();
      expect(ids, equals({idA1, idA2}));
      expect(ids, isNot(contains(idB)));
      expect(
        results.every((e) => _topicTags(e).contains(topicA)),
        isTrue,
      );
      expect(
        results.any((e) => _topicTags(e).contains(topicB)),
        isFalse,
      );
    }, timeout: _testTimeout);
  });

  group('relay kind-5 deletion', () {
    test(
      'removes the deleted event from a subsequent subscription',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubKey = getPublicKey(privKey);
        final nonce = _nonce();

        final targetId = await _publish(
          _buildVideoEvent(
            privateKey: privKey,
            dTag: 'del-$nonce',
            createdAt: _nowSeconds(),
            topic: 'vine-del-$nonce',
          ),
        );

        final filter = {
          'kinds': [_videoKind],
          'authors': [pubKey],
        };

        // Wait until the published event is queryable before deleting it.
        final before = await _queryUntil(
          filter,
          (events) => events.any((e) => e.id == targetId),
        );
        expect(before.map((e) => e.id), contains(targetId));

        // funnelcake honours kind-5 deletion via an `e` tag referencing the
        // event id (the addressable `a`-coordinate form is not read).
        final deletion = Event(
          pubKey,
          _deletionKind,
          [
            ['e', targetId],
            ['k', '$_videoKind'],
          ],
          '',
        );
        deletion.sign(privKey);
        await _publish(deletion);

        final stillPresent = await _isStillPresentAfterDeletion(
          filter,
          targetId,
        );
        expect(
          stillPresent,
          isFalse,
          reason:
              'kind-5 deletion should remove $targetId from subsequent REQs.',
        );
      },
      timeout: _testTimeout,
    );
  });

  group('relay seeded data smoke', () {
    test(
      'a kinds-only REQ returns at least one kind-34236 event',
      () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        // Proves the harness reaches a live, populated relay (local_up seeds
        // ~100 kind-34236 events). Tolerance-only by design.
        final results = await _query({
          'kinds': [_videoKind],
          'limit': 1,
        });

        expect(results, isNotEmpty);
        expect(results.first.kind, equals(_videoKind));
      },
      timeout: _testTimeout,
    );
  });
}

// ---------------------------------------------------------------------------
// Stack-availability guard (mirrors nip98_relay_acceptance_test.dart)
// ---------------------------------------------------------------------------

bool _skipIfStackUnavailable(bool stackAvailable) {
  if (stackAvailable) return false;

  markTestSkipped(_localStackUnavailableMessage);
  return true;
}

/// Returns `true` when [host]:[port] accepts a TCP connection within 2 s.
Future<bool> _isPortOpen(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Raw-WebSocket Nostr helpers (REQ / EVENT / OK), inlined intentionally
// ---------------------------------------------------------------------------

/// Opens a REQ for [filter], collects EVENT messages until EOSE, then closes.
Future<List<Event>> _query(Map<String, dynamic> filter) async {
  final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
  final subId = 'acc-${DateTime.now().microsecondsSinceEpoch}';
  final events = <Event>[];
  final completer = Completer<List<Event>>();

  final subscription = channel.stream.listen(
    (message) {
      final decoded = jsonDecode(message as String) as List<dynamic>;
      if (decoded[0] == 'EVENT' && decoded[1] == subId) {
        events.add(Event.fromJson(decoded[2] as Map<String, dynamic>));
      } else if (decoded[0] == 'EOSE' && decoded[1] == subId) {
        if (!completer.isCompleted) completer.complete(events);
      }
    },
    onError: (Object error) {
      if (!completer.isCompleted) completer.completeError(error);
    },
  );

  channel.sink.add(jsonEncode(['REQ', subId, filter]));

  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } finally {
    channel.sink.add(jsonEncode(['CLOSE', subId]));
    await subscription.cancel();
    await channel.sink.close();
  }
}

/// Sends [event] to the relay and resolves with its id once OK:true arrives.
///
/// Throws if the relay rejects the event (OK:false) or the connection fails.
Future<String> _publish(Event event) async {
  final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
  final completer = Completer<String>();

  final subscription = channel.stream.listen(
    (message) {
      final decoded = jsonDecode(message as String) as List<dynamic>;
      if (decoded[0] == 'OK' && decoded[1] == event.id) {
        if (decoded[2] == true) {
          if (!completer.isCompleted) completer.complete(event.id);
        } else {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('Relay rejected event ${event.id}: ${decoded[3]}'),
            );
          }
        }
      }
    },
    onError: (Object error) {
      if (!completer.isCompleted) completer.completeError(error);
    },
  );

  channel.sink.add(jsonEncode(['EVENT', event.toJson()]));

  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } finally {
    await subscription.cancel();
    await channel.sink.close();
  }
}

// The relay acknowledges OK on receipt but indexes events to ClickHouse
// asynchronously, so a stored-events REQ becomes consistent a short time after
// publish/delete. The helpers below poll the query until the expected condition
// holds (bounded read-after-write coordination), not arbitrary UI timing.
const _consistencyTimeout = Duration(seconds: 20);
const _pollInterval = Duration(milliseconds: 400);

/// Polls [filter] until [ready] is satisfied or [_consistencyTimeout] elapses,
/// then returns the last result set (whether or not [ready] held).
Future<List<Event>> _queryUntil(
  Map<String, dynamic> filter,
  bool Function(List<Event>) ready,
) async {
  return observeUntil<List<Event>>(
    probe: () => _query(filter),
    ready: ready,
    initialValue: const [],
    interval: _pollInterval,
    timeout: _consistencyTimeout,
  );
}

/// Returns whether [eventId] is still returned by [filter] after waiting for the
/// deletion to take effect (true means it never disappeared within the timeout).
Future<bool> _isStillPresentAfterDeletion(
  Map<String, dynamic> filter,
  String eventId,
) async {
  final results = await _queryUntil(
    filter,
    (events) => events.every((e) => e.id != eventId),
  );
  return results.any((e) => e.id == eventId);
}

// ---------------------------------------------------------------------------
// Event builders
// ---------------------------------------------------------------------------

/// Builds and signs a minimal kind-34236 video event the relay will accept.
///
/// funnelcake validates structure, not blob reachability, so placeholder URLs
/// in the required imeta (source + thumbnail) are sufficient. Required tags:
/// `d`, `title`, an imeta with `url` and `image` fields. [topic] is added as a
/// `t` (vine) tag.
Event _buildVideoEvent({
  required String privateKey,
  required String dTag,
  required int createdAt,
  required String topic,
  String title = 'Acceptance test video',
}) {
  final pubKey = getPublicKey(privateKey);
  final event = Event(
    pubKey,
    _videoKind,
    [
      ['d', dTag],
      ['title', title],
      [
        'imeta',
        'url https://example.invalid/$dTag.mp4',
        'm video/mp4',
        'image https://example.invalid/$dTag.jpg',
      ],
      ['t', topic],
      ['duration', '6'],
      ['alt', title],
      ['client', 'diVine-acceptance'],
    ],
    '',
    createdAt: createdAt,
  );
  event.sign(privateKey);
  return event;
}

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _nonce() => DateTime.now().microsecondsSinceEpoch.toString();

Iterable<String> _topicTags(Event event) => event.tags
    .where((tag) => tag.length >= 2 && tag[0] == 't')
    .map((tag) => tag[1]);
