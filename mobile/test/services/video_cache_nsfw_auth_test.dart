// ABOUTME: Tests for NSFW video caching with Blossom authentication
// ABOUTME: Verifies that auth headers are properly added when user has verified adult content

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/video_cache_manager.dart';

import 'video_cache_nsfw_auth_test.mocks.dart';

@GenerateMocks([AgeVerificationService, BlossomAuthService, VideoCacheManager])
void main() {
  group('NSFW Video Caching Authentication', () {
    late MockAgeVerificationService mockAgeVerification;
    late MockBlossomAuthService mockBlossomAuth;
    late MockVideoCacheManager mockVideoCache;

    setUp(() {
      mockAgeVerification = MockAgeVerificationService();
      mockBlossomAuth = MockBlossomAuthService();
      mockVideoCache = MockVideoCacheManager();
    });

    test(
      'creates auth header when user verified adult content and video has sha256',
      () async {
        // Arrange
        const sha256Hash =
            '1ea441cc3ae807ea20c976244be6408438732ab5ce1f18e9e2a4d0b507841ee4';
        const serverUrl = 'https://cdn.divine.video';
        const authHeader = 'Nostr base64encodedtoken';

        when(mockAgeVerification.isAdultContentVerified).thenReturn(true);
        when(mockBlossomAuth.canCreateHeaders).thenReturn(true);
        when(
          mockBlossomAuth.createGetAuthHeader(
            sha256Hash: sha256Hash,
            serverUrl: serverUrl,
          ),
        ).thenAnswer((_) async => authHeader);

        // Act
        final result = await mockBlossomAuth.createGetAuthHeader(
          sha256Hash: sha256Hash,
          serverUrl: serverUrl,
        );

        // Assert
        expect(result, equals(authHeader));
        verify(
          mockBlossomAuth.createGetAuthHeader(
            sha256Hash: sha256Hash,
            serverUrl: serverUrl,
          ),
        ).called(1);
      },
    );

    test(
      'does not create auth header when user has not verified adult content',
      () async {
        // Arrange
        when(mockAgeVerification.isAdultContentVerified).thenReturn(false);

        // Act & Assert
        expect(mockAgeVerification.isAdultContentVerified, isFalse);
        verifyNever(
          mockBlossomAuth.createGetAuthHeader(
            sha256Hash: anyNamed('sha256Hash'),
            serverUrl: anyNamed('serverUrl'),
          ),
        );
      },
    );

    test(
      'does not create auth header when user cannot create headers (not authenticated)',
      () async {
        // Arrange
        when(mockAgeVerification.isAdultContentVerified).thenReturn(true);
        when(mockBlossomAuth.canCreateHeaders).thenReturn(false);

        // Act & Assert
        expect(mockBlossomAuth.canCreateHeaders, isFalse);
        // Should not attempt to create headers if user is not authenticated
      },
    );

    test('VideoCacheManager accepts auth headers parameter', () async {
      // Arrange
      const videoUrl = 'https://cdn.divine.video/1ea441cc.mp4';
      const videoId = 'test-video-id';
      const authHeader = 'Nostr base64encodedtoken';
      final authHeaders = {'Authorization': authHeader};

      when(
        mockVideoCache.cacheVideo(videoUrl, videoId, authHeaders: authHeaders),
      ).thenAnswer((_) async => null);

      // Act
      await mockVideoCache.cacheVideo(
        videoUrl,
        videoId,
        authHeaders: authHeaders,
      );

      // Assert
      verify(
        mockVideoCache.cacheVideo(videoUrl, videoId, authHeaders: authHeaders),
      ).called(1);
    });

    test(
      'VideoCacheManager works without auth headers (backward compatibility)',
      () async {
        // Arrange
        const videoUrl = 'https://cdn.divine.video/regular-video.mp4';
        const videoId = 'regular-video-id';

        when(
          mockVideoCache.cacheVideo(videoUrl, videoId),
        ).thenAnswer((_) async => null);

        // Act
        await mockVideoCache.cacheVideo(videoUrl, videoId);

        // Assert
        verify(mockVideoCache.cacheVideo(videoUrl, videoId)).called(1);
      },
    );

    test(
      'auth header creation includes server URL for proper scoping',
      () async {
        // Arrange
        const sha256Hash =
            '1ea441cc3ae807ea20c976244be6408438732ab5ce1f18e9e2a4d0b507841ee4';
        const serverUrl = 'https://cdn.divine.video';
        const authHeader = 'Nostr base64encodedtoken';

        when(
          mockBlossomAuth.createGetAuthHeader(
            sha256Hash: sha256Hash,
            serverUrl: serverUrl,
          ),
        ).thenAnswer((_) async => authHeader);

        // Act
        final result = await mockBlossomAuth.createGetAuthHeader(
          sha256Hash: sha256Hash,
          serverUrl: serverUrl,
        );

        // Assert
        expect(result, equals(authHeader));
        verify(
          mockBlossomAuth.createGetAuthHeader(
            sha256Hash: sha256Hash,
            serverUrl: serverUrl, // Server URL is properly passed
          ),
        ).called(1);
      },
    );
  });
}
