// ABOUTME: Tests the heal-and-blame harness for shared process-wide Hive boxes.
// ABOUTME: Each test heals within itself so the root tearDown sees no leak.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';
import 'shared_hive_box_guard.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shared Hive box guard', () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_box_guard_test_');
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

    group('findSharedHiveBoxViolations', () {
      test('is empty while no shared box is open', () {
        expect(sharedHiveBoxNames, contains(HiveBoxNames.pendingUploads));
        expect(findSharedHiveBoxViolations(), isEmpty);
      });

      test('reports a shared box left open', () async {
        await UploadInitializationHelper.initializeUploadsBox();

        expect(
          findSharedHiveBoxViolations(),
          contains(HiveBoxNames.pendingUploads),
        );
      });
    });

    group('healAndBlameSharedHiveBoxes', () {
      test('does nothing when every shared box is closed', () async {
        await expectLater(healAndBlameSharedHiveBoxes(), completes);
      });

      test('closes the leaked box and fails the test that left it', () async {
        await UploadInitializationHelper.initializeUploadsBox();

        await expectLater(
          healAndBlameSharedHiveBoxes(),
          throwsA(isA<TestFailure>()),
        );

        expect(Hive.isBoxOpen(HiveBoxNames.pendingUploads), isFalse);
        expect(findSharedHiveBoxViolations(), isEmpty);
      });
    });
  });
}
