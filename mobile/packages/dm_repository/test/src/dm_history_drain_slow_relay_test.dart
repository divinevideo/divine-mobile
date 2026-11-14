// ABOUTME: History restore finishes when a relay is slow to send a page but is
// ABOUTME: still answering, and still gives up on a silent one (#9472).

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
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

/// When a relay starts answering one REQ, how far apart its stored events
/// arrive, and whether it ends them with EOSE.
typedef _Timing = ({Duration firstFrame, Duration perEvent, bool eose});

const _Timing _prompt = (
  firstFrame: Duration(milliseconds: 10),
  perEvent: Duration.zero,
  eose: true,
);

/// A relay that answers from [store], on the schedule [timingFor] gives.
///
/// [honorsClose] stops a REQ's remaining frames when the client closes it,
/// as a relay whose own pace is the bottleneck does. Without it, frames
/// already on their way keep arriving, as from a relay that finishes its
/// serial work before it reads the CLOSE (divine-funnelcake#1304).
class _TimedRelay extends Relay {
  _TimedRelay(
    String url, {
    required this.store,
    _Timing Function(String subId, List<Map<String, dynamic>> filters)?
    timingFor,
    this.honorsClose = true,
    this.heartbeat,
  }) : timingFor = timingFor ?? ((_, _) => _prompt),
       super(url, RelayStatus(url));

  final List<Event> store;
  final _Timing Function(String subId, List<Map<String, dynamic>> filters)
  timingFor;
  final bool honorsClose;

  /// When set, the relay sends a NOTICE this often from its first REQ on,
  /// standing in for frames it sends other subscriptions on the socket.
  final Duration? heartbeat;

