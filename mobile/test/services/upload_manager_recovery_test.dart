import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockBackgroundActivityManager extends Mock
    implements BackgroundActivityManager {}

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

/// A successful Blossom result stub used across the recovery tests.
const _okResult = BlossomUploadResult(
  success: true,
  url: 'https://media.divine.video/abc',
  thumbnailUrl: 'https://media.divine.video/abc-thumb.jpg',
);

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

  group('UploadManager recovery sweep', () {
    late _MockBlossomUploadService mockBlossomService;
    late UploadManager uploadManager;
    late Directory tempDir;
    late File videoFile;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp('upload_recovery_');
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
          initialDelay: Duration(milliseconds: 10),
          maxDelay: Duration(milliseconds: 10),
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

    /// Seeds a [PendingUpload] directly into the Hive box, bypassing the
    /// normal start flow so a stuck state can be simulated.
    PendingUpload seedUpload({
      UploadStatus status = UploadStatus.uploading,
      String? localVideoPath,
    }) {
      final upload = PendingUpload.create(
        localVideoPath: localVideoPath ?? videoFile.path,
        nostrPubkey: 'test-pubkey',
        title: 'Stuck video',
      ).copyWith(status: status);
      Hive.box<PendingUpload>('pending_uploads').put(upload.id, upload);
      return upload;
    }

    test('onAppResumed re-drives uploads stuck in uploading state', () async {
      seedUpload();

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
      ).thenAnswer((_) async {
        if (!resumeStarted.isCompleted) resumeStarted.complete();
        return _okResult;
      });

      uploadManager.onAppResumed();

      await TestHelpers.waitForCondition(
        () => resumeStarted.isCompleted,
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );
    });

    test('onAppResumed wakes a live upload parked in retry backoff', () async {
      uploadManager.dispose();
      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossomService,
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration(hours: 1),
          maxDelay: Duration(hours: 1),
        ),
      );
      await uploadManager.initialize();

      var uploadAttempts = 0;
      final firstAttemptFailed = Completer<void>();
      final secondAttemptStarted = Completer<void>();
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
        uploadAttempts++;
        if (uploadAttempts == 1) {
          firstAttemptFailed.complete();
          throw Exception('network timeout');
        }
        secondAttemptStarted.complete();
        return _okResult;
      });

      final uploadFuture = uploadManager.startUpload(
        videoFile: videoFile,
        nostrPubkey: 'test-pubkey',
        title: 'Backoff video',
      );

      await TestHelpers.waitForCondition(
        () => firstAttemptFailed.isCompleted,
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );

      final uploadId = uploadManager.pendingUploads.single.id;
      await TestHelpers.waitForCondition(
        () => uploadManager.isUploadWaitingForRetryBackoff(uploadId),
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );

      uploadManager.onAppResumed();

      await TestHelpers.waitForCondition(
        () => secondAttemptStarted.isCompleted,
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );
      await uploadFuture;
      expect(uploadAttempts, equals(2));
      expect(uploadManager.isUploadInFlight(uploadId), isFalse);
    });

    test('onAppResumed re-drives uploads stuck in retrying state', () async {
      seedUpload(status: UploadStatus.retrying);

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
      ).thenAnswer((_) async {
        if (!resumeStarted.isCompleted) resumeStarted.complete();
        return _okResult;
      });

      uploadManager.onAppResumed();

      await TestHelpers.waitForCondition(
        () => resumeStarted.isCompleted,
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );
    });

    test('onAppResumed does not re-drive failed uploads', () async {
      final upload = seedUpload(status: UploadStatus.failed);

      uploadManager.onAppResumed();
      // Give the sweep a chance to run; a failed upload must be skipped.
      await Future<void>.delayed(const Duration(milliseconds: 100));

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

      expect(
        uploadManager.getUpload(upload.id)?.status,
        equals(UploadStatus.failed),
      );
    });

    test(
      'onAppResumed marks stuck upload failed when local file is missing',
      () async {
        final missingPath = '${tempDir.path}/does-not-exist.mp4';
        final upload = seedUpload(localVideoPath: missingPath);

        uploadManager.onAppResumed();

        await TestHelpers.waitForCondition(
          () =>
              uploadManager.getUpload(upload.id)?.status == UploadStatus.failed,
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 20),
        );

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

    test('resumeInterruptedUpload is single-flight per upload id', () async {
      final upload = seedUpload();

      var uploadCallCount = 0;
      final blockGate = Completer<void>();
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
        uploadCallCount++;
        await blockGate.future;
        return _okResult;
      });

      uploadManager.resumeInterruptedUpload(upload.id);
      uploadManager.resumeInterruptedUpload(upload.id);

      await TestHelpers.waitForCondition(
        () => uploadManager.isUploadInFlight(upload.id),
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(uploadCallCount, equals(1));

      blockGate.complete();
      await TestHelpers.waitForCondition(
        () => !uploadManager.isUploadInFlight(upload.id),
        timeout: const Duration(seconds: 2),
        checkInterval: const Duration(milliseconds: 20),
      );
    });

    test(
      'resumeInterruptedUpload clears in-flight marker when file is missing',
      () async {
        final missingPath = '${tempDir.path}/resume-missing.mp4';
        final upload = seedUpload(localVideoPath: missingPath);

        uploadManager.resumeInterruptedUpload(upload.id);

        // Hive's synchronous put lands `failed` one future-completion before
        // whenComplete clears the marker; wait for each transition separately
        // so a stall names the exact one that failed, not a combined timeout.
        await TestHelpers.waitForCondition(
          () =>
              uploadManager.getUpload(upload.id)?.status == UploadStatus.failed,
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 20),
        );
        await TestHelpers.waitForCondition(
          () => !uploadManager.isUploadInFlight(upload.id),
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 20),
        );
      },
    );
  });

  group('UploadManager background-aware registration', () {
    test('initialize registers and dispose unregisters', () async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      final tempDir = await Directory.systemTemp.createTemp(
        'upload_recovery_reg_',
      );
      final originalPathProvider = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      PathProviderPlatform.instance = mockPathProvider;
      await TestHelpers.initHiveHome();

      final mockBlossom = _MockBlossomUploadService();
      when(mockBlossom.isBlossomEnabled).thenAnswer((_) => Future.value(false));
      _mockConnectivity('wifi');

      final mockBgManager = _MockBackgroundActivityManager();
      final manager = UploadManager(
        blossomService: mockBlossom,
        backgroundActivityManager: mockBgManager,
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );

      addTearDown(() async {
        manager.dispose();
        await TestHelpers.cleanupHiveBox('pending_uploads');
        Hive.init(null);
        PathProviderPlatform.instance = originalPathProvider;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await manager.initialize();

      verify(() => mockBgManager.registerService(manager)).called(1);

      manager.dispose();

      verify(() => mockBgManager.unregisterService(manager)).called(1);
    });

    test('serviceName is UploadManager', () {
      final mockBlossom = _MockBlossomUploadService();
      final mockBgManager = _MockBackgroundActivityManager();
      final manager = UploadManager(
        blossomService: mockBlossom,
        backgroundActivityManager: mockBgManager,
      );
      addTearDown(manager.dispose);
      expect(manager.serviceName, equals('UploadManager'));
    });
  });
}
