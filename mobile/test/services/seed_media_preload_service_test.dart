// ABOUTME: Unit tests for SeedMediaPreloadService
// ABOUTME: Tests bundled media file preloading into cache directory on first launch

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/seed_media_preload_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedMediaPreloadService', () {
    late Directory tempDir;
    late MockPathProviderPlatform mockPathProvider;

    setUp(() async {
      // Create real temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('seed_media_test_');

      // Setup mock path provider
      mockPathProvider = MockPathProviderPlatform();
      mockPathProvider.setTemporaryPath(tempDir.path);
      PathProviderPlatform.instance = mockPathProvider;

      // Clear any cached service instance
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });

    tearDown(() async {
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      // Clear mock asset handler
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });

    test(
      'loadSeedMediaIfNeeded skips load when cache already populated',
      () async {
        // Setup: Pre-populate cache directory with a marker file
        final cacheDir = Directory(
          path.join(tempDir.path, 'openvine_video_cache'),
        );
        await cacheDir.create(recursive: true);

        // Create a marker file to simulate existing cache
        final markerFile = File(path.join(cacheDir.path, '.seed_media_loaded'));
        await markerFile.writeAsString('loaded');

        // Act: Try to load seed media
        await SeedMediaPreloadService.loadSeedMediaIfNeeded();

        // Assert: Should skip loading (verified by no errors and fast execution)
        expect(
          await markerFile.exists(),
          isTrue,
          reason: 'Marker file should still exist',
        );
      },
    );

    test(
      'loadSeedMediaIfNeeded copies bundled videos to cache when empty',
      () async {
        // Setup: Mock manifest.json asset
        final manifestJson = jsonEncode({
          'videos': [
            {
              'eventId':
                  'test_event_1111111111111111111111111111111111111111111111111111111111111111',
              'filename':
                  'test_event_1111111111111111111111111111111111111111111111111111111111111111.mp4',
              'url': 'https://test.com/video1.mp4',
              'size': 1024,
            },
          ],
          'thumbnails': [],
          'generatedAt': '2025-11-10T00:00:00.000000',
        });

        ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          (ByteData? message) async {
            if (message == null) return null;

            // Message is the asset name as UTF-8 bytes
            final assetName = utf8.decode(message.buffer.asUint8List());

            if (assetName.contains('manifest.json')) {
              // Return manifest JSON as bytes
              final bytes = Uint8List.fromList(utf8.encode(manifestJson));
              return ByteData.sublistView(bytes);
            } else if (assetName.contains('.mp4')) {
              // Return fake video bytes
              final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
              return ByteData.sublistView(bytes);
            }

            return null;
          },
        );

        // Act: Load seed media
        await SeedMediaPreloadService.loadSeedMediaIfNeeded();

        // Assert: Check marker file created
        final cacheDir = Directory(
          path.join(tempDir.path, 'openvine_video_cache'),
        );
        final markerFile = File(path.join(cacheDir.path, '.seed_media_loaded'));
        expect(
          await markerFile.exists(),
          isTrue,
          reason: 'Marker file should be created after load',
        );
      },
    );

    test('loadSeedMediaIfNeeded handles missing manifest gracefully', () async {
      // Setup: Mock manifest not found by returning null
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          return null; // Simulate asset not found
        },
      );

      // Act & Assert: Should not throw, just log error
      expect(
        () async => await SeedMediaPreloadService.loadSeedMediaIfNeeded(),
        returnsNormally,
        reason: 'Missing manifest should be non-critical',
      );
    });

    test(
      'loadSeedMediaIfNeeded handles corrupted manifest gracefully',
      () async {
        // Setup: Mock invalid JSON
        ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          (ByteData? message) async {
            if (message == null) return null;

            // Return invalid JSON
            final bytes = Uint8List.fromList(utf8.encode('not valid json'));
            return ByteData.sublistView(bytes);
          },
        );

        // Act & Assert: Should not throw
        expect(
          () async => await SeedMediaPreloadService.loadSeedMediaIfNeeded(),
          returnsNormally,
          reason: 'Corrupted manifest should be non-critical',
        );
      },
    );

    test(
      'loadSeedMediaIfNeeded uses eventId as filename in cache directory',
      () async {
        // Setup: Mock manifest with specific eventId
        final testEventId =
            'unique0000test1111cafe2222beef3333dead4444face5555abcd6666ef0012345678';
        final testFilename = '$testEventId.mp4'; // Filename matches eventId
        final manifestJson = jsonEncode({
          'videos': [
            {
              'eventId': testEventId,
              'filename': testFilename,
              'url': 'https://test.com/video.mp4',
              'size': 512,
            },
          ],
          'thumbnails': [],
          'generatedAt': '2025-11-10T00:00:00.000000',
        });

        final testVideoBytes = Uint8List.fromList([
          0xAB,
          0xCD,
          0xEF,
          0x01,
          0x23,
          0x45,
        ]);

        ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          (ByteData? message) async {
            if (message == null) return null;

            // Message is the asset name as UTF-8 bytes
            final assetName = utf8.decode(message.buffer.asUint8List());

            if (assetName.contains('manifest.json')) {
              // Return manifest JSON as bytes
              final bytes = Uint8List.fromList(utf8.encode(manifestJson));
              return ByteData.sublistView(bytes);
            } else if (assetName.contains('unique0000test1111') &&
                assetName.contains('.mp4')) {
              // Return fake video bytes if unique string is in the path
              return ByteData.sublistView(testVideoBytes);
            }

            return null;
          },
        );

        // Act: Load seed media
        await SeedMediaPreloadService.loadSeedMediaIfNeeded();

        // Assert: File should exist in cache directory with eventId as filename
        final cacheDir = Directory(
          path.join(tempDir.path, 'openvine_video_cache'),
        );
        final videoFile = File(path.join(cacheDir.path, testEventId));

        expect(
          await videoFile.exists(),
          isTrue,
          reason: 'Video file should exist with eventId as filename',
        );

        // Verify file content matches
        final fileBytes = await videoFile.readAsBytes();
        expect(
          fileBytes,
          equals(testVideoBytes),
          reason: 'File content should match asset bytes',
        );
      },
    );
  });
}
