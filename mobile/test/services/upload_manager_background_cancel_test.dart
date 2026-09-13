// ABOUTME: Regression test for the cancel race on OS background uploads.
// ABOUTME: A user-initiated stop must not be reported as a failure.

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:upload_repository/upload_repository.dart'
    show PendingUploadAdapter, UploadStatusAdapter;

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockUploadCrashReporter extends Mock implements UploadCrashReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBlossomUploadService mockBlossomService;
  late _MockUploadCrashReporter mockCrashReporter;
  late UploadManager uploadManager;
  late Directory testDir;

  setUpAll(() {
    registerFallbackValue(File(''));
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp(
      'upload_manager_bg_cancel_test_',
    );
    Hive.init(testDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }

    mockBlossomService = _MockBlossomUploadService();
    mockCrashReporter = _MockUploadCrashReporter();
    when(() => mockBlossomService.isBlossomEnabled()).thenAnswer((_) async {
      return false;
    });
    when(
      () => mockCrashReporter.recordError(
        any(),
        any(),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockCrashReporter.setCustomKey(any(), any()),
    ).thenAnswer((_) async {});

    uploadManager = UploadManager(
      backgroundActivityManager: BackgroundActivityManager(),
      blossomService: mockBlossomService,
      crashReporter: mockCrashReporter,
      useBackgroundUpload: true,
    );
    await uploadManager.initialize();
  });

  tearDown(() async {
    uploadManager.dispose();
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {
      // Hive may already have removed the lock file during async shutdown.
    }
    try {
      await testDir.delete(recursive: true);
    } on PathNotFoundException catch (_) {
      // Lock file may already be deleted by Hive.close().
    }
  });

  // Stubs an OS background transfer that never finishes on its own; cancelling
  // it resolves the future with a `cancelled` failure — the race trigger.
  Completer<BlossomUploadResult> stubCancellableTransfer() {
    final transfer = Completer<BlossomUploadResult>();
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
    ).thenAnswer((_) => transfer.future);
    when(() => mockBlossomService.cancelBackgroundUpload(any())).thenAnswer((
      _,
    ) async {
      if (!transfer.isCompleted) {
        transfer.complete(
          const BlossomUploadResult(
            success: false,
            errorMessage: 'Upload cancelled',
            failureReason: BlossomUploadFailureReason.cancelled,
          ),
        );
      }
    });
    return transfer;
  }

  Future<File> newVideoFile() async {
    final videoFile = File(
      '${testDir.path}/${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await videoFile.writeAsString('fake video content');
    return videoFile;
  }

  group('UploadManager background cancel race', () {
    test(
      'cancelling an in-flight background upload marks it failed without a '
      'crash report',
      () async {
        final videoFile = await newVideoFile();
        stubCancellableTransfer();

        // startUpload drives _performUpload; it stays in flight on the
        // transfer future until the cancel resolves it.
        final runFuture = uploadManager.startUpload(
          videoFile: videoFile,
          nostrPubkey: 'pk',
          title: 'T',
        );
        await _pumpUntil(
          () => uploadManager.pendingUploads.any(
            (upload) => upload.status == UploadStatus.uploading,
          ),
        );
        final uploadId = uploadManager.pendingUploads
            .firstWhere((upload) => upload.status == UploadStatus.uploading)
            .id;

        await uploadManager.cancelUpload(uploadId);
        // startUpload surfaces the cancellation to its caller rather than
        // swallowing it; the persisted row is still the authoritative record.
        await expectLater(
          runFuture,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'toString',
              contains('Upload cancelled by user'),
            ),
          ),
        );

        final result = uploadManager.getUpload(uploadId);
        expect(result?.status, equals(UploadStatus.failed));
        expect(result?.errorMessage, equals('Upload cancelled by user'));
        // A deliberate cancel must not be reported to Crashlytics as a failure.
        verifyNever(
          () => mockCrashReporter.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
          ),
        );
      },
    );
  });
}

Future<void> _pumpUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition was not met in time');
}
