// ABOUTME: Tests the heal-and-blame harness for shared process-wide Hive boxes.
// ABOUTME: Each test heals within itself so the root tearDown sees no leak.

import 'dart:async';
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
      // The tearDown half alone cannot protect this suite from a box an
      // earlier suite left registered; the documented contract is both.
      await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      try {
        await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
      } finally {
        // initHiveHome pointed Hive's process-global home path inside tempDir,
        // and HiveStorageService.resetForTesting only clears that service's own
        // latch -- it never touches HiveImpl.homePath. Left set, the next suite
        // to open a box without re-pointing Hive has BackendManagerVm silently
        // recreate the directory deleted below and write there.
        Hive.init(null);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
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
      test(
        'fails promptly with the name of a stranded observed open',
        () async {
          final completer = Completer<Box<dynamic>>();
          final observer = SharedHiveBoxOpenObserver(Zone.current);
          observer.observe<Box<dynamic>>(
            HiveBoxNames.pendingUploads,
            () => completer.future,
          );
          expect(observer.pending, hasLength(1));

          await expectLater(
            healAndBlameSharedHiveBoxes(
              strict: false,
              openObserver: observer,
              pendingOpenTimeout: const Duration(milliseconds: 10),
            ),
            throwsA(
              isA<TestFailure>().having(
                (failure) => failure.message,
                'message',
                allOf(
                  contains(HiveBoxNames.pendingUploads),
                  contains('did not settle'),
                ),
              ),
            ),
          );

          completer.completeError(StateError('synthetic stranded open'));
          await expectLater(completer.future, throwsStateError);
        },
      );

      test('does nothing when every shared box is closed', () async {
        await expectLater(healAndBlameSharedHiveBoxes(strict: true), completes);
      });

      test('closes the leaked box and fails in strict mode', () async {
        await UploadInitializationHelper.initializeUploadsBox();

        await expectLater(
          healAndBlameSharedHiveBoxes(strict: true),
          throwsA(isA<TestFailure>()),
        );

        expect(Hive.isBoxOpen(HiveBoxNames.pendingUploads), isFalse);
        expect(findSharedHiveBoxViolations(), isEmpty);
      });

      test('closes the leaked box without failing during soak mode', () async {
        await UploadInitializationHelper.initializeUploadsBox();

        await expectLater(
          healAndBlameSharedHiveBoxes(strict: false),
          completes,
        );

        expect(findSharedHiveBoxViolations(), isEmpty);
      });

      // One box whose cleanup throws must not abandon the boxes after it.
      // Unguarded, the first throw escaped the loop, left every later box
      // registered for the next suite to inherit, and skipped the fail()
      // below — so the leak survived and the diagnostic never printed.
      test('heals the remaining boxes when one cleanup throws', () async {
        await UploadInitializationHelper.initializeUploadsBox();
        await Hive.openBox<dynamic>(HiveBoxNames.notifications);
        expect(
          findSharedHiveBoxViolations(),
          containsAll([
            HiveBoxNames.pendingUploads,
            HiveBoxNames.notifications,
          ]),
          reason: 'both boxes must leak for the loop to have a second pass',
        );

        final attempted = <String>[];
        await expectLater(
          healAndBlameSharedHiveBoxes(
            strict: true,
            cleanup: (name) async {
              attempted.add(name);
              if (name == HiveBoxNames.pendingUploads) {
                throw StateError('cleanup blew up on $name');
              }
              await TestHelpers.cleanupHiveBox(name);
            },
          ),
          throwsA(
            isA<TestFailure>().having(
              (failure) => failure.message,
              'message',
              allOf(
                contains(HiveBoxNames.pendingUploads),
                contains('Cleanup itself then failed'),
                contains('cleanup blew up'),
              ),
            ),
          ),
        );

        expect(
          attempted,
          containsAll([
            HiveBoxNames.pendingUploads,
            HiveBoxNames.notifications,
          ]),
          reason: 'the throw must not abandon the boxes after it',
        );
        expect(Hive.isBoxOpen(HiveBoxNames.notifications), isFalse);

        // The injected cleanup deliberately left this one open; heal it here
        // so the root tearDown does not blame this test for it.
        await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
      });
    });
  });
}
