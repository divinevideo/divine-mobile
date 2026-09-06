import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void _mockConnectivity(String result) {
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'check') return [result];
        return null;
      });
  // Test-local channel, so it is not covered by the shared-channel
  // heal-and-blame tearDown; remove the per-test override.
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

void main() {
  setUpAll(() async {
    await initializeServiceTestEnvironment();
    registerFallbackValue(File(''));
    registerFallbackValue(
      const BlossomResumableUploadSession(
        uploadId: 'fallback',
        uploadUrl: 'https://upload.divine.video/sessions/fallback',
        chunkSize: 4,
        nextOffset: 0,
      ),
    );
  });

  group('UploadManager resumable uploads', () {
    late _MockBlossomUploadService mockBlossomService;
    late UploadManager uploadManager;
    late Directory tempDir;
    late File videoFile;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp(
        'upload_manager_resumable_',
      );
      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      PathProviderPlatform.instance = mockPathProvider;
      await TestHelpers.initHiveHome();
      videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(List<int>.generate(32, (index) => index));

      mockBlossomService = _MockBlossomUploadService();
      when(
        () => mockBlossomService.isBlossomEnabled(),
      ).thenAnswer((_) async => false);
      _mockConnectivity('wifi');

      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossomService,
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      await uploadManager.initialize();
    });

    tearDown(() async {
      uploadManager.dispose();
      // dispose() nulls the store's reference without closing the box, so
      // close and delete it before the directory underneath it goes away.
      await TestHelpers.cleanupHiveBox('pending_uploads');
      Hive.init(null);
      PathProviderPlatform.instance = originalPathProviderInstance;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'resumeInterruptedUpload restarts from the last committed offset',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Resumable video',
            ).copyWith(
              status: UploadStatus.uploading,
              uploadProgress: 0.4,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_123',
                uploadUrl: 'https://upload.divine.video/sessions/up_123',
                chunkSize: 8,
                nextOffset: 16,
              ),
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);

        final resumeStarted = Completer<void>();
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
        ).thenAnswer((invocation) async {
          final session =
              invocation.namedArguments[#resumableSession]
                  as BlossomResumableUploadSession?;
          final onResumableSessionUpdated =
              invocation.namedArguments[#onResumableSessionUpdated]
                  as void Function(BlossomResumableUploadSession)?;

          expect(session?.uploadId, equals('up_123'));
          expect(session?.nextOffset, equals(16));

          onResumableSessionUpdated?.call(session!.copyWith(nextOffset: 32));
          resumeStarted.complete();

          return const BlossomUploadResult(
            success: true,
            videoId: 'video-123',
            url: 'https://media.divine.video/video-123',
            fallbackUrl: 'https://media.divine.video/video-123',
            thumbnailUrl: 'https://media.divine.video/video-123-thumb.jpg',
          );
        });

        uploadManager.resumeInterruptedUpload(upload.id);

        await TestHelpers.waitForCondition(
          () => resumeStarted.isCompleted,
          timeout: const Duration(seconds: 1),
          checkInterval: const Duration(milliseconds: 20),
        );
        await TestHelpers.waitForCondition(() {
          final currentUpload = uploadManager.getUpload(upload.id);
          return currentUpload?.status == UploadStatus.readyToPublish;
        });

        final resumedUpload = uploadManager.getUpload(upload.id);
        expect(resumedUpload, isNotNull);
        expect(resumedUpload!.videoId, equals('video-123'));
        expect(
          resumedUpload.cdnUrl,
          equals('https://media.divine.video/video-123'),
        );
        expect(resumedUpload.resumableSession, isNull);
      },
    );

    test(
      'upload uses uploadVideoWithResume and threads the persisted session',
      () async {
        // A failed upload with a committed resumable session is the exact
        // "retry must resume from offset, not byte 0" scenario. The combined
        // method must receive the persisted session so its resumable leg
        // skips the OS whole-file PUT and resumes by offset.
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Combined path resume',
            ).copyWith(
              status: UploadStatus.failed,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_combined',
                uploadUrl: 'https://upload.divine.video/sessions/up_combined',
                chunkSize: 8,
                nextOffset: 16,
              ),
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);

        BlossomResumableUploadSession? capturedSession;
        bool? capturedUseBackgroundFirst;

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
        ).thenAnswer((invocation) async {
          capturedSession =
              invocation.namedArguments[#resumableSession]
                  as BlossomResumableUploadSession?;
          capturedUseBackgroundFirst =
              invocation.namedArguments[#useBackgroundFirst] as bool;
          return const BlossomUploadResult(
            success: true,
            videoId: 'video-combined',
            url: 'https://media.divine.video/video-combined',
            fallbackUrl: 'https://media.divine.video/video-combined',
            thumbnailUrl: 'https://media.divine.video/video-combined-thumb.jpg',
          );
        });

        await uploadManager.retryUpload(upload.id);

        await TestHelpers.waitForCondition(() {
          final currentUpload = uploadManager.getUpload(upload.id);
          return currentUpload?.status == UploadStatus.readyToPublish;
        });

        expect(capturedSession, isNotNull);
        expect(capturedSession!.uploadId, equals('up_combined'));
        expect(capturedSession!.nextOffset, equals(16));
        // useBackgroundUpload defaults to false in these tests' UploadManager
        // construction, so useBackgroundFirst must be false.
        expect(capturedUseBackgroundFirst, isFalse);
      },
    );

    test(
      'resumeInterruptedUpload preserves existing thumbnail URL when result omits one',
      () async {
        const thumbnailUrl = 'https://media.divine.video/thumb-existing';
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Video with generated thumbnail',
            ).copyWith(
              status: UploadStatus.uploading,
              thumbnailPath: thumbnailUrl,
              uploadProgress: 0.8,
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);

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
            videoId: 'video-with-thumbnail',
            url: 'https://media.divine.video/video-with-thumbnail',
            fallbackUrl: 'https://media.divine.video/video-with-thumbnail',
          ),
        );

        uploadManager.resumeInterruptedUpload(upload.id);

        await TestHelpers.waitForCondition(() {
          final currentUpload = uploadManager.getUpload(upload.id);
          return currentUpload?.status == UploadStatus.readyToPublish;
        });

        final completedUpload = uploadManager.getUpload(upload.id);
        expect(completedUpload, isNotNull);
        expect(completedUpload!.videoId, equals('video-with-thumbnail'));
        expect(completedUpload.thumbnailPath, equals(thumbnailUrl));
      },
    );

    test('resumeInterruptedUpload keeps existing CDN thumbnail over a '
        'non-HTTP result thumbnail', () async {
      const cdnThumbnailUrl = 'https://media.divine.video/thumb-existing';
      const localThumbnailPath = '/var/cache/thumbnails/frame.jpg';
      final upload =
          PendingUpload.create(
            localVideoPath: videoFile.path,
            nostrPubkey: 'test-pubkey',
            title: 'Video with uploaded thumbnail',
          ).copyWith(
            status: UploadStatus.uploading,
            thumbnailPath: cdnThumbnailUrl,
            uploadProgress: 0.8,
          );

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(upload.id, upload);

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
        // The upload result carries a non-HTTP thumbnail (a stale local
        // path). It must never overwrite the already-uploaded CDN URL.
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'video-with-thumbnail',
          url: 'https://media.divine.video/video-with-thumbnail',
          fallbackUrl: 'https://media.divine.video/video-with-thumbnail',
          thumbnailUrl: localThumbnailPath,
        ),
      );

      uploadManager.resumeInterruptedUpload(upload.id);

      await TestHelpers.waitForCondition(() {
        final currentUpload = uploadManager.getUpload(upload.id);
        return currentUpload?.status == UploadStatus.readyToPublish;
      });

      final completedUpload = uploadManager.getUpload(upload.id);
      expect(completedUpload, isNotNull);
      expect(completedUpload!.videoId, equals('video-with-thumbnail'));
      expect(completedUpload.thumbnailPath, equals(cdnThumbnailUrl));
      expect(completedUpload.thumbnailPath, isNot(equals(localThumbnailPath)));
    });

    test('resumeInterruptedUpload fails when only a stale non-HTTP thumbnail '
        'exists', () async {
      const localThumbnailPath = '/var/cache/thumbnails/frame.jpg';
      final upload =
          PendingUpload.create(
            localVideoPath: videoFile.path,
            nostrPubkey: 'test-pubkey',
            title: 'Video with stale thumbnail',
          ).copyWith(
            status: UploadStatus.uploading,
            thumbnailPath: localThumbnailPath,
            uploadProgress: 0.8,
          );

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(upload.id, upload);

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
          videoId: 'video-without-thumbnail',
          url: 'https://media.divine.video/video-without-thumbnail',
          fallbackUrl: 'https://media.divine.video/video-without-thumbnail',
        ),
      );

      uploadManager.resumeInterruptedUpload(upload.id);

      await TestHelpers.waitForCondition(() {
        final currentUpload = uploadManager.getUpload(upload.id);
        return currentUpload?.status == UploadStatus.failed;
      });

      final completedUpload = uploadManager.getUpload(upload.id);
      expect(completedUpload, isNotNull);
      expect(completedUpload!.status, equals(UploadStatus.failed));
      expect(completedUpload.errorMessage, isNotEmpty);
    });

    test(
      'resumeInterruptedUpload falls back to failed when session expires',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Expired resumable video',
            ).copyWith(
              status: UploadStatus.uploading,
              uploadProgress: 0.4,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_123',
                uploadUrl: 'https://upload.divine.video/sessions/up_123',
                chunkSize: 8,
                nextOffset: 16,
              ),
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);

        final resumeAttempted = Completer<void>();
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
        ).thenAnswer((_) async {
          resumeAttempted.complete();
          throw const BlossomResumableUploadException(
            'Resumable upload session expired',
            statusCode: 410,
          );
        });

        uploadManager.resumeInterruptedUpload(upload.id);

        await TestHelpers.waitForCondition(
          () => resumeAttempted.isCompleted,
          timeout: const Duration(seconds: 1),
          checkInterval: const Duration(milliseconds: 20),
        );
        await TestHelpers.waitForCondition(() {
          final currentUpload = uploadManager.getUpload(upload.id);
          return currentUpload?.status == UploadStatus.failed;
        });

        final failedUpload = uploadManager.getUpload(upload.id);
        expect(failedUpload, isNotNull);
        expect(failedUpload!.status, equals(UploadStatus.failed));
        expect(failedUpload.resumableSession, isNull);
        expect(failedUpload.errorMessage, contains('session expired'));
      },
    );

    test(
      'serializes rapid session-progress writes so the latest offset wins',
      () async {
        const chunkSize = 8;
        const fileSize = 80;

        // Create a file of the expected size so lengthSync() is consistent.
        videoFile = File('${tempDir.path}/video_serial.mp4')
          ..writeAsBytesSync(List<int>.generate(fileSize, (i) => i));

        final uploadCompleter = Completer<BlossomUploadResult>();

        // Capture the onResumableSessionUpdated callback so we can call it
        // rapidly ourselves.
        void Function(BlossomResumableUploadSession)? capturedCallback;

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
        ).thenAnswer((invocation) async {
          capturedCallback =
              invocation.namedArguments[#onResumableSessionUpdated]
                  as void Function(BlossomResumableUploadSession)?;

          return uploadCompleter.future;
        });

        // Start the upload — startUpload blocks until the upload completes,
        // but we need to interact with the callback mid-upload so we don't
        // await yet. We await uploadFuture at the end so the full
        // post-upload logic finishes before tearDown disposes the manager.
        final uploadFuture = uploadManager.startUpload(
          videoFile: videoFile,
          nostrPubkey: 'test-pubkey',
          title: 'Serialization test',
          thumbnailTimestamp: VideoEditorConstants.defaultThumbnailExtractTime,
        );

        await TestHelpers.waitForCondition(
          () => capturedCallback != null,
          timeout: const Duration(seconds: 2),
        );

        final uploads = uploadManager.pendingUploads;
        expect(uploads, isNotEmpty);
        final uploadId = uploads.first.id;

        for (var i = 1; i <= 5; i++) {
          capturedCallback!(
            BlossomResumableUploadSession(
              uploadId: 'up_serial',
              uploadUrl: 'https://upload.divine.video/sessions/up_serial',
              chunkSize: chunkSize,
              nextOffset: chunkSize * i,
            ),
          );
        }

        await TestHelpers.waitForCondition(
          () {
            final u = uploadManager.getUpload(uploadId);
            if (u == null) return false;
            const expectedOffset = chunkSize * 5;
            return u.resumableSession?.nextOffset == expectedOffset;
          },
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 20),
        );

        final persisted = uploadManager.getUpload(uploadId)!;
        expect(persisted.resumableSession?.nextOffset, equals(chunkSize * 5));

        final expectedProgress =
            ((chunkSize * 5) / fileSize * videoProgressShare).clamp(
              0.0,
              videoProgressShare,
            );
        expect(persisted.uploadProgress, closeTo(expectedProgress, 0.001));

        // Complete the upload future and await the full startUpload so
        // post-upload logic finishes before tearDown disposes the manager.
        uploadCompleter.complete(
          const BlossomUploadResult(
            success: true,
            videoId: 'video-serial',
            url: 'https://media.divine.video/video-serial',
            fallbackUrl: 'https://media.divine.video/video-serial',
            thumbnailUrl: 'https://media.divine.video/video-serial-thumb.jpg',
          ),
        );
        await uploadFuture;
      },
    );

    test(
      'does not re-upload video when required thumbnail upload fails',
      () async {
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
            videoId: 'video-without-thumbnail',
            url: 'https://media.divine.video/video-without-thumbnail',
            fallbackUrl: 'https://media.divine.video/video-without-thumbnail',
            thumbnailUrl: 'https://',
          ),
        );

        await expectLater(
          uploadManager.startUpload(
            videoFile: videoFile,
            nostrPubkey: 'test-pubkey',
            title: 'Video missing thumbnail',
            thumbnailTimestamp:
                VideoEditorConstants.defaultThumbnailExtractTime,
          ),
          throwsA(isA<Exception>()),
        );

        verify(
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
        ).called(1);

        final failedUpload = uploadManager.pendingUploads.singleWhere(
          (upload) => upload.title == 'Video missing thumbnail',
        );
        expect(failedUpload.status, equals(UploadStatus.failed));
        expect(failedUpload.errorMessage, isNotEmpty);
      },
    );

    test(
      'resumeInterruptedUpload ignores non-uploading/retrying statuses',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Paused video',
            ).copyWith(
              status: UploadStatus.paused,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_456',
                uploadUrl: 'https://upload.divine.video/sessions/up_456',
                chunkSize: 8,
                nextOffset: 8,
              ),
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);

        uploadManager.resumeInterruptedUpload(upload.id);

        await Future<void>.delayed(const Duration(milliseconds: 200));

        final current = uploadManager.getUpload(upload.id);
        expect(current!.status, equals(UploadStatus.paused));

        verifyNever(
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
        );
      },
    );

    test(
      'initialize auto-resumes interrupted uploads from a prior session',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Interrupted video',
            ).copyWith(
              status: UploadStatus.uploading,
              uploadProgress: 0.3,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_789',
                uploadUrl: 'https://upload.divine.video/sessions/up_789',
                chunkSize: 8,
                nextOffset: 8,
              ),
            );

        final uploadStarted = Completer<void>();
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
        ).thenAnswer((_) async {
          if (!uploadStarted.isCompleted) uploadStarted.complete();
          return const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/abc',
            thumbnailUrl: 'https://media.divine.video/abc-thumb.jpg',
          );
        });

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);
        uploadManager.dispose();

        uploadManager = UploadManager(
          backgroundActivityManager: BackgroundActivityManager(),
          blossomService: mockBlossomService,
          retryConfig: const UploadRetryConfig(
            initialDelay: Duration.zero,
            maxDelay: Duration.zero,
          ),
        );
        await uploadManager.initialize();

        // The startup recovery sweep should re-drive the stuck upload.
        await TestHelpers.waitForCondition(
          () => uploadStarted.isCompleted,
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 20),
        );
      },
    );
  });

  group('UploadManager findReusableUpload', () {
    late _MockBlossomUploadService mockBlossomService;
    late UploadManager uploadManager;
    late Directory tempDir;
    late File videoFile;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp(
        'upload_manager_reusable_',
      );
      originalPathProviderInstance = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      await TestHelpers.initHiveHome();
      videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(List<int>.generate(32, (index) => index));

      mockBlossomService = _MockBlossomUploadService();
      when(
        () => mockBlossomService.isBlossomEnabled(),
      ).thenAnswer((_) async => false);

      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossomService,
      );
      await uploadManager.initialize();
    });

    tearDown(() async {
      uploadManager.dispose();
      // dispose() nulls the store's reference without closing the box, so
      // close and delete it before the directory underneath it goes away.
      await TestHelpers.cleanupHiveBox('pending_uploads');
      Hive.init(null);
      PathProviderPlatform.instance = originalPathProviderInstance;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns upload in uploading status with matching path', () async {
      final upload =
          PendingUpload.create(
            localVideoPath: videoFile.path,
            nostrPubkey: 'test-pubkey',
            title: 'Uploading video',
          ).copyWith(
            status: UploadStatus.uploading,
            resumableSession: const BlossomResumableUploadSession(
              uploadId: 'up_1',
              uploadUrl: 'https://upload.divine.video/sessions/up_1',
              chunkSize: 8,
              nextOffset: 8,
            ),
          );

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(upload.id, upload);

      final result = uploadManager.findReusableUpload(videoFile.path);
      expect(result, isNotNull);
      expect(result!.id, equals(upload.id));
    });

    test('returns publishable readyToPublish upload', () async {
      final upload =
          PendingUpload.create(
            localVideoPath: videoFile.path,
            nostrPubkey: 'test-pubkey',
            title: 'Ready video',
          ).copyWith(
            status: UploadStatus.readyToPublish,
            videoId: 'ready-video',
            cdnUrl: 'https://media.divine.video/ready-video',
            thumbnailPath: 'https://media.divine.video/ready-video-thumb.jpg',
          );

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(upload.id, upload);

      final result = uploadManager.findReusableUpload(videoFile.path);
      expect(result, isNotNull);
      expect(result!.status, equals(UploadStatus.readyToPublish));
    });

    test('skips readyToPublish upload without an HTTP thumbnail', () async {
      final upload =
          PendingUpload.create(
            localVideoPath: videoFile.path,
            nostrPubkey: 'test-pubkey',
            title: 'Ready video without thumbnail',
          ).copyWith(
            status: UploadStatus.readyToPublish,
            videoId: 'ready-video-no-thumb',
            cdnUrl: 'https://media.divine.video/ready-video-no-thumb',
          );

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(upload.id, upload);

      final result = uploadManager.findReusableUpload(videoFile.path);
      expect(result, isNull);
    });

    test(
      'cleanup moves readyToPublish upload without thumbnail to failed',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Stale ready video',
            ).copyWith(
              status: UploadStatus.readyToPublish,
              videoId: 'stale-ready-video',
              cdnUrl: 'https://media.divine.video/stale-ready-video',
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, upload);

        await uploadManager.cleanupProblematicUploads();

        final cleanedUpload = uploadManager.getUpload(upload.id);
        expect(cleanedUpload, isNotNull);
        expect(cleanedUpload!.status, equals(UploadStatus.failed));
      },
    );

    test(
      'returns failed upload only when it has a resumable session',
      () async {
        final failedWithSession =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Failed with session',
            ).copyWith(
              status: UploadStatus.failed,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_2',
                uploadUrl: 'https://upload.divine.video/sessions/up_2',
                chunkSize: 8,
                nextOffset: 8,
              ),
            );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(failedWithSession.id, failedWithSession);

        final result = uploadManager.findReusableUpload(videoFile.path);
        expect(result, isNotNull);
        expect(result!.id, equals(failedWithSession.id));
      },
    );

    test('skips failed upload without resumable session', () async {
      final failedNoSession = PendingUpload.create(
        localVideoPath: videoFile.path,
        nostrPubkey: 'test-pubkey',
        title: 'Failed without session',
      ).copyWith(status: UploadStatus.failed);

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(failedNoSession.id, failedNoSession);

      final result = uploadManager.findReusableUpload(videoFile.path);
      expect(result, isNull);
    });

    test('skips published, pending, and paused uploads', () async {
      final box = Hive.box<PendingUpload>('pending_uploads');

      for (final status in [
        UploadStatus.published,
        UploadStatus.pending,
        UploadStatus.paused,
      ]) {
        final upload = PendingUpload.create(
          localVideoPath: videoFile.path,
          nostrPubkey: 'test-pubkey',
          title: 'Skip $status',
        ).copyWith(status: status);
        await box.put(upload.id, upload);
      }

      final result = uploadManager.findReusableUpload(videoFile.path);
      expect(result, isNull);
    });

    test('returns null when no uploads match the path', () async {
      final upload = PendingUpload.create(
        localVideoPath: '/some/other/path.mp4',
        nostrPubkey: 'test-pubkey',
        title: 'Other video',
      ).copyWith(status: UploadStatus.uploading);

      final box = Hive.box<PendingUpload>('pending_uploads');
      await box.put(upload.id, upload);

      final result = uploadManager.findReusableUpload(videoFile.path);
      expect(result, isNull);
    });
  });
}
