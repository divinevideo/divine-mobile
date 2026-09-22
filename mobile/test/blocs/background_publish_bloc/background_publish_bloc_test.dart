import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/background_publish/publish_foreground_session.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:path/path.dart' as p;

class _MockVineDraft extends Mock implements DivineVideoDraft {}

class _MockVideoPublishService extends Mock implements VideoPublishService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// Records begin/end calls; optionally throws to prove the session is
/// best-effort and never breaks the publish.
class _FakeForegroundSession implements PublishForegroundSession {
  _FakeForegroundSession({this.throws = false});

  final bool throws;
  final List<String> beginCalls = [];
  final List<String> endCalls = [];

  @override
  Future<void> begin(String sessionId) async {
    beginCalls.add(sessionId);
    if (throws) throw Exception('begin failed');
  }

  @override
  Future<void> end(String sessionId) async {
    endCalls.add(sessionId);
    if (throws) throw Exception('end failed');
  }
}

void main() {
  late _MockDraftStorageService mockDraftStorageService;

  Future<_MockVideoPublishService> defaultVieoPublishServiceFactory({
    required OnProgressChanged onProgress,
  }) => Future.value(_MockVideoPublishService());

  setUpAll(() {
    registerFallbackValue(PublishStatus.draft);
  });

  setUp(() {
    mockDraftStorageService = _MockDraftStorageService();
    when(
      () => mockDraftStorageService.updatePublishStatus(
        draftId: any(named: 'draftId'),
        status: any(named: 'status'),
        publishError: any(named: 'publishError'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockDraftStorageService.deleteDraft(any()),
    ).thenAnswer((_) async {});
    // Default: the draft a publish copy was made from is still on disk.
    when(
      () => mockDraftStorageService.draftExists(any()),
    ).thenAnswer((_) async => true);
  });

  group('BackgroundPublishState', () {
    group('hasUploadInProgress', () {
      test('returns false when uploads list is empty', () {
        const state = BackgroundPublishState();
        expect(state.hasUploadInProgress, isFalse);
      });

      test('returns true when there is an upload with null result', () {
        final draft = _MockVineDraft();
        when(() => draft.id).thenReturn('1');

        final state = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.5),
          ],
        );
        expect(state.hasUploadInProgress, isTrue);
      });

      test('returns false when all uploads have a result', () {
        final draft = _MockVineDraft();
        when(() => draft.id).thenReturn('1');

        final state = BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        );
        expect(state.hasUploadInProgress, isFalse);
      });

      test('returns true when at least one upload has null result', () {
        final draft1 = _MockVineDraft();
        final draft2 = _MockVineDraft();
        when(() => draft1.id).thenReturn('1');
        when(() => draft2.id).thenReturn('2');

        final state = BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft1,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
            BackgroundUpload(draft: draft2, result: null, progress: 0.3),
          ],
        );
        expect(state.hasUploadInProgress, isTrue);
      });
    });
  });

  group('BackgroundBlocUpload', () {
    test('can be instantiated', () {
      expect(
        BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        isNotNull,
      );
    });

    group('BackgroundPublishRequested', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      group('when the upload is a success', () {
        blocTest(
          'is removed from the uploads list',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0),
              ],
            ),
            // Success: upload removed and recentlySucceededIds populated.
            const BackgroundPublishState(
              recentlyPublished: [PublishedVideo(draftId: draftId)],
            ),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.deleteDraft(draftId),
            ).called(1);
          },
        );

        // Its own mock rather than the group's shared `draft`: mocktail
        // stubs persist for the mock's lifetime, so stubbing a thumbnail on
        // the shared instance would leak into every later test in the group.
        late _MockVineDraft thumbedDraft;
        late Directory thumbDir;
        late File thumbFile;
        final thumbBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        blocTest<BackgroundPublishBloc, BackgroundPublishState>(
          'carries the published d tag and the cover frame so the '
          'confirmation can link to and preview the video',
          setUp: () {
            thumbDir = Directory.systemTemp.createTempSync('publish_thumb');
            thumbFile = File(p.join(thumbDir.path, 'thumb.jpg'))
              ..writeAsBytesSync(thumbBytes);
            thumbedDraft = _MockVineDraft();
            when(() => thumbedDraft.id).thenReturn(draftId);
            when(() => thumbedDraft.sourceDraftId).thenReturn(null);
            when(
              () => thumbedDraft.coverThumbnailPath,
            ).thenReturn(thumbFile.path);
          },
          tearDown: () => thumbDir.deleteSync(recursive: true),
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: thumbedDraft,
              publishmentProcess: Future.value(
                const PublishSuccess(stableId: 'published-d-tag'),
              ),
            ),
          ),
          skip: 1,
          expect: () => [
            const BackgroundPublishState(
              recentlyPublished: [
                PublishedVideo(draftId: draftId, stableId: 'published-d-tag'),
              ],
            ),
          ],
          // thumbnailBytes is outside props (it cannot vary independently of
          // draftId), so assert it here rather than through state equality.
          verify: (bloc) {
            expect(
              bloc.state.recentlyPublished.single.thumbnailBytes,
              equals(thumbBytes),
            );
          },
        );

        blocTest<BackgroundPublishBloc, BackgroundPublishState>(
          'reads the cover frame before the draft cleanup reclaims it',
          setUp: () {
            thumbDir = Directory.systemTemp.createTempSync('publish_thumb');
            thumbFile = File(p.join(thumbDir.path, 'thumb.jpg'))
              ..writeAsBytesSync(thumbBytes);
            thumbedDraft = _MockVineDraft();
            when(() => thumbedDraft.id).thenReturn(draftId);
            when(() => thumbedDraft.sourceDraftId).thenReturn(null);
            when(
              () => thumbedDraft.coverThumbnailPath,
            ).thenReturn(thumbFile.path);
            // deleteDraft reclaims every file the draft owned, the cover
            // frame included. A path handed to the confirmation would be
            // dangling by the time the sheet decoded it.
            when(() => mockDraftStorageService.deleteDraft(draftId)).thenAnswer(
              (_) async => thumbFile.deleteSync(),
            );
          },
          tearDown: () => thumbDir.deleteSync(recursive: true),
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: thumbedDraft,
              publishmentProcess: Future.value(
                const PublishSuccess(stableId: 'published-d-tag'),
              ),
            ),
          ),
          verify: (bloc) {
            expect(thumbFile.existsSync(), isFalse);
            expect(
              bloc.state.recentlyPublished.single.thumbnailBytes,
              equals(thumbBytes),
            );
          },
        );

        test('emits success before the draft cleanup completes', () async {
          // Draft deletion reclaims files and rescans the clip table, so it
          // must never sit in front of the success state — the video is
          // already live by then (#6548).
          final cleanupGate = Completer<void>();
          var cleanupStarted = false;
          var cleanupFinished = false;
          when(() => mockDraftStorageService.deleteDraft(draftId)).thenAnswer((
            _,
          ) {
            cleanupStarted = true;
            return cleanupGate.future.then((_) => cleanupFinished = true);
          });

          final bloc = BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          );
          addTearDown(bloc.close);
          // Registered after `bloc.close` so it runs before it — tear-downs
          // are LIFO. Without it, an expectation failing below would skip the
          // `complete()` at the end and park `close()` on a gate that never
          // opens, turning a clear failure into a suite-wide timeout.
          addTearDown(() {
            if (!cleanupGate.isCompleted) cleanupGate.complete();
          });

          final states = <BackgroundPublishState>[];
          final subscription = bloc.stream.listen(states.add);
          addTearDown(subscription.cancel);

          bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          );
          await pumpEventQueue();

          // The deletion is still gated, yet the UI already sees the publish
          // land: it is not waiting on garbage collection.
          expect(states.last.recentlySucceededIds, contains(draftId));
          expect(states.last.uploads, isEmpty);
          expect(cleanupStarted, isTrue);
          expect(cleanupFinished, isFalse);

          // ...and the cleanup still runs to completion afterwards.
          cleanupGate.complete();
          await pumpEventQueue();
          expect(cleanupFinished, isTrue);
        });
      });

      group('when the upload is a failure', () {
        blocTest(
          'is kept on the uploads list and persists failed status',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(
                const PublishError(PublishErrorKind.generic),
              ),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0),
              ],
            ),
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: const PublishError(PublishErrorKind.generic),
                  progress: 1.0,
                ),
              ],
            ),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.updatePublishStatus(
                draftId: draftId,
                status: PublishStatus.failed,
                publishError: 'pek1:generic',
              ),
            ).called(1);
          },
        );
      });

      group('when the post is scheduled', () {
        final scheduledDraft = _MockVineDraft();
        const scheduledDraftId = 'publish_scheduled';
        const sourceDraftId = 'draft_source';
        final scheduled = PublishScheduled(
          eventId: 'e' * 64,
          publishAt: DateTime.utc(2026, 10),
          submitted: true,
        );

        setUp(() {
          when(() => scheduledDraft.id).thenReturn(scheduledDraftId);
          when(() => scheduledDraft.sourceDraftId).thenReturn(sourceDraftId);
        });

        blocTest<BackgroundPublishBloc, BackgroundPublishState>(
          'leaves the uploads list, keeps the copy as a scheduled draft '
          'and reclaims only the source',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: scheduledDraft,
              publishmentProcess: Future.value(scheduled),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: scheduledDraft,
                  result: null,
                  progress: 0,
                ),
              ],
            ),
            // Not published: nothing to confirm, no draft to celebrate.
            const BackgroundPublishState(),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.updatePublishStatus(
                draftId: scheduledDraftId,
                status: PublishStatus.scheduled,
              ),
            ).called(1);
            verify(
              () => mockDraftStorageService.deleteDraft(sourceDraftId),
            ).called(1);
            verifyNever(
              () => mockDraftStorageService.deleteDraft(scheduledDraftId),
            );
          },
        );
      });

      group('when a transient publish copy succeeds', () {
        final publishDraft = _MockVineDraft();

        const publishDraftId = 'draft_publish_1';
        const sourceDraftId = 'draft_1';

        setUp(() {
          when(() => publishDraft.id).thenReturn(publishDraftId);
          when(() => publishDraft.sourceDraftId).thenReturn(sourceDraftId);
        });

        blocTest(
          'deletes the publish copy and the source draft',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: publishDraft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: publishDraft,
                  result: null,
                  progress: 0,
                ),
              ],
            ),
            const BackgroundPublishState(
              recentlyPublished: [PublishedVideo(draftId: publishDraftId)],
            ),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.deleteDraft(publishDraftId),
            ).called(1);
            verify(
              () => mockDraftStorageService.deleteDraft(sourceDraftId),
            ).called(1);
          },
        );

        blocTest(
          'keeps the recycled autosave slot when the publish copy succeeds',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          setUp: () {
            when(
              () => publishDraft.sourceDraftId,
            ).thenReturn(VideoEditorConstants.autoSaveId);
          },
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: publishDraft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: publishDraft,
                  result: null,
                  progress: 0,
                ),
              ],
            ),
            const BackgroundPublishState(
              recentlyPublished: [PublishedVideo(draftId: publishDraftId)],
            ),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.deleteDraft(publishDraftId),
            ).called(1);
            verifyNever(
              () => mockDraftStorageService.deleteDraft(
                VideoEditorConstants.autoSaveId,
              ),
            );
          },
        );
      });

      group('when the publish process throws an exception', () {
        blocTest<BackgroundPublishBloc, BackgroundPublishState>(
          'transitions the upload to error state',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future<PublishResult>.delayed(
                Duration.zero,
                () => throw Exception('Network connection lost'),
              ),
            ),
          ),
          errors: () => [isA<Exception>()],
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0),
              ],
            ),
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: const PublishError(PublishErrorKind.generic),
                  progress: 1.0,
                ),
              ],
            ),
          ],
        );
      });

      group('when the draft is already uploading', () {
        blocTest(
          'does not add duplicate upload',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          seed: () => BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            // Only emits the final state after success, no duplicate added.
            // recentlySucceededIds is populated so UploadFailureListener can
            // distinguish a true success from BackgroundPublishVanished.
            const BackgroundPublishState(
              recentlyPublished: [PublishedVideo(draftId: draftId)],
            ),
          ],
        );
      });
    });

    group('BackgroundPublishProgressChanged', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      blocTest(
        'updates the background upload',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [BackgroundUpload(draft: draft, result: null, progress: 0)],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .3),
        ),
        expect: () => [
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: .3),
            ],
          ),
        ],
      );

      blocTest(
        'ignores progress when it is less than current progress',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.5),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .3),
        ),
        expect: () => <BackgroundPublishState>[],
      );

      blocTest(
        'ignores progress when it is equal to the current progress',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.5),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .5),
        ),
        expect: () => <BackgroundPublishState>[],
      );

      blocTest(
        'ignores progress when the upload already has a result',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .5),
        ),
        expect: () => <BackgroundPublishState>[],
      );

      blocTest(
        'ignores progress when the draft is not found',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => const BackgroundPublishState(),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(
            draftId: 'non-existent',
            progress: .5,
          ),
        ),
        expect: () => <BackgroundPublishState>[],
      );
    });

    group('BackgroundPublishVanished', () {
      late _MockVineDraft draft;

      const draftId = '1';

      setUp(() {
        draft = _MockVineDraft();
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });
      blocTest(
        'removes the background upload and resets status to draft',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verify(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: draftId,
              status: PublishStatus.draft,
            ),
          ).called(1);
        },
      );

      blocTest(
        'does NOT populate recentlySucceededIds — '
        'regression: vanished upload must not trigger a success snackbar',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        verify: (bloc) {
          // recentlySucceededIds must be empty — Vanished is not a publish
          // success and must never trigger a success snackbar.
          expect(bloc.state.recentlySucceededIds, isEmpty);
        },
      );

      blocTest(
        'deletes a transient publish copy instead of mutating the source draft',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(() => draft.sourceDraftId).thenReturn('draft_source');
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verify(() => mockDraftStorageService.deleteDraft(draftId)).called(1);
          verifyNever(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          );
        },
      );

      blocTest(
        'parks the publish copy when the draft it was copied from is gone',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(() => draft.sourceDraftId).thenReturn('draft_source');
          when(
            () => mockDraftStorageService.draftExists('draft_source'),
          ).thenAnswer((_) async => false);
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verifyNever(() => mockDraftStorageService.deleteDraft(any()));
          verify(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: draftId,
              status: PublishStatus.draft,
            ),
          ).called(1);
        },
      );

      blocTest(
        'parks a copy of the autosave slot even while a row under that id '
        'exists — regression: the shared slot is not a usable fallback',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          // A fresh recording's source is the fixed autosave id, which
          // `clearAll` reaps right after the publish handoff. Whatever sits
          // under that id by the time this upload is parked belongs to a
          // *later* editor session (or, since `draftExists` is unscoped, to
          // another account) — never to this video, so it is not a fallback.
          when(
            () => draft.sourceDraftId,
          ).thenReturn(VideoEditorConstants.autoSaveId);
          when(
            () => mockDraftStorageService.draftExists(
              VideoEditorConstants.autoSaveId,
            ),
          ).thenAnswer((_) async => true);
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verifyNever(() => mockDraftStorageService.deleteDraft(any()));
          verify(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: draftId,
              status: PublishStatus.draft,
            ),
          ).called(1);
        },
      );

      blocTest(
        'parks a self-referencing publish row instead of deleting it',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(() => draft.sourceDraftId).thenReturn(draftId);
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verifyNever(() => mockDraftStorageService.deleteDraft(any()));
          verify(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: draftId,
              status: PublishStatus.draft,
            ),
          ).called(1);
        },
      );
    });

    group('parkInFlight', () {
      late _MockVineDraft inFlight;
      late _MockVineDraft alsoInFlight;
      late _MockVineDraft finished;

      _MockVineDraft draftWithId(String id) {
        final draft = _MockVineDraft();
        when(() => draft.id).thenReturn(id);
        when(() => draft.sourceDraftId).thenReturn(null);
        return draft;
      }

      setUp(() {
        inFlight = draftWithId('in_flight');
        alsoInFlight = draftWithId('also_in_flight');
        finished = draftWithId('finished');
      });

      blocTest(
        'parks every upload that has not finished yet',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: inFlight, result: null, progress: 0),
            BackgroundUpload(draft: alsoInFlight, result: null, progress: 0),
            BackgroundUpload(
              draft: finished,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1,
            ),
          ],
        ),
        act: (bloc) => bloc.parkInFlight(),
        verify: (bloc) {
          for (final draftId in ['in_flight', 'also_in_flight']) {
            verify(
              () => mockDraftStorageService.updatePublishStatus(
                draftId: draftId,
                status: PublishStatus.draft,
              ),
            ).called(greaterThanOrEqualTo(1));
          }
          verifyNever(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: 'finished',
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          );
          // The finished upload stays in the queue so its failure sheet is
          // still there to act on.
          expect(bloc.state.uploads.map((upload) => upload.draft.id), [
            'finished',
          ]);
        },
      );

      blocTest(
        'does not return before the park write has landed',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: inFlight, result: null, progress: 0),
          ],
        ),
        act: (bloc) async {
          // The account switch disposes the container this bloc lives in the
          // moment parkInFlight resolves, so a write still in flight at that
          // point is a lost video.
          final write = Completer<bool>();
          when(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          ).thenAnswer((_) => write.future);

          var parked = false;
          final parking = bloc.parkInFlight().then((_) => parked = true);
          await Future<void>.delayed(Duration.zero);
          expect(parked, isFalse);

          write.complete(true);
          await parking;
          expect(parked, isTrue);
        },
      );

      blocTest(
        'propagates a failed park write to the account-switch caller',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          ).thenThrow(Exception('database locked'));
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: inFlight, result: null, progress: 0),
          ],
        ),
        act: (bloc) async {
          await expectLater(bloc.parkInFlight(), throwsA(isA<Exception>()));
        },
        errors: () => [isA<Exception>()],
      );

      blocTest(
        'rejects a park write that did not update a draft row',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          ).thenAnswer((_) async => false);
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: inFlight, result: null, progress: 0),
          ],
        ),
        act: (bloc) async {
          await expectLater(bloc.parkInFlight(), throwsA(isA<StateError>()));
        },
        errors: () => [isA<StateError>()],
      );

      blocTest(
        'does nothing when no upload is in flight',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: finished,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1,
            ),
          ],
        ),
        act: (bloc) => bloc.parkInFlight(),
        expect: () => const <BackgroundPublishState>[],
        verify: (_) {
          verifyNever(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          );
          verifyNever(() => mockDraftStorageService.deleteDraft(any()));
        },
      );
    });

    group('BackgroundPublishFailed', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'adds interrupted upload to state with error result',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishFailed(
            draft: draft,
            error: const PublishError(PublishErrorKind.interrupted),
          ),
        ),
        expect: () => [
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: draft,
                result: const PublishError(PublishErrorKind.interrupted),
                progress: 0,
              ),
            ],
          ),
        ],
      );

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'does not duplicate when the same draft is already tracked',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishFailed(
            draft: draft,
            error: const PublishError(PublishErrorKind.interrupted),
          ),
        ),
        expect: () => <BackgroundPublishState>[],
      );
    });

    group('foreground session', () {
      late _MockVineDraft draft;
      late _FakeForegroundSession session;

      const draftId = '1';

      setUp(() {
        draft = _MockVineDraft();
        session = _FakeForegroundSession();
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'begins and ends the session around a successful publish',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
          foregroundSession: session,
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(const PublishSuccess()),
          ),
        ),
        verify: (_) {
          expect(session.beginCalls, [draftId]);
          expect(session.endCalls, [draftId]);
        },
      );

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'ends the session even when the publish fails',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
          foregroundSession: session,
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(
              const PublishError(PublishErrorKind.generic),
            ),
          ),
        ),
        verify: (_) {
          expect(session.beginCalls, [draftId]);
          expect(session.endCalls, [draftId]);
        },
      );

      test(
        'holds the session open until the draft cleanup completes',
        () async {
          // Deleting the draft row is the only record that this publish
          // finished, so it must stay inside the keep-alive window: losing the
          // process first makes resume offer a retry for an already-live video.
          final cleanupGate = Completer<void>();
          when(
            () => mockDraftStorageService.deleteDraft(draftId),
          ).thenAnswer((_) => cleanupGate.future);

          final bloc = BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
            foregroundSession: session,
          );
          addTearDown(bloc.close);
          addTearDown(() {
            if (!cleanupGate.isCompleted) cleanupGate.complete();
          });

          bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          );
          await pumpEventQueue();

          expect(session.beginCalls, [draftId]);
          expect(session.endCalls, isEmpty);

          cleanupGate.complete();
          await pumpEventQueue();

          expect(session.endCalls, [draftId]);
        },
      );

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'a session failure does not abort the publish',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
          foregroundSession: _FakeForegroundSession(throws: true),
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(const PublishSuccess()),
          ),
        ),
        expect: () => [
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0),
            ],
          ),
          const BackgroundPublishState(
            recentlyPublished: [PublishedVideo(draftId: draftId)],
          ),
        ],
      );
    });

    group('BackgroundPublishRetryRequested', () {
      late _MockVineDraft draft;
      late _MockVideoPublishService mockPublishService;

      const draftId = '1';

      setUp(() {
        draft = _MockVineDraft();
        mockPublishService = _MockVideoPublishService();
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'clears previous failed upload and retries',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory:
              ({required OnProgressChanged onProgress}) {
                return Future.value(mockPublishService);
              },
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(
            () => mockPublishService.publishVideo(draft: draft),
          ).thenAnswer((_) => Future.value(const PublishSuccess()));
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(BackgroundPublishRetryRequested(draftId: draftId)),
        expect: () => [
          // First: old failed upload is cleared
          const BackgroundPublishState(),
          // Then: new upload is added (from BackgroundPublishRequested)
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0),
            ],
          ),
          // Finally: successful retry removes the upload, recentlySucceededIds
          // is populated so UploadFailureListener shows a success snackbar.
          const BackgroundPublishState(
            recentlyPublished: [PublishedVideo(draftId: draftId)],
          ),
        ],
        verify: (_) {
          verify(() => mockPublishService.publishVideo(draft: draft)).called(1);
        },
      );

      test(
        'does not add retry publish event after close while service loads',
        () async {
          final serviceCompleter = Completer<_MockVideoPublishService>();
          final bloc = BackgroundPublishBloc(
            videoPublishServiceFactory:
                ({required OnProgressChanged onProgress}) {
                  return serviceCompleter.future;
                },
            draftStorageService: mockDraftStorageService,
          );
          bloc.add(
            BackgroundPublishFailed(
              draft: draft,
              error: const PublishError(PublishErrorKind.generic),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          bloc.add(BackgroundPublishRetryRequested(draftId: draftId));
          await Future<void>.delayed(Duration.zero);

          final closeFuture = bloc.close();
          serviceCompleter.complete(mockPublishService);

          await expectLater(closeFuture, completes);
          verifyNever(() => mockPublishService.publishVideo(draft: draft));
        },
      );

      test('ignores progress callbacks after close', () async {
        late OnProgressChanged capturedProgress;
        final publishCompleter = Completer<PublishResult>();
        final bloc = BackgroundPublishBloc(
          videoPublishServiceFactory:
              ({required OnProgressChanged onProgress}) {
                capturedProgress = onProgress;
                return Future.value(mockPublishService);
              },
          draftStorageService: mockDraftStorageService,
        );

        bloc.add(
          BackgroundPublishFailed(
            draft: draft,
            error: const PublishError(PublishErrorKind.generic),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockPublishService.publishVideo(draft: draft),
        ).thenAnswer((_) => publishCompleter.future);

        bloc.add(BackgroundPublishRetryRequested(draftId: draftId));
        await Future<void>.delayed(Duration.zero);
        final closeFuture = bloc.close();

        expect(
          () => capturedProgress(draftId: draftId, progress: 0.5),
          returnsNormally,
        );
        publishCompleter.complete(const PublishSuccess());
        await expectLater(closeFuture, completes);
      });
    });
  });
}
