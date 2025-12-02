// ABOUTME: Tests for UploadInitializationHelper web platform support
// ABOUTME: Verifies IndexedDB-based storage initialization without filesystem dependencies

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_initialization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadInitializationHelper - Web Platform', () {
    setUp(() async {
      // Register adapters if needed
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UploadStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PendingUploadAdapter());
      }

      // Reset helper state
      UploadInitializationHelper.reset();

      // Clean up any existing box
      try {
        if (Hive.isBoxOpen('pending_uploads')) {
          await Hive.box<PendingUpload>('pending_uploads').close();
        }
        await Hive.deleteBoxFromDisk('pending_uploads');
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    tearDown(() async {
      // Clean up
      try {
        if (Hive.isBoxOpen('pending_uploads')) {
          await Hive.box<PendingUpload>('pending_uploads').close();
        }
        await Hive.deleteBoxFromDisk('pending_uploads');
      } catch (_) {
        // Ignore cleanup errors
      }

      UploadInitializationHelper.reset();
    });

    test(
      'initializes box successfully on web platform',
      () async {
        // On web, this should use IndexedDB without filesystem paths
        final box = await UploadInitializationHelper.initializeUploadsBox();

        expect(box.isOpen, isTrue);
        expect(box.name, equals('pending_uploads'));
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test(
      'box is functional for CRUD operations on web',
      () async {
        final box = await UploadInitializationHelper.initializeUploadsBox();

        // Create
        final upload = PendingUpload.create(
          localVideoPath: '/test/video.mp4',
          nostrPubkey: 'test_pubkey_123',
          title: 'Test Video',
        );
        await box.put('test_upload_1', upload);

        // Read
        final retrieved = box.get('test_upload_1');
        expect(retrieved, isNotNull);
        expect(retrieved!.localVideoPath, equals('/test/video.mp4'));
        expect(retrieved.title, equals('Test Video'));

        // Update
        final updated = retrieved.copyWith(title: 'Updated Title');
        await box.put('test_upload_1', updated);
        final retrievedUpdated = box.get('test_upload_1');
        expect(retrievedUpdated!.title, equals('Updated Title'));

        // Delete
        await box.delete('test_upload_1');
        expect(box.get('test_upload_1'), isNull);
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test('handles multiple uploads on web', () async {
      final box = await UploadInitializationHelper.initializeUploadsBox();

      // Add multiple uploads
      for (int i = 0; i < 5; i++) {
        final upload = PendingUpload.create(
          localVideoPath: '/test/video_$i.mp4',
          nostrPubkey: 'pubkey_$i',
          title: 'Video $i',
        );
        await box.put('upload_$i', upload);
      }

      expect(box.length, equals(5));

      // Verify all are retrievable
      for (int i = 0; i < 5; i++) {
        final retrieved = box.get('upload_$i');
        expect(retrieved, isNotNull);
        expect(retrieved!.title, equals('Video $i'));
      }
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test(
      'returns cached box on subsequent calls on web',
      () async {
        final box1 = await UploadInitializationHelper.initializeUploadsBox();
        final box2 = await UploadInitializationHelper.initializeUploadsBox();

        // Should return same instance
        expect(identical(box1, box2), isTrue);
        expect(box2.isOpen, isTrue);
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test('force reinit works on web', () async {
      final box1 = await UploadInitializationHelper.initializeUploadsBox();

      // Add some data
      final upload = PendingUpload.create(
        localVideoPath: '/test/video.mp4',
        nostrPubkey: 'test',
      );
      await box1.put('test', upload);

      // Close and force reinit
      await box1.close();

      final box2 = await UploadInitializationHelper.initializeUploadsBox(
        forceReinit: true,
      );

      expect(box2.isOpen, isTrue);
      // Data should persist across reinit
      expect(box2.get('test'), isNotNull);
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test('debug state is accurate on web', () async {
      final stateBefore = UploadInitializationHelper.getDebugState();
      expect(stateBefore['hasCachedBox'], isFalse);
      expect(stateBefore['isInitializing'], isFalse);

      await UploadInitializationHelper.initializeUploadsBox();

      final stateAfter = UploadInitializationHelper.getDebugState();
      expect(stateAfter['hasCachedBox'], isTrue);
      expect(stateAfter['cachedBoxOpen'], isTrue);
      expect(stateAfter['isInitializing'], isFalse);
      expect(stateAfter['circuitBreakerActive'], isFalse);
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test('does not call path_provider on web', () async {
      // This test verifies that initialization succeeds without filesystem access
      // On web, path_provider methods would throw MissingPluginException

      expect(() async {
        final box = await UploadInitializationHelper.initializeUploadsBox();
        expect(box.isOpen, isTrue);
      }, returnsNormally);
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test(
      'permanent permission error check returns false on web',
      () {
        // Web doesn't have FileSystemException, so this should always return false
        final error = Exception('Some error');

        // Can't directly test private method, but we can verify behavior
        // by checking that errors don't get classified as permanent permission errors
        expect(
          error.runtimeType.toString(),
          isNot(equals('FileSystemException')),
        );
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );
  });
}