  final List<(String, List<Map<String, dynamic>>)> reqs = [];
  final List<String> closes = [];
  final Map<String, List<Timer>> _bySub = {};
  Timer? _beat;

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
      final subId = message[1] as String;
      final filters = [
        for (final f in message.skip(2)) Map<String, dynamic>.from(f as Map),
      ];
      reqs.add((subId, filters));
      _answer(subId, filters, timingFor(subId, filters));
      final every = heartbeat;
      if (every != null && _beat == null) {
        _beat = Timer.periodic(every, (_) => _deliver(['NOTICE', 'busy']));
      }
    } else if (message.length > 1 && message[0] == 'CLOSE') {
      final subId = message[1] as String;
      closes.add(subId);
      if (honorsClose) {
        for (final timer in _bySub.remove(subId) ?? const <Timer>[]) {
          timer.cancel();
        }
      }
    } else if (message.length > 1 &&
        message[0] == 'EVENT' &&
        message[1] is Map) {
      final id = (message[1] as Map)['id'] as String;
      Timer(
        const Duration(milliseconds: 5),
        () => _deliver(['OK', id, true, '']),
      );
    }
    return true;
  }

  void stopBeating() => _beat?.cancel();

  void _answer(
    String subId,
    List<Map<String, dynamic>> filters,
    _Timing timing,
  ) {
    final timers = _bySub.putIfAbsent(subId, () => []);
    var at = timing.firstFrame;
    for (final event in _serve(filters)) {
      final frame = ['EVENT', subId, event.toJson()];
      timers.add(Timer(at, () => _deliver(frame)));
      at += timing.perEvent;
    }
    if (timing.eose) {
      timers.add(
        Timer(at + const Duration(milliseconds: 1), () {
          _deliver(['EOSE', subId]);
        }),
      );
    }
  }

  List<Event> _serve(List<Map<String, dynamic>> filters) {
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
  final ids = filter['ids'] as List?;
  if (ids != null && !ids.contains(e.id)) return false;
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

bool _readsKind(List<Map<String, dynamic>> filters, int kind) => filters.any(
  (filter) => (filter['kinds'] as List?)?.contains(kind) ?? false,
);

const _ownerKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _senderKey =
    '7777777777777777777777777777777777777777777777777777777777777777';
const _poolRelayUrl = 'wss://pool.example';
const _ownInboxUrl = 'wss://own-inbox.example';
final String _owner = getPublicKey(_ownerKey);
final String _sender = getPublicKey(_senderKey);

/// [count] signed kind-1059 events addressed to the owner, newest first, a
/// minute apart and an hour below now. Their content does not decrypt; the
/// drain pages on wire time alone.
List<Event> _wraps(int count) {
  final newest = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
  return [
    for (var i = 0; i < count; i++)
      Event(
        _sender,
        EventKind.giftWrap,
        [
          ['p', _owner],
        ],
        'undecryptable-$i',
        createdAt: newest - i * 60,
      )..sign(_senderKey),
  ];
}

typedef _Harness = ({
  NostrClient client,
  DmRepository repository,
  DmSyncState syncState,
  AppDatabase db,
  Map<String, _TimedRelay> tempRelays,
});

/// A [DmRepository] over a real [NostrClient] and relay pool holding [pooled],
/// with a real in-memory database. Built inside a [FakeAsync] zone.
_Harness _harness(
  FakeAsync async, {
  required _TimedRelay pooled,
  required SharedPreferences prefs,
  List<_TimedRelay> alsoPooled = const [],
  _TimedRelay Function(String url)? tempRelay,
  String? dmInboxRelayUrl,
}) {
  final db = AppDatabase.test(NativeDatabase.memory());
  final tempRelays = <String, _TimedRelay>{};
  final nostr = Nostr(
    LocalNostrSigner(_ownerKey),
    [],
    (url) => tempRelays.putIfAbsent(
      url,
      () => tempRelay?.call(url) ?? _TimedRelay(url, store: const []),
    ),
  );
  final pool = [pooled, ...alsoPooled];
  for (final relay in pool) {
    unawaited(nostr.relayPool.add(relay));
  }
  async.flushMicrotasks();
  final urls = [for (final relay in pool) relay.url];
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(urls);
  when(() => relayManager.configuredRelays).thenReturn(urls);
  when(() => relayManager.connectedRelayCount).thenReturn(urls.length);
  when(() => relayManager.configuredRelayCount).thenReturn(urls.length);
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
    dmInboxRelayUrl: dmInboxRelayUrl,
    signer: LocalNostrSigner(_ownerKey),
    rumorDecryptor: (_, _) async => null,
    verifyIsolateSpawner: () async => _InlineVerifyWorker(),
  );
  return (
    client: client,
    repository: repository,
    syncState: syncState,
    db: db,
    tempRelays: tempRelays,
  );
}

void _tearDown(FakeAsync async, _Harness h) {
  unawaited(h.repository.stopListening());
  unawaited(h.client.dispose());
  unawaited(h.db.close());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1));
}

/// Runs the first drain pass and returns whether it latched completion, and
/// how long it took on the fake clock.
({bool? complete, Duration took}) _firstPass(FakeAsync async, _Harness h) {
  bool? complete;
  Duration? took;
  final start = async.elapsed;
  unawaited(
    h.repository.backfillHistoryIfNeeded().then((_) {
      complete = h.syncState.historyDrainComplete(_owner);
      took = async.elapsed - start;
    }),
  );
  async.elapse(const Duration(seconds: 90));
  return (complete: complete, took: took ?? Duration.zero);
}

_Timing Function(String, List<Map<String, dynamic>>) _pages(
  _Timing pages,
) =>
    (subId, filters) =>
        subId.startsWith('dm_drain_') && _readsKind(filters, EventKind.giftWrap)
        ? pages
        : _prompt;

/// Answers the reads whose subscription id starts with one of [prefixes] on
/// [timing], and every other read at once.
_Timing Function(String, List<Map<String, dynamic>>) _reads(
  List<String> prefixes,
  _Timing timing,
) =>
    (subId, filters) => prefixes.any(subId.startsWith) ? timing : _prompt;

