// ABOUTME: Tests media auth behavior for adult playback preferences
// ABOUTME: Covers verified blocking, auto-auth, and verify-on-play behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

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
    when(() => mockAgeVerificationService.initialized).thenAnswer((_) async {});
    when(() => mockContentFilterService.initialized).thenAnswer((_) async {});
  });

  group('MediaAuthInterceptor - preference handling', () {
    test(
      'handleUnauthorizedMedia blocks verified users at default preferences '
      'even after unlock',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        final realAgeVerificationService = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _testPubkey,
        );
        await realAgeVerificationService.initialize();
        await realAgeVerificationService.setAdultContentVerified(true);

        final realContentFilterService = ContentFilterService(
          ageVerificationService: realAgeVerificationService,
        );
        await realContentFilterService.initialize();
        await realContentFilterService.unlockAdultCategories();

        final interceptor = MediaAuthInterceptor(
          ageVerificationService: realAgeVerificationService,
          contentFilterService: realContentFilterService,
          mediaViewerAuthService: mockMediaViewerAuthService,
        );

        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(() => mockContext.mounted).thenReturn(true);

        // Adult categories stay hidden after unlock; playback stays blocked
        // until the user opts in via Content Filters.
        expect(
          realContentFilterService.adultPlaybackPreference,
          ContentFilterPreference.hide,
        );
        expect(await interceptor.canAutoAuthorizeAdultMedia(), isFalse);

        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        expect(result, isA<ViewerAuthBlockedByPreference>());
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
      'handleUnauthorizedMedia blocks verified users after only a partial '
      'adult-category opt-in',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        final realAgeVerificationService = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _testPubkey,
        );
        await realAgeVerificationService.initialize();
        await realAgeVerificationService.setAdultContentVerified(true);

        final realContentFilterService = ContentFilterService(
          ageVerificationService: realAgeVerificationService,
        );
        await realContentFilterService.initialize();
        await realContentFilterService.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.warn,
        );

        final interceptor = MediaAuthInterceptor(
          ageVerificationService: realAgeVerificationService,
          contentFilterService: realContentFilterService,
          mediaViewerAuthService: mockMediaViewerAuthService,
        );

        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);

        expect(
          realContentFilterService.adultPlaybackPreference,
          ContentFilterPreference.hide,
        );
        expect(await interceptor.canAutoAuthorizeAdultMedia(), isFalse);

        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        expect(result, isA<ViewerAuthBlockedByPreference>());
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
      'handleUnauthorizedMedia creates auth headers after an explicit '
      'per-category opt-in',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        final realAgeVerificationService = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _testPubkey,
        );
        await realAgeVerificationService.initialize();
        await realAgeVerificationService.setAdultContentVerified(true);

        final realContentFilterService = ContentFilterService(
          ageVerificationService: realAgeVerificationService,
        );
        await realContentFilterService.initialize();
        await realContentFilterService.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.warn,
        );
        await realContentFilterService.setPreference(
          ContentLabel.sexual,
          ContentFilterPreference.warn,
        );

        final interceptor = MediaAuthInterceptor(
          ageVerificationService: realAgeVerificationService,
          contentFilterService: realContentFilterService,
          mediaViewerAuthService: mockMediaViewerAuthService,
        );

        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => const ViewerAuthAuthorized({
            'Authorization': 'Nostr unlockedToken',
          }),
        );

        when(() => mockContext.mounted).thenReturn(true);

        expect(
          realContentFilterService.adultPlaybackPreference,
          ContentFilterPreference.warn,
        );
        expect(await interceptor.canAutoAuthorizeAdultMedia(), isTrue);

        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        expect(result, isA<ViewerAuthAuthorized>());
        expect(
          result.headersOrNull,
          equals({'Authorization': 'Nostr unlockedToken'}),
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
      'handleUnauthorizedMedia reports a preference block when verified user '
      'preference is hide',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);

        expect(await interceptor.canAutoAuthorizeAdultMedia(), isFalse);

        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        expect(result, isA<ViewerAuthBlockedByPreference>());
        verifyNever(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );
      },
    );

    test(
      'handleUnauthorizedMedia keeps adult media blocked after verification '
      'when preferences still hide it',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
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

        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        expect(result, isA<ViewerAuthBlockedByPreference>());
        verify(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).called(1);
        verify(
          () => mockContentFilterService.unlockAdultCategories(),
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
      'handleUnauthorizedMedia auto-creates auth when alwaysShow and verified',
      () async {
        // Arrange - alwaysShow preference, already verified
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr autoToken'}),
        );

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - auto auth header created, no dialog shown
        expect(await interceptor.canAutoAuthorizeAdultMedia(), isTrue);
        expect(result, isA<ViewerAuthAuthorized>());
        expect(
          result.headersOrNull,
          equals({'Authorization': 'Nostr autoToken'}),
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
      'createAutoAuthHeadersForAdultMedia creates auth when alwaysShow and verified',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.show);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr autoToken'}),
        );

        final result = await interceptor.createAutoAuthHeadersForAdultMedia(
          sha256Hash: 'abc123',
          url: 'https://media.divine.video/abc123',
          serverUrl: 'https://media.divine.video',
        );

        expect(result, isA<ViewerAuthAuthorized>());
        expect(result.headersOrNull, {'Authorization': 'Nostr autoToken'});
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: 'abc123',
            url: 'https://media.divine.video/abc123',
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    test(
      'createAutoAuthHeadersForAdultMedia creates auth without prompting when preference is warn',
      () async {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => const ViewerAuthAuthorized({
            'Authorization': 'Nostr warnToken',
          }),
        );

        final result = await interceptor.createAutoAuthHeadersForAdultMedia(
          sha256Hash: 'abc123',
        );

        expect(result, isA<ViewerAuthAuthorized>());
        expect(result.headersOrNull, {'Authorization': 'Nostr warnToken'});
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
      'handleUnauthorizedMedia auto-creates auth when warn and verified',
      () async {
        // Arrange - warn preference, already verified for age
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.canCreateHeaders,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => const ViewerAuthAuthorized({
            'Authorization': 'Nostr dialogToken',
          }),
        );

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - auth header created without re-verification
        expect(await interceptor.canAutoAuthorizeAdultMedia(), isTrue);
        expect(result, isA<ViewerAuthAuthorized>());
        expect(
          result.headersOrNull,
          equals({'Authorization': 'Nostr dialogToken'}),
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
      'handleUnauthorizedMedia returns null when askEachTime and user declines',
      () async {
        // Arrange - askEachTime preference, unverified user declines in dialog
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => false);

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - user declined, no auth header
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
  });
}
