// ABOUTME: Tests TestHelpers' shared-Hive-box cleanup contract.
// ABOUTME: Pins #6748 — cleanupHiveBox silently no-opped on an open typed box.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';
import 'test_helpers.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TestHelpers.cleanupHiveBox', () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cleanup_hive_box_test_');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      await TestHelpers.initHiveHome();
    });

    tearDown(() async {
      await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<Box<PendingUpload>> openBoxWithOneRow() async {
      final box = await UploadInitializationHelper.initializeUploadsBox();
      await box.put(
        'row',
        PendingUpload.create(
          localVideoPath: '${tempDir.path}/video.mp4',
          nostrPubkey: _pubkey,
        ),
      );
      return box;
    }

    // The box is opened as Box<PendingUpload>, which is the case the old
    // implementation could not handle: it reached for Hive.box(name) —
    // Hive.box<dynamic> — and hive_ce threw before the delete ever ran.
    test('closes a box that is open with a concrete value type', () async {
      final box = await openBoxWithOneRow();
      expect(box.length, 1, reason: 'the box must have a row to leak');
      expect(Hive.isBoxOpen(HiveBoxNames.pendingUploads), isTrue);

      await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);

      expect(Hive.isBoxOpen(HiveBoxNames.pendingUploads), isFalse);
    });

    test('deletes the rows, so the next open sees an empty box', () async {
      await openBoxWithOneRow();

      await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
      final reopened = await UploadInitializationHelper.initializeUploadsBox();

      expect(reopened.length, isZero);
    });

    test('is a no-op when the box was never opened', () async {
      expect(Hive.isBoxOpen(HiveBoxNames.pendingUploads), isFalse);

      await expectLater(
        TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads),
        completes,
      );
      expect(Hive.isBoxOpen(HiveBoxNames.pendingUploads), isFalse);
    });
  });
}
