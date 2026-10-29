import 'dart:convert';
import 'dart:io';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/challenges/challenge_app_session.dart';
import 'package:openvine/services/challenges/challenge_nostr_adapter.dart';
import 'package:openvine/services/challenges/sqlite_challenge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../packages/challenges_repository/test/harness.dart' show Harness;
import '../../../packages/challenges_repository/test/synthetic.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {
  _Client(this.definition);
  final NostrEvent definition;
  List<NostrEvent>? definitions;
  final requestedRelays = <List<String>>[];
  final publishedBodies = <String>[];
  final publishedTargets = <List<String>>[];
  String? acceptedRelay;
  @override
  Future<PublishOutcome> publishEventAwaitOk(
    Event event, {
    List<String>? targetRelays,
    Duration timeout = const Duration(seconds: 15),
    String? diagnosticTag,
  }) async {
    publishedBodies.add(jsonEncode(event.toJson()));
    publishedTargets.add(targetRelays!);
    return PublishOutcome(
      eventId: event.id,
      acceptedBy: [?acceptedRelay],
      rejectedBy: const {},
      noResponseFrom: targetRelays
          .where((relay) => relay != acceptedRelay)
          .toList(),
    );
  }

  @override
  List<String> get configuredRelays => const ['wss://configured.example.test'];
  @override
  List<String> get writableRelays => configuredRelays;
  @override
  bool isRelayAllowed(String relay) => true;
  @override
  Future<QueryResult> readEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useCache = true,
    bool useQueryPool = true,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
    int? maxCollectedEvents,
    int? maxCollectedBytes,
  }) async {
    requestedRelays.add(tempRelays!);
    return QueryResult(
      events: filters.single.kinds!.contains(31923)
          ? (definitions ?? [definition])
                .where(
                  (event) => event.tags.any(
                    (tag) =>
                        tag.length > 1 &&
                        tag.first == 'd' &&
                        tag[1] == filters.single.d!.single,
                  ),
                )
                .map((event) => Event.fromJson(event.toJson()))
                .toList()
          : [],
      endedBy: QueryEnd.complete,
      answeredNetworkRelayCount: tempRelays
          .where((relay) => !relay.contains('dead'))
          .length,
    );
  }
}

