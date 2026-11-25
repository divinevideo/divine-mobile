// ABOUTME: An awaited publish still waiting for its OK when its relay's socket
// ABOUTME: is replaced or reconnects is sent again on the new socket (#11446).

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _url = 'wss://relay.example';
const _otherUrl = 'wss://other.example';
const _tempUrl = 'wss://inbox.example';
const _timeout = Duration(seconds: 15);

/// When the socket is replaced or drops, measured from the publish.
const _reconnectAt = Duration(milliseconds: 1600);

/// How long a relay here takes to answer a publish.
const _answerDelay = Duration(seconds: 4);

Event _note() => Event(
  getPublicKey(_key),
  EventKind.textNote,
  const [],
  'held publish',
  createdAt: 1700000000,
)..sign(_key);

/// The frames of [type] the client wrote to [channel], decoded.
List<List<dynamic>> _sent(FakeWebSocketChannel channel, String type) => [
  for (final raw in channel.sentMessages)
    if ((jsonDecode(raw as String) as List<dynamic>).first == type)
      jsonDecode(raw) as List<dynamic>,
];

/// Ids of the events the client published on [channel].
List<String> _published(FakeWebSocketChannel channel) => [
  for (final frame in _sent(channel, 'EVENT'))
    (frame[1] as Map<String, dynamic>)['id'] as String,
];

