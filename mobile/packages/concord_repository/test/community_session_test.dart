import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

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
            (filter['authors'] as List).contains(event['pubkey']))
          controller.add(event);
      }
      await Future<void>.delayed(Duration.zero);
      done.complete();
    });
    return controller.stream;
  }

  Future<void> close() async {
    for (final c in controllers) await c.close();
  }
}

void main() {
  final fixture =
      jsonDecode(
            File(
              '../concord_protocol/test/fixtures/community-interop.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
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
      for (final c in expected['channels'] as List) {
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
    'owner rotation and dissolution stop publication while impostor tombstones do not',
    () async {
      final lifecycle =
          jsonDecode(
                File(
                  '../concord_protocol/test/fixtures/community-lifecycle.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
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
}