/// Answers the account's own kind-10050 lookups on [timing], and every other
/// read at once.
_Timing Function(String, List<Map<String, dynamic>>) _inboxList(
  _Timing timing,
) =>
    (_, filters) =>
        _readsKind(filters, EventKind.dmRelaysList) ? timing : _prompt;

const _Timing _twentySecondsLate = (
  firstFrame: Duration(seconds: 20),
  perEvent: Duration.zero,
  eose: true,
);

const _Timing _eightSecondsLate = (
  firstFrame: Duration(seconds: 8),
  perEvent: Duration.zero,
  eose: true,
);

const _Timing _neverAnswered = (
  firstFrame: Duration.zero,
  perEvent: Duration.zero,
  eose: false,
);

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// The account's own kind-10050 list, naming [_ownInboxUrl].
Event _ownInboxList() => Event(
  _owner,
  EventKind.dmRelaysList,
  [
    ['relay', _ownInboxUrl],
  ],
  '',
  createdAt: _now() - 7200,
)..sign(_ownerKey);

/// A gift wrap addressed to the owner, stamped [wire].
Event _wrapAt(int wire, String content) => Event(
  _sender,
  EventKind.giftWrap,
  [
    ['p', _owner],
  ],
  content,
  createdAt: wire,
)..sign(_senderKey);

/// An install whose history restore finished long ago, last seeing a wrap
/// stamped [wire]: the next inbox open re-reads below the live window.
Future<void> _establish(SharedPreferences prefs, int wire) async {
  final sync = DmSyncState(prefs);
  await sync.recordSeen(_owner, createdAt: wire);
  await sync.recordWireSeen(_owner, createdAt: wire);
  await sync.markHistoryDrainComplete(_owner);
  await sync.setDrainVersion(_owner, DmSyncState.currentDrainVersion);
  await sync.setDrainCoveredOwnInbox(_owner);
  await sync.setGroupRecoveryVersion(
    _owner,
    DmSyncState.currentGroupRecoveryVersion,
  );
}

