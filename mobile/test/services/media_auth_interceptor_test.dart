// ABOUTME: Tests for media authentication interceptor handling 401 errors
// ABOUTME: Validates privacy-first auth flow for age-restricted Blossom content

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';

class MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class MockContentFilterService extends Mock implements ContentFilterService {}

class MockMediaViewerAuthService extends Mock
    implements MediaViewerAuthService {}

class MockBuildContext extends Mock implements BuildContext {}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockAgeVerificationService mockAgeVerificationService;
  late MockContentFilterService mockContentFilterService;
  late MockMediaViewerAuthService mockMediaViewerAuthService;
  late MediaAuthInterceptor interceptor;
  late MockBuildContext mockContext;

  setUpAll(() {
    registerFallbackValue(FakeBuildContext());
  });

  setUp(() {
    mockAgeVerificationService = MockAgeVerificationService();
    mockContentFilterService = MockContentFilterService();
    mockMediaViewerAuthService = MockMediaViewerAuthService();
    mockContext = MockBuildContext();
    interceptor = MediaAuthInterceptor(
      ageVerificationService: mockAgeVerificationService,
      contentFilterService: mockContentFilterService,
      mediaViewerAuthService: mockMediaViewerAuthService,
    );

    // Default mock behavior for preference checks
    when(
      () => mockContentFilterService.adultPlaybackPreference,
    ).thenReturn(ContentFilterPreference.warn);
    when(() => mockAgeVerificationService.initialized).thenAnswer((_) async {});
    when(() => mockContentFilterService.initialized).thenAnswer((_) async {});
  });

  group('MediaAuthInterceptor - 401 handling', () {
    test(
      'returns null when user is not verified and denies confirmation',
      () async {
        // Arrange
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => false);

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, isA<ViewerAuthUnavailable>());
        verify(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).called(1);
        verifyNever(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
      },
    );

    test(
      'creates auth header when user has alwaysShow preference and is verified',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => const ViewerAuthAuthorized({
            'Authorization': 'Nostr abc123token',
          }),
        );

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, isA<ViewerAuthAuthorized>());
        expect(
          result.headersOrNull,
          equals({'Authorization': 'Nostr abc123token'}),
        );
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: 'abc123',
          ),
        ).called(1);
      },
    );

    test(
      'creates auth header when user confirms adult content access via dialog',
      () async {
        // Arrange - warn preference uses the click-through verification path
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockContentFilterService.unlockAdultCategories(),
        ).thenAnswer((_) async {});
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => const ViewerAuthAuthorized({
            'Authorization': 'Nostr abc123token',
          }),
        );

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, isA<ViewerAuthAuthorized>());
        expect(
          result.headersOrNull,
          equals({'Authorization': 'Nostr abc123token'}),
        );
        verify(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).called(1);
        verify(
          () => mockContentFilterService.unlockAdultCategories(),
        ).called(1);
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: 'abc123',
          ),
        ).called(1);
      },
    );

    test('includes serverUrl in auth header when provided', () async {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.show);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer(
        (_) async => const ViewerAuthAuthorized({
          'Authorization': 'Nostr tokenWithServer',
        }),
      );

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'xyz789',
        serverUrl: 'https://blossom.example.com',
        category: 'nudity',
      );

      // Assert
      expect(result, isA<ViewerAuthAuthorized>());
      expect(
        result.headersOrNull,
        equals({'Authorization': 'Nostr tokenWithServer'}),
      );
      verify(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: 'xyz789',
          serverUrl: 'https://blossom.example.com',
        ),
      ).called(1);
    });

    test('logs category for future extensibility', () async {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.show);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      // Act - Test with different category (future-proofing for violence, etc.)
      await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'violence',
      );

      // Assert - Should still work (currently only handles nudity/adult content)
      verify(
        () =>
            mockMediaViewerAuthService.createAuthHeaders(sha256Hash: 'abc123'),
      ).called(1);
    });

    test(
      'returns null when BlossomAuthService fails to create header',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, isA<ViewerAuthUnavailable>());
      },
    );

    test(
      'propagates ViewerAuthSignerUnreachable when the remote signer times out',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthSignerUnreachable());

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert — the timeout outcome reaches the caller unchanged so the UI
        // can show the connectivity-specific message.
        expect(result, isA<ViewerAuthSignerUnreachable>());
      },
    );
  });

  group('MediaAuthInterceptor - helper methods', () {
    test(
      'waits for moderation readiness before auto-auth gate checks',
      () async {
        final ageReady = Completer<void>();
        final filterReady = Completer<void>();
        when(
          () => mockAgeVerificationService.initialized,
        ).thenAnswer((_) => ageReady.future);
        when(
          () => mockContentFilterService.initialized,
        ).thenAnswer((_) => filterReady.future);
        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );

        final resultFuture = interceptor.createAutoAuthHeadersForAdultMedia(
          sha256Hash: 'abc123',
        );
        await Future<void>.value();

        verifyNever(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );

        ageReady.complete();
        filterReady.complete();
        final result = await resultFuture;

        expect(result, isA<ViewerAuthAuthorized>());
      },
    );

    test(
      'waits for readiness before returning verified hide preference',
      () async {
        final ageReady = Completer<void>();
        final filterReady = Completer<void>();
        // Persisted verification is only available once the services finish
        // initializing. Before then the in-memory default reads as unverified,
        // which would route to the verify-dialog path. Reading the gate before
        // awaiting readiness is exactly the cold-start bug this guards.
        var loaded = false;
        when(
          () => mockAgeVerificationService.initialized,
        ).thenAnswer((_) => ageReady.future);
        when(
          () => mockContentFilterService.initialized,
        ).thenAnswer((_) => filterReady.future);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenAnswer((_) => loaded);
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => false);

        final resultFuture = interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
        );
        await Future<void>.value();

        // Until initialization completes the gate must not fall through to the
        // verify-dialog path on the pre-load unverified default.
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );

        loaded = true;
        ageReady.complete();
        filterReady.complete();
        final result = await resultFuture;

        expect(result, isA<ViewerAuthBlockedByPreference>());
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );
      },
    );

    test('canCreateAuthHeaders delegates to MediaViewerAuthService', () {
      // Arrange
      when(() => mockMediaViewerAuthService.canCreateHeaders).thenReturn(true);

      // Act
      final result = interceptor.canCreateAuthHeaders;

      // Assert
      expect(result, isTrue);
      verify(() => mockMediaViewerAuthService.canCreateHeaders).called(1);
    });
  });

  group('MediaAuthInterceptor - passive media auth', () {
    test(
      'creates hash-bound headers only for verified users with show preference',
      () async {
        when(
          () => mockMediaViewerAuthService.canCreatePassiveHeaders,
        ).thenReturn(true);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );

        final result = await interceptor.createPassiveAuthHeadersForAdultMedia(
          sha256Hash: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          serverUrl: 'https://media.divine.video',
        );

        expect(result.headersOrNull, equals({'Authorization': 'Nostr token'}));
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    test('does not create passive headers for warn preference', () async {
      when(
        () => mockMediaViewerAuthService.canCreatePassiveHeaders,
      ).thenReturn(true);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.warn);

      final result = await interceptor.createPassiveAuthHeadersForAdultMedia(
        sha256Hash:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        serverUrl: 'https://media.divine.video',
      );

      expect(result, isA<ViewerAuthUnavailable>());
      verifyNever(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    test('does not create passive headers for unverified users', () async {
      when(
        () => mockMediaViewerAuthService.canCreatePassiveHeaders,
      ).thenReturn(true);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(false);

      final result = await interceptor.createPassiveAuthHeadersForAdultMedia(
        sha256Hash:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      expect(result, isA<ViewerAuthUnavailable>());
      verifyNever(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    test('does not fall back to URL-bound auth when hash is empty', () async {
      when(
        () => mockMediaViewerAuthService.canCreatePassiveHeaders,
      ).thenReturn(true);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.show);

      final result = await interceptor.createPassiveAuthHeadersForAdultMedia(
        sha256Hash: '',
        serverUrl: 'https://media.divine.video',
      );

      expect(result, isA<ViewerAuthUnavailable>());
      verifyNever(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    test('does not create passive headers for interactive signers', () async {
      when(
        () => mockMediaViewerAuthService.canCreatePassiveHeaders,
      ).thenReturn(false);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.show);

      final result = await interceptor.createPassiveAuthHeadersForAdultMedia(
        sha256Hash:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        serverUrl: 'https://media.divine.video',
      );

      expect(result, isA<ViewerAuthUnavailable>());
      verifyNever(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    test('waits for moderation readiness before passive gate checks', () async {
      final ageReady = Completer<void>();
      final filterReady = Completer<void>();
      when(
        () => mockAgeVerificationService.initialized,
      ).thenAnswer((_) => ageReady.future);
      when(
        () => mockContentFilterService.initialized,
      ).thenAnswer((_) => filterReady.future);
      when(
        () => mockMediaViewerAuthService.canCreatePassiveHeaders,
      ).thenReturn(true);
      when(
        () => mockAgeVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.show);
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      final resultFuture = interceptor.createPassiveAuthHeadersForAdultMedia(
        sha256Hash:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        serverUrl: 'https://media.divine.video',
      );
      await Future<void>.value();

      verifyNever(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );

      ageReady.complete();
      filterReady.complete();
      final result = await resultFuture;

      expect(result, isA<ViewerAuthAuthorized>());
      verify(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
    });
  });
}
