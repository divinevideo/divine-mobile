// ABOUTME: Tests for VideoPublishService
// ABOUTME: Uses mocked dependencies to test publish flow without real uploads

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_publish/draft_upload_materializer.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes
class MockUploadManager extends Mock implements UploadManager {}

class MockAuthService extends Mock implements AuthService {}

class MockVideoEventPublisher extends Mock implements VideoEventPublisher {}

class MockBlossomUploadService extends Mock implements BlossomUploadService {}

class MockDraftStorageService extends Mock implements DraftStorageService {}

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class MockMentionResolutionService extends Mock
    implements MentionResolutionService {}

/// Captures what a publish would report to Firebase, without any Firebase.
class _MockDraftUploadMaterializer extends Mock
    implements DraftUploadMaterializer {}

class _FakePerformanceTrace implements PerformanceTrace {
  final Map<String, int> metrics = {};
  final Map<String, String> attributes = {};
  int stopCount = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() async => stopCount++;
}

class _FakePerformanceMonitor implements PerformanceTraceMonitor {
  final List<String> startedOperations = [];
  final _FakePerformanceTrace trace = _FakePerformanceTrace();

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    startedOperations.add(traceName);
    return trace;
  }
}

void main() {
  const descriptionMentionPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const overlayMentionPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const collaboratorPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  late MockUploadManager mockUploadManager;
  late _MockDraftUploadMaterializer mockDraftMaterializer;
  late MockAuthService mockAuthService;
  late MockVideoEventPublisher mockVideoEventPublisher;
  late MockBlossomUploadService mockBlossomService;
  late MockDraftStorageService mockDraftService;
  late MockCollaboratorInviteService mockCollaboratorInviteService;
  late MockMentionResolutionService mockMentionResolutionService;
  late _FakePerformanceMonitor fakePerformanceMonitor;
  late VideoPublishService service;

  late List<double> progressChanges;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(File(''));
    registerFallbackValue(
      DivineVideoDraft.create(
        clips: [_createTestClip()],
        title: 'Test',
        description: 'Test',
        hashtags: {},
        selectedApproach: 'test',
      ),
    );
    registerFallbackValue(_createPendingUpload(status: UploadStatus.pending));
  });

  setUp(() {
    mockUploadManager = MockUploadManager();
    mockDraftMaterializer = _MockDraftUploadMaterializer();
    mockAuthService = MockAuthService();
    mockVideoEventPublisher = MockVideoEventPublisher();
    mockBlossomService = MockBlossomUploadService();
    mockDraftService = MockDraftStorageService();
    mockCollaboratorInviteService = MockCollaboratorInviteService();
    mockMentionResolutionService = MockMentionResolutionService();
    fakePerformanceMonitor = _FakePerformanceMonitor();

    progressChanges = [];

    // Default: the draft belongs to the signed-in account. The ownership guard
    // is exercised explicitly in the "account switch" group.
    when(
      () => mockDraftService.isDraftOwnedByAnotherAccount(any()),
    ).thenAnswer((_) async => false);

    // The materializer turns a draft into an uploadable file; its own
    // behaviour is covered by draft_upload_materializer_test.dart.
    when(
      () => mockDraftMaterializer.materialize(
        draft: any(named: 'draft'),
        pendingUploads: any(named: 'pendingUploads'),
        videoDuration: any(named: 'videoDuration'),
      ),
    ).thenAnswer(
      (_) async => (
        videoFile: File('/test/video.mp4'),
        videoWidth: 640,
        videoHeight: 480,
        videoDuration: const Duration(seconds: 6),
        transientRenderPaths: <String>{},
      ),
    );

    service = VideoPublishService(
      draftMaterializer: mockDraftMaterializer,
      uploadManager: mockUploadManager,
      authService: mockAuthService,
      videoEventPublisher: mockVideoEventPublisher,
      blossomService: mockBlossomService,
      draftService: mockDraftService,
      collaboratorInviteService: mockCollaboratorInviteService,
      mentionResolutionService: mockMentionResolutionService,
      performanceMonitor: fakePerformanceMonitor,
      onProgressChanged:
          ({required double progress, required String draftId}) =>
              progressChanges.add(progress),
    );
  });

  group('VideoPublishService', () {
    group('publishVideo', () {
      test('returns error when user is not authenticated', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.notSignedIn);
      });

      test('reports the publish breakdown as one performance trace', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );

        await service.publishVideo(draft: _createTestDraft());

        expect(
          fakePerformanceMonitor.startedOperations,
          equals([publishTraceName]),
        );
        expect(
          fakePerformanceMonitor.trace.attributes['outcome'],
          equals('success'),
        );
        expect(
          fakePerformanceMonitor.trace.metrics,
          contains(publishTotalMetric),
        );
        expect(fakePerformanceMonitor.trace.stopCount, equals(1));
      });

      test('tags a failed publish with the error it ended on', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});

        await service.publishVideo(draft: _createTestDraft());

        expect(
          fakePerformanceMonitor.trace.attributes['outcome'],
          equals('error:notSignedIn'),
        );
      });

      test('still reports a publish that threw its way out', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockDraftService.isDraftOwnedByAnotherAccount(any()),
        ).thenThrow(StateError('storage gone'));

        await expectLater(
          service.publishVideo(draft: _createTestDraft()),
          throwsStateError,
        );

        // A publish that escapes by exception is the one most worth seeing in
        // the console, and it must not land in the success distribution.
        expect(
          fakePerformanceMonitor.trace.attributes['outcome'],
          equals('threw'),
        );
        expect(fakePerformanceMonitor.trace.stopCount, equals(1));
      });

      test(
        'returns success and leaves the draft for the bloc to reclaim',
        () async {
          // Draft deletion and its file cleanup are BackgroundPublishBloc's job
          // and run after the success state is emitted — the video is already
          // live, so the caller must not wait on garbage collection (#6548).
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );

          final draft = _createTestDraft();

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verifyNever(() => mockDraftService.deleteDraft(any()));
        },
      );

      test('reports the published video d tag on success', () async {
        // The post-publish confirmation links to /video/<stableId> and
        // builds its share URL from this. Without it the success result
        // says a video exists but not which one.
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
          readyUpload: _createPendingUpload(
            status: UploadStatus.readyToPublish,
            videoId: 'published-d-tag',
          ),
        );

        final result = await service.publishVideo(draft: _createTestDraft());

        expect(
          result,
          isA<PublishSuccess>().having(
            (r) => r.stableId,
            'stableId',
            equals('published-d-tag'),
          ),
        );
      });

      test('reports no d tag when the upload carried an empty one', () async {
        // An empty videoId is as unusable as a missing one — it would route
        // to `/video/` and share `divine.video/video/`. Reporting it as null
        // is what makes the confirmation fall back to the snackbar.
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
          readyUpload: _createPendingUpload(
            status: UploadStatus.readyToPublish,
            videoId: '',
          ),
        );

        final result = await service.publishVideo(draft: _createTestDraft());

        expect(
          result,
          isA<PublishSuccess>().having((r) => r.stableId, 'stableId', isNull),
        );
      });

      test('holds the bar below 100% until the event lands', () async {
        // Arrange
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );

        // Snapshot the bar at the moment the Nostr publish begins — signing
        // and broadcasting took ~2s on device, and the bar used to sit at
        // 100% for all of it.
        late List<double> beforeEvent;
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
            collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
            mentionedPubkeys: any(named: 'mentionedPubkeys'),
            inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
            inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
            inspiredByNpub: any(named: 'inspiredByNpub'),
            clipSourceCredits: any(named: 'clipSourceCredits'),
            selectedAudio: any(named: 'selectedAudio'),
            selectedAudioEventId: any(named: 'selectedAudioEventId'),
            selectedAudioRelay: any(named: 'selectedAudioRelay'),
            language: any(named: 'language'),
            contentWarning: any(named: 'contentWarning'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            replyContext: any(named: 'replyContext'),
            addReplyToFeed: any(named: 'addReplyToFeed'),
            textTrackRefs: any(named: 'textTrackRefs'),
            textTrackLang: any(named: 'textTrackLang'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        ).thenAnswer((invocation) async {
          beforeEvent = List<double>.of(progressChanges);
          // Standing in for the publisher: it reports back once the event is
          // signed, part-way through a phase that measured ~1.5s on device.
          // This pins the service's end of the contract — that it passes a
          // callback which moves the bar to the signing step. The publisher's
          // own forwarding is mocked out here.
          (invocation.namedArguments[#onEventSigned] as void Function()?)
              ?.call();
          return true;
        });

        // Act
        final result = await service.publishVideo(draft: _createTestDraft());

        // Assert
        expect(result, isA<PublishSuccess>());
        expect(beforeEvent, isNotEmpty);
        for (final value in beforeEvent) {
          expect(
            value,
            lessThan(1.0),
            reason: 'bar reported done while the event was still unpublished',
          );
        }
        expect(progressChanges.last, equals(1.0));
        expect(
          progressChanges,
          contains(0.92),
          reason: 'the signing step never reached the bar',
        );
        for (var i = 1; i < progressChanges.length; i++) {
          expect(
            progressChanges[i],
            greaterThanOrEqualTo(progressChanges[i - 1]),
            reason: 'progress went backwards: $progressChanges',
          );
        }
      });

      // The media is already uploaded when the sound's terms block the post, so
      // the user used to be told to check their relay settings for a problem no
      // relay setting can fix.
      //
      // The id is deliberately one that collides with the substring matcher
      // (`404` is valid hex): classifying by message instead of by type would
      // yield `serverNotFound`, so this also pins the type-first ordering in
      // `_classifyError`.
      test('reports a withheld sound as its own kind, not a relay '
          'failure', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );
        _stubPublishVideoEventThrows(
          mockVideoEventPublisher,
          AudioReuseNotPermittedException('404${'b' * 61}'),
        );

        final result = await service.publishVideo(draft: _createTestDraft());

        expect(
          result,
          isA<PublishError>()
              .having(
                (error) => error.kind,
                'kind',
                PublishErrorKind.audioReuseNotPermitted,
              )
              .having((error) => error.rawFallback, 'rawFallback', isNull),
        );
      });

      test(
        'reports an account restriction as terminal publish failure',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          _stubPublishVideoEventThrows(
            mockVideoEventPublisher,
            const AccountRestrictedPublishException(
              reason: 'blocked: pubkey is suspended',
              source: AccountRestrictionSource.rest,
            ),
          );

          final result = await service.publishVideo(draft: _createTestDraft());

          expect(
            result,
            isA<PublishError>().having(
              (error) => error.kind,
              'kind',
              PublishErrorKind.accountRestricted,
            ),
          );
        },
      );

      group('caption publishing', () {
        const overlayTrack = CaptionTrack(
          presetId: 'classic',
          languageTag: 'de-CH',
          cues: [
            CaptionCue(
              id: 'cue-0',
              text: 'Hallo.',
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
          ],
        );

        Map<String, dynamic> editingParamsFor(CaptionTrack track) => {
          'meta': {'captions': track.toJson()},
        };

        test(
          'uploads VTT, publishes 39307, and passes text-track refs',
          () async {
            _setupSuccessfulPublish(
              mockAuthService: mockAuthService,
              mockUploadManager: mockUploadManager,
              mockDraftService: mockDraftService,
              mockVideoEventPublisher: mockVideoEventPublisher,
            );
            when(
              () => mockBlossomService.uploadSubtitleVtt(
                bytes: any(named: 'bytes'),
              ),
            ).thenAnswer(
              (_) async => const BlossomUploadResult(
                success: true,
                url: 'https://media.divine.video/vtt123',
              ),
            );
            when(
              () => mockVideoEventPublisher.publishSubtitleTrack(
                vineId: any(named: 'vineId'),
                vttContent: any(named: 'vttContent'),
                blossomUrl: any(named: 'blossomUrl'),
                lang: any(named: 'lang'),
              ),
            ).thenAnswer((_) async => '39307:pk:subtitles:test_video_id');

            final result = await service.publishVideo(
              draft: _createTestDraft(
                editorEditingParameters: editingParamsFor(overlayTrack),
              ),
            );

            expect(result, isA<PublishSuccess>());
            // The 39307 targets the upload's vineId with the bare language.
            verify(
              () => mockVideoEventPublisher.publishSubtitleTrack(
                vineId: 'test_video_id',
                vttContent: any(named: 'vttContent'),
                blossomUrl: 'https://media.divine.video/vtt123',
                lang: 'de',
              ),
            ).called(1);
            final captured = verify(
              () => _verifyPublishVideoEvent(
                mockVideoEventPublisher,
                textTrackRefs: captureAny(named: 'textTrackRefs'),
                textTrackLang: captureAny(named: 'textTrackLang'),
              ),
            ).captured;
            expect(
              captured.first,
              equals([
                'https://media.divine.video/vtt123',
                '39307:pk:subtitles:test_video_id',
              ]),
            );
            expect(captured.last, equals('de'));
          },
        );

        test(
          'publishes the video without refs when the VTT upload fails',
          () async {
            _setupSuccessfulPublish(
              mockAuthService: mockAuthService,
              mockUploadManager: mockUploadManager,
              mockDraftService: mockDraftService,
              mockVideoEventPublisher: mockVideoEventPublisher,
            );
            when(
              () => mockBlossomService.uploadSubtitleVtt(
                bytes: any(named: 'bytes'),
              ),
            ).thenAnswer(
              (_) async => const BlossomUploadResult(
                success: false,
                errorMessage: 'boom',
              ),
            );

            final result = await service.publishVideo(
              draft: _createTestDraft(
                editorEditingParameters: editingParamsFor(overlayTrack),
              ),
            );

            expect(result, isA<PublishSuccess>());
            verifyNever(
              () => mockVideoEventPublisher.publishSubtitleTrack(
                vineId: any(named: 'vineId'),
                vttContent: any(named: 'vttContent'),
                blossomUrl: any(named: 'blossomUrl'),
                lang: any(named: 'lang'),
              ),
            );
            final captured = verify(
              () => _verifyPublishVideoEvent(
                mockVideoEventPublisher,
                textTrackRefs: captureAny(named: 'textTrackRefs'),
                textTrackLang: any(named: 'textTrackLang'),
              ),
            ).captured;
            expect(captured.single, isEmpty);
          },
        );

        test(
          'publishes without refs when the VTT upload never completes',
          () async {
            _setupSuccessfulPublish(
              mockAuthService: mockAuthService,
              mockUploadManager: mockUploadManager,
              mockDraftService: mockDraftService,
              mockVideoEventPublisher: mockVideoEventPublisher,
            );
            // A stalled Dio upload never resolves; the bounded deadline must
            // still let the primary video publish proceed without caption refs.
            when(
              () => mockBlossomService.uploadSubtitleVtt(
                bytes: any(named: 'bytes'),
              ),
            ).thenAnswer((_) => Completer<BlossomUploadResult>().future);

            final boundedService = VideoPublishService(
              draftMaterializer: mockDraftMaterializer,
              uploadManager: mockUploadManager,
              authService: mockAuthService,
              videoEventPublisher: mockVideoEventPublisher,
              blossomService: mockBlossomService,
              draftService: mockDraftService,
              collaboratorInviteService: mockCollaboratorInviteService,
              mentionResolutionService: mockMentionResolutionService,
              subtitlePublishTimeout: const Duration(milliseconds: 20),
              onProgressChanged:
                  ({required double progress, required String draftId}) =>
                      progressChanges.add(progress),
            );

            final result = await boundedService.publishVideo(
              draft: _createTestDraft(
                editorEditingParameters: editingParamsFor(overlayTrack),
              ),
            );

            expect(result, isA<PublishSuccess>());
            verifyNever(
              () => mockVideoEventPublisher.publishSubtitleTrack(
                vineId: any(named: 'vineId'),
                vttContent: any(named: 'vttContent'),
                blossomUrl: any(named: 'blossomUrl'),
                lang: any(named: 'lang'),
              ),
            );
            final captured = verify(
              () => _verifyPublishVideoEvent(
                mockVideoEventPublisher,
                textTrackRefs: captureAny(named: 'textTrackRefs'),
                textTrackLang: any(named: 'textTrackLang'),
              ),
            ).captured;
            expect(captured.single, isEmpty);
          },
        );

        test(
          'passes the uploaded VTT URL when subtitle event publish times out',
          () async {
            _setupSuccessfulPublish(
              mockAuthService: mockAuthService,
              mockUploadManager: mockUploadManager,
              mockDraftService: mockDraftService,
              mockVideoEventPublisher: mockVideoEventPublisher,
            );
            when(
              () => mockBlossomService.uploadSubtitleVtt(
                bytes: any(named: 'bytes'),
              ),
            ).thenAnswer(
              (_) async => const BlossomUploadResult(
                success: true,
                url: 'https://media.divine.video/vtt123',
              ),
            );
            when(
              () => mockVideoEventPublisher.publishSubtitleTrack(
                vineId: any(named: 'vineId'),
                vttContent: any(named: 'vttContent'),
                blossomUrl: any(named: 'blossomUrl'),
                lang: any(named: 'lang'),
              ),
            ).thenAnswer((_) => Completer<String?>().future);

            final boundedService = VideoPublishService(
              draftMaterializer: mockDraftMaterializer,
              uploadManager: mockUploadManager,
              authService: mockAuthService,
              videoEventPublisher: mockVideoEventPublisher,
              blossomService: mockBlossomService,
              draftService: mockDraftService,
              collaboratorInviteService: mockCollaboratorInviteService,
              mentionResolutionService: mockMentionResolutionService,
              subtitlePublishTimeout: const Duration(milliseconds: 20),
              onProgressChanged:
                  ({required double progress, required String draftId}) =>
                      progressChanges.add(progress),
            );

            final result = await boundedService.publishVideo(
              draft: _createTestDraft(
                editorEditingParameters: editingParamsFor(overlayTrack),
              ),
            );

            expect(result, isA<PublishSuccess>());
            final captured = verify(
              () => _verifyPublishVideoEvent(
                mockVideoEventPublisher,
                textTrackRefs: captureAny(named: 'textTrackRefs'),
                textTrackLang: any(named: 'textTrackLang'),
              ),
            ).captured;
            expect(
              captured.single,
              equals(['https://media.divine.video/vtt123']),
            );
          },
        );

        test(
          'passes the uploaded VTT URL when subtitle event publish throws',
          () async {
            _setupSuccessfulPublish(
              mockAuthService: mockAuthService,
              mockUploadManager: mockUploadManager,
              mockDraftService: mockDraftService,
              mockVideoEventPublisher: mockVideoEventPublisher,
            );
            when(
              () => mockBlossomService.uploadSubtitleVtt(
                bytes: any(named: 'bytes'),
              ),
            ).thenAnswer(
              (_) async => const BlossomUploadResult(
                success: true,
                url: 'https://media.divine.video/vtt123',
              ),
            );
            when(
              () => mockVideoEventPublisher.publishSubtitleTrack(
                vineId: any(named: 'vineId'),
                vttContent: any(named: 'vttContent'),
                blossomUrl: any(named: 'blossomUrl'),
                lang: any(named: 'lang'),
              ),
            ).thenThrow(StateError('relay unavailable'));

            final result = await service.publishVideo(
              draft: _createTestDraft(
                editorEditingParameters: editingParamsFor(overlayTrack),
              ),
            );

            expect(result, isA<PublishSuccess>());
            final captured = verify(
              () => _verifyPublishVideoEvent(
                mockVideoEventPublisher,
                textTrackRefs: captureAny(named: 'textTrackRefs'),
                textTrackLang: any(named: 'textTrackLang'),
              ),
            ).captured;
            expect(
              captured.single,
              equals(['https://media.divine.video/vtt123']),
            );
          },
        );

        test('publishes CC for burned-in caption tracks too', () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockBlossomService.uploadSubtitleVtt(
              bytes: any(named: 'bytes'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: 'https://media.divine.video/vtt123',
            ),
          );
          when(
            () => mockVideoEventPublisher.publishSubtitleTrack(
              vineId: any(named: 'vineId'),
              vttContent: any(named: 'vttContent'),
              blossomUrl: any(named: 'blossomUrl'),
              lang: any(named: 'lang'),
            ),
          ).thenAnswer((_) async => '39307:pk:subtitles:test_video_id');

          final result = await service.publishVideo(
            draft: _createTestDraft(
              editorEditingParameters: editingParamsFor(
                overlayTrack.copyWith(burnIn: true),
              ),
            ),
          );

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockBlossomService.uploadSubtitleVtt(
              bytes: any(named: 'bytes'),
            ),
          ).called(1);
        });

        test('publishes no CC when there are no cues', () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );

          final result = await service.publishVideo(
            draft: _createTestDraft(
              editorEditingParameters: editingParamsFor(
                const CaptionTrack(
                  burnIn: true,
                  presetId: 'pop',
                  languageTag: 'en-US',
                ),
              ),
            ),
          );

          expect(result, isA<PublishSuccess>());
          verifyNever(
            () => mockBlossomService.uploadSubtitleVtt(
              bytes: any(named: 'bytes'),
            ),
          );
        });
      });

      test(
        'publishes a stop-motion draft whose clips.first has no rendered mp4',
        () async {
          // Regression: the publish flow used to read clips.first.requireVideo
          // for a log line, which threw StateError for a frames-only
          // stop-motion clip and aborted the whole publish. The rendered mp4
          // lives in finalRenderedClip, and the upload path already prefers it.
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );

          final draft = DivineVideoDraft.create(
            clips: [_createStopMotionClip()],
            title: 'Stop Motion',
            description: 'Test',
            hashtags: {'test'},
            selectedApproach: 'test',
            id: 'stop_motion_draft_id',
            finalRenderedClip: _createTestClip(),
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
        },
      );

      test(
        'returns error and does not publish when upload has no CDN thumbnail',
        () async {
          // Arrange
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
            readyUpload: _createPendingUpload(
              status: UploadStatus.readyToPublish,
              thumbnailPath: null,
            ),
          );

          final draft = _createTestDraft();

          // Act
          final result = await service.publishVideo(draft: draft);

          // Assert
          expect(result, isA<PublishError>());
          expect(
            (result as PublishError).kind,
            PublishErrorKind.thumbnailFailed,
          );
          verifyNever(
            () => mockVideoEventPublisher.publishVideoEvent(
              upload: any(named: 'upload'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              expirationTimestamp: any(named: 'expirationTimestamp'),
              allowAudioReuse: any(named: 'allowAudioReuse'),
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
              inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
              inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
              inspiredByNpub: any(named: 'inspiredByNpub'),
              clipSourceCredits: any(named: 'clipSourceCredits'),
              selectedAudio: any(named: 'selectedAudio'),
              selectedAudioEventId: any(named: 'selectedAudioEventId'),
              selectedAudioRelay: any(named: 'selectedAudioRelay'),
              language: any(named: 'language'),
              contentWarning: any(named: 'contentWarning'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              replyContext: any(named: 'replyContext'),
              addReplyToFeed: any(named: 'addReplyToFeed'),
              onEventSigned: any(named: 'onEventSigned'),
              onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
            ),
          );
        },
      );

      test(
        'passes picked caption mentions through as selected bindings',
        () async {
          // The picker exists to disambiguate: without the binding reaching
          // the resolver, an ambiguous display name produces no p tag at all.
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              selectedMentions: any(named: 'selectedMentions'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer(
            (_) async => const MentionResolutionResult(
              canonicalText: '',
              resolvedPubkeys: [descriptionMentionPubkey],
              unresolvedTokens: [],
            ),
          );

          final draft = _createTestDraft(
            description: 'dedicated to @OG-AB',
            captionMentions: const [
              CaptionMention(
                display: 'OG-AB',
                pubkey: descriptionMentionPubkey,
                start: 14,
                end: 20,
              ),
            ],
          );

          final result = await service.publishVideo(draft: draft);
          expect(result, isA<PublishSuccess>());

          final captured =
              verify(
                    () => mockMentionResolutionService.resolveTextMentions(
                      rawText: any(named: 'rawText'),
                      selectedMentions: captureAny(named: 'selectedMentions'),
                      currentUserPubkey: any(named: 'currentUserPubkey'),
                    ),
                  ).captured.single
                  as List<MentionBinding>;

          expect(
            captured,
            equals(const [
              MentionBinding(
                display: 'OG-AB',
                pubkey: descriptionMentionPubkey,
                start: 14,
                end: 20,
              ),
            ]),
          );
        },
      );

      test(
        'resolves mentions from description and text overlays before publishing',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((invocation) async {
            final rawText = invocation.namedArguments[#rawText] as String;
            expect(rawText, contains('caption from @alice'));
            expect(rawText, contains('overlay by @bob'));

            return const MentionResolutionResult(
              canonicalText: '',
              resolvedPubkeys: [
                descriptionMentionPubkey,
                overlayMentionPubkey,
                collaboratorPubkey,
              ],
              unresolvedTokens: [],
            );
          });

          final draft = _createTestDraft(
            description: 'caption from @alice',
            collaboratorPubkeys: {collaboratorPubkey},
            editorStateHistory: {
              'position': 0,
              'references': {
                'text-layer-1': TextLayer(
                  id: 'text-layer-1',
                  text: 'overlay by @bob',
                ).toMap(),
              },
              'history': [
                {
                  'layers': [
                    {'id': 'text-layer-1'},
                  ],
                },
              ],
            },
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockVideoEventPublisher.publishVideoEvent(
              upload: any(named: 'upload'),
              title: any(named: 'title'),
              description: 'caption from @alice',
              hashtags: any(named: 'hashtags'),
              expirationTimestamp: any(named: 'expirationTimestamp'),
              allowAudioReuse: any(named: 'allowAudioReuse'),
              collaboratorPubkeys: [collaboratorPubkey],
              mentionedPubkeys: const [
                descriptionMentionPubkey,
                overlayMentionPubkey,
              ],
              inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
              inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
              inspiredByNpub: any(named: 'inspiredByNpub'),
              clipSourceCredits: any(named: 'clipSourceCredits'),
              selectedAudio: any(named: 'selectedAudio'),
              selectedAudioEventId: any(named: 'selectedAudioEventId'),
              selectedAudioRelay: any(named: 'selectedAudioRelay'),
              language: any(named: 'language'),
              contentWarning: any(named: 'contentWarning'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              replyContext: any(named: 'replyContext'),
              addReplyToFeed: any(named: 'addReplyToFeed'),
              onEventSigned: any(named: 'onEventSigned'),
              onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
            ),
          ).called(1);
        },
      );

      test(
        'resolves text overlay mentions only from current editor history item',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((invocation) async {
            final rawText = invocation.namedArguments[#rawText] as String;
            expect(rawText, contains('current @newmention'));
            expect(rawText, isNot(contains('deleted @oldmention')));

            return const MentionResolutionResult(
              canonicalText: '',
              resolvedPubkeys: [overlayMentionPubkey],
              unresolvedTokens: [],
            );
          });

          final draft = _createTestDraft(
            description: '',
            editorStateHistory: {
              'position': 1,
              'references': {
                'deleted-layer': TextLayer(
                  id: 'deleted-layer',
                  text: 'deleted @oldmention',
                ).toMap(),
                'current-layer': TextLayer(
                  id: 'current-layer',
                  text: 'current @newmention',
                ).toMap(),
              },
              'history': [
                {
                  'layers': [
                    {'id': 'deleted-layer'},
                  ],
                },
                {
                  'layers': [
                    {'id': 'current-layer'},
                  ],
                },
              ],
            },
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockVideoEventPublisher.publishVideoEvent(
              upload: any(named: 'upload'),
              title: any(named: 'title'),
              description: '',
              hashtags: any(named: 'hashtags'),
              expirationTimestamp: any(named: 'expirationTimestamp'),
              allowAudioReuse: any(named: 'allowAudioReuse'),
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              mentionedPubkeys: const [overlayMentionPubkey],
              inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
              inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
              inspiredByNpub: any(named: 'inspiredByNpub'),
              clipSourceCredits: any(named: 'clipSourceCredits'),
              selectedAudio: any(named: 'selectedAudio'),
              selectedAudioEventId: any(named: 'selectedAudioEventId'),
              selectedAudioRelay: any(named: 'selectedAudioRelay'),
              language: any(named: 'language'),
              contentWarning: any(named: 'contentWarning'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              replyContext: any(named: 'replyContext'),
              addReplyToFeed: any(named: 'addReplyToFeed'),
              onEventSigned: any(named: 'onEventSigned'),
              onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
            ),
          ).called(1);
        },
      );

      test('publishes without mention tags when resolution fails', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );
        when(
          () => mockMentionResolutionService.resolveTextMentions(
            rawText: any(named: 'rawText'),
            currentUserPubkey: any(named: 'currentUserPubkey'),
          ),
        ).thenThrow(Exception('profile search unavailable'));

        final draft = _createTestDraft(description: 'caption from @alice');

        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishSuccess>());
        final captured = verify(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
            collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
            mentionedPubkeys: captureAny(named: 'mentionedPubkeys'),
            inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
            inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
            inspiredByNpub: any(named: 'inspiredByNpub'),
            clipSourceCredits: any(named: 'clipSourceCredits'),
            selectedAudio: any(named: 'selectedAudio'),
            selectedAudioEventId: any(named: 'selectedAudioEventId'),
            selectedAudioRelay: any(named: 'selectedAudioRelay'),
            language: any(named: 'language'),
            contentWarning: any(named: 'contentWarning'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            replyContext: any(named: 'replyContext'),
            addReplyToFeed: any(named: 'addReplyToFeed'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        )..called(1);
        expect(captured.captured.single, isEmpty);
      });

      test('collaborator invites are sent after successful publish', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );
        when(
          () => mockCollaboratorInviteService.sendInvites(
            collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
            creatorPubkey: any(named: 'creatorPubkey'),
            videoAddress: any(named: 'videoAddress'),
            title: any(named: 'title'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            relayHint: any(named: 'relayHint'),
          ),
        ).thenAnswer(
          (_) async => const CollaboratorInviteBatchResult(results: {}),
        );

        final draft = _createTestDraft(
          collaboratorPubkeys: {
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        );

        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishSuccess>());
        verify(
          () => mockCollaboratorInviteService.sendInvites(
            collaboratorPubkeys: draft.collaboratorPubkeys,
            creatorPubkey: 'test_pubkey',
            videoAddress: '34236:test_pubkey:test_video_id',
            title: 'Test Video',
            thumbnailUrl: _defaultThumbnailPath,
            relayHint: 'wss://relay.divine.video',
          ),
        ).called(1);
      });

      test(
        'excludes a restored self-collaborator from publishing and invites',
        () async {
          const creatorPubkey =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          const collaboratorPubkey =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(creatorPubkey);
          when(
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ).thenAnswer(
            (_) async => const CollaboratorInviteBatchResult(results: {}),
          );
          final draft = _createTestDraft(
            collaboratorPubkeys: {
              creatorPubkey.toUpperCase(),
              NostrKeyUtils.encodePubKey(creatorPubkey),
              collaboratorPubkey.toUpperCase(),
              NostrKeyUtils.encodePubKey(collaboratorPubkey),
              'not-a-pubkey',
            },
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          final publishedCollaborators =
              verify(
                    () => mockVideoEventPublisher.publishVideoEvent(
                      upload: any(named: 'upload'),
                      title: any(named: 'title'),
                      description: any(named: 'description'),
                      hashtags: any(named: 'hashtags'),
                      expirationTimestamp: any(named: 'expirationTimestamp'),
                      allowAudioReuse: any(named: 'allowAudioReuse'),
                      collaboratorPubkeys: captureAny(
                        named: 'collaboratorPubkeys',
                      ),
                      mentionedPubkeys: any(named: 'mentionedPubkeys'),
                      inspiredByAddressableId: any(
                        named: 'inspiredByAddressableId',
                      ),
                      inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
                      inspiredByNpub: any(named: 'inspiredByNpub'),
                      clipSourceCredits: any(named: 'clipSourceCredits'),
                      selectedAudio: any(named: 'selectedAudio'),
                      selectedAudioEventId: any(named: 'selectedAudioEventId'),
                      selectedAudioRelay: any(named: 'selectedAudioRelay'),
                      language: any(named: 'language'),
                      contentWarning: any(named: 'contentWarning'),
                      thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
                      replyContext: any(named: 'replyContext'),
                      addReplyToFeed: any(named: 'addReplyToFeed'),
                      onEventSigned: any(named: 'onEventSigned'),
                      onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
                    ),
                  ).captured.single
                  as List<String>;
          final invitedCollaborators =
              verify(
                    () => mockCollaboratorInviteService.sendInvites(
                      collaboratorPubkeys: captureAny(
                        named: 'collaboratorPubkeys',
                      ),
                      creatorPubkey: creatorPubkey,
                      videoAddress: any(named: 'videoAddress'),
                      title: any(named: 'title'),
                      thumbnailUrl: any(named: 'thumbnailUrl'),
                      relayHint: any(named: 'relayHint'),
                    ),
                  ).captured.single
                  as Iterable<String>;
          expect(publishedCollaborators, [collaboratorPubkey]);
          expect(invitedCollaborators, [collaboratorPubkey]);
        },
      );

      test('collaborator invites include the uploaded thumbnail URL', () async {
        const thumbnailUrl = 'https://cdn.divine.video/thumbs/test_video.jpg';
        final readyUpload = _createPendingUpload(
          status: UploadStatus.readyToPublish,
          thumbnailPath: thumbnailUrl,
        );
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
          readyUpload: readyUpload,
        );
        when(
          () => mockCollaboratorInviteService.sendInvites(
            collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
            creatorPubkey: any(named: 'creatorPubkey'),
            videoAddress: any(named: 'videoAddress'),
            title: any(named: 'title'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            relayHint: any(named: 'relayHint'),
          ),
        ).thenAnswer(
          (_) async => const CollaboratorInviteBatchResult(results: {}),
        );

        final draft = _createTestDraft(
          collaboratorPubkeys: {
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        );

        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishSuccess>());
        verify(
          () => mockCollaboratorInviteService.sendInvites(
            collaboratorPubkeys: draft.collaboratorPubkeys,
            creatorPubkey: 'test_pubkey',
            videoAddress: '34236:test_pubkey:test_video_id',
            title: 'Test Video',
            thumbnailUrl: thumbnailUrl,
            relayHint: 'wss://relay.divine.video',
          ),
        ).called(1);
      });

      test(
        'publishes video event before sending collaborator invites',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ).thenAnswer(
            (_) async => const CollaboratorInviteBatchResult(results: {}),
          );

          final draft = _createTestDraft(
            collaboratorPubkeys: {
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            },
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verifyInOrder([
            () => mockVideoEventPublisher.publishVideoEvent(
              upload: any(named: 'upload'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              expirationTimestamp: any(named: 'expirationTimestamp'),
              allowAudioReuse: any(named: 'allowAudioReuse'),
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
              inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
              inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
              inspiredByNpub: any(named: 'inspiredByNpub'),
              clipSourceCredits: any(named: 'clipSourceCredits'),
              selectedAudio: any(named: 'selectedAudio'),
              selectedAudioEventId: any(named: 'selectedAudioEventId'),
              selectedAudioRelay: any(named: 'selectedAudioRelay'),
              language: any(named: 'language'),
              contentWarning: any(named: 'contentWarning'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              replyContext: any(named: 'replyContext'),
              addReplyToFeed: any(named: 'addReplyToFeed'),
              onEventSigned: any(named: 'onEventSigned'),
              onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
            ),
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ]);
        },
      );

      test(
        'does not send collaborator invites when event publish fails',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);
          when(() => mockUploadManager.pendingUploads).thenReturn([]);
          when(
            () => mockUploadManager.startUpload(
              videoFile: any(named: 'videoFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              videoWidth: any(named: 'videoWidth'),
              videoHeight: any(named: 'videoHeight'),
              videoDuration: any(named: 'videoDuration'),
              proofManifestJson: any(named: 'proofManifestJson'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer(
            (_) async =>
                _createPendingUpload(status: UploadStatus.readyToPublish),
          );
          when(() => mockUploadManager.getUpload(any())).thenReturn(
            _createPendingUpload(status: UploadStatus.readyToPublish),
          );
          when(
            () => mockVideoEventPublisher.publishVideoEvent(
              upload: any(named: 'upload'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              expirationTimestamp: any(named: 'expirationTimestamp'),
              allowAudioReuse: any(named: 'allowAudioReuse'),
              selectedAudio: any(named: 'selectedAudio'),
              onEventSigned: any(named: 'onEventSigned'),
              onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://test.server');

          final draft = _createTestDraft(
            collaboratorPubkeys: {
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            },
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishError>());
          verifyNever(
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          );
        },
      );

      test(
        'collaborator invite failure does not fail successful publish',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ).thenAnswer(
            (_) async => const CollaboratorInviteBatchResult(
              results: {
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb':
                    CollaboratorInviteResult(
                      success: false,
                      error: 'relay unavailable',
                    ),
              },
            ),
          );

          final draft = _createTestDraft(
            collaboratorPubkeys: {
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            },
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
        },
      );

      test(
        'successful publish exposes failed collaborator invite warnings',
        () async {
          const collaboratorPubkey =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          const thumbnailUrl = 'https://cdn.divine.video/thumbs/test_video.jpg';
          final readyUpload = _createPendingUpload(
            status: UploadStatus.readyToPublish,
            thumbnailPath: thumbnailUrl,
          );
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
            readyUpload: readyUpload,
          );
          when(
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ).thenAnswer(
            (_) async => const CollaboratorInviteBatchResult(
              results: {
                collaboratorPubkey: CollaboratorInviteResult(
                  success: false,
                  error: 'relay unavailable',
                ),
              },
            ),
          );

          final draft = _createTestDraft(
            collaboratorPubkeys: {collaboratorPubkey},
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          final success = result as PublishSuccess;
          expect(success.inviteWarnings, hasLength(1));
          expect(
            success.inviteWarnings.single.collaboratorPubkey,
            collaboratorPubkey,
          );
          expect(success.inviteWarnings.single.creatorPubkey, 'test_pubkey');
          expect(
            success.inviteWarnings.single.videoAddress,
            '34236:test_pubkey:test_video_id',
          );
          expect(success.inviteWarnings.single.title, 'Test Video');
          expect(success.inviteWarnings.single.thumbnailUrl, thumbnailUrl);
          expect(
            success.inviteWarnings.single.relayHint,
            'wss://relay.divine.video',
          );
          expect(success.inviteWarnings.single.error, 'relay unavailable');
        },
      );

      test(
        'successful publish does not warn for a queued collaborator invite',
        () async {
          const collaboratorPubkey =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          when(
            () => mockCollaboratorInviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ).thenAnswer(
            (_) async => const CollaboratorInviteBatchResult(
              results: {
                collaboratorPubkey: CollaboratorInviteResult(
                  success: false,
                  retryablePending: true,
                ),
              },
            ),
          );

          final result = await service.publishVideo(
            draft: _createTestDraft(
              collaboratorPubkeys: {collaboratorPubkey},
            ),
          );

          expect(result, isA<PublishSuccess>());
          expect((result as PublishSuccess).inviteWarnings, isEmpty);
        },
      );

      test('returns error when video event publishing fails', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async =>
              _createPendingUpload(status: UploadStatus.readyToPublish),
        );
        when(
          () => mockUploadManager.getUpload(any()),
        ).thenReturn(_createPendingUpload(status: UploadStatus.readyToPublish));
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
            selectedAudio: any(named: 'selectedAudio'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://test.server');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
      });

      test('saves draft with publishing status before starting', () async {
        // Arrange
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );

        final draft = _createTestDraft();

        // Act
        await service.publishVideo(draft: draft);

        // Assert
        verify(() => mockDraftService.saveDraft(any())).called(greaterThan(0));
      });

      test('initializes upload manager if not initialized', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(false);
        when(() => mockUploadManager.initialize()).thenAnswer((_) async {});
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async =>
              _createPendingUpload(status: UploadStatus.readyToPublish),
        );
        when(
          () => mockUploadManager.getUpload(any()),
        ).thenReturn(_createPendingUpload(status: UploadStatus.readyToPublish));
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
            selectedAudio: any(named: 'selectedAudio'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        ).thenAnswer((_) async => true);

        final draft = _createTestDraft();

        // Act
        await service.publishVideo(draft: draft);

        // Assert
        verify(() => mockUploadManager.initialize()).called(1);
      });

      test('returns error when upload fails', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => _createPendingUpload(
            status: UploadStatus.failed,
            errorMessage: 'Network error',
          ),
        );
        when(() => mockUploadManager.getUpload(any())).thenReturn(
          _createPendingUpload(
            status: UploadStatus.failed,
            errorMessage: 'Network error',
          ),
        );
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://test.server');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
      });
    });

    // Switching accounts mid-upload leaves the leaving account's draft
    // reachable from the new session. Publishing it would sign the video with
    // the wrong identity and reassign the draft's owner on the way.
    group('account switched mid-upload', () {
      setUp(() {
        when(
          () => mockDraftService.isDraftOwnedByAnotherAccount(any()),
        ).thenAnswer((_) async => true);
      });

      test('publishVideo refuses a draft owned by another account', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );
        final draft = _createTestDraft();

        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.accountChanged);
        verifyNever(() => mockDraftService.saveDraft(any()));
        verifyNever(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        );
        verifyNever(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        );
      });
    });

    group('paused upload polling', () {
      test(
        'terminates instead of polling a paused upload forever',
        () async {
          // UploadStatus.paused is a tombstone (#6935) — no shipped code path
          // writes it. _pollUploadProgress used to treat it as a poll state and
          // recurse with no timeout or iteration cap, so a paused row hung the
          // publish flow at 20 Hz forever. This test times out if that returns.
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);
          when(() => mockUploadManager.pendingUploads).thenReturn([]);

          final pausedUpload = _createPendingUpload(
            status: UploadStatus.paused,
          );
          when(
            () => mockUploadManager.startUpload(
              videoFile: any(named: 'videoFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              videoWidth: any(named: 'videoWidth'),
              videoHeight: any(named: 'videoHeight'),
              videoDuration: any(named: 'videoDuration'),
              proofManifestJson: any(named: 'proofManifestJson'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => pausedUpload);
          when(
            () => mockUploadManager.getUpload(any()),
          ).thenReturn(pausedUpload);

          final result = await service.publishVideo(draft: _createTestDraft());

          expect(result, isA<PublishError>());
        },
        timeout: const Timeout(Duration(seconds: 15)),
      );
    });

    group('draft upload composition', () {
      test(
        'forwards materialized output and registers transient renders',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );
          final videoFile = File('/materialized/video.mp4');
          const transientPaths = {'/materialized/stop-motion.mp4'};
          when(
            () => mockDraftMaterializer.materialize(
              draft: any(named: 'draft'),
              pendingUploads: any(named: 'pendingUploads'),
              videoDuration: any(named: 'videoDuration'),
            ),
          ).thenAnswer(
            (_) async => (
              videoFile: videoFile,
              videoWidth: 1080,
              videoHeight: 1920,
              videoDuration: const Duration(seconds: 5),
              transientRenderPaths: transientPaths,
            ),
          );
          final draft = _createTestDraft(
            proofManifestJson: '{"proof":"manifest"}',
            thumbnailTimestamp: const Duration(seconds: 2),
          );

          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockUploadManager.startUpload(
              videoFile: videoFile,
              nostrPubkey: 'test_pubkey',
              title: 'Test Video',
              description: 'Test description',
              hashtags: any(
                named: 'hashtags',
                that: unorderedEquals(['test', 'video']),
              ),
              videoWidth: 1080,
              videoHeight: 1920,
              videoDuration: const Duration(seconds: 5),
              proofManifestJson: '{"proof":"manifest"}',
              thumbnailTimestamp: const Duration(seconds: 2),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          verify(
            () => mockUploadManager.registerTransientRenderPaths(
              'test_upload_id',
              transientPaths,
            ),
          ).called(1);
        },
      );
    });

    group('upload reuse', () {
      test('reuses readyToPublish upload matching video path', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);

        final readyUpload = _createPendingUpload(
          status: UploadStatus.readyToPublish,
        );
        when(
          () => mockUploadManager.findReusableUpload(any()),
        ).thenReturn(readyUpload);
        when(() => mockUploadManager.getUpload(any())).thenReturn(readyUpload);
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
            selectedAudio: any(named: 'selectedAudio'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        ).thenAnswer((_) async => true);

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishSuccess>());
        // Should NOT have started a new upload.
        verifyNever(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      });

      test(
        'falls through to new upload when no reusable upload exists',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );

          // Explicitly return null for path lookup.
          when(
            () => mockUploadManager.findReusableUpload(any()),
          ).thenReturn(null);

          final draft = _createTestDraft();
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockUploadManager.startUpload(
              videoFile: any(named: 'videoFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              videoWidth: any(named: 'videoWidth'),
              videoHeight: any(named: 'videoHeight'),
              videoDuration: any(named: 'videoDuration'),
              proofManifestJson: any(named: 'proofManifestJson'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
        },
      );

      test('resumes interrupted upload when reusable upload is in '
          'uploading status', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);

        final uploadingUpload = _createPendingUpload(
          status: UploadStatus.uploading,
        );
        final readyUpload = _createPendingUpload(
          status: UploadStatus.readyToPublish,
        );

        when(
          () => mockUploadManager.findReusableUpload(any()),
        ).thenReturn(uploadingUpload);

        // First call returns uploading (triggers resume),
        // subsequent calls return readyToPublish (poll succeeds).
        var getUploadCalls = 0;
        when(() => mockUploadManager.getUpload(any())).thenAnswer((_) {
          getUploadCalls++;
          return getUploadCalls <= 1 ? uploadingUpload : readyUpload;
        });
        when(
          () => mockUploadManager.resumeInterruptedUpload(any()),
        ).thenReturn(null);
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
            selectedAudio: any(named: 'selectedAudio'),
            onEventSigned: any(named: 'onEventSigned'),
            onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
          ),
        ).thenAnswer((_) async => true);

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishSuccess>());
        verify(
          () => mockUploadManager.resumeInterruptedUpload(uploadingUpload.id),
        ).called(1);
        verifyNever(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      });
    });

    group('error messages', () {
      test('returns user-friendly message for 404 error', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('404 not_found'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.serverNotFound);
        expect(result.serverName, 'media.divine.video');
      });

      test('returns user-friendly message for network error', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('network connection failed'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.generic);
      });

      test('returns user-friendly message for timeout error', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('Connection timed out'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.timeout);
      });

      test('returns user-friendly message for TLS/certificate error', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('HandshakeException: certificate verify failed'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.tls);
      });

      test('returns user-friendly message for 413 payload too large', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('413 payload too large'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.fileTooLarge);
      });

      test(
        'returns user-friendly message for 500 internal server error',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);
          when(() => mockUploadManager.pendingUploads).thenReturn([]);
          when(
            () => mockUploadManager.startUpload(
              videoFile: any(named: 'videoFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              videoWidth: any(named: 'videoWidth'),
              videoHeight: any(named: 'videoHeight'),
              videoDuration: any(named: 'videoDuration'),
              proofManifestJson: any(named: 'proofManifestJson'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenThrow(Exception('500 internal server error'));
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://media.divine.video');

          final draft = _createTestDraft();
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishError>());
          final error = result as PublishError;
          expect(error.kind, PublishErrorKind.serverInternalError);
          expect(error.serverName, 'media.divine.video');
        },
      );

      test(
        'returns user-friendly message for 502/503 service unavailable',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);
          when(() => mockUploadManager.pendingUploads).thenReturn([]);
          when(
            () => mockUploadManager.startUpload(
              videoFile: any(named: 'videoFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              hashtags: any(named: 'hashtags'),
              videoWidth: any(named: 'videoWidth'),
              videoHeight: any(named: 'videoHeight'),
              videoDuration: any(named: 'videoDuration'),
              proofManifestJson: any(named: 'proofManifestJson'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenThrow(Exception('502 bad gateway'));
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://media.divine.video');

          final draft = _createTestDraft();
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishError>());
          final error = result as PublishError;
          expect(error.kind, PublishErrorKind.serverDown);
          expect(error.serverName, 'media.divine.video');
        },
      );

      test('returns user-friendly message for 401 unauthorized', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('401 unauthorized'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.notSignedIn);
      });

      test('returns user-friendly message for 403 forbidden', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('403 forbidden'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.forbidden);
      });

      test('returns user-friendly message for file not found', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('No such file or directory'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.fileNotFound);
      });

      test('returns user-friendly message for storage full', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('no space left, disk full'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.lowStorage);
      });

      test('returns user-friendly message for Nostr relay failure', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('Failed to publish nostr event'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).kind,
          PublishErrorKind.nostrPublishFailed,
        );
      });

      test('returns user-friendly message for SocketException '
          '(no internet)', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('SocketException: Network is unreachable'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect((result as PublishError).kind, PublishErrorKind.noInternet);
      });

      test('returns user-friendly message for connection refused', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(() => mockUploadManager.pendingUploads).thenReturn([]);
        when(
          () => mockUploadManager.startUpload(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            videoWidth: any(named: 'videoWidth'),
            videoHeight: any(named: 'videoHeight'),
            videoDuration: any(named: 'videoDuration'),
            proofManifestJson: any(named: 'proofManifestJson'),
            thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('Connection refused'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).kind,
          PublishErrorKind.serverUnreachable,
        );
      });

      test('re-localizes an already-rendered upload-manager message instead of '
          'passing it through as English rawFallback', () async {
        // The upload manager hands the publish service an already-rendered
        // English sentence via PendingUpload.errorMessage. It must map to a
        // kind (so it re-localizes on resume), not survive as rawFallback.
        const message =
            'No internet connection. Check your WiFi or cellular data '
            'and try again.';
        _stubFailedUpload(
          mockAuthService: mockAuthService,
          mockDraftService: mockDraftService,
          mockUploadManager: mockUploadManager,
          mockBlossomService: mockBlossomService,
          errorMessage: message,
        );

        final result = await service.publishVideo(draft: _createTestDraft());

        expect(result, isA<PublishError>());
        final error = result as PublishError;
        expect(error.kind, PublishErrorKind.noInternet);
        expect(error.rawFallback, isNull);
      });

      test('re-localizes an upload-manager file-too-large message', () async {
        const message =
            'Video is too large to upload. Try recording a shorter video.';
        _stubFailedUpload(
          mockAuthService: mockAuthService,
          mockDraftService: mockDraftService,
          mockUploadManager: mockUploadManager,
          mockBlossomService: mockBlossomService,
          errorMessage: message,
        );

        final result = await service.publishVideo(draft: _createTestDraft());

        expect(result, isA<PublishError>());
        final error = result as PublishError;
        expect(error.kind, PublishErrorKind.fileTooLarge);
        expect(error.rawFallback, isNull);
      });

      test(
        'still renders a genuinely unknown upstream sentence via rawFallback',
        () async {
          const message =
              'A brand new upstream failure we do not classify yet. '
              'Please retry.';
          _stubFailedUpload(
            mockAuthService: mockAuthService,
            mockDraftService: mockDraftService,
            mockUploadManager: mockUploadManager,
            mockBlossomService: mockBlossomService,
            errorMessage: message,
          );

          final result = await service.publishVideo(draft: _createTestDraft());

          expect(result, isA<PublishError>());
          final error = result as PublishError;
          expect(error.kind, PublishErrorKind.generic);
          expect(error.rawFallback, message);
        },
      );
    });

    group('content language self-labelling', () {
      VideoPublishService buildServiceWithLanguage(
        LanguagePreferenceService languageService,
      ) => VideoPublishService(
        draftMaterializer: mockDraftMaterializer,
        uploadManager: mockUploadManager,
        authService: mockAuthService,
        videoEventPublisher: mockVideoEventPublisher,
        blossomService: mockBlossomService,
        draftService: mockDraftService,
        collaboratorInviteService: mockCollaboratorInviteService,
        mentionResolutionService: mockMentionResolutionService,
        performanceMonitor: fakePerformanceMonitor,
        languagePreferenceService: languageService,
        onProgressChanged:
            ({required double progress, required String draftId}) {},
      );

      test('omits the language tag when the user never declared one', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final languageService = LanguagePreferenceService();
        await languageService.initialize();

        await buildServiceWithLanguage(
          languageService,
        ).publishVideo(draft: _createTestDraft());

        final captured = verify(
          () => _verifyPublishVideoEvent(
            mockVideoEventPublisher,
            language: captureAny(named: 'language'),
            textTrackRefs: any(named: 'textTrackRefs'),
            textTrackLang: any(named: 'textTrackLang'),
          ),
        ).captured;
        expect(captured.single, isNull);
      });

      test('sends the declared language when the user chose one', () async {
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final languageService = LanguagePreferenceService();
        await languageService.initialize();
        await languageService.setContentLanguage('pt');

        await buildServiceWithLanguage(
          languageService,
        ).publishVideo(draft: _createTestDraft());

        final captured = verify(
          () => _verifyPublishVideoEvent(
            mockVideoEventPublisher,
            language: captureAny(named: 'language'),
            textTrackRefs: any(named: 'textTrackRefs'),
            textTrackLang: any(named: 'textTrackLang'),
          ),
        ).captured;
        expect(captured.single, equals('pt'));
      });
    });
  });
}

