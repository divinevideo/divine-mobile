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
import 'package:openvine/services/challenges/sqlite_challenge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../packages/challenges_repository/test/synthetic.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {
  _Client(this.definition);
  final NostrEvent definition;
  @override
  List<String> get configuredRelays => const ['wss://relay.example.test'];
  @override
  List<String> get writableRelays => configuredRelays;
  @override
  bool isRelayAllowed(String relay) => configuredRelays.contains(relay);
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
  }) async => QueryResult(
    events: filters.single.kinds!.contains(31923)
        ? [Event.fromJson(definition.toJson())]
        : [],
    endedBy: QueryEnd.complete,
    answeredNetworkRelayCount: 1,
  );
}

void main() {
  group('ChallengeAppSession recording and handoff', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test(
      'recording and exact successful-video review survive SQLite reopen',
      () async {
        SharedPreferences.setMockInitialValues({});
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
        var recoveryWrites = 0;
        await expectLater(
          replacement.recoverPublishedDraft(draft, () async {
            recoveryWrites++;
          }),
          throwsA(isA<ChallengeOwnerRevoked>()),
        );
        expect(recoveryWrites, 0);
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
