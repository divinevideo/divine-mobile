import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

import 'fixture_reader.dart';

class _Relay implements RelayGateway, RelayHistoryStatus {
  _Relay(this.events);
  final List<Map<String, dynamic>> events;
  final pending = <Future<void>>[];
  final controllers = <StreamController<Map<String, dynamic>>>[];
  @override
  bool historyLimited = false;
  @override
  Future<void> get historyReady => Future.wait(pending);
  @override
  Future<void> publish(Map<String, dynamic> event) async =>
      throw StateError('Read-only bootstrap');
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) {
    final controller = StreamController<Map<String, dynamic>>();
    controllers.add(controller);
    final done = Completer<void>();
    pending.add(done.future);
    scheduleMicrotask(() async {
      for (final event in events) {
        if ((filter['kinds'] as List).contains(event['kind']) &&
            (filter['authors'] as List).contains(event['pubkey'])) {
          controller.add(event);
        }
      }
      await Future<void>.delayed(Duration.zero);
      done.complete();
    });
    return controller.stream;
  }

  Future<void> close() async {
    for (final c in controllers) {
      await c.close();
    }
  }
}

class _DelayedStore extends InMemoryConcordStore {
  _DelayedStore(super.pubkey);
  final writing = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> writeBatch(
    Map<String, String> values, {
    List<String> remove = const [],
  }) async {
    if (!writing.isCompleted) writing.complete();
    await release.future;
    await super.writeBatch(values, remove: remove);
  }
}