/// Stubs the publish flow so a fresh upload immediately resolves to a failed
/// [PendingUpload] carrying [errorMessage].
void _stubFailedUpload({
  required MockAuthService mockAuthService,
  required MockDraftStorageService mockDraftService,
  required MockUploadManager mockUploadManager,
  required MockBlossomUploadService mockBlossomService,
  required String errorMessage,
}) {
  when(() => mockAuthService.isAuthenticated).thenReturn(true);
  when(() => mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
  when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
  when(() => mockUploadManager.isInitialized).thenReturn(true);
  when(() => mockUploadManager.pendingUploads).thenReturn([]);
  final failed = _createPendingUpload(
    status: UploadStatus.failed,
    errorMessage: errorMessage,
  );
  when(
    () => mockUploadManager.startUpload(
      videoFile: any(named: 'videoFile'),
      nostrPubkey: any(named: 'nostrPubkey'),
      title: any(named: 'title'),
      description: any(named: 'description'),
      hashtags: any(named: 'hashtags'),
      videoWidth: any(named: 'videoWidth'),
      videoHeight: any(named: 'videoHeight'),
      videoDuration: any(named: 'videoDuration'),
      proofManifestJson: any(named: 'proofManifestJson'),
      thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
      onProgress: any(named: 'onProgress'),
    ),
  ).thenAnswer((_) async => failed);
  when(() => mockUploadManager.getUpload(any())).thenReturn(failed);
  when(
    () => mockBlossomService.getBlossomServer(),
  ).thenAnswer((_) async => 'https://media.divine.video');
}

// Helper functions

DivineVideoClip _createTestClip() {
  return DivineVideoClip(
    id: 'test_clip',
    video: EditorVideo.file('/test/video.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

/// A frames-only stop-motion clip whose mp4 is not rendered yet — its rendered
/// video lives in the draft's [DivineVideoDraft.finalRenderedClip].
DivineVideoClip _createStopMotionClip() {
  return DivineVideoClip(
    id: 'clip_sm_test',
    stopMotionFrames: const [
      StopMotionClipFrame(
        path: '/test/frame_0.jpg',
        duration: Duration(microseconds: 83333),
      ),
    ],
    duration: const Duration(seconds: 1),
    recordedAt: DateTime.now(),
    targetAspectRatio: AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

/// Re-stubs `publishVideoEvent` to throw [error], on top of an existing
/// [_setupSuccessfulPublish].
void _stubPublishVideoEventThrows(
  MockVideoEventPublisher publisher,
  Object error,
) {
  when(
    () => publisher.publishVideoEvent(
      upload: any(named: 'upload'),
      title: any(named: 'title'),
      description: any(named: 'description'),
      hashtags: any(named: 'hashtags'),
      expirationTimestamp: any(named: 'expirationTimestamp'),
      allowAudioReuse: any(named: 'allowAudioReuse'),
      collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
      mentionedPubkeys: any(named: 'mentionedPubkeys'),
      inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
      inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
      inspiredByNpub: any(named: 'inspiredByNpub'),
      clipSourceCredits: any(named: 'clipSourceCredits'),
      selectedAudio: any(named: 'selectedAudio'),
      audioShareAttribution: any(named: 'audioShareAttribution'),
      selectedAudioEventId: any(named: 'selectedAudioEventId'),
      selectedAudioRelay: any(named: 'selectedAudioRelay'),
      language: any(named: 'language'),
      contentWarning: any(named: 'contentWarning'),
      thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
      replyContext: any(named: 'replyContext'),
      addReplyToFeed: any(named: 'addReplyToFeed'),
      textTrackRefs: any(named: 'textTrackRefs'),
      textTrackLang: any(named: 'textTrackLang'),
      onEventSigned: any(named: 'onEventSigned'),
      onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
    ),
  ).thenThrow(error);
}

/// A full-argument `publishVideoEvent` matcher for `verify`, so tests only
/// spell out the arguments they capture. Mocktail's verify needs every named
/// argument of the actual invocation to be matched.
const Object _anyLanguageMatcher = Object();

Future<bool> _verifyPublishVideoEvent(
  MockVideoEventPublisher publisher, {
  required List<String> textTrackRefs,
  required String textTrackLang,
  dynamic language = _anyLanguageMatcher,
}) => publisher.publishVideoEvent(
  upload: any(named: 'upload'),
  title: any(named: 'title'),
  description: any(named: 'description'),
  hashtags: any(named: 'hashtags'),
  expirationTimestamp: any(named: 'expirationTimestamp'),
  allowAudioReuse: any(named: 'allowAudioReuse'),
  collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
  mentionedPubkeys: any(named: 'mentionedPubkeys'),
  inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
  inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
  inspiredByNpub: any(named: 'inspiredByNpub'),
  clipSourceCredits: any(named: 'clipSourceCredits'),
  selectedAudio: any(named: 'selectedAudio'),
  audioShareAttribution: any(named: 'audioShareAttribution'),
  selectedAudioEventId: any(named: 'selectedAudioEventId'),
  selectedAudioRelay: any(named: 'selectedAudioRelay'),
  language: identical(language, _anyLanguageMatcher)
      ? any(named: 'language') as String?
      : language as String?,
  contentWarning: any(named: 'contentWarning'),
  thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
  replyContext: any(named: 'replyContext'),
  addReplyToFeed: any(named: 'addReplyToFeed'),
  textTrackRefs: textTrackRefs,
  textTrackLang: textTrackLang,
  onEventSigned: any(named: 'onEventSigned'),
  onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
);

DivineVideoDraft _createTestDraft({
  String description = 'Test description',
  Map<String, dynamic> editorStateHistory = const {},
  Set<String> collaboratorPubkeys = const {},
  List<CaptionMention> captionMentions = const [],
  Map<String, dynamic>? editorEditingParameters,
  String? proofManifestJson,
  Duration? thumbnailTimestamp,
}) {
  return DivineVideoDraft.create(
    clips: [_createTestClip()],
    title: 'Test Video',
    description: description,
    hashtags: {'test', 'video'},
    selectedApproach: 'test',
    id: 'test_draft_id',
    editorStateHistory: editorStateHistory,
    collaboratorPubkeys: collaboratorPubkeys,
    captionMentions: captionMentions,
    editorEditingParameters: editorEditingParameters,
    proofManifestJson: proofManifestJson,
    thumbnailTimestamp: thumbnailTimestamp,
  );
}

PendingUpload _createPendingUpload({
  required UploadStatus status,
  String? errorMessage,
  Object? thumbnailPath = _defaultThumbnailPath,
  String videoId = 'test_video_id',
}) {
  return PendingUpload(
    id: 'test_upload_id',
    localVideoPath: '/test/video.mp4',
    nostrPubkey: 'test_pubkey',
    status: status,
    createdAt: DateTime.now(),
    errorMessage: errorMessage,
    uploadProgress: status == UploadStatus.readyToPublish ? 1.0 : 0.5,
    videoId: videoId,
    cdnUrl: 'https://test.cdn/video.mp4',
    thumbnailPath: thumbnailPath as String?,
  );
}

const String _defaultThumbnailPath = 'https://test.cdn/thumbnail.jpg';

void _setupSuccessfulPublish({
  required MockAuthService mockAuthService,
  required MockUploadManager mockUploadManager,
  required MockDraftStorageService mockDraftService,
  required MockVideoEventPublisher mockVideoEventPublisher,
  PendingUpload? readyUpload,
}) {
  final upload =
      readyUpload ?? _createPendingUpload(status: UploadStatus.readyToPublish);
  when(() => mockAuthService.isAuthenticated).thenReturn(true);
  when(() => mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
  when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
  when(() => mockUploadManager.isInitialized).thenReturn(true);
  when(() => mockUploadManager.pendingUploads).thenReturn([]);
  when(
    () => mockUploadManager.startUpload(
      videoFile: any(named: 'videoFile'),
      nostrPubkey: any(named: 'nostrPubkey'),
      title: any(named: 'title'),
      description: any(named: 'description'),
      hashtags: any(named: 'hashtags'),
      videoWidth: any(named: 'videoWidth'),
      videoHeight: any(named: 'videoHeight'),
      videoDuration: any(named: 'videoDuration'),
      proofManifestJson: any(named: 'proofManifestJson'),
      thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
      onProgress: any(named: 'onProgress'),
    ),
  ).thenAnswer((_) async => upload);
  when(() => mockUploadManager.getUpload(any())).thenReturn(upload);
  when(
    () => mockVideoEventPublisher.publishVideoEvent(
      upload: any(named: 'upload'),
      title: any(named: 'title'),
      description: any(named: 'description'),
      hashtags: any(named: 'hashtags'),
      expirationTimestamp: any(named: 'expirationTimestamp'),
      allowAudioReuse: any(named: 'allowAudioReuse'),
      collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
      mentionedPubkeys: any(named: 'mentionedPubkeys'),
      inspiredByAddressableId: any(named: 'inspiredByAddressableId'),
      inspiredByRelayUrl: any(named: 'inspiredByRelayUrl'),
      inspiredByNpub: any(named: 'inspiredByNpub'),
      clipSourceCredits: any(named: 'clipSourceCredits'),
      selectedAudio: any(named: 'selectedAudio'),
      audioShareAttribution: any(named: 'audioShareAttribution'),
      selectedAudioEventId: any(named: 'selectedAudioEventId'),
      selectedAudioRelay: any(named: 'selectedAudioRelay'),
      language: any(named: 'language'),
      contentWarning: any(named: 'contentWarning'),
      thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
      replyContext: any(named: 'replyContext'),
      addReplyToFeed: any(named: 'addReplyToFeed'),
      textTrackRefs: any(named: 'textTrackRefs'),
      textTrackLang: any(named: 'textTrackLang'),
      onEventSigned: any(named: 'onEventSigned'),
      onAudioReuseDegraded: any(named: 'onAudioReuseDegraded'),
    ),
  ).thenAnswer((_) async => true);
}
