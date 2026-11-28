// ABOUTME: A relay object replaced under the same url, as a forced reconnect
// ABOUTME: does, keeps the reads and COUNTs its socket still owed (#11343).

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

import '../support/fake_web_socket.dart';

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _url = 'wss://relay.example';
const _readId = 'held-read';
const _countId = 'held-count';
const _liveId = 'live-feed';
const _timeout = Duration(seconds: 12);

final _filter = Filter(kinds: const [EventKind.textNote], limit: 10).toJson();

Event _note() => Event(
  getPublicKey(_key),
  EventKind.textNote,
  const [],
  'stored',
  createdAt: 1700000000,
)..sign(_key);

/// The frames of [type] the client wrote to [channel], decoded.
List<List<dynamic>> _sent(FakeWebSocketChannel channel, String type) => [
  for (final raw in channel.sentMessages)
    if ((jsonDecode(raw as String) as List<dynamic>).first == type)
      jsonDecode(raw) as List<dynamic>,
];

/// Sub ids of the frames of [type] the client wrote to [channel].
List<String> _ids(FakeWebSocketChannel channel, String type) => [
  for (final frame in _sent(channel, type)) frame[1] as String,
];

class _Rig {
  _Rig(this.async) {
    nostr = Nostr(LocalNostrSigner(_key), [], (url) {
      throw StateError('no temp relays in this test: $url');
    });
    unawaited(pool.add(_relay(), autoSubscribe: true));
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final factory = FakeWebSocketChannelFactory();
  late final Nostr nostr;

  RelayPool get pool => nostr.relayPool;

  /// The socket the newest relay object for [_url] opened.
  FakeWebSocketChannel get socket => factory.lastChannel!;

  RelayBase _relay() =>
      RelayBase(_url, RelayStatus(_url), channelFactory: factory);

  /// What `RelayManager` does to every relay on a forced reconnect: drop the
  /// object for the url and add a new one in its place.
  void replace() {
    pool.remove(_url);
    unawaited(pool.add(_relay(), autoSubscribe: true));
    async.flushMicrotasks();
  }

  /// [frame], arriving from the relay on [channel].
  void deliver(FakeWebSocketChannel channel, List<dynamic> frame) {
    channel.simulateMessage(jsonEncode(frame));
    async.flushMicrotasks();
  }

  /// The relay's whole answer to [subId] on [channel]: one event, then EOSE,
  /// one frame per turn as a socket delivers them.
  void answer(FakeWebSocketChannel channel, String subId) {
    deliver(channel, ['EVENT', subId, _note().toJson()]);
    deliver(channel, ['EOSE', subId]);
  }
}

class _Read {
  QueryResult? result;
  Duration? tookFor;
}

_Read _startRead(_Rig rig, {bool full = false}) {
  final read = _Read();
  final started = rig.async.elapsed;
  unawaited(
    rig.nostr
        .readEvents(
          [_filter],
          id: _readId,
          timeout: _timeout,
          requireAllRelaysSettled: full,
        )
        .then((result) {
          read
            ..result = result
            ..tookFor = rig.async.elapsed - started;
        }),
  );
  rig.async.flushMicrotasks();
  return read;
}

class _Count {
  CountResponse? response;
  Object? error;
  Duration? tookFor;
}

_Count _startCount(_Rig rig) {
  final count = _Count();
  final started = rig.async.elapsed;
  unawaited(
    rig.pool
        .count([_filter], id: _countId, timeout: const Duration(seconds: 5))
        .then<void>((response) => count.response = response)
        .catchError((Object error) => count.error = error)
        .whenComplete(() => count.tookFor = rig.async.elapsed - started),
  );
  rig.async.flushMicrotasks();
  return count;
}

void main() {
  group('$RelayPool relay replaced under the same url (#11343)', () {
    group('one-shot read', () {
      test('is sent once on the new socket', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          _startRead(rig);
          final first = rig.socket;
          expect(_ids(first, 'REQ'), [_readId]);

          rig.replace();

          expect(rig.socket, isNot(same(first)));
          expect(_ids(rig.socket, 'REQ'), [_readId]);
        });
      });

      test('completes with the answer the new socket gives', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final read = _startRead(rig);
          async.elapse(const Duration(seconds: 1));

          rig.replace();
          async.elapse(const Duration(seconds: 1));
          rig.answer(rig.socket, _readId);

          expect(read.result?.endedBy, QueryEnd.complete);
          expect(read.result?.events.map((event) => event.id), [_note().id]);
          expect(read.tookFor, const Duration(seconds: 2));
        });
      });

      test('stays open while the new socket connects, and completes on its '
          'answer', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final read = _startRead(rig);
          rig.factory.readyDelay = const Duration(seconds: 2);

          rig.replace();
          async.elapse(const Duration(seconds: 1));
          expect(read.result, isNull);

          async.elapse(const Duration(seconds: 1));
          expect(_ids(rig.socket, 'REQ'), [_readId]);
          rig.answer(rig.socket, _readId);

          expect(read.result?.endedBy, QueryEnd.complete);
          expect(read.result?.events, hasLength(1));
        });
      });

      test('requiring every relay to settle, completes on the new socket', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final read = _startRead(rig, full: true);

          rig.replace();
          rig.answer(rig.socket, _readId);

          expect(read.result?.endedBy, QueryEnd.complete);
          expect(read.result?.isComplete, isTrue);
        });
      });

      test(
        'ends at once when the relay is removed and nothing replaces it',
        () {
          fakeAsync((async) {
            final rig = _Rig(async);
            final read = _startRead(rig, full: true);

            rig.pool.remove(_url);
            async.flushMicrotasks();

            expect(read.result?.endedBy, QueryEnd.socketDropped);
            expect(read.tookFor, Duration.zero);
          });
        },
      );

      test('ends at once when the new socket cannot connect', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final read = _startRead(rig, full: true);
          rig.factory.readyError = Exception('connection refused');

          rig.replace();
          async.elapse(const Duration(seconds: 1));

          expect(read.result?.endedBy, QueryEnd.socketDropped);
          expect(read.tookFor, lessThan(_timeout));
        });
      });

      test('leaves a live subscription to the pool, which sends it once', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          rig.nostr.subscribe([_filter], (_) {}, id: _liveId);
          _startRead(rig);
          async.flushMicrotasks();

          rig.replace();

          expect(_ids(rig.socket, 'REQ'), unorderedEquals([_liveId, _readId]));
        });
      });
    });

    group('COUNT', () {
      test('is sent again on the new socket, whose count it returns', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final count = _startCount(rig);
          final relaySubId = _ids(rig.socket, 'COUNT').single;
          async.elapse(const Duration(seconds: 1));

          rig.replace();
          expect(_ids(rig.socket, 'COUNT'), [relaySubId]);
          rig.deliver(rig.socket, [
            'COUNT',
            relaySubId,
            {'count': 7},
          ]);

          expect(count.response?.count, 7);
          expect(count.tookFor, const Duration(seconds: 1));
        });
      });

      test(
        'fails at once when the relay is removed and nothing replaces it',
        () {
          fakeAsync((async) {
            final rig = _Rig(async);
            final count = _startCount(rig);

            rig.pool.remove(_url);
            async.flushMicrotasks();

            expect(count.error, isA<CountNotSupportedException>());
            expect(count.tookFor, Duration.zero);
          });
        },
      );

      test('fails at once when the new socket cannot connect', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final count = _startCount(rig);
          rig.factory.readyError = Exception('connection refused');

          rig.replace();
          async.elapse(const Duration(seconds: 1));

          expect(count.error, isA<CountNotSupportedException>());
          expect(count.tookFor, lessThan(const Duration(seconds: 5)));
        });
      });

      test('is dropped from the new relay when the caller stops waiting', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final count = _startCount(rig);
          final relaySubId = _ids(rig.socket, 'COUNT').single;
          async.elapse(const Duration(seconds: 1));

          rig.replace();
          final replacement = rig.pool.getRelay(_url)!;
          expect(replacement.hasCountQuery(relaySubId), isTrue);
          async.elapse(const Duration(seconds: 5));

          expect(count.error, isA<CountNotSupportedException>());
          expect(replacement.hasCountQuery(relaySubId), isFalse);
        });
      });

      test('is not sent by a new socket that connects after the caller '
          'stopped waiting', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final count = _startCount(rig);
          async.elapse(const Duration(seconds: 1));
          rig.factory.readyDelay = const Duration(seconds: 6);

          rig.replace();
          async.elapse(const Duration(seconds: 5));
          expect(count.error, isA<CountNotSupportedException>());
          async.elapse(const Duration(seconds: 2));

          expect(
            rig.pool.getRelay(_url)!.relayStatus.connected,
            ClientConnected.connected,
          );
          expect(_ids(rig.socket, 'COUNT'), isEmpty);
        });
      });
    });
  });
}
