// ABOUTME: Tests for VideoContentActionsBloc
// ABOUTME: Verifies save, bookmark status, add-to-clips, and copy actions

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/remix_consent_repository.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockBookmarksRepository extends Mock implements BookmarksRepository {}

class _MockVideoClipImportService extends Mock
    implements VideoClipImportService {}

class _MockRemixConsentRepository extends Mock
    implements RemixConsentRepository {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _viewerPubkey =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

DivineVideoClip _clip({String? libraryTitle}) {
  return DivineVideoClip(
    id: 'clip-1',
    video: EditorVideo.file('/tmp/clip.mp4'),
    libraryTitle: libraryTitle,
    duration: const Duration(seconds: 6),
    recordedAt: DateTime.utc(2026),
    targetAspectRatio: .square,
    originalAspectRatio: 1,
  );
}

/// A [VideoEvent] whose [toJson] always throws, used to test error paths.
class _ThrowingJsonVideoEvent extends Fake implements VideoEvent {
  @override
  String get id =>
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  @override
  String get pubkey =>
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  @override
  Map<String, dynamic> toJson() => throw const FormatException('bad json');
}

/// A [VideoEvent] with an invalid hex [id], causing nevent encoding to throw.
class _InvalidIdVideoEvent extends Fake implements VideoEvent {
  @override
  String get id => 'not-valid-hex';

  @override
  String get pubkey =>
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(VideoContentActionsBloc, () {
    late _MockBookmarksRepository mockBookmarksRepository;
    late _MockRemixConsentRepository mockRemixConsentRepository;
    late VideoEvent testVideo;

    setUp(() {
      mockBookmarksRepository = _MockBookmarksRepository();
      mockRemixConsentRepository = _MockRemixConsentRepository();
      when(
        () => mockRemixConsentRepository.consentFor(any()),
      ).thenAnswer((_) async => RemixConsent.allowed);
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
      when(
        () => mockBookmarksRepository.isVideoBookmarkedGlobally(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenReturn(false);
      when(
        () => mockBookmarksRepository.hasUnreadablePrivateItems,
      ).thenReturn(false);
    });

    VideoContentActionsBloc createBloc({
      BookmarksRepository? bookmarksRepository,
      // Distinguishes "no bookmark service wired" from "use the default
      // mock": a bare null would fall through to the mock below.
      bool withBookmarksRepository = true,
      String relayUrl = 'wss://relay.test.example',
      VideoClipImportService? videoClipImportService,
      // Same distinction as [withBookmarksRepository]: by default the
      // creator allows remixing, so the import tests reach the importer.
      bool withRemixConsentRepository = true,
      String? viewerPubkey = _viewerPubkey,
    }) => VideoContentActionsBloc(
      video: testVideo,
      relayUrl: relayUrl,
      bookmarksRepository: withBookmarksRepository
          ? (bookmarksRepository ?? mockBookmarksRepository)
          : null,
      videoClipImportService: videoClipImportService,
      remixConsentRepository: withRemixConsentRepository
          ? mockRemixConsentRepository
          : null,
      viewerPubkey: viewerPubkey,
    );

    group('close and concurrency', () {
      late Completer<VideoClipImportResult> importCompleter;
      late Completer<BookmarkToggleResult> toggleCompleter;
      late _MockVideoClipImportService importer;

      setUp(() {
        importCompleter = Completer<VideoClipImportResult>();
        toggleCompleter = Completer<BookmarkToggleResult>();
        importer = _MockVideoClipImportService();
      });

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'drops a second add-to-clips request while the first is in flight',
        build: () {
          when(
            () => importer.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenAnswer((_) => importCompleter.future);
          return createBloc(videoClipImportService: importer);
        },
        act: (bloc) async {
          bloc
            ..add(const VideoContentAddToClipsRequested(libraryTitle: 'a'))
            ..add(const VideoContentAddToClipsRequested(libraryTitle: 'a'));
          await pumpEventQueue();
          importCompleter.complete(VideoClipImportSuccess(_clip()));
        },
        verify: (_) => verify(
          () => importer.importToLibrary(
            any(),
            libraryTitle: any(named: 'libraryTitle'),
          ),
        ).called(1),
      );

      test(
        'close during an in-flight toggle drops the late result without error',
        () async {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) => toggleCompleter.future);
          final bloc = createBloc()..add(const VideoContentSaveRequested());
          await pumpEventQueue();
          expect(bloc.state.isSaving, isTrue);
          await bloc.close();
          toggleCompleter.complete(
            const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
          await pumpEventQueue();
          expect(bloc.state.isSaving, isTrue);
        },
      );
    });

    group('defaultClipTitle', () {
      test('returns the video title for a titled video', () {
        expect(createBloc().defaultClipTitle, equals('Test Video'));
      });
    });

    group('VideoContentSaveRequested', () {
      // The save handler emits a pending state before it touches the
      // network, then the terminal result, so each expectation below opens
      // with this one.
      final savePending = isA<VideoContentActionsState>()
          .having((s) => s.isSaving, 'isSaving', isTrue)
          .having((s) => s.actionResult, 'actionResult', isNull);

      late Completer<BookmarkToggleResult> saveGate;

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentSaveResult with succeeded=true, removed=false when adding bookmark',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isTrue)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentSaveResult with succeeded=true, removed=true when removing bookmark',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: true,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isTrue)
                    .having((r) => r.removed, 'removed', isTrue)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentSaveResult with succeeded=false when bookmark fails',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: false,
              wasBookmarked: false,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits failure with wasBookmarkedBeforeToggle true when removing '
        'bookmark fails',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: false,
              wasBookmarked: true,
              isBookmarked: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentSaveResult with succeeded=false when bookmark throws',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenThrow(Exception('offline'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits failure with wasBookmarkedBeforeToggle true when toggle '
        'throws while bookmarked',
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(true);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenThrow(Exception('offline'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentSaveResult with succeeded=false when no bookmark service',
        build: () => createBloc(withBookmarksRepository: false),
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'consecutive saves emit distinct states via identity equality',
        setUp: () {
          var inGlobalBookmarks = false;
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) async {
            final wasBookmarked = inGlobalBookmarks;
            inGlobalBookmarks = !inGlobalBookmarks;
            return BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: wasBookmarked,
              isBookmarked: inGlobalBookmarks,
            );
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoContentSaveRequested());
          await pumpEventQueue();
          bloc.add(const VideoContentSaveRequested());
        },
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>()
                    .having((r) => r.removed, 'removed', isTrue)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'swallows a repeat save while the first is still in flight',
        setUp: () {
          saveGate = Completer<BookmarkToggleResult>();
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) => saveGate.future);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoContentSaveRequested());
          await pumpEventQueue();
          // Still reconciling. The sheet is showing the pending affordance and
          // this second tap must not start another reconcile-and-publish of a
          // replaceable list.
          bloc.add(const VideoContentSaveRequested());
          await pumpEventQueue();
          saveGate.complete(
            const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
        },
        expect: () => [
          savePending,
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>().having(
                  (r) => r.succeeded,
                  'succeeded',
                  isTrue,
                ),
              ),
        ],
        verify: (_) => verify(
          () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
            any(),
            addressableId: any(named: 'addressableId'),
          ),
        ).called(1),
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'does not emit after close when save completes late',
        setUp: () {
          saveGate = Completer<BookmarkToggleResult>();
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) => saveGate.future);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoContentSaveRequested());
          await pumpEventQueue();
          await bloc.close();
          saveGate.complete(
            const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
          await pumpEventQueue();
        },
        expect: () => [savePending],
      );
    });

    group('VideoContentAddToClipsRequested', () {
      late _MockVideoClipImportService mockImporter;

      setUp(() {
        mockImporter = _MockVideoClipImportService();
      });

      test(
        'reports the import as running until the importer finishes',
        () async {
          final importCompleter = Completer<VideoClipImportResult>();
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenAnswer((_) => importCompleter.future);
          final bloc = createBloc(videoClipImportService: mockImporter);
          addTearDown(bloc.close);

          expect(bloc.state.isImportingClip, isFalse);
          bloc.add(const VideoContentAddToClipsRequested());
          await pumpEventQueue();
          expect(bloc.state.isImportingClip, isTrue);

          importCompleter.complete(VideoClipImportSuccess(_clip()));
          await pumpEventQueue();
          expect(bloc.state.isImportingClip, isFalse);
        },
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits import success when video is added to clips',
        setUp: () {
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenAnswer(
            (_) async =>
                VideoClipImportSuccess(_clip(libraryTitle: 'My local cut')),
          );
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(
          const VideoContentAddToClipsRequested(
            libraryTitle: 'My local cut',
          ),
        ),
        expect: () => [
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isTrue,
              )
              .having((state) => state.actionResult, 'actionResult', isNull),
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isFalse,
              )
              .having(
                (state) => state.actionResult,
                'actionResult',
                isA<VideoContentClipImportResult>()
                    .having((result) => result.succeeded, 'succeeded', isTrue)
                    .having(
                      (result) => result.libraryTitle,
                      'libraryTitle',
                      'My local cut',
                    ),
              ),
        ],
        verify: (_) {
          verify(
            () => mockImporter.importToLibrary(
              testVideo,
              libraryTitle: 'My local cut',
            ),
          ).called(1);
        },
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits import failure when importer cannot add the clip',
        setUp: () {
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenAnswer(
            (_) async => const VideoClipImportFailure(
              VideoClipImportFailureReason.downloadFailed,
            ),
          );
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        expect: () => [
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isTrue,
              )
              .having((state) => state.actionResult, 'actionResult', isNull),
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isFalse,
              )
              .having(
                (state) => state.actionResult,
                'actionResult',
                isA<VideoContentClipImportResult>().having(
                  (result) => result.succeeded,
                  'succeeded',
                  isFalse,
                ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits import failure when importer is unavailable',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        expect: () => [
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isTrue,
              )
              .having((state) => state.actionResult, 'actionResult', isNull),
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isFalse,
              )
              .having(
                (state) => state.actionResult,
                'actionResult',
                isA<VideoContentClipImportResult>().having(
                  (result) => result.succeeded,
                  'succeeded',
                  isFalse,
                ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits import failure AND addError when importer throws (#3715)',
        setUp: () {
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenThrow(Exception('download failed'));
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<Exception>(),
          ),
        ],
        expect: () => [
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isTrue,
              )
              .having((state) => state.actionResult, 'actionResult', isNull),
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isFalse,
              )
              .having(
                (state) => state.actionResult,
                'actionResult',
                isA<VideoContentClipImportResult>().having(
                  (result) => result.succeeded,
                  'succeeded',
                  isFalse,
                ),
              ),
        ],
      );
    });

    group('VideoContentAddToClipsRequested remix consent', () {
      late _MockVideoClipImportService mockImporter;

      setUp(() {
        mockImporter = _MockVideoClipImportService();
        when(
          () => mockImporter.importToLibrary(
            any(),
            libraryTitle: any(named: 'libraryTitle'),
          ),
        ).thenAnswer((_) async => VideoClipImportSuccess(_clip()));
      });

      Matcher refusedWith(RemixConsent consent) =>
          isA<VideoContentActionsState>()
              .having(
                (state) => state.isImportingClip,
                'isImportingClip',
                isFalse,
              )
              .having(
                (state) => state.actionResult,
                'actionResult',
                isA<VideoContentRemixRefused>().having(
                  (result) => result.consent,
                  'consent',
                  consent,
                ),
              );

      final checking = isA<VideoContentActionsState>().having(
        (state) => state.isImportingClip,
        'isImportingClip',
        isTrue,
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'refuses without importing when the creator blocks remixing',
        setUp: () {
          when(
            () => mockRemixConsentRepository.consentFor(any()),
          ).thenAnswer((_) async => RemixConsent.blocked);
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        expect: () => [checking, refusedWith(RemixConsent.blocked)],
        verify: (_) {
          verify(
            () => mockRemixConsentRepository.consentFor(testVideo.pubkey),
          ).called(1);
          verifyNever(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          );
        },
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'refuses without importing when consent cannot be read',
        setUp: () {
          when(
            () => mockRemixConsentRepository.consentFor(any()),
          ).thenAnswer((_) async => RemixConsent.unknown);
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        expect: () => [checking, refusedWith(RemixConsent.unknown)],
        verify: (_) => verifyNever(
          () => mockImporter.importToLibrary(
            any(),
            libraryTitle: any(named: 'libraryTitle'),
          ),
        ),
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'refuses as unknown when no consent repository is wired',
        build: () => createBloc(
          videoClipImportService: mockImporter,
          withRemixConsentRepository: false,
        ),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        expect: () => [checking, refusedWith(RemixConsent.unknown)],
        verify: (_) => verifyNever(
          () => mockImporter.importToLibrary(
            any(),
            libraryTitle: any(named: 'libraryTitle'),
          ),
        ),
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'refuses as unknown and reports when the consent check throws',
        setUp: () {
          when(
            () => mockRemixConsentRepository.consentFor(any()),
          ).thenThrow(StateError('broken invariant'));
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        expect: () => [checking, refusedWith(RemixConsent.unknown)],
        verify: (_) => verifyNever(
          () => mockImporter.importToLibrary(
            any(),
            libraryTitle: any(named: 'libraryTitle'),
          ),
        ),
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        "imports a blocked account's video when it is the viewer's own",
        setUp: () {
          when(
            () => mockRemixConsentRepository.consentFor(any()),
          ).thenAnswer((_) async => RemixConsent.blocked);
        },
        build: () => createBloc(
          videoClipImportService: mockImporter,
          viewerPubkey: testVideo.pubkey,
        ),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        verify: (_) {
          verifyNever(() => mockRemixConsentRepository.consentFor(any()));
          verify(
            () => mockImporter.importToLibrary(
              testVideo,
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'checks consent when the viewer is signed out',
        build: () => createBloc(
          videoClipImportService: mockImporter,
          viewerPubkey: null,
        ),
        act: (bloc) => bloc.add(const VideoContentAddToClipsRequested()),
        verify: (_) => verify(
          () => mockRemixConsentRepository.consentFor(testVideo.pubkey),
        ).called(1),
      );
    });

    group('VideoContentCopyEventJsonRequested', () {
      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentCopiedToClipboard with formatted JSON',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentCopyEventJsonRequested()),
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<VideoContentCopiedToClipboard>()
                .having((r) => r.kind, 'kind', VideoContentCopiedKind.eventJson)
                .having(
                  (r) => r.text.contains('"id"'),
                  'text contains id field',
                  isTrue,
                ),
          ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentActionFailure when toJson throws',
        build: () => VideoContentActionsBloc(
          video: _ThrowingJsonVideoEvent(),
          relayUrl: 'wss://relay.test.example',
        ),
        act: (bloc) => bloc.add(const VideoContentCopyEventJsonRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<FormatException>(),
          ),
        ],
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<VideoContentActionFailure>(),
          ),
        ],
      );
    });

    group('VideoContentCopyEventIdRequested', () {
      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentCopiedToClipboard with nevent-encoded ID',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentCopyEventIdRequested()),
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<VideoContentCopiedToClipboard>()
                .having((r) => r.kind, 'kind', VideoContentCopiedKind.eventId)
                .having(
                  (r) => r.text.startsWith('nevent'),
                  'text starts with nevent',
                  isTrue,
                ),
          ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'emits $VideoContentActionFailure when encoding throws',
        build: () => VideoContentActionsBloc(
          video: _InvalidIdVideoEvent(),
          relayUrl: 'wss://relay.test.example',
        ),
        act: (bloc) => bloc.add(const VideoContentCopyEventIdRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<FormatException>(),
          ),
        ],
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<VideoContentActionFailure>(),
          ),
        ],
      );
    });

    // An edit republishes an addressable video under a new event id, so the
    // sheet names the video by its coordinate as well (#7135).
    group('addressable video', () {
      late String coordinate;

      setUp(() {
        testVideo = VideoEvent(
          id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          createdAt: 1757385263,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
          videoUrl: 'https://example.com/video.mp4',
          title: 'Test Video',
          addressableDTag: 'clip',
        );
        coordinate = testVideo.addressableId!;
        when(
          () => mockBookmarksRepository.syncGlobalBookmarks(),
        ).thenAnswer((_) async => true);
      });

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'reads the video as saved when its coordinate is bookmarked',
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              testVideo.id,
              addressableId: coordinate,
            ),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentBookmarkStatusRequested()),
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.bookmarkStatus,
            'bookmarkStatus',
            VideoBookmarkStatus.saved,
          ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'toggles the bookmark by the video coordinate',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        verify: (_) {
          verify(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              testVideo.id,
              addressableId: coordinate,
            ),
          ).called(1);
        },
      );
    });

    group('VideoContentBookmarkStatusRequested', () {
      late Completer<bool> bookmarkStatusSyncCompleter;

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'resolves saved when the reconciled list contains the video',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => true);
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentBookmarkStatusRequested()),
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.bookmarkStatus,
            'bookmarkStatus',
            VideoBookmarkStatus.saved,
          ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'resolves notSaved when the reconciled list omits the video',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => true);
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentBookmarkStatusRequested()),
        expect: () => [
          isA<VideoContentActionsState>().having(
            (s) => s.bookmarkStatus,
            'bookmarkStatus',
            VideoBookmarkStatus.notSaved,
          ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'stays unknown when the list has private items it could not read',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => true);
          when(
            () => mockBookmarksRepository.hasUnreadablePrivateItems,
          ).thenReturn(true);
          // The public half says "not bookmarked", but the encrypted half is
          // exactly where the video might be — claiming notSaved here is the
          // mislabel that precedes the disclosure (#7136).
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentBookmarkStatusRequested()),
        expect: () => <VideoContentActionsState>[],
        verify: (bloc) =>
            expect(bloc.state.bookmarkStatus, VideoBookmarkStatus.unknown),
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'does not let a late status read overwrite a successful toggle',
        setUp: () {
          bookmarkStatusSyncCompleter = Completer<bool>();
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) => bookmarkStatusSyncCompleter.future);
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(false);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
          addTearDown(() {
            if (!bookmarkStatusSyncCompleter.isCompleted) {
              bookmarkStatusSyncCompleter.complete(false);
            }
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoContentBookmarkStatusRequested());
          await pumpEventQueue();
          bloc.add(const VideoContentSaveRequested());
          await pumpEventQueue();
          bookmarkStatusSyncCompleter.complete(true);
        },
        expect: () => [
          // The in-flight save (#7073) emits before the toggle resolves; the
          // label must not commit to a direction while it is pending.
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isTrue)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                VideoBookmarkStatus.unknown,
              ),
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                VideoBookmarkStatus.saved,
              )
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<VideoContentSaveResult>().having(
                  (r) => r.succeeded,
                  'succeeded',
                  isTrue,
                ),
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'stays unknown when the reconcile is inconclusive, and never reads '
        'the stale local cache',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentBookmarkStatusRequested()),
        expect: () => <VideoContentActionsState>[],
        verify: (_) {
          verifyNever(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'stays unknown when the bookmark service is unavailable',
        build: () => createBloc(withBookmarksRepository: false),
        act: (bloc) => bloc.add(const VideoContentBookmarkStatusRequested()),
        expect: () => <VideoContentActionsState>[],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'a successful remove flips the status to notSaved',
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(true);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: true,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isTrue)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                VideoBookmarkStatus.unknown,
              ),
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                VideoBookmarkStatus.notSaved,
              ),
        ],
      );

      blocTest<VideoContentActionsBloc, VideoContentActionsState>(
        'a failed toggle leaves the status untouched rather than adopting the '
        'pre-toggle guess',
        seed: () => const VideoContentActionsState(
          bookmarkStatus: VideoBookmarkStatus.saved,
        ),
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenReturn(false);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: false,
              wasBookmarked: false,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoContentSaveRequested()),
        expect: () => [
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isTrue)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                VideoBookmarkStatus.saved,
              ),
          isA<VideoContentActionsState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                VideoBookmarkStatus.saved,
              ),
        ],
      );
    });
  });
}
