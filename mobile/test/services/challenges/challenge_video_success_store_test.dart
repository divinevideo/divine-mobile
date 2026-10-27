import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/models/challenge_recording_context.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/challenges/challenge_video_success_store.dart';
import 'package:openvine/services/challenges/sqlite_challenge_store.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../packages/challenges_repository/test/synthetic.dart';
import '../../mocks/mock_path_provider_platform.dart';

class _Auth extends Mock implements AuthService {}

class _Uploads extends Mock implements UploadManager {}

class _Publisher extends Mock implements VideoEventPublisher {}

class _Blossom extends Mock implements BlossomUploadService {}

class _HeldDatabase extends AppDatabase {
  _HeldDatabase(super.e) : super.test();
  Completer<void>? entered;
  Completer<void>? release;
  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    final gate = release;
    if (gate != null) {
      release = null;
      entered!.complete();
      await gate.future;
    }
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  group('successful challenge video independent completion', () {
    late Directory ownedRoot;
    late Directory documents;
    late PathProviderPlatform originalPathProvider;
    setUp(() async {
      ownedRoot = await Directory.systemTemp.createTemp(
        'challenge-terminal-fixture-',
      );
      documents = await Directory('${ownedRoot.path}/documents').create();
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(documents.path);
      resetCachedDocumentsPath();
    });
    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      resetCachedDocumentsPath();
      await ownedRoot.delete(recursive: true);
    });
    test(
      'direct terminal DAO writes refresh the visible draft library',
      () async {
        final signer = SyntheticSigner();
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final generation = await db.challengeRecordsDao.openOwner(
          signer.pubkey,
        );
        final context = ChallengeRecordingContext(
          owner: signer.pubkey,
          generation: generation,
          definition: NostrEvent.fromJson(signer.definition()),
          recordingId: 'recording',
          clientTags: const [],
        );
        final service = DraftStorageService(
          draftsDao: db.draftsDao,
          clipsDao: db.clipsDao,
          ownerPubkey: signer.pubkey,
        );
        final file = await File(
          '${await getDocumentsPath()}/challenge-library-test.mp4',
        ).writeAsBytes([0]);
        addTearDown(file.delete);
        final clip = DivineVideoClip(
          id: 'visible-clip',
          video: EditorVideo.file(file.path),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime.now(),
          targetAspectRatio: AspectRatio.square,
          originalAspectRatio: 1,
        );
        final draft = DivineVideoDraft.create(
          id: 'visible',
          clips: [clip],
          title: 'Synthetic draft',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
          challengeContext: context,
        );
        await service.saveDraft(draft);
        final bloc = DraftsLibraryBloc(
          draftStorageService: service,
          changes: db
              .tableUpdates(TableUpdateQuery.onTable(db.drafts))
              .map((_) {}),
        );
        addTearDown(bloc.close);
        final first = bloc.stream.firstWhere((s) => s is DraftsLibraryLoaded);
        bloc.add(const DraftsLibraryLoadRequested());
        expect((await first as DraftsLibraryLoaded).drafts, hasLength(1));
        final removed = bloc.stream.firstWhere(
          (s) => s is DraftsLibraryLoaded && s.drafts.isEmpty,
        );
        await ChallengeVideoSuccessStore(db).record(draft, null);
        expect((await removed as DraftsLibraryLoaded).drafts, isEmpty);
      },
    );
    for (final readd in [false, true]) {
      test(
        'late terminal write after removal${readd ? ' and re-add' : ''} only retires original rows',
        () async {
          final signer = SyntheticSigner();
          final foreign = SyntheticSigner();
          final directory = await Directory.systemTemp.createTemp(
            'terminal-removal-',
          );
          final db = _HeldDatabase(
            NativeDatabase(File('${directory.path}/app.sqlite')),
          );
          addTearDown(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
          final generation = await db.challengeRecordsDao.openOwner(
            signer.pubkey,
          );
          final context = ChallengeRecordingContext(
            owner: signer.pubkey,
            generation: generation,
            definition: NostrEvent.fromJson(signer.definition()),
            recordingId: 'recording',
            clientTags: const [],
          );
          final draft = DivineVideoDraft.create(
            id: 'publish',
            clips: const [],
            title: 'original',
            description: '',
            hashtags: {},
            selectedApproach: 'video',
            challengeContext: context,
          ).copyWith(sourceDraftId: 'foreign-source');
          Future<void> save(DivineVideoDraft value, String owner) =>
              db.draftsDao.upsertDraft(
                id: value.id,
                title: value.title,
                description: '',
                publishStatus: 'publishing',
                createdAt: value.createdAt,
                lastModified: value.lastModified,
                data: jsonEncode(value.toJson()),
                renderedFilePath: null,
                renderedThumbnailPath: null,
                ownerPubkey: owner,
              );
          await save(draft, signer.pubkey);
          await save(draft.copyWith(id: 'foreign-source'), foreign.pubkey);
          final terminal = ChallengeVideoSuccessStore(db);
          final release = Completer<void>();
          db.entered = Completer<void>();
          db.release = release;
          final pending = terminal.record(
            draft,
            jsonEncode(
              signer.sign(
                kind: 34236,
                tags: [
                  ['d', 'synthetic-video'],
                ],
              ),
            ),
          );
          await db.entered!.future;
          await db.challengeRecordsDao.removeOwner(signer.pubkey);
          if (readd) {
            final fresh = await db.challengeRecordsDao.openOwner(signer.pubkey);
            await save(
              draft.copyWith(
                id: 'publish',
                challengeContext: ChallengeRecordingContext(
                  owner: signer.pubkey,
                  generation: fresh,
                  definition: context.definition,
                  recordingId: 'fresh',
                  clientTags: const [],
                ),
              ),
              signer.pubkey,
            );
          }
          release.complete();
          await pending;
          expect(
            await db.draftsDao.getDraftById('publish'),
            readd ? isNotNull : isNull,
          );
          expect(
            (await db.draftsDao.getDraftById('foreign-source'))!.ownerPubkey,
            foreign.pubkey,
          );
          if (readd) {
            expect(
              (await db.draftsDao.getDraftById('publish'))!.publishStatus,
              'publishing',
            );
          }
          await terminal.record(draft, null);
          await terminal.discardDrafts(draft);
          expect(
            await db.draftsDao.getDraftById('publish'),
            readd ? isNotNull : isNull,
          );
          expect(await db.draftsDao.getDraftById('foreign-source'), isNotNull);
          expect(
            await db.customSelect('SELECT * FROM challenge_records').get(),
            isEmpty,
          );
        },
      );
    }
    for (final switched in [false, true]) {
      test(
        '${switched ? 'switch' : 'capability loss'} survives reopen without upload or signing',
        () async {
          final signer = SyntheticSigner();
          final directory = await Directory.systemTemp.createTemp(
            'terminal-video-',
          );
          final file = File('${directory.path}/app.sqlite');
          var db = AppDatabase.test(NativeDatabase(file));
          String? current = signer.pubkey;
          final store = await SqliteChallengeStore.open(
            dao: db.challengeRecordsDao,
            owner: signer.pubkey,
            currentOwner: () => current,
          );
          final media = File(
            '${await getDocumentsPath()}/${directory.uri.pathSegments.where((s) => s.isNotEmpty).last}.mp4',
          );
          await media.parent.create(recursive: true);
          await media.writeAsBytes([0]);
          addTearDown(() async {
            if (media.existsSync()) await media.delete();
          });
          final clip = DivineVideoClip(
            id: 'clip',
            video: EditorVideo.file(media.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 1,
          );
          final context = ChallengeRecordingContext(
            owner: signer.pubkey,
            generation: store.generation,
            definition: NostrEvent.fromJson(signer.definition()),
            recordingId: 'recording',
            clientTags: const [],
          );
          final draft =
              DivineVideoDraft.create(
                id: 'publish',
                clips: [clip],
                title: 'publish title',
                description: '',
                hashtags: {},
                selectedApproach: 'video',
                challengeContext: context,
              ).copyWith(
                sourceDraftId: 'source',
                publishStatus: PublishStatus.publishing,
              );
          for (final value in [
            draft,
            draft.copyWith(id: 'source', title: 'source own title'),
          ]) {
            await db.draftsDao.upsertDraft(
              id: value.id,
              title: value.title,
              description: '',
              publishStatus: value.publishStatus.name,
              createdAt: value.createdAt,
              lastModified: value.lastModified,
              data: jsonEncode(value.toJson()),
              renderedFilePath: '${value.id}.mp4',
              renderedThumbnailPath: null,
              ownerPubkey: signer.pubkey,
            );
            await db.clipsDao.upsertClip(
              id: '${value.id}:clip',
              draftId: value.id,
              orderIndex: 0,
              durationMs: 6000,
              recordedAt: clip.recordedAt,
              data: jsonEncode(clip.toJson()),
              filePath: media.path,
              thumbnailPath: null,
              ownerPubkey: signer.pubkey,
            );
          }
          final drafts = DraftStorageService(
            draftsDao: db.draftsDao,
            clipsDao: db.clipsDao,
            ownerPubkey: signer.pubkey,
          );
          final body = jsonEncode(
            signer.sign(
              content: switched ? 'x' * 70000 : '',
              kind: 34236,
              tags: [
                ['d', 'synthetic-video'],
              ],
            ),
          );
          current = switched ? SyntheticSigner().pubkey : null;
          final entered = Completer<void>();
          final bloc = BackgroundPublishBloc(
            videoPublishServiceFactory: ({required onProgress}) async =>
                throw StateError('Unexpected pipeline'),
            draftStorageService: drafts,
            challengeHandoff: (_, _) async {
              entered.complete();
              throw StateError('No active signing session');
            },
            challengeVideoSuccess: ChallengeVideoSuccessStore(db).record,
            challengeDraftCleanup: ChallengeVideoSuccessStore(db).discardDrafts,
          );
          bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(
                PublishSuccess(signedEventBody: body),
              ),
            ),
          );
          await entered.future;
          await bloc.close();
          expect(bloc.state.recentlyPublished.single.signedVideoBody, body);
          await db.close();
          db = AppDatabase.test(NativeDatabase(file));
          addTearDown(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
          final resumed = DraftStorageService(
            draftsDao: db.draftsDao,
            clipsDao: db.clipsDao,
            ownerPubkey: signer.pubkey,
          );
          expect(
            (await db.draftsDao.getDraftById('publish'))!.publishStatus,
            'published',
          );
          expect(
            await resumed.getDraftsByPublishStatuses({
              PublishStatus.publishing,
              PublishStatus.failed,
            }),
            isEmpty,
          );
          final row = (await db.draftsDao.getDraftById('source'))!;
          expect(row.title, 'source own title');
          expect(
            (jsonDecode(row.data) as Map<String, dynamic>)['title'],
            'source own title',
          );
          expect(row.renderedFilePath, 'source.mp4');
          final recovery = (await resumed.getDraftById('publish'))!;
          expect(recovery.publishStatus, PublishStatus.published);
          expect(recovery.publishedVideoEvent, body);
          final auth = _Auth();
          final uploads = _Uploads();
          final publisher = _Publisher();
          final blossom = _Blossom();
          final retry = VideoPublishService(
            uploadManager: uploads,
            authService: auth,
            videoEventPublisher: publisher,
            blossomService: blossom,
            draftService: resumed,
            onProgressChanged: ({required draftId, required progress}) {},
          );
          expect(
            await retry.publishVideo(draft: recovery),
            isA<PublishSuccess>(),
          );
          verifyZeroInteractions(auth);
          verifyZeroInteractions(uploads);
          verifyZeroInteractions(publisher);
          verifyZeroInteractions(blossom);
          await ChallengeVideoSuccessStore(db).discardDrafts(draft);
          expect(await db.draftsDao.getDraftById('publish'), isNull);
          expect(await db.draftsDao.getDraftById('source'), isNull);
          expect(await db.clipsDao.getClipsByDraftId('publish'), isEmpty);
          expect(await db.clipsDao.getClipsByDraftId('source'), isEmpty);
        },
      );
    }
  });
}
