import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:challenges_repository/challenges_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/challenge_recording_context.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/account_state_write_barrier.dart';
import 'package:openvine/services/challenges/sqlite_challenge_store.dart';

import '../../../packages/challenges_repository/test/harness.dart' show Harness;

class _HeldDao extends ChallengeRecordsDao {
  _HeldDao(super.attachedDatabase);
  Completer<void>? entered;
  Completer<void>? release;
  String heldCategory = 'action';
  @override
  Future<String> put(
    String owner,
    String generation,
    String category,
    String key,
    String payload, {
    String? signedBody,
    bool insertOnly = false,
  }) async {
    if (category == heldCategory && release != null) {
      entered!.complete();
      await release!.future;
    }
    return super.put(
      owner,
      generation,
      category,
      key,
      payload,
      signedBody: signedBody,
      insertOnly: insertOnly,
    );
  }
}

void main() {
  group('SQLite app challenge adapter', () {
    for (final category in ['retained', 'context']) {
      test(
        'paused app $category write stays revoked after real owner cleanup',
        () async {
          final h = Harness();
          final directory = await Directory.systemTemp.createTemp(
            'challenge-journal-race-',
          );
          final db = AppDatabase.test(
            NativeDatabase(File('${directory.path}/app.sqlite')),
          );
          addTearDown(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
          final dao = _HeldDao(db)
            ..heldCategory = category
            ..entered = Completer<void>()
            ..release = Completer<void>();
          final store = await SqliteChallengeStore.open(
            dao: dao,
            owner: h.creator.pubkey,
            currentOwner: () => h.owner,
          );
          final barrier = AccountStateWriteBarrier();
          barrier.register(h.creator.pubkey, store.retire);
          final pending = category == 'retained'
              ? store.replace(
                  '31923:${h.organizer.pubkey}:synthetic:challenge',
                  [jsonEncode(h.definition.toJson())],
                  limited: false,
                )
              : store.writeRecord(
                  'context',
                  'recording',
                  jsonEncode(
                    ChallengeRecordingContext(
                      generation: store.generation,
                      owner: h.creator.pubkey,
                      definition: h.definition,
                      recordingId: 'recording',
                      clientTags: const [],
                    ).toJson(),
                  ),
                );
          await dao.entered!.future;
          h.owner = null;
          await barrier.stop(h.creator.pubkey);
          await db.challengeRecordsDao.removeOwner(h.creator.pubkey);
          final rejected = expectLater(
            pending,
            throwsA(isA<ChallengeOwnerRevoked>()),
          );
          dao.release!.complete();
          await rejected;
          expect(
            await db.customSelect('SELECT * FROM challenge_records').get(),
            isEmpty,
          );
          expect(
            await db.customSelect('SELECT * FROM challenge_owners').get(),
            isEmpty,
          );
        },
      );
    }

    test(
      'draft JSON and publish copy preserve context while duplicate retires it',
      () {
        final h = Harness();
        final context = ChallengeRecordingContext(
          generation: 'c' * 64,
          owner: h.creator.pubkey,
          definition: h.definition,
          recordingId: 'recording',
          clientTags: const [
            ['client', 'Synthetic Divine client'],
          ],
        );
        final draft = DivineVideoDraft.create(
          id: 'source',
          clips: const [],
          title: '',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
          challengeContext: context,
        );
        final restored = DivineVideoDraft.fromJson(
          jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
          '/synthetic',
        );
        expect(restored.challengeContext!.definition.id, h.definition.id);
        expect(
          restored
              .copyWith(id: 'publish', sourceDraftId: draft.id)
              .challengeContext!
              .clientTags
              .single,
          ['client', 'Synthetic Divine client'],
        );
        expect(restored.duplicate().challengeContext, isNull);
        expect(
          DivineVideoDraft.fromJson(
            {...draft.toJson()}..remove('challengeContext'),
            '/synthetic',
          ).challengeContext,
          isNull,
        );
      },
    );
    test(
      'outbox and reviewed client metadata survive a real process-style reopen',
      () async {
        final h = Harness();
        final directory = await Directory.systemTemp.createTemp(
          'challenge-store-',
        );
        final file = File('${directory.path}/app.sqlite');
        var db = AppDatabase.test(NativeDatabase(file));
        var store = await SqliteChallengeStore.open(
          dao: db.challengeRecordsDao,
          owner: h.creator.pubkey,
          currentOwner: () => h.owner,
        );
        final review = await h.prepare(
          clientTags: [
            ['client', 'Synthetic Divine client'],
          ],
        );
        final action = (await h.repository.submit(review)).action!;
        await store.saveReview(h.creator.pubkey, review);
        await store.insertAction(h.creator.pubkey, action);
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        addTearDown(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        store = await SqliteChallengeStore.open(
          dao: db.challengeRecordsDao,
          owner: h.creator.pubkey,
          currentOwner: () => h.owner,
        );
        final restored = (await store.loadAction(h.creator.pubkey, review.id))!;
        expect(restored.signedBody, action.signedBody);
        expect(
          (await store.loadReview(h.creator.pubkey, review.id))!.video.id,
          h.video.id,
        );
        expect(restored.review.fields.tags.last, [
          'client',
          'Synthetic Divine client',
        ]);
        h.owner = h.organizer.pubkey;
        final acknowledged = PendingChallengeAction(
          review: review,
          signedBody: action.signedBody,
          challengeRelays: action.challengeRelays,
          targets: action.targets,
          outcomes: {h.relay: RelayOutcome.accepted},
        );
        await store.saveAction(h.creator.pubkey, acknowledged);
        h.owner = h.creator.pubkey;
        expect(
          (await store.loadAction(h.creator.pubkey, review.id))!.submitted,
          isTrue,
        );
        await expectLater(
          store.loadAction(h.organizer.pubkey, review.id),
          throwsA(isA<ChallengeOwnerRevoked>()),
        );
      },
    );
    test(
      'account write drain and removal defeat a paused real outbox insert',
      () async {
        final h = Harness();
        final directory = await Directory.systemTemp.createTemp(
          'challenge-owner-race-',
        );
        final db = AppDatabase.test(
          NativeDatabase(File('${directory.path}/app.sqlite')),
        );
        addTearDown(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        final dao = _HeldDao(db)
          ..entered = Completer<void>()
          ..release = Completer<void>();
        final store = await SqliteChallengeStore.open(
          dao: dao,
          owner: h.creator.pubkey,
          currentOwner: () => h.owner,
        );
        final barrier = AccountStateWriteBarrier();
        barrier.register(h.creator.pubkey, store.retire);
        var signing = 0;
        var publishing = 0;
        final repository = ChallengeSubmissionRepository(
          reads: h.reads,
          store: store,
          currentOwner: () => h.owner,
          currentVideoId: (_) => h.videoId,
          canPublish: (_) => true,
          writableRelays: () => [],
          sign: (fields) async {
            signing++;
            return h.signFields(fields);
          },
          transport: (_, _) async {
            publishing++;
            return {};
          },
        );
        final review = await repository.prepareEntry(
          definition: h.definition,
          video: h.video,
        );
        final pending = repository.submit(review);
        await dao.entered!.future;
        expect(signing, 1);
        h.owner = null;
        await barrier.stop(h.creator.pubkey);
        await db.challengeRecordsDao.removeOwner(h.creator.pubkey);
        dao.release!.complete();
        final result = await pending;
        expect(result.status, SubmissionStatus.persistenceFailed);
        expect(publishing, 0);
        expect(signing, 1);
        expect(
          await db.customSelect('SELECT * FROM challenge_records').get(),
          isEmpty,
        );
        expect(
          await db.customSelect('SELECT * FROM challenge_owners').get(),
          isEmpty,
        );
      },
    );
  });
}