void main() {
  group('ChallengeAppSession recording and handoff', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test(
      'fresh retry seeds only verified original and delivery coordinate relays',
      () async {
        final h = Harness();
        // Choose SDK serialization before durable insertion, as the app signer
        // does. Hydration and retry must preserve this exact body.
        h.signer = (fields) async => jsonEncode(
          Event.fromJson(
            jsonDecode(h.signFields(fields)) as Map<String, dynamic>,
          ).toJson(),
        );
        final initial = (await h.repository.submit(await h.prepare())).action!;
        const migratedRelay = 'wss://migration.example.test';
        h.source.records = [
          jsonEncode(
            h.organizer.definition(createdAt: 151, relay: migratedRelay),
          ),
        ];
        final migrated = (await h.repository.retry(initial.review.id)).action!;
        final directory = await Directory.systemTemp.createTemp(
          'fresh-relay-retry-',
        );
        final file = File('${directory.path}/app.sqlite');
        var db = AppDatabase.test(NativeDatabase(file));
        var store = await SqliteChallengeStore.open(
          dao: db.challengeRecordsDao,
          owner: h.creator.pubkey,
          currentOwner: () => h.creator.pubkey,
        );
        await store.insertAction(h.creator.pubkey, migrated);
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        addTearDown(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        store = await SqliteChallengeStore.open(
          dao: db.challengeRecordsDao,
          owner: h.creator.pubkey,
          currentOwner: () => h.creator.pubkey,
        );
        final client = _Client(migrated.deliveryDefinition!)
          ..acceptedRelay = migratedRelay;
        final session = ChallengeAppSession(
          store: store,
          auth: _Auth(),
          nostr: client,
          isVisible: (_) => true,
          canPublish: (_) => true,
          currentVideoId: (_) => h.video.id,
        );
        final result = await session.submissions.retry(migrated.review.id);
        expect(result.status, SubmissionStatus.submitted);
        expect(result.action!.signedBody, initial.signedBody);
        expect(client.publishedBodies, [initial.signedBody]);
        expect(client.publishedTargets.single.toSet(), {
          h.relay,
          migratedRelay,
          ...client.configuredRelays,
        });
        expect(h.signatures, 1);
        expect(client.requestedRelays.last.toSet(), {
          h.relay,
          migratedRelay,
          ...client.configuredRelays,
        });
        final unrelated = NostrEvent.fromJson(
          h.organizer.definition(
            identifier: 'unrelated',
            relay: 'wss://unrelated.example.test',
          ),
        );
        client.definitions = [unrelated];
        await session.reads.refresh('31923:${h.organizer.pubkey}:unrelated');
        expect(client.requestedRelays.last, client.configuredRelays);
      },
    );
    test(
      'exactly16 selected relays complete;17 distinct relays truncate',
      () async {
        final signer = SyntheticSigner();
        final definition = NostrEvent.fromJson(signer.definition());
        final client = _Client(definition);
        for (final count in [16, 17]) {
          final adapter = ChallengeNostrAdapter(
            client: client,
            knownRelays: () => [
              for (var i = 0; i < count; i++) 'wss://relay$i.example.test',
            ],
            checkOwner: () async {},
          );
          final read = await adapter.read(
            '31923:${signer.pubkey}:synthetic:challenge',
          );
          expect(client.requestedRelays.last, hasLength(16));
          expect(read.revisionsComplete, count == 16);
        }
      },
    );
    test('challenge relay selection stays coordinate scoped across many recordings', () async {
      SharedPreferences.setMockInitialValues({});
      final signer = SyntheticSigner();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      NostrEvent definition(String id, String relay) => NostrEvent.fromJson(
        signer.definition(
          identifier: id,
          relay: relay,
          createdAt: now - 5,
          start: now - 10,
          end: now + 300,
        ),
      );
      final bad = definition('unreachable', 'wss://dead.example.test');
      final client = _Client(bad);
      final directory = await Directory.systemTemp.createTemp(
        'coordinate-relays-',
      );
      final db = AppDatabase.test(
        NativeDatabase(File('${directory.path}/app.sqlite')),
      );
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      final session = ChallengeAppSession(
        store: await SqliteChallengeStore.open(
          dao: db.challengeRecordsDao,
          owner: signer.pubkey,
          currentOwner: () => signer.pubkey,
        ),
        auth: _Auth(),
        nostr: client,
        isVisible: (_) => true,
        canPublish: (_) => true,
        currentVideoId: (_) => null,
      );
      await expectLater(
        session.prepareRecording(recordingId: 'bad', definition: bad),
        throwsA(isA<SubmissionException>()),
      );
      for (var i = 0; i < 20; i++) {
        final good = definition(
          'challenge-$i',
          'wss://organizer$i.example.test',
        );
        client.definitions = [good];
        await session.prepareRecording(
          recordingId: 'recording-$i',
          definition: good,
        );
        expect(client.requestedRelays.last.toSet(), {
          'wss://organizer$i.example.test',
          ...client.configuredRelays,
        });
      }
    });
    test(
      'recording and exact successful-video review survive SQLite reopen',
      () async {
        SharedPreferences.setMockInitialValues({});
        // This test turns the client tag off, and later suites in the merged
        // run would inherit it. resetForTest() clears only the cache, so the
        // persisted preference is wiped too.
        addTearDown(() {
          SharedPreferences.setMockInitialValues({});
          Nip89ClientTag.resetForTest();
        });
        await Nip89ClientTag.setEnabled(enabled: true);
        final organizer = SyntheticSigner();
        final creator = SyntheticSigner();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final definition = NostrEvent.fromJson(
          organizer.definition(
            createdAt: now - 20,
            start: now - 10,
            end: now + 300,
          ),
        );
        final video = NostrEvent.fromJson(
          creator.sign(
            kind: 34236,
            createdAt: now,
            tags: [
              ['d', 'synthetic-video'],
            ],
          ),
        );
        final client = _Client(definition);
        final auth = _Auth();
        final directory = await Directory.systemTemp.createTemp(
          'challenge-session-',
        );
        final file = File('${directory.path}/app.sqlite');
        var db = AppDatabase.test(NativeDatabase(file));
        String? owner = creator.pubkey;
        Future<ChallengeAppSession> open() async => ChallengeAppSession(
          store: await SqliteChallengeStore.open(
            dao: db.challengeRecordsDao,
            owner: creator.pubkey,
            currentOwner: () => owner,
          ),
          auth: auth,
          nostr: client,
          isVisible: (_) => true,
          canPublish: (_) => true,
          currentVideoId: (_) => video.id,
        );
        var session = await open();
        final context = await session.prepareRecording(
          recordingId: 'recording',
          definition: definition,
        );
        expect(context.clientTags, [Nip89ClientTag.tag]);
        final draft = DivineVideoDraft.create(
          id: 'publish',
          clips: const [],
          title: '',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
          challengeContext: context,
        ).copyWith(sourceDraftId: 'source');
        final signedVideo = jsonEncode(Event.fromJson(video.toJson()).toJson());
        await session.recordPublished(draft, signedVideo);
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        addTearDown(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        session = await open();
        expect(
          (await session.recording('recording'))!.definition.id,
          definition.id,
        );
        final handoff = jsonDecode(
          (await session.store.readRecord('handoff', 'recording'))!,
        ) as Map<String, dynamic>;
        expect(handoff['signedVideo'], signedVideo);
        final review = await session.reviewPublished('recording');
        expect(review.video.id, video.id);
        expect(review.fields.tags, contains(equals(Nip89ClientTag.tag)));
        verifyZeroInteractions(auth);
        await Nip89ClientTag.setEnabled(enabled: false);
        expect(
          (await session.submissions.submit(review)).status,
          SubmissionStatus.reviewRequired,
        );
        verifyZeroInteractions(auth);
        await db.challengeRecordsDao.removeOwner(creator.pubkey);
        final replacement = await open();
        expect(replacement.store.generation, isNot(context.generation));
        expect(await replacement.recording('recording'), isNull);
        await expectLater(
          replacement.recordPublished(draft, signedVideo),
          throwsA(isA<ChallengeOwnerRevoked>()),
        );
        expect(
          await replacement.store.readRecord('handoff', 'recording'),
          isNull,
        );
        final fresh = await replacement.prepareRecording(
          recordingId: 'fresh-recording',
          definition: definition,
        );
        expect(fresh.generation, replacement.store.generation);
        await replacement.recordPublished(
          draft.copyWith(challengeContext: fresh),
          signedVideo,
        );
        expect(
          await replacement.store.readRecord('handoff', 'fresh-recording'),
          isNotNull,
        );
        owner = null;
        await expectLater(
          session.recordPublished(draft, signedVideo),
          throwsA(isA<ChallengeOwnerRevoked>()),
        );
      },
    );
  });
}
