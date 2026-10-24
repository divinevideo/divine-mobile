import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

const creator =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const viewer =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const second =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const sound =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const address = '34236:$creator:clip';
DmMessage requestMessage(String who, String id) => DmMessage(
  id: id,
  conversationId: DmRepository.computeConversationId([creator, who]),
  senderPubkey: who,
  content: 'request',
  createdAt: 1,
  giftWrapId: sound,
  tags: [
    const ['p', creator],
    ...soundRequestTags(videoAddress: address),
  ],
);

class MemoryStore implements SoundRequestStore {
  final data = <String, SoundRequestSnapshot>{};
  bool fail = false;
  bool failRead = false;
  Completer<void>? readGate;
  bool failAcknowledgement = false;
  @override
  Future<SoundRequestSnapshot> read(String owner) async {
    await readGate?.future;
    if (failRead) throw const FormatException('unreadable');
    return data[owner] ?? const SoundRequestSnapshot();
  }

  @override
  Future<void> write(String owner, SoundRequestSnapshot value) async {
    if (fail ||
        (failAcknowledgement && value.metadataPublishedVideos.isNotEmpty)) {
      throw StateError('disk full');
    }
    data[owner] = SoundRequestSnapshot.fromJson(
      jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>,
    );
  }
}

class Transport implements SoundRequestTransport {
  Transport(this.messages);
  final List<DmMessage> messages;
  final intents = <String, SoundRequestSendIntent>{};
  bool failDelivery = false;
  bool refuseEnqueue = false;
  int enqueueAttempts = 0;
  int attempts = 0;
  final retryBudgetResets = <bool>[];
  final delivered = <String>{};
  StreamController<List<DmMessage>>? live;
  @override
  Stream<List<DmMessage>> watchMessages() =>
      live?.stream ?? Stream.value(messages);
  @override
  Future<String> enqueue(SoundRequestSendIntent intent) async {
    enqueueAttempts++;
    if (refuseEnqueue) throw const SoundRequestSendRefused();
    intents[intent.key] = intent;
    return sha256.convert(utf8.encode(intent.key)).toString();
  }

  @override
  Future<bool> isDelivered(String id) async => delivered.contains(id);

  @override
  Future<void> retry(String id, {bool resetRetryBudget = false}) async {
    attempts++;
    retryBudgetResets.add(resetRetryBudget);
    if (failDelivery) throw StateError('offline');
    delivered.add(id);
  }
}

class Publisher implements SoundRequestPublisher {
  bool enabled = false;
  bool retainedAudio = false;
  bool policyVerified = true;
  int metadataPublishes = 0;
  bool failReplacement = false;
  bool failResolve = false;
  int audioPublishes = 0;
  int resolves = 0;
  Completer<void>? resolveGate;
  VideoEvent video = VideoEvent(
    id: 'e' * 64,
    pubkey: creator,
    createdAt: 1,
    content: 'clip',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    addressableDTag: 'clip',
    eventKind: 34236,
  );
  @override
  Future<SoundRequestSource> resolve(String coordinate) async {
    resolves++;
    await resolveGate?.future;
    if (failResolve) throw const SoundRequestException('Source unavailable');
    return SoundRequestSource(
      video: video,
      allowReuse: enabled,
      requestable: true,
      audioEventId: enabled || retainedAudio ? sound : null,
    );
  }

  @override
  Future<String> publishAudio(SoundRequestSource source) async {
    audioPublishes++;
    return sound;
  }

  @override
  Future<void> enableReuse(SoundRequestSource source, String id) async {
    if (failReplacement) throw StateError('rejected');
    metadataPublishes++;
    enabled = true;
  }

  @override
  Future<bool> verifyReady(String coordinate, String id) async =>
      policyVerified && enabled && id == sound;
  @override
  Future<AudioEvent?> resolveReady(String coordinate, String id) async => null;
}

