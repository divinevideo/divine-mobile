// ABOUTME: Verifies app-owned Hive opens remain observable in merged tests.
// ABOUTME: Pins real-zone execution so fake async cannot strand Hive's registry.

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/services/hive_box_opener.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/shared_hive_box_guard.dart';
import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_box_opener_test_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProviderPlatform()
      ..setTemporaryPath(tempDir.path)
      ..setApplicationDocumentsPath('${tempDir.path}/documents')
      ..setApplicationSupportPath('${tempDir.path}/support');
    await TestHelpers.initHiveHome();
    await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    HiveBoxOpener.observerForTesting = null;
    await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
    Hive.init(null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a fake-async caller cannot strand Hive opening state', () async {
    final observer = SharedHiveBoxOpenObserver(Zone.current);
    HiveBoxOpener.observerForTesting = observer;

    late Future<Box<dynamic>> open;
    fakeAsync((_) {
      open = HiveBoxOpener.open<dynamic>(HiveBoxNames.pendingUploads);
    });

    final box = await open;
    expect(box.isOpen, isTrue);
    expect(observer.pending, isEmpty);

    await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
    final reopened = await HiveBoxOpener.open<dynamic>(
      HiveBoxNames.pendingUploads,
    );
    expect(reopened.isOpen, isTrue);
  });
}