void main() {
  late SharedPreferences prefs;
  late DebugPrintCallback originalDebugPrint;
  late List<Event> history;

  setUpAll(() {
    history = _wraps(120);
  });

  setUp(() async {
    originalDebugPrint = debugPrint;
    debugPrint = debugPrintSynchronously;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => debugPrint = originalDebugPrint);

  group('backfillHistoryIfNeeded with a slow relay', () {
    test('finishes when every page takes longer than 5 s to stream', () {
      fakeAsync((async) {
        final relay = _TimedRelay(
          _poolRelayUrl,
          store: history,
          timingFor: _pages(
            (
              firstFrame: const Duration(milliseconds: 50),
              perEvent: const Duration(milliseconds: 80),
              eose: true,
            ),
          ),
        );
        final h = _harness(async, pooled: relay, prefs: prefs);

        final pass = _firstPass(async, h);

        expect(pass.complete, isTrue);
        _tearDown(async, h);
      });
    });

    test('finishes when a relay busy with other requests answers each page '
        '20 s late', () {
      fakeAsync((async) {
        final relay = _TimedRelay(
          _poolRelayUrl,
          store: history,
          honorsClose: false,
          heartbeat: const Duration(seconds: 1),
          timingFor: _pages(
            (
              firstFrame: const Duration(seconds: 20),
              perEvent: Duration.zero,
              eose: true,
            ),
          ),
        );
        final h = _harness(async, pooled: relay, prefs: prefs);

        final pass = _firstPass(async, h);
        relay.stopBeating();

        expect(pass.complete, isTrue);
        _tearDown(async, h);
      });
    });

    test('finishes when the own kind-10050 list arrives 8 s late, past the '
        "inbox lookup's usual budget", () {
      fakeAsync((async) {
        final relay = _TimedRelay(
          _poolRelayUrl,
          store: [...history.take(20), _ownInboxList()],
          timingFor: _inboxList(_eightSecondsLate),
        );
        final h = _harness(async, pooled: relay, prefs: prefs);

        final pass = _firstPass(async, h);

        expect(pass.complete, isTrue);
        _tearDown(async, h);
      });
    });

    test("finishes when the account's listed inbox relay answers its "
        'kind-10050 list 8 s late', () {
      fakeAsync((async) {
        final pooled = _TimedRelay(
          _poolRelayUrl,
          store: history.take(20).toList(),
        );
        final h = _harness(
          async,
          pooled: pooled,
          prefs: prefs,
          dmInboxRelayUrl: _ownInboxUrl,
          tempRelay: (url) => _TimedRelay(
            url,
            store: [_ownInboxList()],
            timingFor: _inboxList(_eightSecondsLate),
          ),
        );

        final pass = _firstPass(async, h);

        expect(pass.complete, isTrue);
        _tearDown(async, h);
      });
    });

    test('finishes when the end-of-restore recovery passes are answered '
        '20 s late', () {
      fakeAsync((async) {
        final relay = _TimedRelay(
          _poolRelayUrl,
          store: history.take(20).toList(),
          honorsClose: false,
          heartbeat: const Duration(seconds: 1),
          timingFor: _reads(const [
            'dm_drain_nip04_',
            'dm_drain_k5_',
          ], _twentySecondsLate),
        );
        final h = _harness(async, pooled: relay, prefs: prefs);

        final pass = _firstPass(async, h);
        relay.stopBeating();

        expect(pass.complete, isTrue);
        _tearDown(async, h);
      });
    });

    test('records a re-read below the live window whose pages are answered '
        '20 s late', () {
      fakeAsync((async) {
        final lastWire = _now() - 86400;
        final windowStart = lastWire - 2 * 86400;
        unawaited(_establish(prefs, lastWire));
        async.flushMicrotasks();
        final relay = _TimedRelay(
          _poolRelayUrl,
          store: [
            _wrapAt(lastWire - 3600, 'in window'),
            _wrapAt(windowStart - 1, 'below the window'),
          ],
          honorsClose: false,
          heartbeat: const Duration(seconds: 1),
          timingFor: _reads(const ['dm_requery'], _twentySecondsLate),
        );
        final h = _harness(async, pooled: relay, prefs: prefs);
        unawaited(h.repository.startListening());
        async.flushMicrotasks();

        _firstPass(async, h);
        relay.stopBeating();

        expect(h.syncState.belowWindowRequeryAt(_owner), isNotNull);
        _tearDown(async, h);
      });
    });

    test('gives up on an own kind-10050 read that goes unanswered within '
        'the silence bound, not the cap', () {
      fakeAsync((async) {
        final relay = _TimedRelay(
          _poolRelayUrl,
          store: history.take(20).toList(),
          timingFor: _inboxList(_neverAnswered),
        );
        final h = _harness(async, pooled: relay, prefs: prefs);

        final pass = _firstPass(async, h);

        expect(pass.complete, isFalse);
        expect(pass.took, lessThan(const Duration(seconds: 45)));
        _tearDown(async, h);
      });
    });

    test('still gives up, about 10 s per attempt, on a relay that takes a '
        'page and then sends nothing at all', () {
      fakeAsync((async) {
        // A relay that takes each page and never answers it: no events, no
        // EOSE, and nothing else on its socket.
        final silent = _TimedRelay(
          _poolRelayUrl,
          store: const [],
          timingFor: _pages(
            (firstFrame: Duration.zero, perEvent: Duration.zero, eose: false),
          ),
        );
        final h = _harness(async, pooled: silent, prefs: prefs);

        final pass = _firstPass(async, h);

        expect(pass.complete, isFalse);
        expect(pass.took, greaterThanOrEqualTo(const Duration(seconds: 25)));
        expect(pass.took, lessThan(const Duration(seconds: 45)));
        _tearDown(async, h);
      });
    });
  });
}
