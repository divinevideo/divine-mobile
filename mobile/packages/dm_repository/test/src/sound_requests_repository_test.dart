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
  @override
  Future<SoundRequestSnapshot> read(String owner) async =>
      data[owner] ?? const SoundRequestSnapshot();
  @override
  Future<void> write(String owner, SoundRequestSnapshot value) async {
    if (fail) throw StateError('disk full');
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
  int attempts = 0;
  final delivered = <String>{};
  @override
  Stream<List<DmMessage>> watchMessages() => Stream.value(messages);
  @override
  Future<String> enqueue(SoundRequestSendIntent intent) async {
    intents[intent.key] = intent;
    return sha256.convert(utf8.encode(intent.key)).toString();
  }

  @override
  Future<void> retry(String id) async {
    attempts++;
    if (failDelivery) throw StateError('offline');
    delivered.add(id);
  }
}

class Publisher implements SoundRequestPublisher {
  bool enabled = false;
  bool failReplacement = false;
  int audioPublishes = 0;
  final video = VideoEvent(
    id: 'e' * 64,
    pubkey: creator,
    createdAt: 1,
    content: 'clip',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    addressableDTag: 'clip',
    eventKind: 34236,
  );
  @override
  Future<SoundRequestSource> resolve(String coordinate) async =>
      SoundRequestSource(
        video: video,
        allowReuse: enabled,
        requestable: true,
        audioEventId: enabled ? sound : null,
      );
  @override
  Future<String> publishAudio(SoundRequestSource source) async {
    audioPublishes++;
    return sound;
  }

  @override
  Future<void> enableReuse(SoundRequestSource source, String id) async {
    if (failReplacement) throw StateError('rejected');
    enabled = true;
  }

  @override
  Future<bool> verifyReady(String coordinate, String id) async =>
      enabled && id == sound;
  @override
  Future<AudioEvent?> resolveReady(String coordinate, String id) async => null;
}

SoundRequestsRepository repository(
  String owner,
  Transport transport,
  MemoryStore store,
  Publisher publisher,
) => SoundRequestsRepository(
  ownerPubkey: owner,
  transport: transport,
  store: store,
  publisher: publisher,
  requestBody: (_) => 'Please enable this sound',
  readyBody: (_) => 'Your requested sound is ready',
  now: () => DateTime.utc(2026, 10, 16),
);
void main() {
  test('a fulfilled requester can ask again after reuse is disabled', () async {
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
  });

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
  test(
    'restart after failed reply retries delivery without republishing',
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
      expect(transport.delivered, hasLength(1));
      expect(resumed.state.jobs, isEmpty);
    },
  );
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
      await expectLater(repo.request(address), throwsStateError);
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
}
