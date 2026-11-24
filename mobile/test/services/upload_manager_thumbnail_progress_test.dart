// ABOUTME: Pins that the thumbnail leg runs beside the video transfer and
// ABOUTME: that the video alone drives a monotonic progress bar.

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadManager thumbnail leg', () {
    late _MockBlossomUploadService mockBlossom;
    late UploadManager uploadManager;
    late Directory testDir;
    late PathProviderPlatform originalPathProvider;

    /// Completes as soon as the thumbnail upload starts, so the video stub can
    /// prove the two legs overlap.
    late Completer<void> thumbnailStarted;

    setUpAll(() {
      registerFallbackValue(File(''));
      registerFallbackValue(Uint8List(0));
    });

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp(
        'upload_thumbnail_parallel_test_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(testDir.path)
        ..setApplicationDocumentsPath('${testDir.path}/documents')
        ..setApplicationSupportPath('${testDir.path}/support');
      await Directory('${testDir.path}/support').create(recursive: true);
      await TestHelpers.initHiveHome();

      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'check') return ['wifi'];
            return null;
          });

      thumbnailStarted = Completer<void>();
      mockBlossom = _MockBlossomUploadService();

      // Stands in for the native extractor: hands back a frame so the
      // thumbnail leg proceeds to the upload step.
      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossom,
        // Zero delays so the retry test does not sleep the default 2s backoff.
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
          networkTimeout: Duration(seconds: 30),
        ),
        thumbnailExtractor:
            ({
              required String videoPath,
              required Duration targetTimestamp,
              required int quality,
            }) async => ThumbnailResult(
              bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
              timestamp: targetTimestamp,
            ),
      );
      await uploadManager.initialize();
    });

    tearDown(() async {
      uploadManager.dispose();
      PathProviderPlatform.instance = originalPathProvider;
      try {
        await Hive.close();
      } catch (_) {}
      try {
        await testDir.delete(recursive: true);
      } catch (_) {}
    });

    /// Stubs the image upload to announce its start via [thumbnailStarted].
    void stubThumbnailUpload() {
      when(
        () => mockBlossom.uploadImageBytes(
          bytes: any(named: 'bytes'),
          nostrPubkey: any(named: 'nostrPubkey'),
          filename: any(named: 'filename'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer((_) async {
        if (!thumbnailStarted.isCompleted) thumbnailStarted.complete();
        return const BlossomUploadResult(
          success: true,
          videoId: 'thumb-1',
          url: 'https://media.divine.video/thumb-1.jpg',
          fallbackUrl: 'https://media.divine.video/thumb-1.jpg',
        );
      });
    }

    /// Stubs the video transfer, running [duringTransfer] before it resolves.
    void stubVideoUpload({
      Future<void> Function(void Function(double) reportProgress)?
      duringTransfer,
    }) {
      when(() => mockBlossom.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => mockBlossom.uploadVideoWithResume(
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
        final report =
            invocation.namedArguments[#onProgress] as void Function(double)?;
        await duringTransfer?.call(report ?? (_) {});
        return const BlossomUploadResult(
          success: true,
          videoId: 'vid-1',
          url: 'https://media.divine.video/vid-1',
          fallbackUrl: 'https://media.divine.video/vid-1',
        );
      });
    }

    test(
      'uploads the thumbnail while the video transfer is still open',
      () async {
        stubThumbnailUpload();

        var overlapped = false;
        stubVideoUpload(
          duringTransfer: (_) async {
            // Resolves only if the thumbnail leg was started before the transfer
            // finished. Sequential execution would leave it pending.
            overlapped = await thumbnailStarted.future
                .timeout(const Duration(seconds: 2))
                .then((_) => true, onError: (_) => false);
          },
        );

        final videoFile = File('${testDir.path}/video.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);

        await uploadManager.startUpload(
          videoFile: videoFile,
          nostrPubkey: 'pubkey-1',
        );

        expect(
          overlapped,
          isTrue,
          reason: 'the thumbnail must not wait for the video transfer',
        );
      },
    );

    test('does not re-upload the thumbnail after a failed transfer', () async {
      var thumbnailUploads = 0;
      when(
        () => mockBlossom.uploadImageBytes(
          bytes: any(named: 'bytes'),
          nostrPubkey: any(named: 'nostrPubkey'),
          filename: any(named: 'filename'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer((_) async {
        thumbnailUploads++;
        if (!thumbnailStarted.isCompleted) thumbnailStarted.complete();
        return const BlossomUploadResult(
          success: true,
          videoId: 'thumb-1',
          url: 'https://media.divine.video/thumb-1.jpg',
          fallbackUrl: 'https://media.divine.video/thumb-1.jpg',
        );
      });

      // Fail the transfer once, then succeed — the retry policy re-enters the
      // whole execute step, thumbnail leg included.
      var transferAttempts = 0;
      when(() => mockBlossom.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => mockBlossom.uploadVideoWithResume(
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
        transferAttempts++;
        if (transferAttempts == 1) {
          throw const BlossomUploadFailureException('connection refused');
        }
        return const BlossomUploadResult(
          success: true,
          videoId: 'vid-1',
          url: 'https://media.divine.video/vid-1',
          fallbackUrl: 'https://media.divine.video/vid-1',
        );
      });

      final videoFile = File('${testDir.path}/video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      await uploadManager.startUpload(
        videoFile: videoFile,
        nostrPubkey: 'pubkey-1',
      );

      expect(transferAttempts, equals(2));
      expect(
        thumbnailUploads,
        equals(1),
        reason: 'the retry must reuse the thumbnail already on the CDN',
      );
      // The reused leg still emits a timeline line, so a log export reads
      // "reused" rather than "the leg never ran".
      expect(
        LogCaptureService().getRecentLogs().any(
          (entry) => entry.message.contains('upload.thumbnail 0ms reused'),
        ),
        isTrue,
        reason: 'retry must log the reused thumbnail leg',
      );
    });

    test('lets the video alone drive a monotonic bar up to 1.0', () async {
      stubThumbnailUpload();
      stubVideoUpload(
        duringTransfer: (reportProgress) async {
          // Report once the thumbnail leg is underway (parallelism is the
          // other test's job, so a miss here must not hang this one): if that
          // leg also wrote progress, these would arrive out of order.
          await thumbnailStarted.future
              .timeout(const Duration(seconds: 2))
              .then((_) => true, onError: (_) => false);
          reportProgress(0.5);
          reportProgress(1);
        },
      );

      final videoFile = File('${testDir.path}/video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      final reported = <double>[];
      await uploadManager.startUpload(
        videoFile: videoFile,
        nostrPubkey: 'pubkey-1',
        onProgress: reported.add,
      );

      expect(reported, isNotEmpty);
      for (var i = 1; i < reported.length; i++) {
        expect(
          reported[i],
          greaterThanOrEqualTo(reported[i - 1]),
          reason: 'progress went backwards: $reported',
        );
      }
      // The transfer tops out at the video's share, and only the join to the
      // thumbnail completes the bar.
      expect(reported, contains(0.95));
      expect(reported.last, equals(1.0));
    });
  });
}
