// ABOUTME: Pins what an upload does when its thumbnail leg yields no CDN URL:
// ABOUTME: the leg's real cause is classified, and transient ones retry alone.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:upload_repository/upload_repository.dart';

import 'helpers/hive_test_home.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _RecordingCrashReporter implements UploadCrashReporter {
  final recorded = <({Object error, String? reason})>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    recorded.add((error: error, reason: reason));
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

class _NoopTransientRenderCleaner implements TransientRenderCleaner {
  @override
  Future<void> cleanupMaterializedOutputPath(String filePath) async {}

  @override
  bool isMaterializedOutputPath(String filePath) => false;
}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _thumbnailUrl = 'https://media.divine.video/thumb-1';

Future<Box<PendingUpload>> _openUploadsBox({bool forceReinit = false}) async {
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(UploadStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(PendingUploadAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BlossomResumableUploadSessionAdapter());
  }
  return Hive.openBox<PendingUpload>('pending_uploads');
}

const _thumbnailUnavailable = BlossomUploadResult(
  success: false,
  statusCode: 503,
  errorMessage: 'Upload failed: 503 - Service Unavailable',
  failureReason: BlossomUploadFailureReason.server,
);

const _thumbnailUploaded = BlossomUploadResult(
  success: true,
  url: _thumbnailUrl,
  fallbackUrl: _thumbnailUrl,
);

