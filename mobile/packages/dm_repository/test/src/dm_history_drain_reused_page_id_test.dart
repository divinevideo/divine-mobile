// ABOUTME: History restore asks each read under its own subscription id, so a
// ABOUTME: relay's late answer to an earlier REQ cannot settle a later one.

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _InlineVerifyWorker implements DmVerifyWorker {
  @override
  Future<bool> verifyPart(Event event) async => event.isValid && event.isSigned;

  @override
  void close() {}
}

/// The pool's off-main verify, holding one event until [gate] completes.
class _GatedPoolVerify implements EventVerifyWorker {
  _GatedPoolVerify(this.heldId);

  final String? heldId;
  final Completer<bool> gate = Completer<bool>();

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async =>
      heldId != null && eventJson['id'] == heldId && !gate.isCompleted
      ? gate.future
      : true;

  @override
  void close() {}
}

typedef _Req = ({String subId, List<Map<String, dynamic>> filters});

/// A relay whose answers the test scripts through [onReq]: frames it sends
/// keep arriving after a CLOSE, as from a relay that finishes a REQ before it
/// reads the CLOSE (divine-funnelcake#1304).
class _ScriptedRelay extends Relay {
  _ScriptedRelay({required this.store, required this.onReq, this.onClose})
    : super('wss://pool.example', RelayStatus('wss://pool.example'));