SoundRequestsRepository repository(
  String owner,
  Transport transport,
  MemoryStore store,
  Publisher publisher, {
  DateTime Function()? now,
}) => SoundRequestsRepository(
  ownerPubkey: owner,
  transport: transport,
  store: store,
  publisher: publisher,
  requestBody: (_) => 'Please enable this sound',
  readyBody: (_) => 'Your requested sound is ready',
  now: now ?? () => DateTime.utc(2026, 10, 16),
);
void main() {
  group('start', () {
    late StreamController<List<DmMessage>> live;
    late Transport transport;

    setUp(() {
      live = StreamController();
      transport = Transport([])..live = live;
    });
    tearDown(() => live.close());

    for (final incoming in [false, true]) {
      test(
        'history does not resend an undelivered job: incoming=$incoming',
        () async {
          final request = requestMessage(viewer, '1' * 64);
          final history = incoming ? [request] : <DmMessage>[];
          final publisher = Publisher();
          final repo = repository(
            incoming ? creator : viewer,
            transport..failDelivery = true,
            MemoryStore(),
            publisher,
          );
          addTearDown(repo.close);
          live.add(history);
          await repo.start();
          await expectLater(
            incoming ? repo.approve(request.id) : repo.request(address),
            throwsStateError,
          );
          expect(transport.attempts, 1);
          final job = repo.state.jobs.values.single;
          expect(job.rumorId, isNotNull);
          for (var i = 0; i < 3; i++) {
            live.add(history);
          }
          await pumpEventQueue();
          expect(transport.attempts, 1);
          expect(repo.state.jobs, hasLength(1));
          transport.failDelivery = false;
          await repo.retry(incoming ? request.id : job.rumorId!);
          expect(transport.attempts, 2);
          expect(transport.retryBudgetResets, [false, true]);
          expect(repo.state.jobs, isEmpty);
        },
      );
    }

    test('automatic fulfillment rechecks pending sound availability', () async {
      final request = requestMessage(viewer, '1' * 64);
      final publisher = Publisher()
        ..enabled = true
        ..policyVerified = false;
      var now = DateTime.utc(2026, 10, 16);
      final repo = repository(
        creator,
        transport,
        MemoryStore(),
        publisher,
        now: () => now,
      );
      addTearDown(repo.close);
      live.add([request]);
      await repo.start();
      expect(
        repo.state.requests[request.id]?.status,
        SoundRequestStatus.awaitingPolicy,
      );
      expect(transport.delivered, isEmpty);
      publisher.policyVerified = true;
      live.add([request]);
      await pumpEventQueue();
      expect(publisher.resolves, 1);
      expect(
        repo.state.requests[request.id]?.status,
        SoundRequestStatus.awaitingPolicy,
      );
      now = now.add(SoundRequestsRepository.backgroundRecheckInterval);
      live.add([request]);
      await pumpEventQueue();
      expect(repo.state.requests[request.id]?.status, SoundRequestStatus.ready);
      expect(transport.delivered, hasLength(1));
      expect(publisher.audioPublishes, 0);
      expect(publisher.metadataPublishes, 0);
    });

    test('a failed lookup is retried after the recheck interval', () async {
      final request = requestMessage(viewer, '1' * 64);
      final publisher = Publisher()
        ..enabled = true
        ..failResolve = true;
      var now = DateTime.utc(2026, 10, 16);
      final repo = repository(
        creator,
        transport,
        MemoryStore(),
        publisher,
        now: () => now,
      );
      addTearDown(repo.close);
      live.add([request]);
      await repo.start();
      expect(publisher.resolves, 1);
      for (var i = 0; i < 3; i++) {
        live.add([request]);
      }
      await pumpEventQueue();
      expect(publisher.resolves, 1);
      publisher.failResolve = false;
      now = now.add(SoundRequestsRepository.backgroundRecheckInterval);
      live.add([request]);
      await pumpEventQueue();
      expect(publisher.resolves, 2);
      expect(repo.state.requests[request.id]?.status, SoundRequestStatus.ready);
      expect(transport.delivered, hasLength(1));
    });

    test('unchanged history does not look up pending requests again', () async {
      final a = requestMessage(viewer, '1' * 64);
      final publisher = Publisher();
      final repo = repository(creator, transport, MemoryStore(), publisher);
      addTearDown(repo.close);
      live.add([a]);
      await repo.start();
      expect(publisher.resolves, 1);
      for (var i = 0; i < 3; i++) {
        live.add([a]);
      }
      await pumpEventQueue();
      expect(publisher.resolves, 1);
    });

    test(
      'a new request is checked against reuse enabled since the last check',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final b = requestMessage(second, '2' * 64);
        final publisher = Publisher();
        final repo = repository(creator, transport, MemoryStore(), publisher);
        addTearDown(repo.close);
        live.add([a]);
        await repo.start();
        expect(repo.state.requests[a.id]?.status, SoundRequestStatus.pending);
        publisher.enabled = true;
        live.add([a, b]);
        await pumpEventQueue();
        expect(publisher.resolves, 2);
        expect(
          repo.state.requests.values.map((r) => r.status),
          everyElement(SoundRequestStatus.ready),
        );
        expect(transport.delivered, hasLength(2));
      },
    );

    test('history arriving during a pass is reconciled once', () async {
      final a = requestMessage(viewer, '1' * 64);
      final b = requestMessage(second, '2' * 64);
      final c = requestMessage(viewer, '3' * 64);
      final gate = Completer<void>();
      final publisher = Publisher()..resolveGate = gate;
      final repo = repository(creator, transport, MemoryStore(), publisher);
      addTearDown(repo.close);
      live.add([a]);
      final started = repo.start();
      await pumpEventQueue();
      expect(publisher.resolves, 1);
      live
        ..add([a, b])
        ..add([a, b, c]);
      await pumpEventQueue();
      gate.complete();
      await started;
      expect(publisher.resolves, 2);
      expect(repo.state.requests.keys, containsAll([a.id, b.id, c.id]));
    });

    test(
      'an approval awaiting policy is rechecked as history changes',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final publisher = Publisher()..policyVerified = false;
        final repo = repository(creator, transport, MemoryStore(), publisher);
        addTearDown(repo.close);
        live.add([a]);
        await repo.start();
        await repo.approve(a.id);
        expect(
          repo.state.requests[a.id]?.status,
          SoundRequestStatus.awaitingPolicy,
        );
        publisher.policyVerified = true;
        live.add([a]);
        await pumpEventQueue();
        expect(repo.state.requests[a.id]?.status, SoundRequestStatus.ready);
        expect(transport.delivered, hasLength(1));
      },
    );
  });

  group('restore', () {
    for (final startPending in [false, true]) {
      test(
        'actions cannot overwrite unrestored state: pending=$startPending',
        () async {
          final stored = SoundRequestSnapshot(
            requests: {
              '1' * 64: SoundRequestEntry(
                id: '1' * 64,
                requester: viewer,
                videoAddress: address,
                status: SoundRequestStatus.dismissed,
              ),
            },
          );
          final gate = Completer<void>();
          final store = MemoryStore()
            ..data[viewer] = stored
            ..readGate = gate;
          final transport = Transport([]);
          final publisher = Publisher();
          final repo = repository(viewer, transport, store, publisher);
          addTearDown(repo.close);
          final started = startPending ? repo.start() : null;
          await expectLater(
            repo.request(address),
            throwsA(isA<SoundRequestException>()),
          );
          expect(store.data[viewer], same(stored));
          expect(publisher.resolves, 0);
          expect(transport.intents, isEmpty);
          gate.complete();
          await started;
          if (!startPending) await repo.start();
          expect(
            repo.state.requests.values.single.status,
            SoundRequestStatus.dismissed,
          );
          // Successful restoration allows the next explicit request normally.
          await repo.request(address);
          expect(transport.delivered, hasLength(1));
        },
      );
    }

    test('a failed restore does not overwrite the stored records', () async {
      final transport = Transport([]);
      final store = MemoryStore();
      final publisher = Publisher();
      final earlier = repository(viewer, transport, store, publisher);
      await earlier.start();
      await earlier.request(address);
      await earlier.close();
      final stored = store.data[viewer];
      expect(stored?.requests, hasLength(1));
      store.failRead = true;
      final repo = repository(viewer, transport, store, publisher);
      addTearDown(repo.close);
      await expectLater(repo.start(), throwsFormatException);
      await expectLater(
        repo.request('34236:$creator:other'),
        throwsA(isA<SoundRequestException>()),
      );
      expect(store.data[viewer], stored);
      expect(transport.intents, hasLength(1));
    });
  });

  group('request', () {
    test(
      'a source that is no longer requestable is an expected failure',
      () async {
        final publisher = Publisher()..enabled = true;
        final transport = Transport([]);
        final repo = repository(viewer, transport, MemoryStore(), publisher);
        addTearDown(repo.close);
        await repo.start();
        await expectLater(
          repo.request(address),
          throwsA(isA<SoundRequestException>()),
        );
        expect(transport.intents, isEmpty);
      },
    );
  });

  group('request send refusal', () {
    test('does not auto-send a refused request after restart', () async {
      final transport = Transport([])..refuseEnqueue = true;
      final store = MemoryStore();
      final publisher = Publisher();
      final repo = repository(viewer, transport, store, publisher);
      await repo.start();
      await expectLater(
        repo.request(address),
        throwsA(isA<SoundRequestSendRefused>()),
      );
      expect(repo.state.jobs, isEmpty);
      expect(repo.state.requests, isEmpty);
      await repo.close();
      transport.refuseEnqueue = false;
      final resumed = repository(viewer, transport, store, publisher);
      addTearDown(resumed.close);
      await resumed.start();
      expect(transport.enqueueAttempts, 1);
      // Only a new explicit request may try again after the policy changes.
      await resumed.request(address);
      expect(transport.enqueueAttempts, 2);
      expect(transport.delivered, hasLength(1));
    });

    test('does not auto-send a refused ready reply after restart', () async {
      final request = requestMessage(viewer, '1' * 64);
      final transport = Transport([request])..refuseEnqueue = true;
      final store = MemoryStore();
      final publisher = Publisher();
      final repo = repository(creator, transport, store, publisher);
      await repo.start();
      await expectLater(
        repo.approve(request.id),
        throwsA(isA<SoundRequestSendRefused>()),
      );
      expect(repo.state.jobs, isEmpty);
      await repo.close();
      transport.refuseEnqueue = false;
      final resumed = repository(creator, transport, store, publisher);
      addTearDown(resumed.close);
      await resumed.start();
      expect(transport.enqueueAttempts, 1);
      expect(transport.delivered, isEmpty);
      expect(publisher.audioPublishes, 1);
    });
  });
  group('dismiss', () {
    test(
      'dismissing the last failed approval does not approve later requests',
      () async {
        final first = requestMessage(viewer, '1' * 64);
        final transport = Transport([first]);
        final store = MemoryStore();
        final publisher = Publisher()..failReplacement = true;
        final repo = repository(creator, transport, store, publisher);
        await repo.start();
        await expectLater(repo.approve(first.id), throwsStateError);
        await repo.dismiss(first.id);
        await repo.close();
        publisher.failReplacement = false;
        transport.messages.add(requestMessage(second, '2' * 64));
        final resumed = repository(creator, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        expect(publisher.enabled, isFalse);
        expect(transport.intents, isEmpty);
      },
    );
  });
  group('retry', () {
    test(
      'lost acknowledgement checkpoint cannot replay consent after revision',
      () async {
        final request = requestMessage(viewer, '1' * 64);
        final transport = Transport([request]);
        final store = MemoryStore()..failAcknowledgement = true;
        final publisher = Publisher()
          ..retainedAudio = true
          ..policyVerified = false;
        final repo = repository(creator, transport, store, publisher);
        await repo.start();
        await expectLater(repo.approve(request.id), throwsStateError);
        expect(publisher.metadataPublishes, 1);
        await repo.close();
        store.failAcknowledgement = false;
        publisher
          ..enabled = false
          ..video = publisher.video.copyWith(id: '9' * 64);
        final resumed = repository(creator, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        expect(publisher.enabled, isFalse);
        expect(publisher.metadataPublishes, 1);
        expect(
          resumed.state.requests[request.id]?.status,
          SoundRequestStatus.pending,
        );
        // A new explicit approval can enable sharing on the changed revision.
        publisher.policyVerified = true;
        await resumed.approve(request.id);
        expect(publisher.enabled, isTrue);
        expect(publisher.metadataPublishes, 2);
      },
    );

    for (final retained in [true, false]) {
      test(
        'accepted metadata respects revocation: retained=$retained',
        () async {
          final request = requestMessage(viewer, '1' * 64);
          final transport = Transport([request]);
          final store = MemoryStore();
          final publisher = Publisher()
            ..retainedAudio = retained
            ..policyVerified = false;
          final repo = repository(creator, transport, store, publisher);
          await repo.start();
          await repo.approve(request.id);
          expect(
            repo.state.requests[request.id]?.status,
            SoundRequestStatus.awaitingPolicy,
          );
          await repo.close();
          publisher.enabled = false;
          final resumed = repository(creator, transport, store, publisher);
          addTearDown(resumed.close);
          await resumed.start();
          await resumed.retry(request.id);
          expect(publisher.enabled, isFalse);
          expect(publisher.metadataPublishes, 1);
          expect(transport.intents, isEmpty);
        },
      );
    }

    test('rechecks an automatic reply awaiting policy', () async {
      final request = requestMessage(viewer, '1' * 64);
      final transport = Transport([request]);
      final publisher = Publisher()
        ..enabled = true
        ..policyVerified = false;
      final repo = repository(creator, transport, MemoryStore(), publisher);
      addTearDown(repo.close);
      await repo.start();
      expect(
        repo.state.requests[request.id]?.status,
        SoundRequestStatus.awaitingPolicy,
      );
      expect(repo.state.approvedVideos, isEmpty);
      publisher.policyVerified = true;
      await repo.retry(request.id);
      expect(repo.state.requests[request.id]?.status, SoundRequestStatus.ready);
      expect(transport.delivered, hasLength(1));
      expect(publisher.audioPublishes, 0);
      expect(publisher.metadataPublishes, 0);
    });

    test(
      'an automatic reply awaiting policy returns to pending once reuse is off',
      () async {
        final request = requestMessage(viewer, '1' * 64);
        final transport = Transport([request]);
        final publisher = Publisher()
          ..enabled = true
          ..policyVerified = false;
        final repo = repository(creator, transport, MemoryStore(), publisher);
        addTearDown(repo.close);
        await repo.start();
        expect(
          repo.state.requests[request.id]?.status,
          SoundRequestStatus.awaitingPolicy,
        );
        publisher.enabled = false;
        await repo.retry(request.id);
        expect(
          repo.state.requests[request.id]?.status,
          SoundRequestStatus.pending,
        );
        expect(transport.intents, isEmpty);
        // The creator can now approve it explicitly.
        publisher.policyVerified = true;
        await repo.approve(request.id);
        expect(publisher.metadataPublishes, 1);
        expect(transport.delivered, hasLength(1));
      },
    );

    test(
      'retries approval when original audio reference predates approval',
      () async {
        final request = requestMessage(viewer, '1' * 64);
        final publisher = Publisher()
          ..retainedAudio = true
          ..failReplacement = true;
        final repo = repository(
          creator,
          Transport([request]),
          MemoryStore(),
          publisher,
        );
        addTearDown(repo.close);
        await repo.start();
        await expectLater(repo.approve(request.id), throwsStateError);
        publisher.failReplacement = false;
        await repo.retry(request.id);
        expect(publisher.enabled, isTrue);
        expect(
          repo.state.requests[request.id]?.status,
          SoundRequestStatus.ready,
        );
      },
    );
  });

  for (final reversed in [true, false]) {
    for (final fulfilled in [true, false]) {
      group('interactions', () {
        test(
          'reconstructs consent cycles: reversed=$reversed '
          'fulfilled=$fulfilled',
          () async {
            final first = requestMessage(viewer, '1' * 64);
            final next = requestMessage(viewer, '2' * 64);
            DmMessage ready(String id, String requestId) => DmMessage(
              id: id,
              conversationId: first.conversationId,
              senderPubkey: creator,
              content: 'ready',
              createdAt: 2,
              giftWrapId: sound,
              tags: [
                const ['p', viewer],
                ...soundReadyTags(
                  videoAddress: address,
                  requestId: requestId,
                  audioEventId: sound,
                ),
              ],
            );
            final history = [
              first,
              ready('3' * 64, first.id),
              next,
              if (fulfilled) ready('4' * 64, next.id),
            ];
            final repo = repository(
              viewer,
              Transport(reversed ? history.reversed.toList() : history),
              MemoryStore(),
              Publisher(),
            );
            addTearDown(repo.close);
            await repo.start();
            expect(
              repo.state.requests[first.id]?.status,
              SoundRequestStatus.ready,
            );
            expect(
              repo.state.requests[next.id]?.status,
              fulfilled ? SoundRequestStatus.ready : SoundRequestStatus.pending,
            );
          },
        );
      });
    }
  }

  group('interactions', () {
    test(
      'a fulfilled requester can ask again after reuse is disabled',
      () async {
        final transport = Transport([]);
        final store = MemoryStore();
        final publisher = Publisher();
        final repo = repository(viewer, transport, store, publisher);
        await repo.start();
        final first = await repo.request(address);
        await repo.close();
        final snapshot = store.data[viewer]!;
        store.data[viewer] = snapshot.copyWith(
          requests: {
            first: snapshot.requests[first]!.copyWith(
              status: SoundRequestStatus.ready,
            ),
          },
        );
        final resumed = repository(viewer, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        final next = await resumed.request(address);
        expect(next, isNot(first));
        expect(transport.intents, hasLength(2));
      },
    );
  });

  group('interactions', () {
    test(
      'completed approval cannot enable reuse again for a later request',
      () async {
        final first = requestMessage(viewer, '1' * 64);
        final transport = Transport([first]);
        final store = MemoryStore();
        final publisher = Publisher();
        final repo = repository(creator, transport, store, publisher);
        await repo.start();
        await repo.approve(first.id);
        await repo.close();
        publisher.enabled = false;
        transport.messages.add(requestMessage(second, '2' * 64));
        final resumed = repository(creator, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        expect(publisher.enabled, isFalse);
        expect(transport.delivered, hasLength(1));
      },
    );
  });
  group('interactions', () {
    test('repeated approval does not send another ready reply', () async {
      final first = requestMessage(viewer, '1' * 64);
      final transport = Transport([first]);
      final store = MemoryStore();
      final publisher = Publisher();
      final repo = repository(creator, transport, store, publisher);
      addTearDown(repo.close);
      await repo.start();
      await repo.approve(first.id);
      await repo.approve(first.id);
      expect(publisher.audioPublishes, 1);
      expect(transport.attempts, 1);
    });
  });

  group('interactions', () {
    test(
      'one approval publishes once and replies to all pending requesters',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final b = requestMessage(second, '2' * 64);
        final transport = Transport([a, b]);
        final store = MemoryStore();
        final publisher = Publisher();
        final repo = repository(creator, transport, store, publisher);
        addTearDown(repo.close);
        await repo.start();
        await repo.approve(a.id);
        expect(publisher.audioPublishes, 1);
        expect(transport.delivered, hasLength(2));
        expect(
          repo.state.requests.values.map((r) => r.status),
          everyElement(SoundRequestStatus.ready),
        );
      },
    );
  });
  group('interactions', () {
    test(
      'replacement failure sends no reply and retry reuses the published audio',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final transport = Transport([a]);
        final store = MemoryStore();
        final publisher = Publisher()..failReplacement = true;
        final repo = repository(creator, transport, store, publisher);
        addTearDown(repo.close);
        await repo.start();
        await expectLater(repo.approve(a.id), throwsStateError);
        expect(transport.intents, isEmpty);
        expect(publisher.audioPublishes, 1);
        publisher.failReplacement = false;
        await repo.retry(a.id);
        expect(publisher.audioPublishes, 1);
        expect(transport.delivered, hasLength(1));
      },
    );
  });
  group('interactions', () {
    test(
      'restart observes outbox delivery without resending or republishing',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final store = MemoryStore();
        final publisher = Publisher();
        final transport = Transport([a])..failDelivery = true;
        final repo = repository(creator, transport, store, publisher);
        await repo.start();
        await expectLater(repo.approve(a.id), throwsStateError);
        await repo.close();
        expect(store.data[creator]!.jobs, isNotEmpty);
        transport.failDelivery = false;
        final resumed = repository(creator, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        expect(publisher.audioPublishes, 1);
        expect(transport.attempts, 1);
        expect(transport.delivered, isEmpty);
        expect(resumed.state.jobs, hasLength(1));
        // The shared outbox service delivers independently of this lifecycle.
        transport.delivered.add(resumed.state.jobs.values.single.rumorId!);
        await resumed.close();
        final delivered = repository(creator, transport, store, publisher);
        addTearDown(delivered.close);
        await delivered.start();
        expect(transport.delivered, hasLength(1));
        expect(delivered.state.jobs, isEmpty);
        expect(transport.attempts, 1);
        expect(publisher.audioPublishes, 1);
      },
    );
  });
  group('interactions', () {
    test(
      'dismissal survives history replay and does not receive a ready reply',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final b = requestMessage(second, '2' * 64);
        final transport = Transport([a, b]);
        final store = MemoryStore();
        final publisher = Publisher();
        final repo = repository(creator, transport, store, publisher);
        await repo.start();
        await repo.dismiss(a.id);
        await repo.approve(b.id);
        await repo.close();
        final resumed = repository(creator, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        expect(
          resumed.state.requests[a.id]!.status,
          SoundRequestStatus.dismissed,
        );
        expect(transport.intents.values.map((j) => j.recipient), [second]);
      },
    );
  });
  group('interactions', () {
    test(
      'duplicate request taps and restart reuse the same persisted intent',
      () async {
        final transport = Transport([])..failDelivery = true;
        final store = MemoryStore();
        final publisher = Publisher();
        final repo = repository(viewer, transport, store, publisher);
        await repo.start();
        await expectLater(repo.request(address), throwsStateError);
        final first = store.data[viewer]!.jobs.values.single;
        expect(await repo.request(address), first.rumorId);
        await repo.close();
        final resumed = repository(viewer, transport, store, publisher);
        addTearDown(resumed.close);
        await resumed.start();
        expect(
          store.data[viewer]!.jobs.values.single,
          first.withRumor(sha256.convert(utf8.encode(first.key)).toString()),
        );
        expect(transport.intents, hasLength(1));
      },
    );
  });
  group('interactions', () {
    test(
      'persistence failure prevents publishing and preserves previous state',
      () async {
        final a = requestMessage(viewer, '1' * 64);
        final store = MemoryStore();
        final publisher = Publisher();
        final repo = repository(creator, Transport([a]), store, publisher);
        addTearDown(repo.close);
        await repo.start();
        store.fail = true;
        await expectLater(repo.approve(a.id), throwsStateError);
        expect(publisher.audioPublishes, 0);
        expect(repo.state.approvedVideos, isEmpty);
      },
    );
  });
}