void main() {
  final fixture = readConcordFixture('community-interop.json');
  final event = fixture['bundleEvent'] as Map<String, dynamic>;
  final expected = fixture['expected'] as Map;
  final fragment = ConcordInviteFragment.decode(
    Uri.parse(fixture['inviteUrl'] as String).fragment,
  );
  List<Map<String, dynamic>> events({bool incomplete = false}) => [
    event,
    ...(fixture['controlEvents'] as List).cast<Map<String, dynamic>>(),
    if (incomplete)
      ...(fixture['rejectedControlEvents'] as List)
          .cast<Map<String, dynamic>>(),
  ];
  ConcordCommunitySession session(
    _Relay relay,
    String account,
    AccountScopedStore store,
  ) => ConcordCommunitySession(
    relay: relay,
    store: store,
    linkSigner: event['pubkey'] as String,
    fragment: fragment,
    account: account,
    nowMs: () => 0,
  );
  test(
    'real session exposes only verified public control rooms and stream epochs',
    () async {
      final relay = _Relay(events());
      final s = session(
        relay,
        expected['member'] as String,
        InMemoryConcordStore('11' * 32),
      );
      await s.start();
      expect(s.ready, isTrue);
      expect(s.control!.publicChannels.map((c) => c.name).toSet(), {
        'general',
        'introductions',
      });
      for (final raw in expected['channels'] as List) {
        final c = raw as Map<String, dynamic>;
        final stream = publicChannelKey(
          s.bundle!.communityRoot,
          c['id'] as String,
          s.bundle!.rootEpoch,
        );
        expect(stream.pubkey, ((c['streams'] as List).first as Map)['pubkey']);
      }
      await s.close();
      await relay.close();
    },
  );
  test(
    'incomplete authority and banned membership fail visibly closed',
    () async {
      for (final bad in [false, true]) {
        final relay = _Relay(events(incomplete: bad));
        final s = session(
          relay,
          expected[bad ? 'member' : 'bannedMember'] as String,
          InMemoryConcordStore('22' * 32),
        );
        await expectLater(s.start(), throwsStateError);
        expect(s.ready, isFalse);
        expect(s.failure, isNotNull);
        await s.close();
        await relay.close();
      }
    },
  );
  test('a missing invite cannot open deterministic POC rooms', () async {
    final relay = _Relay([]);
    final s = session(
      relay,
      expected['member'] as String,
      InMemoryConcordStore('33' * 32),
    );
    await expectLater(s.start(), throwsStateError);
    expect(s.bundle, isNull);
    expect(s.ready, isFalse);
    await s.close();
    await relay.close();
  });
  test(
    'owner lifecycle signals stop publication; impostors do not',
    () async {
      final lifecycle = readConcordFixture('community-lifecycle.json');
      final bundleEvent = lifecycle['bundleEvent'] as Map<String, dynamic>;
      for (final name in [
        'baseRekeyEvents',
        'dissolvedEvents',
        'impostorDissolvedEvents',
      ]) {
        final relay = _Relay([
          bundleEvent,
          ...(lifecycle['controlEvents'] as List).cast<Map<String, dynamic>>(),
          ...(lifecycle[name] as List).cast<Map<String, dynamic>>(),
        ]);
        final s = ConcordCommunitySession(
          relay: relay,
          store: InMemoryConcordStore('88' * 32),
          linkSigner: bundleEvent['pubkey'] as String,
          fragment: ConcordInviteFragment.decode(
            Uri.parse(lifecycle['inviteUrl'] as String).fragment,
          ),
          account: (lifecycle['expected'] as Map)['member'] as String,
          nowMs: () => 0,
        );
        if (name == 'impostorDissolvedEvents') {
          await s.start();
          expect(s.canPublish, isTrue);
        } else {
          await expectLater(s.start(), throwsStateError);
          expect(s.canPublish, isFalse);
        }
        await s.close();
        await relay.close();
      }
    },
  );
  test(
    'malformed relay carriers do not suppress valid community authority',
    () async {
      final carriers = events();
      final valid =
          (fixture['controlEvents'] as List).first as Map<String, dynamic>;
      carriers.insert(1, {...valid, 'content': 'corrupt encrypted carrier'});
      final relay = _Relay(carriers);
      final s = session(
        relay,
        expected['member'] as String,
        InMemoryConcordStore('99' * 32),
      );
      await s.start();
      expect(s.ready, isTrue);
      expect(s.control!.publicChannels.length, 2);
      await s.close();
      await relay.close();
    },
  );
  test(
    'a refreshed invite retains old-epoch authority and accepted floors',
    () async {
      final lifecycle = readConcordFixture('community-lifecycle.json');
      final bundleEvent = lifecycle['bundleEvent'] as Map<String, dynamic>;
      final link = ConcordInviteFragment.decode(
        Uri.parse(lifecycle['inviteUrl'] as String).fragment,
      );
      final account = (lifecycle['expected'] as Map)['member'] as String;
      final store = InMemoryConcordStore(account);
      ConcordCommunitySession build(_Relay relay) => ConcordCommunitySession(
        relay: relay,
        store: store,
        linkSigner: bundleEvent['pubkey'] as String,
        fragment: link,
        account: account,
        nowMs: () => 0,
      );
      final firstRelay = _Relay([
        bundleEvent,
        ...(lifecycle['controlEvents'] as List).cast<Map<String, dynamic>>(),
      ]);
      final first = build(firstRelay);
      await first.start();
      final priorHeads = {
        for (final entry in first.control!.heads.entries)
          entry.key: entry.value.hash,
      };
      final stopped = first.changes.firstWhere((_) => !first.ready);
      for (final event in lifecycle['baseRekeyEvents'] as List) {
        firstRelay.controllers.last.add(event as Map<String, dynamic>);
      }
      await stopped.timeout(const Duration(seconds: 10));
      expect(first.canPublish, isFalse);
      await first.close();
      await firstRelay.close();
      final nextRelay = _Relay([
        lifecycle['refreshedBundleEvent'] as Map<String, dynamic>,
        ...(lifecycle['nextEpochControlEvents'] as List)
            .cast<Map<String, dynamic>>(),
      ]);
      final next = build(nextRelay);
      await next.start();
      expect(next.bundle!.rootEpoch, 1);
      expect(next.canPublish, isTrue);
      expect({
        for (final entry in next.control!.heads.entries)
          entry.key: entry.value.hash,
      }, priorHeads);
      expect(next.control!.publicChannels.map((c) => c.name).toSet(), {
        'general',
        'introductions',
      });
      await next.close();
      await nextRelay.close();
    },
  );
  test(
    'close drains a pending bootstrap write before account erasure',
    () async {
      final relay = _Relay(events());
      final store = _DelayedStore(expected['member'] as String);
      final s = session(relay, expected['member'] as String, store);
      final bootstrap = s.start();
      await store.writing.future;
      final erased = s.close().then((_) => store.clearAccount());
      await Future<void>.delayed(Duration.zero);
      store.release.complete();
      await Future.wait([bootstrap, erased]);
      expect(await store.get('community-held-roots'), isNull);
      expect(await store.get('community-control-wraps'), isNull);
      expect(await store.get('community-control-heads'), isNull);
      await relay.close();
    },
  );
}
