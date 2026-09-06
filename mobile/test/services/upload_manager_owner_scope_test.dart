// ABOUTME: Regression tests for owner-scoped Hive pending upload visibility.
// ABOUTME: Ensures account switches do not expose another account's uploads.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
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

void main() {
  setUpAll(() async {
    await initializeServiceTestEnvironment();
  });

  group('UploadManager owner-scoped pending uploads', () {
    const pubkeyA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pubkeyB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    late _MockBlossomUploadService mockBlossomService;
    late Directory tempDir;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp(
        'upload_manager_owner_scope_',
      );
      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      PathProviderPlatform.instance = mockPathProvider;
      await TestHelpers.initHiveHome();

      mockBlossomService = _MockBlossomUploadService();
      when(
        () => mockBlossomService.isBlossomEnabled(),
      ).thenAnswer((_) async => false);
    });

    tearDown(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      PathProviderPlatform.instance = originalPathProviderInstance;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<UploadManager> createManager({
      required String? currentPubkey,
      bool scopeUploadsToCurrentUser = true,
    }) async {
      final manager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossomService,
        currentNostrPubkey: currentPubkey,
        scopeUploadsToCurrentUser: scopeUploadsToCurrentUser,
      );
      await manager.initialize();
      return manager;
    }

    Future<Map<String, PendingUpload>> seedUploads() async {
      final box = Hive.box<PendingUpload>('pending_uploads');
      final aPending = PendingUpload.create(
        localVideoPath: '${tempDir.path}/a_pending.mp4',
        nostrPubkey: pubkeyA,
        title: 'A pending',
      );
      await box.put(aPending.id, aPending);
      final aProcessing = PendingUpload.create(
        localVideoPath: '${tempDir.path}/a_processing.mp4',
        nostrPubkey: pubkeyA,
        title: 'A processing',
      ).copyWith(status: UploadStatus.processing);
      await box.put(aProcessing.id, aProcessing);
      final bPending = PendingUpload.create(
        localVideoPath: '${tempDir.path}/b_pending.mp4',
        nostrPubkey: pubkeyB,
        title: 'B pending',
      );
      await box.put(bPending.id, bPending);
      final bProcessing = PendingUpload.create(
        localVideoPath: '${tempDir.path}/b_processing.mp4',
        nostrPubkey: pubkeyB,
        title: 'B processing',
      ).copyWith(status: UploadStatus.processing);
      await box.put(bProcessing.id, bProcessing);

      return {
        'aPending': aPending,
        'aProcessing': aProcessing,
        'bPending': bPending,
        'bProcessing': bProcessing,
      };
    }

    test('pendingUploads exposes only the current account', () async {
      final manager = await createManager(currentPubkey: pubkeyA);
      addTearDown(manager.dispose);
      await seedUploads();

      expect(
        manager.pendingUploads.map((upload) => upload.nostrPubkey).toSet(),
        equals({pubkeyA}),
      );
      expect(manager.pendingUploads, hasLength(2));
    });

    test(
      'status and path queries use the scoped pending upload view',
      () async {
        final manager = await createManager(currentPubkey: pubkeyA);
        addTearDown(manager.dispose);
        final uploads = await seedUploads();

        expect(
          manager.pendingUploads
              .where((upload) => upload.status == UploadStatus.processing)
              .map((upload) => upload.nostrPubkey),
          equals([pubkeyA]),
        );
        expect(manager.getUpload(uploads['aPending']!.id), isNotNull);
        expect(manager.getUpload(uploads['bPending']!.id), isNull);
        expect(
          manager.getUploadByFilePath('${tempDir.path}/b_pending.mp4'),
          isNull,
        );
      },
    );

    test(
      'production scoping hides uploads without a current account',
      () async {
        final manager = await createManager(currentPubkey: null);
        addTearDown(manager.dispose);
        await seedUploads();

        expect(manager.pendingUploads, isEmpty);
        expect(manager.uploadStats['total'], equals(0));
      },
    );

    test(
      'direct unscoped managers keep maintenance access to all uploads',
      () async {
        final manager = await createManager(
          currentPubkey: null,
          scopeUploadsToCurrentUser: false,
        );
        addTearDown(manager.dispose);
        await seedUploads();

        expect(
          manager.pendingUploads.map((upload) => upload.nostrPubkey).toSet(),
          equals({pubkeyA, pubkeyB}),
        );
      },
    );

    test('completed cleanup still scans all accounts', () async {
      final manager = await createManager(currentPubkey: pubkeyA);
      addTearDown(manager.dispose);
      final box = Hive.box<PendingUpload>('pending_uploads');
      final aPublished = PendingUpload.create(
        localVideoPath: '${tempDir.path}/a_published.mp4',
        nostrPubkey: pubkeyA,
      ).copyWith(status: UploadStatus.published);
      await box.put(aPublished.id, aPublished);
      final bPublished = PendingUpload.create(
        localVideoPath: '${tempDir.path}/b_published.mp4',
        nostrPubkey: pubkeyB,
      ).copyWith(status: UploadStatus.published);
      await box.put(bPublished.id, bPublished);

      await manager.cleanupCompletedUploads();

      expect(box.values, isEmpty);
    });

    test(
      'owner cleanup scans all accounts even when manager is scoped elsewhere',
      () async {
        final manager = await createManager(currentPubkey: pubkeyB);
        addTearDown(manager.dispose);
        final uploads = await seedUploads();
        manager.startProcessingPoll(uploads['aProcessing']!);

        final deleted = await manager.deleteAllForOwner(pubkeyA);

        final box = Hive.box<PendingUpload>('pending_uploads');
        expect(deleted, equals(2));
        expect(box.get(uploads['aPending']!.id), isNull);
        expect(box.get(uploads['aProcessing']!.id), isNull);
        expect(box.get(uploads['bPending']!.id), isNotNull);
        expect(box.get(uploads['bProcessing']!.id), isNotNull);
      },
    );
  });
}
