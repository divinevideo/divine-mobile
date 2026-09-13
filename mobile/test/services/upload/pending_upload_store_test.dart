// ABOUTME: App/plugin adapter integration for the upload store: the real
// ABOUTME: UploadInitializationHelper opener drives a package PendingUploadStore
// ABOUTME: on the app's Hive home. Core store behavior is tested in the package.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upload_repository/upload_repository.dart';

import '../../helpers/test_helpers.dart';
import '../../mocks/mock_path_provider_platform.dart';

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// The app-layer store wiring: the helper owns the box, the package owns the
/// store. Every test here crosses that adapter boundary.
PendingUploadStore _store() => PendingUploadStore(
  scopeUploadsToCurrentUser: false,
  currentNostrPubkey: null,
  openBox: UploadInitializationHelper.initializeUploadsBox,
  isWeb: false,
);

void main() {
  setUpAll(() async {
    await initializeServiceTestEnvironment();
  });

  group('PendingUploadStore through the app adapter', () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp(
        'pending_upload_store_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      await TestHelpers.initHiveHome();
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      try {
        await TestHelpers.cleanupHiveBox('pending_uploads');
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('round-trips a record through the helper-opened box', () async {
      final store = _store();
      await store.open();
      addTearDown(store.disposeStore);

      final upload = PendingUpload.create(
        localVideoPath: '${tempDir.path}/video.mp4',
        nostrPubkey: _pubkeyA,
        title: 'Adapter round-trip',
      );
      await store.save(upload);

      expect(store.getUpload(upload.id), isNotNull);
      expect(store.getUpload(upload.id)!.title, equals('Adapter round-trip'));
    });

    test('persists a record across a fresh store instance', () async {
      final first = _store();
      await first.open();
      final upload = PendingUpload.create(
        localVideoPath: '${tempDir.path}/video.mp4',
        nostrPubkey: _pubkeyA,
      );
      await first.save(upload);
      first.disposeStore();

      final second = _store();
      await second.open();
      addTearDown(second.disposeStore);

      expect(second.getUpload(upload.id), isNotNull);
    });

    test('queues the save when the helper cannot open storage', () async {
      // Point Hive's home at a regular file so neither the helper's normal
      // open nor its recovery strategy can create box files; the store must
      // fall back to its deferred-save queue.
      UploadInitializationHelper.reset();
      final blockerDir = await Directory.systemTemp.createTemp(
        'pending_upload_store_blocker_',
      );
      addTearDown(() async {
        UploadInitializationHelper.reset();
        if (blockerDir.existsSync()) {
          await blockerDir.delete(recursive: true);
        }
      });
      final blocker = File('${blockerDir.path}/storage_blocker');
      await blocker.writeAsString('not a directory');
      Hive.init(blocker.path);

      final store = _store();
      addTearDown(store.disposeStore);
      final upload = PendingUpload.create(
        localVideoPath: '${tempDir.path}/video.mp4',
        nostrPubkey: _pubkeyA,
      );

      await expectLater(
        () => store.save(upload),
        throwsA(isA<Exception>()),
      );
      expect(store.queuedCount, equals(1));
    });
  });
}