void main() {
  group('$UploadRepository thumbnail failures', () {
    late Directory tempDir;
    late _MockBlossomUploadService blossom;
    late _RecordingCrashReporter crashReporter;
    late File videoFile;
    late int extractions;
    late bool extractorFindsFrame;
    late int thumbnailUploads;
    late int videoTransfers;

    UploadRepository buildRepository({
      UploadRetryConfig retryConfig = const UploadRetryConfig(
        maxRetries: 2,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
    }) {
      final repository = UploadRepository(
        blossomService: blossom,
        openPendingUploadsBox: _openUploadsBox,
        crashReporter: crashReporter,
        thumbnailExtractor:
            ({
              required String videoPath,
              required Duration targetTimestamp,
              required int quality,
            }) async {
              extractions++;
              if (!extractorFindsFrame) return null;
              final path = '${tempDir.path}/thumb_$extractions.jpg';
              File(path).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
              return (path: path);
            },
        blurhashGenerator: (Uint8List bytes) async => null,
        transientRenderCleaner: _NoopTransientRenderCleaner(),
        connectivityProvider: () async => UploadConnectivity.wifi,
        debugStateProvider: () => const <String, Object?>{},
        platformName: 'test',
        isWeb: false,
        defaultThumbnailTimestamp: Duration.zero,
        retryConfig: retryConfig,
      );
      addTearDown(repository.dispose);
      return repository;
    }

    /// Answers the thumbnail PUTs with [results] in order, repeating the last.
    void stubThumbnailUploads(List<BlossomUploadResult> results) {
      when(
        () => blossom.uploadImage(
          imageFile: any(named: 'imageFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer(
        (_) async => results[(thumbnailUploads++).clamp(0, results.length - 1)],
      );
    }

    /// Answers the video transfer with success once [waitFor] completes.
    void stubVideoTransfer({Future<void>? waitFor}) {
      when(() => blossom.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => blossom.uploadVideoWithResume(
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
        videoTransfers++;
        await waitFor;
        return const BlossomUploadResult(
          success: true,
          videoId: 'vid-1',
          url: 'https://media.divine.video/vid-1',
          fallbackUrl: 'https://media.divine.video/vid-1',
        );
      });
    }

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('thumbnail_failure_');
      setHiveTestHome(tempDir.path);
      addTearDown(() async {
        await Hive.close();
        await tempDir.delete(recursive: true);
      });
      blossom = _MockBlossomUploadService();
      crashReporter = _RecordingCrashReporter();
      extractions = 0;
      extractorFindsFrame = true;
      thumbnailUploads = 0;
      videoTransfers = 0;
      videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);
    });

    test(
      'retries only the thumbnail after the server turns it away, '
      'then publishes',
      () async {
        final repository = buildRepository();
        await repository.initialize();
        stubVideoTransfer();
        stubThumbnailUploads([_thumbnailUnavailable, _thumbnailUploaded]);

        final upload = await repository.startUpload(
          videoFile: videoFile,
          nostrPubkey: _pubkey,
        );

        expect(upload.thumbnailPath, equals(_thumbnailUrl));
        expect(upload.status, equals(UploadStatus.readyToPublish));
        expect(thumbnailUploads, equals(2));
        expect(
          videoTransfers,
          equals(1),
          reason: 'the video was already on the CDN',
        );
        expect(crashReporter.recorded, isEmpty);
      },
    );

    test(
      'fails as SERVER_UNAVAILABLE once the thumbnail retries run out, '
      'without reporting it',
      () async {
        final repository = buildRepository();
        await repository.initialize();
        stubVideoTransfer();
        stubThumbnailUploads([_thumbnailUnavailable]);

        await expectLater(
          repository.startUpload(videoFile: videoFile, nostrPubkey: _pubkey),
          throwsA(isA<Exception>()),
        );

        final failed = repository.pendingUploads.single;
        expect(failed.status, equals(UploadStatus.failed));
        expect(
          failed.errorMessage,
          equals(
            UploadProgressReporter.userFriendlyErrorMessage(
              'SERVER_UNAVAILABLE',
              UploadConnectivity.wifi,
            ),
          ),
        );
        expect(thumbnailUploads, equals(3), reason: '1 try + 2 retries');
        expect(videoTransfers, equals(1));
        expect(crashReporter.recorded, isEmpty);
      },
    );

    test(
      'reports a thumbnail the device could not make, with the cause, '
      'without retrying it',
      () async {
        final repository = buildRepository();
        await repository.initialize();
        stubVideoTransfer();
        stubThumbnailUploads([_thumbnailUploaded]);
        extractorFindsFrame = false;

        await expectLater(
          repository.startUpload(videoFile: videoFile, nostrPubkey: _pubkey),
          throwsA(isA<Exception>()),
        );

        expect(extractions, equals(1));
        expect(thumbnailUploads, equals(0));
        expect(crashReporter.recorded, hasLength(1));
        final report = crashReporter.recorded.single;
        expect(
          report.error,
          isA<ThumbnailUploadException>()
              .having(
                (e) => e.stage,
                'stage',
                ThumbnailUploadFailureStage.extraction,
              )
              .having(
                (e) => e.toString(),
                'message',
                contains('no frame could be extracted'),
              ),
        );
        expect(
          report.reason,
          equals('Video upload failure - THUMBNAIL_EXTRACTION_FAILED'),
        );
      },
    );

    test(
      'reports an unclassified thumbnail failure with the server message, '
      'without retrying it',
      () async {
        final repository = buildRepository();
        await repository.initialize();
        stubVideoTransfer();
        stubThumbnailUploads([
          const BlossomUploadResult(
            success: false,
            errorMessage: 'Upload response missing URL field',
            failureReason: BlossomUploadFailureReason.unknown,
          ),
        ]);

        await expectLater(
          repository.startUpload(videoFile: videoFile, nostrPubkey: _pubkey),
          throwsA(isA<Exception>()),
        );

        expect(thumbnailUploads, equals(1));
        final report = crashReporter.recorded.single;
        expect(
          report.error.toString(),
          contains('Upload response missing URL field'),
        );
        expect(report.reason, equals('Video upload failure - UNKNOWN'));
      },
    );

    test('an app resume retries a waiting thumbnail at once', () async {
      final repository = buildRepository(
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration(hours: 1),
          maxDelay: Duration(hours: 1),
        ),
      );
      await repository.initialize();
      final firstThumbnailFailed = Completer<void>();
      // Holding the video until the thumbnail has failed puts the thumbnail
      // retry right behind the transfer, with no storage write between.
      stubVideoTransfer(waitFor: firstThumbnailFailed.future);
      when(
        () => blossom.uploadImage(
          imageFile: any(named: 'imageFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer((_) async {
        if (thumbnailUploads++ > 0) return _thumbnailUploaded;
        firstThumbnailFailed.complete();
        return _thumbnailUnavailable;
      });

      final published = repository.startUpload(
        videoFile: videoFile,
        nostrPubkey: _pubkey,
      );
      await firstThumbnailFailed.future;
      await pumpEventQueue();
      final uploadId = repository.pendingUploads.single.id;
      expect(repository.isUploadWaitingForRetryBackoff(uploadId), isTrue);

      await repository.recoverInterruptedUploads();
      final upload = await published;

      expect(upload.thumbnailPath, equals(_thumbnailUrl));
      expect(thumbnailUploads, equals(2));
      expect(videoTransfers, equals(1));
    });
  });
}
