// ABOUTME: Tests the draft -> upload path: DraftUploadMaterializer composed
// ABOUTME: with UploadManager.startUpload, exactly as VideoPublishService does.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_publish/draft_upload_materializer.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/test_helpers.dart';
import '../../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  setUpAll(() async {
    await initializeServiceTestEnvironment();
    registerFallbackValue(File(''));
  });

  group('draft -> upload path', () {
    late UploadManager uploadManager;

    // Composes DraftUploadMaterializer + UploadManager.startUpload exactly as
    // VideoPublishService._startNewUpload does, so these keep covering the
    // draft -> upload path after #6935 split it into two units.
    Future<PendingUpload> startUploadFromDraft({
      required DivineVideoDraft draft,
      required String nostrPubkey,
      Duration? videoDuration,
    }) async {
      final materialized = await const DraftUploadMaterializer().materialize(
        draft: draft,
        pendingUploads: uploadManager.pendingUploads,
        videoDuration: videoDuration,
      );
      final upload = await uploadManager.startUpload(
        videoFile: materialized.videoFile,
        nostrPubkey: nostrPubkey,
        title: draft.title,
        description: draft.description,
        hashtags: draft.hashtags.toList(),
        videoWidth: materialized.videoWidth,
        videoHeight: materialized.videoHeight,
        videoDuration: materialized.videoDuration,
        proofManifestJson: draft.proofManifestJson,
        thumbnailTimestamp: draft.thumbnailTimestamp,
      );
      uploadManager.registerTransientRenderPaths(
        upload.id,
        materialized.transientRenderPaths,
      );
      return upload;
    }

    late _MockBlossomUploadService mockBlossomService;
    late Directory tempDir;
    late File sourceVideoFile;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      tempDir = await Directory.systemTemp.createTemp('upload_draft_test_');
      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      PathProviderPlatform.instance = mockPathProvider;
      await TestHelpers.initHiveHome();
      await TestHelpers.cleanupHiveBox('pending_uploads');
      sourceVideoFile = File('${tempDir.path}/source_video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      mockBlossomService = _MockBlossomUploadService();
      when(
        () => mockBlossomService.isBlossomEnabled(),
      ).thenAnswer((_) async => false);
      when(
        () => mockBlossomService.uploadVideoWithResume(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          useBackgroundFirst: any(named: 'useBackgroundFirst'),
          resumableTimeout: any(named: 'resumableTimeout'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'test-video-id',
          url: 'https://media.divine.video/test-video-id',
          fallbackUrl: 'https://media.divine.video/test-video-id',
          thumbnailUrl: 'https://media.divine.video/test-video-id-thumb.jpg',
        ),
      );
      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossomService,
        // The default config sleeps 2+4+8+16+32s of real time before giving
        // up, so each failure-path test below burned ~62s. Only the retry
        // *count* matters here — the backoff arithmetic itself is covered by
        // upload_retry_policy_test.dart. maxRetries stays at the production
        // default so exhaustion still takes the same number of attempts.
        retryConfig: const UploadRetryConfig(initialDelay: Duration.zero),
      );
      await uploadManager.initialize();
    });

    tearDown(() async {
      // Cancel UploadManager's save-queue/retry/poll Timers and close the Hive
      // box before deleting tempDir, so neither leaks into the merged VGV
      // optimizer isolate (#5159).
      uploadManager.dispose();
      PathProviderPlatform.instance = originalPathProviderInstance;
      try {
        await TestHelpers.cleanupHiveBox('pending_uploads');
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('should create upload from draft with ProofMode data', () async {
      // Create draft with ProofMode JSON
      const proofJson = '{"segments":[],"deviceAttestation":null}';

      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file(sourceVideoFile.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test Video',
        description: 'Test Description',
        hashtags: {'test'},
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      expect(draft.hasProofMode, isTrue);
      expect(draft.proofManifestJson, equals(proofJson));

      final upload = await startUploadFromDraft(
        draft: draft,
        nostrPubkey: 'test-pubkey',
        videoDuration: const Duration(seconds: 5),
      );

      expect(upload.title, equals('Test Video'));
      expect(upload.description, equals('Test Description'));
      expect(upload.hashtags, containsAll(['test']));
      expect(upload.proofManifestJson, equals(proofJson));
      expect(upload.hasProofMode, isTrue);
    });

    test('should preserve ProofMode data through draft copyWith', () async {
      const proofJson = '{"segments":[],"deviceAttestation":null}';

      final originalDraft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file(sourceVideoFile.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Original Title',
        description: 'Original Description',
        hashtags: {'original'},
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      // Update metadata while preserving ProofMode
      final updatedDraft = originalDraft.copyWith(
        title: 'Updated Title',
        description: 'Updated Description',
        hashtags: {'updated'},
      );

      expect(updatedDraft.title, equals('Updated Title'));
      expect(updatedDraft.description, equals('Updated Description'));
      expect(updatedDraft.hashtags, containsAll(['updated']));
      expect(updatedDraft.proofManifestJson, equals(proofJson));
      expect(updatedDraft.hasProofMode, isTrue);

      final upload = await startUploadFromDraft(
        draft: updatedDraft,
        nostrPubkey: 'test-pubkey',
        videoDuration: const Duration(seconds: 5),
      );

      expect(upload.title, equals('Updated Title'));
      expect(upload.proofManifestJson, equals(proofJson));
    });

    test('prefers final rendered clip when draft already has one', () async {
      final renderedFile = File('${tempDir.path}/final_rendered.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      when(
        () => mockBlossomService.uploadVideoWithResume(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          useBackgroundFirst: any(named: 'useBackgroundFirst'),
          resumableTimeout: any(named: 'resumableTimeout'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'rendered-video',
          url: 'https://media.divine.video/rendered-video',
          fallbackUrl: 'https://media.divine.video/rendered-video',
          thumbnailUrl: 'https://media.divine.video/rendered-video-thumb.jpg',
        ),
      );

      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'source_clip_1',
            video: EditorVideo.file('source_clip_1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
          DivineVideoClip(
            id: 'source_clip_2',
            video: EditorVideo.file('source_clip_2.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Rendered Video',
        description: 'Uses final render',
        hashtags: {'rendered'},
        selectedApproach: 'native',
        finalRenderedClip: DivineVideoClip(
          id: 'rendered_clip',
          video: EditorVideo.file(renderedFile.path),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime.now(),
          targetAspectRatio: AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      final upload = await startUploadFromDraft(
        draft: draft,
        nostrPubkey: 'test-pubkey',
        videoDuration: const Duration(seconds: 6),
      );

      expect(upload.localVideoPath, equals(renderedFile.path));
    });

    test('should handle draft without ProofMode data', () async {
      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file(sourceVideoFile.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test Video',
        description: 'Test Description',
        hashtags: {'test'},
        selectedApproach: 'native',
      );

      expect(draft.hasProofMode, isFalse);
      expect(draft.proofManifestJson, isNull);

      final upload = await startUploadFromDraft(
        draft: draft,
        nostrPubkey: 'test-pubkey',
        videoDuration: const Duration(seconds: 5),
      );

      expect(upload.title, equals('Test Video'));
      expect(upload.hasProofMode, isFalse);
      expect(upload.proofManifestJson, isNull);
    });

    test(
      'keeps transient stop-motion render until the upload is published',
      () async {
        // No finalRenderedClip, so startUploadFromDraft hits the fallback that
        // re-renders the frames-only clip into a documents-dir mp4.
        final renderPath = '${tempDir.path}/documents/stop_motion_123.mp4';
        StopMotionRenderService.assembleOverride =
            ({
              required frames,
              required aspectRatio,
              frameRate = StopMotionRenderService.defaultFrameRate,
              taskId,
            }) async {
              File(renderPath)
                ..parent.createSync(recursive: true)
                ..writeAsBytesSync([0, 1, 2, 3]);
              return renderPath;
            };
        StopMotionRenderService.probeDurationOverride = (_) async =>
            const Duration(seconds: 2);
        addTearDown(() {
          StopMotionRenderService.assembleOverride = null;
          StopMotionRenderService.probeDurationOverride = null;
        });

        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'sm_clip',
              stopMotionFrames: const [
                StopMotionClipFrame(
                  path: '/tmp/f0.jpg',
                  duration: Duration(milliseconds: 167),
                ),
              ],
              duration: const Duration(milliseconds: 167),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Stop Motion',
          description: 'Fallback render',
          hashtags: {'sm'},
          selectedApproach: 'native',
        );

        final upload = await startUploadFromDraft(
          draft: draft,
          nostrPubkey: 'test-pubkey',
        );

        expect(upload.localVideoPath, equals(renderPath));
        expect(File(renderPath).existsSync(), isTrue);

        await uploadManager.updateUploadStatus(
          upload.id,
          UploadStatus.published,
          nostrEventId: 'event-id',
        );

        expect(File(renderPath).existsSync(), isFalse);
      },
    );

    test('cleans failed non-resumable transient stop-motion renders', () async {
      final renderPath = '${tempDir.path}/documents/stop_motion_456.mp4';
      StopMotionRenderService.assembleOverride =
          ({
            required frames,
            required aspectRatio,
            frameRate = StopMotionRenderService.defaultFrameRate,
            taskId,
          }) async {
            File(renderPath)
              ..parent.createSync(recursive: true)
              ..writeAsBytesSync([0, 1, 2, 3]);
            return renderPath;
          };
      StopMotionRenderService.probeDurationOverride = (_) async =>
          const Duration(seconds: 2);
      addTearDown(() {
        StopMotionRenderService.assembleOverride = null;
        StopMotionRenderService.probeDurationOverride = null;
      });

      when(
        () => mockBlossomService.uploadVideoWithResume(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          useBackgroundFirst: any(named: 'useBackgroundFirst'),
          resumableTimeout: any(named: 'resumableTimeout'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: false,
          errorMessage: 'upload failed',
        ),
      );

      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'sm_clip',
            stopMotionFrames: const [
              StopMotionClipFrame(
                path: '/tmp/f0.jpg',
                duration: Duration(milliseconds: 167),
              ),
            ],
            duration: const Duration(milliseconds: 167),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Stop Motion',
        description: 'Fallback render',
        hashtags: {'sm'},
        selectedApproach: 'native',
      );

      await expectLater(
        () => startUploadFromDraft(
          draft: draft,
          nostrPubkey: 'test-pubkey',
        ),
        throwsA(isA<Exception>()),
      );
      expect(File(renderPath).existsSync(), isTrue);
      final failedUpload = uploadManager.pendingUploads.firstWhere(
        (upload) => upload.localVideoPath == renderPath,
      );
      expect(failedUpload.status, UploadStatus.failed);

      await uploadManager.cleanupCompletedUploads();

      expect(File(renderPath).existsSync(), isFalse);
      expect(
        uploadManager.pendingUploads.where(
          (upload) => upload.localVideoPath == renderPath,
        ),
        isEmpty,
      );
    });

    test(
      'throws when upload finishes in failed state instead of returning a completed upload',
      () async {
        final renderedFile = File('${tempDir.path}/failed_render.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);

        when(
          () => mockBlossomService.isBlossomEnabled(),
        ).thenAnswer((_) async => false);
        when(
          () => mockBlossomService.uploadVideoWithResume(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            taskId: any(named: 'taskId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            useBackgroundFirst: any(named: 'useBackgroundFirst'),
            resumableTimeout: any(named: 'resumableTimeout'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: false,
            errorMessage: '401 upload auth failed',
          ),
        );

        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'source_clip',
              video: EditorVideo.file(renderedFile.path),
              duration: const Duration(seconds: 4),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Failure Video',
          description: 'Should fail cleanly',
          hashtags: {'failed'},
          selectedApproach: 'native',
          finalRenderedClip: DivineVideoClip(
            id: 'rendered_clip',
            video: EditorVideo.file(renderedFile.path),
            duration: const Duration(seconds: 4),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        );

        await expectLater(
          () => startUploadFromDraft(
            draft: draft,
            nostrPubkey: 'test-pubkey',
            videoDuration: const Duration(seconds: 4),
          ),
          throwsA(isA<Exception>()),
        );

        final failedUpload = uploadManager.pendingUploads.firstWhere(
          (upload) => upload.localVideoPath == renderedFile.path,
        );
        expect(failedUpload.status, equals(UploadStatus.failed));
        expect(failedUpload.errorMessage, isNotEmpty);
      },
    );
  });
}
