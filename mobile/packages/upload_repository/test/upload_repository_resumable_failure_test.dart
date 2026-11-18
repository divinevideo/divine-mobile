// ABOUTME: Pins what an upload does when the resumable transfer gives up on a
// ABOUTME: server outage: it retries, keeps its session, and is not reported.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
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

const _session = BlossomResumableUploadSession(
  uploadId: 'session-1',
  uploadUrl: 'https://media.divine.video/upload/session-1',
  chunkSize: 2,
  nextOffset: 2,
);

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

/// The result `BlossomUploadService` returns for a Divine-hosted upload whose
/// chunk PUT kept failing with [statusCode]: the recoverable resumable
/// exception, turned into a failed result that keeps its typed reason and
/// message but not its status.
BlossomUploadResult _recoverableResumableFailure(int statusCode) {
  final requestOptions = RequestOptions(path: '/upload/session-1');
  final dioException = DioException.badResponse(
    statusCode: statusCode,
    requestOptions: requestOptions,
    response: Response<void>(
      requestOptions: requestOptions,
      statusCode: statusCode,
    ),
  );
  return BlossomUploadResult(
    success: false,
    errorMessage: 'Recoverable resumable upload failure: $dioException',
    failureReason: BlossomUploadFailureReason.fromDioException(dioException),
  );
}

void main() {
  group('$UploadRepository resumable transfer failures', () {
    late Directory tempDir;
    late _MockBlossomUploadService blossom;
    late _RecordingCrashReporter crashReporter;
    late File videoFile;
    late List<BlossomResumableUploadSession?> sessionsPassed;

    UploadRepository buildRepository() {
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
              final path = '${tempDir.path}/thumb.jpg';
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
        retryConfig: const UploadRetryConfig(
          maxRetries: 2,
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      addTearDown(repository.dispose);
      return repository;
    }

    /// Answers every video transfer with [result]. The first one also
    /// reports a committed chunk, as a transfer that got partway would.
    void stubVideoTransfer(BlossomUploadResult result) {
      when(() => blossom.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => blossom.uploadImage(
          imageFile: any(named: 'imageFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          url: _thumbnailUrl,
          fallbackUrl: _thumbnailUrl,
        ),
      );
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
      ).thenAnswer((invocation) async {
        sessionsPassed.add(
          invocation.namedArguments[#resumableSession]
              as BlossomResumableUploadSession?,
        );
        if (sessionsPassed.length == 1) {
          final onSessionUpdated =
              invocation.namedArguments[#onResumableSessionUpdated]
                  as void Function(BlossomResumableUploadSession)?;
          onSessionUpdated?.call(_session);
        }
        return result;
      });
    }

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('resumable_failure_');
      setHiveTestHome(tempDir.path);
      addTearDown(() async {
        await Hive.close();
        await tempDir.delete(recursive: true);
      });
      blossom = _MockBlossomUploadService();
      crashReporter = _RecordingCrashReporter();
      sessionsPassed = [];
      videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);
    });

    test(
      'fails as SERVER_ERROR after retrying a 503, without reporting it',
      () async {
        final repository = buildRepository();
        await repository.initialize();
        stubVideoTransfer(_recoverableResumableFailure(503));

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
              'SERVER_ERROR',
              UploadConnectivity.wifi,
            ),
          ),
        );
        expect(sessionsPassed, hasLength(3), reason: '1 try + 2 retries');
        expect(crashReporter.recorded, isEmpty);
      },
    );

    test(
      'resumes the session on each retry and keeps it for a manual retry',
      () async {
        final repository = buildRepository();
        await repository.initialize();
        stubVideoTransfer(_recoverableResumableFailure(503));

        await expectLater(
          repository.startUpload(videoFile: videoFile, nostrPubkey: _pubkey),
          throwsA(isA<Exception>()),
        );

        expect(
          sessionsPassed.map((session) => session?.uploadId),
          equals([null, _session.uploadId, _session.uploadId]),
        );
        expect(
          repository.pendingUploads.single.resumableSession?.uploadId,
          equals(_session.uploadId),
        );
      },
    );
  });
}