  final List<Event> store;
  final void Function(_ScriptedRelay relay, _Req req) onReq;
  final void Function(String subId)? onClose;
  final List<_Req> reqs = [];

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
    if (message.length > 2 && message[0] == 'REQ') {
      final req = (
        subId: message[1] as String,
        filters: [
          for (final f in message.skip(2)) Map<String, dynamic>.from(f as Map),
        ],
      );
      reqs.add(req);
      onReq(this, req);
    } else if (message.length > 1 && message[0] == 'CLOSE') {
      onClose?.call(message[1] as String);
    }
    return true;
  }

  /// Sends [events] under [subId] after [after], then EOSE when [eose].
  void answer(
    String subId,
    List<Event> events, {
    bool eose = true,
    Duration after = const Duration(milliseconds: 10),
  }) {
    Timer(after, () {
      for (final event in events) {
        _deliver(['EVENT', subId, event.toJson()]);
      }
      if (eose) _deliver(['EOSE', subId]);
    });
  }

  /// What the relay holds for [filters], newest first, each filter capped
  /// at its limit.
  List<Event> serve(List<Map<String, dynamic>> filters) {
    final out = <String, Event>{};
    for (final filter in filters) {
      final matched = store.where((e) => _admits(filter, e)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final limit = filter['limit'] as int?;
      for (final e in limit == null ? matched : matched.take(limit)) {
        out[e.id] = e;
      }
    }
    return out.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void answerFromStore(_Req req) => answer(req.subId, serve(req.filters));

  void _deliver(List<dynamic> frame) {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

bool _admits(Map<String, dynamic> filter, Event e) {
  final kinds = filter['kinds'] as List?;
  if (kinds != null && !kinds.contains(e.kind)) return false;
  final authors = filter['authors'] as List?;
  if (authors != null && !authors.contains(e.pubkey)) return false;
  final p = filter['#p'] as List?;
  if (p != null &&
      !e.tags.any(
        (tag) => tag.length > 1 && tag[0] == 'p' && p.contains(tag[1]),
      )) {
    return false;
  }
  final since = filter['since'] as int?;
  if (since != null && e.createdAt < since) return false;
  final until = filter['until'] as int?;
  if (until != null && e.createdAt > until) return false;
  return true;
}

const _ownerKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _senderKey =
    '7777777777777777777777777777777777777777777777777777777777777777';
final String _owner = getPublicKey(_ownerKey);
final String _sender = getPublicKey(_senderKey);

/// Whether [req] reads a page of the history drain, as opposed to its
/// recovery passes, the deletions read beside it, or anything else.
bool _isHistoryPage(_Req req) =>
    req.subId.startsWith('${scopedSubscriptionId('dm_drain', _owner)}_') &&
    req.filters.any(
      (f) => (f['kinds'] as List?)?.contains(EventKind.giftWrap) ?? false,
    );

/// Whether [req] reads the account's own outgoing NIP-04 messages.
bool _isNip04Recovery(_Req req) =>
    req.subId.startsWith(scopedSubscriptionId('dm_drain_nip04', _owner));

typedef _Harness = ({
  DmRepository repository,
  DmSyncState syncState,
  AppDatabase db,
  NostrClient client,
});

_Harness _harness(
  FakeAsync async,
  _ScriptedRelay relay, {
  required Map<String, Event> rumors,
  EventVerifyWorker? poolVerify,
}) {
  poolVerify ??= _GatedPoolVerify(null);
  late SharedPreferences prefs;
  unawaited(SharedPreferences.getInstance().then((p) => prefs = p));
  async.flushMicrotasks();
  final db = AppDatabase.test(NativeDatabase.memory());
  final nostr = Nostr(
    LocalNostrSigner(_ownerKey),
    [],
    (url) => RelayBase(url, RelayStatus(url)),
  );
  nostr.relayPool.eventVerifyWorker = poolVerify;
  unawaited(nostr.relayPool.add(relay));
  async.flushMicrotasks();
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn([relay.url]);
  when(() => relayManager.configuredRelays).thenReturn([relay.url]);
  when(() => relayManager.connectedRelayCount).thenReturn(1);
  when(() => relayManager.configuredRelayCount).thenReturn(1);
  when(
    () => relayManager.currentStatuses,
  ).thenReturn(<String, RelayConnectionStatus>{});
  when(
    () => relayManager.statusStream,
  ).thenAnswer((_) => const Stream.empty());
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  final client = NostrClient.forTesting(
    nostr: nostr,
    relayManager: relayManager,
  );
  final syncState = DmSyncState(prefs);
  final repository = DmRepository(
    nostrClient: client,
    directMessagesDao: DirectMessagesDao(db),
    conversationsDao: ConversationsDao(db),
    processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
    syncState: syncState,
    userPubkey: _owner,
    signer: LocalNostrSigner(_ownerKey),
    rumorDecryptor: (_, wrap) async => rumors[wrap.id],
    verifyIsolateSpawner: () async => _InlineVerifyWorker(),
  );
  return (repository: repository, syncState: syncState, db: db, client: client);
}

/// Runs one restore pass to its end on the fake clock.
void _restore(FakeAsync async, _Harness h) {
  unawaited(h.repository.backfillHistoryIfNeeded());
  async.elapse(const Duration(seconds: 90));
}

Set<String> _stored(FakeAsync async, _Harness h, List<Event> wraps) {
  final stored = <String>{};
  final dao = DirectMessagesDao(h.db);
  for (final wrap in wraps) {
    unawaited(
      dao.hasGiftWrap(wrap.id, ownerPubkey: _owner).then((has) {
        if (has) stored.add(wrap.id);
      }),
    );
  }
  async.flushMicrotasks();
  return stored;
}

void _tearDown(FakeAsync async, _Harness h) {
  unawaited(h.repository.stopListening());
  unawaited(h.client.dispose());
  unawaited(h.db.close());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1));
}

void main() {
  group('history restore under a reused subscription id', () {
    late List<Event> wraps;
    late Map<String, Event> rumors;

    /// [count] signed gift wraps addressed to the owner, newest first, a
    /// minute apart, each decrypting to its own kind-14 message.
    void seed(int count) {
      final newest = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
      wraps = [];
      rumors = {};
      for (var i = 0; i < count; i++) {
        final createdAt = newest - i * 60;
        final wrap = Event(
          _sender,
          EventKind.giftWrap,
          [
            ['p', _owner],
          ],
          'wrap-$i',
          createdAt: createdAt,
        )..sign(_senderKey);
        wraps.add(wrap);
        rumors[wrap.id] = Event(
          _sender,
          EventKind.privateDirectMessage,
          [
            ['p', _owner],
          ],
          'message $i',
          createdAt: createdAt,
        );
      }
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('stores every wrap of a page whose first read ended while one of '
        'its events was being verified (#11025)', () {
      seed(5);
      fakeAsync((async) {
        final verify = _GatedPoolVerify(wraps[2].id);
        String? firstReadId;
        var pageReads = 0;
        final relay = _ScriptedRelay(
          store: wraps,
          onReq: (relay, req) {
            if (!_isHistoryPage(req) || ++pageReads > 2) {
              relay.answerFromStore(req);
              return;
            }
            if (pageReads == 1) {
              firstReadId = req.subId;
              relay.answer(req.subId, wraps.sublist(0, 3), eose: false);
              return;
            }
            // The rest of the first answer reaches the relay's socket first,
            // under the first REQ's id; this REQ's own answer follows it.
            relay
              ..answer(firstReadId!, wraps.sublist(3))
              ..answer(
                req.subId,
                relay.serve(req.filters),
                after: const Duration(milliseconds: 20),
              );
          },
          // The held event finishes verifying once the first read has ended
          // and before the retry has asked again.
          onClose: (subId) {
            if (subId == firstReadId && !verify.gate.isCompleted) {
              verify.gate.complete(true);
            }
          },
        );
        final h = _harness(async, relay, rumors: rumors, poolVerify: verify);

        _restore(async, h);

        expect(pageReads, greaterThanOrEqualTo(2), reason: 'a retry ran');
        expect(verify.gate.isCompleted, isTrue);
        expect(_stored(async, h, wraps), containsAll(wraps.map((w) => w.id)));
        expect(h.syncState.historyDrainComplete(_owner), isTrue);
        _tearDown(async, h);
      });
    });

    test('a later restore is not ended by the late answer to an earlier '
        "restore's read of the same page number", () {
      seed(230);
      fakeAsync((async) {
        _Req? unanswered;
        var pageReads = 0;
        final relay = _ScriptedRelay(
          store: wraps,
          onReq: (relay, req) {
            if (!_isHistoryPage(req)) {
              relay.answerFromStore(req);
              return;
            }
            switch (++pageReads) {
              // The first restore's first read of page 0 goes unanswered for
              // now; its retry is answered.
              case 1:
                unanswered = req;
              // The first restore's page 2, and its retry, go unanswered, so
              // it stops there and leaves the rest for the next restore.
              case 4 || 5:
                break;
              // The next restore's page 0 starts at that window. The answer
              // to the first REQ arrives first; none of it is in this window.
              case 6:
                relay
                  ..answer(unanswered!.subId, relay.serve(unanswered!.filters))
                  ..answer(
                    req.subId,
                    relay.serve(req.filters),
                    after: const Duration(milliseconds: 20),
                  );
              default:
                relay.answerFromStore(req);
            }
          },
        );
        final h = _harness(async, relay, rumors: rumors);

        // The first restore defers at page 2, and the next one starts on its
        // own once it has.
        _restore(async, h);

        expect(pageReads, greaterThanOrEqualTo(6), reason: 'a restore resumed');
        expect(_stored(async, h, wraps), hasLength(wraps.length));
        expect(h.syncState.historyDrainComplete(_owner), isTrue);
        _tearDown(async, h);
      });
    });

    test('every read across two restores asks under its own id', () {
      seed(5);
      fakeAsync((async) {
        var nip04Reads = 0;
        final relay = _ScriptedRelay(
          store: wraps,
          onReq: (relay, req) {
            // The first outgoing NIP-04 recovery read goes unanswered, so
            // the first restore cannot complete and a second one runs.
            if (_isNip04Recovery(req) && ++nip04Reads == 1) return;
            relay.answerFromStore(req);
          },
        );
        final h = _harness(async, relay, rumors: rumors);

        _restore(async, h);

        expect(nip04Reads, greaterThanOrEqualTo(2), reason: 'restore resumed');
        expect(h.syncState.historyDrainComplete(_owner), isTrue);
        expect(relay.reqs.where(_isHistoryPage).length, greaterThan(2));
        final ids = [for (final req in relay.reqs) req.subId];
        expect(ids.toSet(), hasLength(ids.length), reason: '$ids');
        _tearDown(async, h);
      });
    });
  });
}
