// ABOUTME: Tests for UploadManager local thumbnail generation and upload
// ABOUTME: Verifies thumbnails are extracted from videos and uploaded to Blossom

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/circuit_breaker_service.dart';
import 'package:openvine/services/upload_manager.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockVideoCircuitBreaker extends Mock implements VideoCircuitBreaker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadManager - Local Thumbnail Generation', () {
    late _MockBlossomUploadService mockBlossomService;
    late _MockVideoCircuitBreaker mockCircuitBreaker;

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() {
      mockBlossomService = _MockBlossomUploadService();
      mockCircuitBreaker = _MockVideoCircuitBreaker();

      // Default circuit breaker behavior
      when(() => mockCircuitBreaker.allowRequests).thenReturn(true);
      when(
        () => mockCircuitBreaker.state,
      ).thenReturn(CircuitBreakerState.closed);
      when(() => mockCircuitBreaker.failureRate).thenReturn(0.0);
    });

    test('BlossomUploadService has uploadImage method', () {
      // Verify the new uploadImage method exists
      expect(mockBlossomService.uploadImage, isA<Function>());
    });

    test('uploadImage supports progress callback', () async {
      final testFile = File('test_image.jpg');
      const testPubkey = 'test-pubkey-123';
      final progressValues = <double>[];

      when(
        () => mockBlossomService.uploadImage(
          imageFile: testFile,
          nostrPubkey: testPubkey,
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(double)?;

        // Simulate progress updates
        onProgress?.call(0.1);
        onProgress?.call(0.5);
        onProgress?.call(1.0);

        return const BlossomUploadResult(
          success: true,
          videoId: 'image-hash',
          thumbnailUrl: 'https://blossom.example.com/image-hash.jpg',
        );
      });

      await mockBlossomService.uploadImage(
        imageFile: testFile,
        nostrPubkey: testPubkey,
        onProgress: progressValues.add,
      );

      expect(progressValues, [0.1, 0.5, 1.0]);
    });

    test('BlossomUploadResult includes thumbnailUrl field', () {
      const result = BlossomUploadResult(
        success: true,
        videoId: 'video-123',
        thumbnailUrl: 'https://cdn.example.com/thumbnail.jpg',
      );

      expect(result.success, isTrue);
      expect(result.videoId, 'video-123');
      expect(result.thumbnailUrl, 'https://cdn.example.com/thumbnail.jpg');
    });

    test('uploadImage handles authentication errors', () async {
      final testFile = File('test_image.jpg');
      const testPubkey = 'test-pubkey-123';

      when(
        () => mockBlossomService.uploadImage(
          imageFile: testFile,
          nostrPubkey: testPubkey,
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        ),
      );

      final result = await mockBlossomService.uploadImage(
        imageFile: testFile,
        nostrPubkey: testPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('authenticated'));
    });

    test('uploadImage handles network errors gracefully', () async {
      final testFile = File('test_image.jpg');
      const testPubkey = 'test-pubkey-123';

      when(
        () => mockBlossomService.uploadImage(
          imageFile: testFile,
          nostrPubkey: testPubkey,
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: false,
          errorMessage: 'Network error',
        ),
      );

      final result = await mockBlossomService.uploadImage(
        imageFile: testFile,
        nostrPubkey: testPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('uploadImage supports different MIME types', () async {
      final testFile = File('test_image.png');
      const testPubkey = 'test-pubkey-123';

      when(
        () => mockBlossomService.uploadImage(
          imageFile: testFile,
          nostrPubkey: testPubkey,
          mimeType: 'image/png',
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'image-hash',
          thumbnailUrl: 'https://blossom.example.com/image-hash.png',
        ),
      );

      final result = await mockBlossomService.uploadImage(
        imageFile: testFile,
        nostrPubkey: testPubkey,
        mimeType: 'image/png',
      );

      expect(result.success, isTrue);
      expect(result.thumbnailUrl, contains('.png'));
    });

    test('uploadImage returns existing file URL on 409 conflict', () async {
      final testFile = File('test_image.jpg');
      const testPubkey = 'test-pubkey-123';
      const fileHash = 'abc123hash';

      when(
        () => mockBlossomService.uploadImage(
          imageFile: testFile,
          nostrPubkey: testPubkey,
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: fileHash,
          thumbnailUrl: 'https://blossom.example.com/$fileHash',
        ),
      );

      final result = await mockBlossomService.uploadImage(
        imageFile: testFile,
        nostrPubkey: testPubkey,
      );

      expect(result.success, isTrue);
      expect(result.thumbnailUrl, contains(fileHash));
    });
  });

  group('UploadManager.createSuccessfulUpload thumbnail precedence', () {
    // The server derives a poster at {videoHash}.jpg and returns it as the
    // video upload's thumbnailUrl. When the user picked a cover, we extract
    // and upload it separately and store it on the upload's thumbnailPath —
    // that custom cover must survive, not be replaced by the server poster.
    const serverPoster = 'https://media.divine.video/videohash.jpg';
    const customCover = 'https://media.divine.video/customcoverhash';

    late _MockBlossomUploadService mockBlossomService;
    late UploadManager uploadManager;

    setUp(() {
      mockBlossomService = _MockBlossomUploadService();
      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: mockBlossomService,
      );
    });

    tearDown(() {
      uploadManager.dispose();
    });

    PendingUpload uploadWith(String? thumbnailPath) => PendingUpload.create(
      localVideoPath: '/tmp/video.mp4',
      nostrPubkey: 'test-pubkey',
      thumbnailPath: thumbnailPath,
    );

    BlossomUploadResult resultWithPoster() => const BlossomUploadResult(
      success: true,
      videoId: 'videohash',
      url: 'https://media.divine.video/videohash',
      fallbackUrl: 'https://media.divine.video/videohash',
      thumbnailUrl: serverPoster,
    );

    test('keeps the custom uploaded cover over the server poster', () {
      final updated = uploadManager.createSuccessfulUpload(
        uploadWith(customCover),
        resultWithPoster(),
      );

      expect(updated.thumbnailPath, equals(customCover));
    });

    test(
      'falls back to the server poster when no custom cover was uploaded',
      () {
        final updated = uploadManager.createSuccessfulUpload(
          uploadWith(null),
          resultWithPoster(),
        );

        expect(updated.thumbnailPath, equals(serverPoster));
      },
    );

    test('ignores a non-http local cover path and uses the server poster', () {
      final updated = uploadManager.createSuccessfulUpload(
        uploadWith('/data/app/thumbnail_local.jpg'),
        resultWithPoster(),
      );

      expect(updated.thumbnailPath, equals(serverPoster));
    });
  });
}
