// ABOUTME: Tests for UploadManager processing-poll timer lifecycle
// ABOUTME: Verifies dispose() cancels polls instead of leaking periodic timers

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBlossomUploadService mockBlossomService;
  late UploadManager uploadManager;
  late Directory testDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp(
      'upload_manager_poll_test_',
    );
    Hive.init(testDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }

    mockBlossomService = _MockBlossomUploadService();
    when(
      () => mockBlossomService.getBlossomServer(),
    ).thenAnswer((_) async => null);

    uploadManager = UploadManager(
      backgroundActivityManager: BackgroundActivityManager(),
      blossomService: mockBlossomService,
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

  Future<PendingUpload> seedProcessingUpload() async {
    final upload = PendingUpload(
      id: 'poll-test-upload',
      localVideoPath: '${testDir.path}/video.mp4',
      nostrPubkey: 'test-pubkey-123',
      status: UploadStatus.processing,
      createdAt: DateTime.now(),
      videoId: 'poll-test-video',
    );
    await Hive.box<PendingUpload>('pending_uploads').put(upload.id, upload);
    return upload;
  }

  group('processing poll lifecycle', () {
    test('polls processing status while the upload is processing', () async {
      final upload = await seedProcessingUpload();

      fakeAsync((fake) {
        uploadManager.startProcessingPoll(upload);

        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        verify(() => mockBlossomService.getBlossomServer()).called(1);
        expect(fake.periodicTimerCount, equals(1));
      });
    });

    test('dispose cancels the processing poll timer', () async {
      final upload = await seedProcessingUpload();

      fakeAsync((fake) {
        uploadManager.startProcessingPoll(upload);
        expect(fake.periodicTimerCount, equals(1));

        uploadManager.dispose();

        expect(
          fake.periodicTimerCount,
          equals(0),
          reason: 'dispose must cancel in-flight processing polls',
        );

        fake
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();
        verifyNever(() => mockBlossomService.getBlossomServer());
      });
    });
  });
}