class _Rig {
  _Rig(this.async, {List<String> urls = const [_url]}) {
    nostr = Nostr(LocalNostrSigner(_key), [], _relay);
    unawaited(nostr.refreshPublicKey());
    for (final url in urls) {
      unawaited(pool.add(_relay(url), autoSubscribe: true));
    }
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final Map<String, FakeWebSocketChannelFactory> _factories = {};
  late final Nostr nostr;

  RelayPool get pool => nostr.relayPool;

  FakeWebSocketChannelFactory get factory => factoryOf(_url);

  FakeWebSocketChannelFactory factoryOf(String url) =>
      _factories.putIfAbsent(url, FakeWebSocketChannelFactory.new);

  /// The socket the newest relay object for [_url] opened.
  FakeWebSocketChannel get socket => factory.lastChannel!;

  List<FakeWebSocketChannel> get sockets => factory.createdChannels;

  RelayBase _relay([String url = _url]) =>
      RelayBase(url, RelayStatus(url), channelFactory: factoryOf(url));

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

  /// The relay accepting [note] on [channel].
  void accept(FakeWebSocketChannel channel, Event note) =>
      deliver(channel, ['OK', note.id, true, '']);

  /// The relay on [channel] challenging for NIP-42, and accepting the AUTH
  /// event the pool answers with when [accepted].
  void challenge(FakeWebSocketChannel channel, {bool accepted = true}) {
    deliver(channel, ['AUTH', 'challenge']);
    if (!accepted) return;
    final auth = _sent(channel, 'AUTH').last[1] as Map<String, dynamic>;
    deliver(channel, ['OK', auth['id'], true, '']);
  }
}

class _Publish {
  PublishOutcome? outcome;
  Duration? tookFor;
}

_Publish _startPublish(
  _Rig rig,
  Event note, {
  Duration timeout = _timeout,
  String? tempRelay,
}) {
  final publish = _Publish();
  final started = rig.async.elapsed;
  unawaited(
    rig.pool
        .sendEventAwaitOk(
          ['EVENT', note.toJson()],
          eventId: note.id,
          timeout: timeout,
          targetRelays: tempRelay == null ? null : [tempRelay],
          tempRelays: tempRelay == null ? null : [tempRelay],
        )
        .then((outcome) {
          publish
            ..outcome = outcome
            ..tookFor = rig.async.elapsed - started;
        }),
  );
  rig.async.flushMicrotasks();
  return publish;
}

void main() {
  group('$RelayPool awaited publish across a reconnect (#11446)', () {
    group('relay replaced under the same url', () {
      test('is sent on the new socket and settles on its answer', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);
          final old = rig.socket;
          expect(_published(old), [note.id]);

          async.elapse(_reconnectAt);
          rig.replace();
          final fresh = rig.socket;
          expect(fresh, isNot(same(old)));
          expect(_published(fresh), [note.id]);

          rig.accept(fresh, note);
          async.elapse(_timeout);

          expect(publish.outcome!.acceptedBy, [_url]);
          expect(publish.outcome!.noResponseFrom, isEmpty);
          expect(publish.tookFor, _reconnectAt);
        });
      });

      test('is not sent again after its relay answered', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);
          rig.accept(rig.socket, note);
          expect(publish.outcome!.acceptedBy, [_url]);

          async.elapse(_reconnectAt);
          rig.replace();

          expect(rig.sockets, hasLength(2));
          expect(_published(rig.socket), isEmpty);
        });
      });

      test('ends at once, unanswered, when the replacement cannot '
          'connect', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);

          async.elapse(_reconnectAt);
          rig.factory.readyError = Exception('connection refused');
          rig.replace();
          async.elapse(Duration.zero);

          expect(publish.outcome, isNotNull);
          expect(publish.outcome!.noResponseFrom, [_url]);
          expect(publish.outcome!.acceptedBy, isEmpty);
          expect(publish.tookFor, _reconnectAt);
        });
      });

      test('ends at once, unanswered, when the relay is removed with '
          'nothing in its place', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);

          async.elapse(_reconnectAt);
          rig.pool.remove(_url);
          async.flushMicrotasks();

          expect(publish.outcome, isNotNull);
          expect(publish.outcome!.noResponseFrom, [_url]);
          expect(publish.tookFor, _reconnectAt);
        });
      });

      test('sends a publish made while the replacement is still opening '
          'only once', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          rig.factory.readyDelay = const Duration(seconds: 2);
          rig.replace();
          final note = _note();
          final publish = _startPublish(rig, note);
          async.elapse(const Duration(seconds: 3));

          expect(rig.sockets, hasLength(2));
          expect(_published(rig.socket), [note.id]);
          rig.accept(rig.socket, note);
          async.elapse(_timeout);
          expect(publish.outcome!.acceptedBy, [_url]);
        });
      });

      test('leaves a publish refused for NIP-42 to the AUTH retry, which '
          'sends it once', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);
          rig.deliver(rig.socket, [
            'OK',
            note.id,
            false,
            'auth-required: you must auth',
          ]);

          async.elapse(_reconnectAt);
          rig.replace();
          final fresh = rig.socket;
          expect(_published(fresh), isEmpty);

          rig.deliver(fresh, ['AUTH', 'challenge']);
          final auth = _sent(fresh, 'AUTH').single[1] as Map<String, dynamic>;
          rig.deliver(fresh, ['OK', auth['id'], true, '']);
          expect(_published(fresh), [note.id]);

          rig.accept(fresh, note);
          async.elapse(_timeout);
          expect(publish.outcome!.acceptedBy, [_url]);
        });
      });
    });

    group('relay that requires NIP-42', () {
      test('sends a publish already re-sent after AUTH again once the next '
          'socket authenticates', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);
          final first = rig.socket;
          rig
            ..deliver(first, ['OK', note.id, false, 'auth-required: auth'])
            ..challenge(first);
          expect(_published(first), [note.id, note.id]);

          async.elapse(_reconnectAt);
          rig.replace();
          final second = rig.socket;
          rig.challenge(second);
          expect(_published(second), [note.id]);

          rig.accept(second, note);
          async.elapse(_timeout);
          expect(publish.outcome!.acceptedBy, [_url]);
        });
      });

      test('sends a publish written to trigger the challenge again on the '
          'next socket', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          rig.challenge(rig.socket, accepted: false);
          final note = _note();
          final publish = _startPublish(rig, note);
          expect(_published(rig.socket), [note.id]);

          async.elapse(_reconnectAt);
          unawaited(rig.socket.closeFromRemote());
          async.elapse(_answerDelay);
          expect(rig.sockets, hasLength(2));
          expect(_published(rig.socket), [note.id]);

          rig.accept(rig.socket, note);
          async.elapse(_timeout);
          expect(publish.outcome!.acceptedBy, [_url]);
        });
      });
    });

    group('temp relay', () {
      test('sends the publish again when its socket reconnects', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note, tempRelay: _tempUrl);
          final inbox = rig.factoryOf(_tempUrl);
          expect(_published(inbox.lastChannel!), [note.id]);

          async.elapse(_reconnectAt);
          unawaited(inbox.lastChannel!.closeFromRemote());
          async.elapse(_answerDelay);
          expect(inbox.createdChannels, hasLength(2));
          expect(_published(inbox.lastChannel!), [note.id]);

          rig.accept(inbox.lastChannel!, note);
          async.elapse(_timeout);
          expect(publish.outcome!.acceptedBy, [_tempUrl]);
        });
      });

      test('hands the publish to the temp relay that replaces it', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note, tempRelay: _tempUrl);
          final inbox = rig.factoryOf(_tempUrl);
          final replaced = rig.pool.checkAndGenTempRelay(_tempUrl);

          async.elapse(_reconnectAt);
          inbox.readyError = Exception('connection refused');
          unawaited(inbox.lastChannel!.closeFromRemote());
          async.flushMicrotasks();
          inbox.readyError = null;
          final replacement = rig.pool.checkAndGenTempRelay(_tempUrl);
          async.flushMicrotasks();
          expect(replacement, isNot(same(replaced)));
          expect(_published(inbox.lastChannel!), [note.id]);

          rig.accept(inbox.lastChannel!, note);
          async.elapse(_timeout);
          expect(publish.outcome!.acceptedBy, [_tempUrl]);
        });
      });
    });

    group('same relay reconnecting in place', () {
      test('is sent on the new socket and settles on its answer', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);
          final old = rig.socket;

          async.elapse(_reconnectAt);
          unawaited(old.closeFromRemote());
          async.elapse(_answerDelay);
          final fresh = rig.socket;
          expect(rig.sockets, hasLength(2));
          expect(_published(fresh), [note.id]);

          rig.accept(fresh, note);
          async.elapse(_timeout);

          expect(publish.outcome!.acceptedBy, [_url]);
          expect(publish.outcome!.noResponseFrom, isEmpty);
        });
      });

      test('is not sent after the publish has settled on another relay', () {
        fakeAsync((async) {
          final rig = _Rig(async, urls: const [_url, _otherUrl]);
          final note = _note();
          final publish = _startPublish(rig, note);
          rig.accept(rig.factoryOf(_otherUrl).lastChannel!, note);
          async.elapse(PublishTracker.defaultSettleWindow);
          expect(publish.outcome!.acceptedBy, [_otherUrl]);
          expect(publish.outcome!.noResponseFrom, [_url]);

          // Settling with this relay silent also force-cycles its socket.
          unawaited(rig.socket.closeFromRemote());
          async.elapse(_answerDelay);

          expect(rig.sockets.length, greaterThan(1));
          expect(rig.sockets.skip(1).expand(_published), isEmpty);
        });
      });

      test('is not sent again on the same socket when nothing cycled', () {
        fakeAsync((async) {
          final rig = _Rig(async);
          final note = _note();
          final publish = _startPublish(rig, note);
          async.elapse(_answerDelay);
          rig.accept(rig.socket, note);

          expect(publish.outcome!.acceptedBy, [_url]);
          expect(rig.sockets, hasLength(1));
          expect(_published(rig.socket), [note.id]);
        });
      });
    });
  });
}
