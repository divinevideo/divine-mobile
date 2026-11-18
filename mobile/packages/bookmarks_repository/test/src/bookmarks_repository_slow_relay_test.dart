// ABOUTME: A relay that answers the kind-10003 read late on its shared
// ABOUTME: connection must not make saving fail when a new one answers (#9335).

import 'dart:async';

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRelayManager extends Mock implements RelayManager {}

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _homeUrl = 'wss://home.example';
const _otherUrl = 'wss://other.example';
const _savedVideo =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _newVideo =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// One connection to a relay that serves the connection's requests in order,
/// as Divine's relay does: [backlog] of earlier work is queued ahead, and a
/// kind-10003 read is answered with [list] only after it. Every other REQ, and
/// every EVENT, is answered at once. One that does not [takeReqs] fails to send
/// them, as a connection whose handshake never completes does.
class _Connection extends Relay {
  _Connection(
    String url, {
    required this.list,
    this.backlog = Duration.zero,
    this.takeReqs = true,
  }) : super(url, RelayStatus(url));

  final Event? list;
  final Duration backlog;
  final bool takeReqs;
  final List<Event> published = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.isNotEmpty && message[0] == 'EVENT') {
      final event = Event.fromJson(
        Map<String, dynamic>.from(message[1] as Map),
      );
      published.add(event);
      Timer(
        const Duration(milliseconds: 5),
        () => _deliver(['OK', event.id, true, '']),
      );
      return true;
    }
    if (message.length > 2 && message[0] == 'REQ') {
      if (!takeReqs) return false;
      final subId = message[1] as String;
      final kinds = (message[2] as Map)['kinds'] as List?;
      if (!(kinds?.contains(10003) ?? false)) {
        Timer(
          const Duration(milliseconds: 5),
          () => _deliver(['EOSE', subId]),
        );
        return true;
      }
      final at = backlog + const Duration(milliseconds: 200);
      if (list case final list?) {
        Timer(at, () => _deliver(['EVENT', subId, list.toJson()]));
      }
      Timer(
        at + const Duration(milliseconds: 1),
        () => _deliver(['EOSE', subId]),
      );
    }
    return true;
  }

  void _deliver(List<dynamic> frame) {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

class _Signer implements BookmarkSigner {
  @override
  bool get isAuthenticated => true;

  @override
  String? get currentPublicKeyHex => getPublicKey(_key);

  @override
  NostrSigner? get currentIdentity => LocalNostrSigner(_key);

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) async => Event(
    getPublicKey(_key),
    kind,
    tags ?? const [],
    content,
    createdAt: createdAt,
  )..sign(_key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Event _listEvent() => Event(
  getPublicKey(_key),
  10003,
  const [
    ['e', _savedVideo],
  ],
  '',
  createdAt: 1700000000,
)..sign(_key);

/// A repository over two relays. The home relay holds the user's list, and the
/// other one does too unless [otherHoldsList] is false. Each relay's
/// shared connection has [homeBacklog] or [otherBacklog] queued ahead; a new
/// connection has [freshBacklog], and cannot send its REQ to the home relay
/// when [homeRefusesFresh].
({
  BookmarksRepository repo,
  _Connection home,
  _Connection other,
  List<_Connection> opened,
})
_harness(
  FakeAsync async, {
  Duration homeBacklog = Duration.zero,
  Duration otherBacklog = Duration.zero,
  Duration freshBacklog = Duration.zero,
  bool otherHoldsList = true,
  bool homeRefusesFresh = false,
}) {
  final list = _listEvent();
  final home = _Connection(_homeUrl, list: list, backlog: homeBacklog);
  final other = _Connection(
    _otherUrl,
    list: otherHoldsList ? list : null,
    backlog: otherBacklog,
  );
  final opened = <_Connection>[];
  final nostr = Nostr(LocalNostrSigner(_key), [], (url) {
    final connection = _Connection(
      url,
      list: list,
      backlog: freshBacklog,
      takeReqs: !(homeRefusesFresh && url.startsWith(_homeUrl)),
    );
    opened.add(connection);
    return connection;
  });
  for (final relay in [home, other]) {
    unawaited(nostr.relayPool.add(relay));
  }
  async.flushMicrotasks();
  final urls = [_homeUrl, _otherUrl];
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(urls);
  when(() => relayManager.configuredRelays).thenReturn(urls);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  SharedPreferences.setMockInitialValues({});
  late SharedPreferences prefs;
  unawaited(SharedPreferences.getInstance().then((p) => prefs = p));
  async.flushMicrotasks();
  return (
    repo: BookmarksRepository(
      nostrClient: NostrClient.forTesting(
        nostr: nostr,
        relayManager: relayManager,
      ),
      signer: _Signer(),
      prefs: prefs,
    ),
    home: home,
    other: other,
    opened: opened,
  );
}

BookmarkToggleResult _toggle(FakeAsync async, BookmarksRepository repo) {
  BookmarkToggleResult? result;
  unawaited(
    repo.toggleVideoInGlobalBookmarks(_newVideo).then((r) => result = r),
  );
  async.elapse(const Duration(seconds: 90));
  return result!;
}

List<String> _itemIds(BookmarksRepository repo) => [
  for (final item in repo.globalBookmarks) item.id,
];

void main() {
  group(BookmarksRepository, () {
    group('toggleVideoInGlobalBookmarks with a relay late on its shared '
        'connection', () {
      test('saves once a new connection to that relay answers', () {
        fakeAsync((async) {
          final h = _harness(async, homeBacklog: const Duration(seconds: 40));

          final result = _toggle(async, h.repo);

          expect(result.succeeded, isTrue);
          expect(_itemIds(h.repo), containsAll([_savedVideo, _newVideo]));
          expect(h.home.published, hasLength(1));
        });
      });

      test('saves when the late relay is not the home relay', () {
        fakeAsync((async) {
          final h = _harness(async, otherBacklog: const Duration(seconds: 40));

          final result = _toggle(async, h.repo);

          expect(result.succeeded, isTrue);
          expect(_itemIds(h.repo), containsAll([_savedVideo, _newVideo]));
        });
      });

      test('still refuses to publish when the relay is late on the new '
          'connection too', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            homeBacklog: const Duration(seconds: 40),
            freshBacklog: const Duration(seconds: 40),
          );

          final result = _toggle(async, h.repo);

          expect(h.opened, isNotEmpty);
          expect(result.succeeded, isFalse);
          expect(result.failure, BookmarkToggleFailure.timedOut);
          expect(h.home.published, isEmpty);
          expect(h.other.published, isEmpty);
        });
      });

      test('still refuses to publish when the late relay cannot take the '
          'REQ on its new connection while the other one answers', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            homeBacklog: const Duration(seconds: 40),
            otherHoldsList: false,
            homeRefusesFresh: true,
          );

          final result = _toggle(async, h.repo);

          expect(h.opened, hasLength(2));
          expect(result.succeeded, isFalse);
          expect(result.failure, BookmarkToggleFailure.timedOut);
          expect(h.home.published, isEmpty);
          expect(h.other.published, isEmpty);
        });
      });

      test('opens no new connection when every relay answers in time', () {
        fakeAsync((async) {
          final h = _harness(async, homeBacklog: const Duration(seconds: 3));

          final result = _toggle(async, h.repo);

          expect(result.succeeded, isTrue);
          expect(h.opened, isEmpty);
        });
      });

      // The slowest new-connection read measured on a phone took 4.6 s
      // (#9335); past the cap the save gives up rather than hold the video's
      // actions for the full default.
      test('saves when the new connection answers after 5 s', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            homeBacklog: const Duration(seconds: 40),
            freshBacklog: const Duration(milliseconds: 4800),
          );

          final result = _toggle(async, h.repo);

          expect(result.succeeded, isTrue);
        });
      });

      test('gives up when the new connection answers after 7 s', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            homeBacklog: const Duration(seconds: 40),
            freshBacklog: const Duration(milliseconds: 6800),
          );

          final result = _toggle(async, h.repo);

          expect(result.succeeded, isFalse);
          expect(result.failure, BookmarkToggleFailure.timedOut);
          expect(h.home.published, isEmpty);
        });
      });
    });

    group('syncGlobalBookmarks with a relay late on its shared connection', () {
      test('lists the saved videos on a device that holds none', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            homeBacklog: const Duration(seconds: 40),
            otherHoldsList: false,
          );
          bool? synced;

          unawaited(h.repo.syncGlobalBookmarks().then((s) => synced = s));
          async.elapse(const Duration(seconds: 90));

          expect(synced, isTrue);
          expect(_itemIds(h.repo), [_savedVideo]);
        });
      });
    });
  });
}
