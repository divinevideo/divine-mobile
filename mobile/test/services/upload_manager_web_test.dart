// ABOUTME: Tests for UploadManager web platform support
// ABOUTME: Verifies web-safe initialization and platform detection

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/upload_manager.dart';

import 'upload_manager_web_test.mocks.dart';

@GenerateMocks([BlossomUploadService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadManager - Web Platform', () {
    late MockBlossomUploadService mockBlossomService;

    setUp(() async {
      mockBlossomService = MockBlossomUploadService();

      // Register Hive adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UploadStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PendingUploadAdapter());
      }

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
    });

    test(
      'initializes successfully on web without filesystem access',
      () async {
        final uploadManager = UploadManager(blossomService: mockBlossomService);

        // Should not throw MissingPluginException for path_provider
        await expectLater(uploadManager.initialize(), completes);

        expect(uploadManager.isInitialized, isTrue);

        uploadManager.dispose();
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test('pending uploads list works on web', () async {
      final uploadManager = UploadManager(blossomService: mockBlossomService);

      await uploadManager.initialize();
      expect(uploadManager.isInitialized, isTrue);

      // Should be able to get pending uploads (even if empty)
      final uploads = uploadManager.pendingUploads;
      expect(uploads, isA<List<PendingUpload>>());

      uploadManager.dispose();
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test('upload stats work on web', () async {
      final uploadManager = UploadManager(blossomService: mockBlossomService);

      await uploadManager.initialize();

      final stats = uploadManager.uploadStats;
      expect(stats, isA<Map<String, int>>());
      expect(stats['total'], equals(0));
      expect(stats['pending'], equals(0));
      expect(stats['uploading'], equals(0));

      uploadManager.dispose();
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test(
      'getUpload returns null for non-existent upload on web',
      () async {
        final uploadManager = UploadManager(blossomService: mockBlossomService);

        await uploadManager.initialize();

        final upload = uploadManager.getUpload('nonexistent_id');
        expect(upload, isNull);

        uploadManager.dispose();
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test(
      'cleanupCompletedUploads does not crash on web',
      () async {
        final uploadManager = UploadManager(blossomService: mockBlossomService);

        await uploadManager.initialize();

        // Should not throw
        await expectLater(uploadManager.cleanupCompletedUploads(), completes);

        uploadManager.dispose();
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test('performance metrics work on web', () async {
      final uploadManager = UploadManager(blossomService: mockBlossomService);

      await uploadManager.initialize();

      final metrics = uploadManager.getPerformanceMetrics();
      expect(metrics, isA<Map<String, dynamic>>());
      expect(metrics['total_uploads'], equals(0));
      expect(metrics['successful_uploads'], equals(0));

      uploadManager.dispose();
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test(
      'multiple initializations are safe on web',
      () async {
        final uploadManager = UploadManager(blossomService: mockBlossomService);

        // First init
        await uploadManager.initialize();
        expect(uploadManager.isInitialized, isTrue);

        // Second init should be safe
        await uploadManager.initialize();
        expect(uploadManager.isInitialized, isTrue);

        uploadManager.dispose();
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );

    test('dispose is safe on web', () async {
      final uploadManager = UploadManager(blossomService: mockBlossomService);

      await uploadManager.initialize();

      // Should not throw
      expect(() => uploadManager.dispose(), returnsNormally);
    }, skip: !kIsWeb ? 'Web-only test' : null);

    test(
      'crash reporting does not throw on web',
      () async {
        final uploadManager = UploadManager(blossomService: mockBlossomService);

        await uploadManager.initialize();

        // The platform detection helper should return 'web' instead of crashing
        // We can't directly test the private helper, but we can verify
        // the manager initializes without Platform.operatingSystem errors
        expect(uploadManager.isInitialized, isTrue);

        uploadManager.dispose();
      },
      skip: !kIsWeb ? 'Web-only test' : null,
    );
  });
}
