// ABOUTME: Centralized provider overrides for widget tests to fix ProviderException failures
// ABOUTME: Provides mock implementations of all providers that throw UnimplementedError in production

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes (public because they are imported by many test files)
class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockAuthService extends Mock implements AuthService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

class MockNostrClient extends Mock implements NostrClient {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockNip05VerificationService extends Mock
    implements Nip05VerificationService {}

class MockFollowRepository extends Mock implements FollowRepository {}

class MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class MockVideoEventService extends Mock implements VideoEventService {
  @override
  Stream<String> get removedVideoIds => const Stream<String>.empty();

  @override
  bool isVideoEventKnownDeleted(VideoEvent video) => false;
}

/// Prevents unrelated widget tests from starting timers or sending analytics.
class TestAnalyticsService extends AnalyticsService {
  TestAnalyticsService()
    : super(
        backgroundActivityManager: BackgroundActivityManager(),
        disableNostrPublishing: true,
        productAnalyticsEnabled: false,
      );

  @override
  Future<void> initialize() async {}
}

/// Creates a properly stubbed MockSharedPreferences for testing
MockSharedPreferences createMockSharedPreferences() {
  final mockPrefs = MockSharedPreferences();

  // Stub all FeatureFlag methods to return sensible defaults
  for (final flag in FeatureFlag.values) {
    when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
    when(
      () => mockPrefs.setBool('ff_${flag.name}', any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPrefs.remove('ff_${flag.name}'),
    ).thenAnswer((_) async => true);
    when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
  }

  // Add common SharedPreferences stubs that tests might need
  when(() => mockPrefs.getBool(any())).thenReturn(null);
  when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getString(any())).thenReturn(null);
  when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getInt(any())).thenReturn(null);
  when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getDouble(any())).thenReturn(null);
  when(() => mockPrefs.setDouble(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getStringList(any())).thenReturn(null);
  when(
    () => mockPrefs.setStringList(any(), any()),
  ).thenAnswer((_) async => true);
  when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);
  when(mockPrefs.clear).thenAnswer((_) async => true);
  when(() => mockPrefs.containsKey(any())).thenReturn(false);

  return mockPrefs;
}

/// Creates a properly stubbed MockAuthService for testing
MockAuthService createMockAuthService({
  AuthState authState = AuthState.unauthenticated,
  String? currentPublicKeyHex,
}) {
  final mockAuth = MockAuthService();

  // Stub common auth methods with sensible defaults
  when(
    () => mockAuth.isAuthenticated,
  ).thenReturn(authState == AuthState.authenticated);
  when(() => mockAuth.canExportLocalNsec).thenReturn(false);
  when(
    () => mockAuth.authenticationSource,
  ).thenReturn(AuthenticationSource.none);
  when(() => mockAuth.currentPublicKeyHex).thenReturn(currentPublicKeyHex);
  when(() => mockAuth.isNip07Available).thenReturn(false);
  when(() => mockAuth.signerReadiness).thenReturn(SignerReadiness.pending);
  when(
    () => mockAuth.authRpcCapability,
  ).thenReturn(AuthRpcCapability.unavailable);
  when(
    () => mockAuth.authRpcCapabilityStream,
  ).thenAnswer((_) => const Stream<AuthRpcCapability>.empty());

  // Stub authState and authStateStream so currentAuthStateProvider does not
  // crash with type 'Null' is not a subtype of type 'Stream<AuthState>'
  when(() => mockAuth.authState).thenReturn(authState);
  when(
    () => mockAuth.authStateStream,
  ).thenAnswer((_) => const Stream<AuthState>.empty());
  _stubSessionCleanupRegistration(mockAuth);

  return mockAuth;
}

void _stubSessionCleanupRegistration(AuthService mockAuth) {
  if (mockAuth is! Mock) return;

  when(
    () => mockAuth.registerBeforeSessionTeardownCallback(any()),
  ).thenReturn(() {});
}

/// Creates a properly stubbed MockNostrClient for testing
MockNostrClient createMockNostrService() {
  final mockNostr = MockNostrClient();

  // Stub common properties
  when(() => mockNostr.isInitialized).thenReturn(true);
  when(() => mockNostr.hasKeys).thenReturn(false);
  when(() => mockNostr.connectedRelayCount).thenReturn(1);
  when(() => mockNostr.configuredRelays).thenReturn(<String>[]);

  // Stub subscribe() to return empty stream (never null) so
  // SubscriptionManager batch fetch does not get
  // type 'Null' is not a subtype of type 'Stream<Event>'
  when(
    () => mockNostr.subscribe(any()),
  ).thenAnswer((_) => const Stream<Event>.empty());

  // Stub queryEvents() to return empty list (never null) so
  // FollowRepository getFollowers/getMyFollowers do not get
  // type 'Null' is not a subtype of type 'Future<List<String>>'
  when(() => mockNostr.queryEvents(any())).thenAnswer((_) async => <Event>[]);

  // Stub publicKey with empty string default so tests that access it
  // do not get type 'Null' is not a subtype of type 'String'
  when(() => mockNostr.publicKey).thenReturn('');

  // Stub ready with a future that never completes so tests that await client
  // initialization do not get type 'Null' is not a subtype of type
  // 'Future<void>'. Tests that need the ready transition should override this
  // in their own setUp via Completer<void>.future.
  when(() => mockNostr.ready).thenAnswer((_) => Completer<void>().future);
  // Match the stubbed `ready` (a Completer that never completes): the
  // synchronous gate isReadyResolved reads isCompleted on the same
  // completer, so it must be false by default. Tests that exercise the
  // "settled but hasKeys still false" path override this to true.
  when(() => mockNostr.isReadyResolved).thenReturn(false);
  return mockNostr;
}

/// Creates a properly stubbed MockSubscriptionManager for testing
MockSubscriptionManager createMockSubscriptionManager() {
  final mockSub = MockSubscriptionManager();

  // Stub createSubscription to return a valid subscription id (never null)
  // and immediately call onComplete to simulate empty results.
  when(
    () => mockSub.createSubscription(
      name: any(named: 'name'),
      filters: any(named: 'filters'),
      onEvent: any(named: 'onEvent'),
      onError: any(named: 'onError'),
      onComplete: any(named: 'onComplete'),
      timeout: any(named: 'timeout'),
      priority: any(named: 'priority'),
    ),
  ).thenAnswer((invocation) async {
    // Call onComplete callback if provided to signal subscription finished
    final onComplete =
        invocation.namedArguments[const Symbol('onComplete')] as Function()?;
    if (onComplete != null) {
      // Use Future.microtask to call after the subscription is "created"
      Future.microtask(onComplete);
    }
    return 'mock_subscription_${DateTime.now().millisecondsSinceEpoch}';
  });

  // Stub cancelSubscription to do nothing
  when(() => mockSub.cancelSubscription(any())).thenAnswer((_) async {});

  return mockSub;
}

/// Creates a properly stubbed MockBlossomAuthService for testing
///
/// This mock avoids the 15-minute cleanup timer that the real service creates.
MockBlossomAuthService createMockBlossomAuthService() {
  final mockBlossom = MockBlossomAuthService();

  // Stub common methods - use named parameters
  when(
    () => mockBlossom.createGetAuthHeader(
      sha256Hash: any(named: 'sha256Hash'),
      serverUrl: any(named: 'serverUrl'),
    ),
  ).thenAnswer((_) async => null);

  return mockBlossom;
}

/// Creates a properly stubbed MockMediaCacheManager for testing
MockMediaCacheManager createMockMediaCacheManager() {
  final mockCache = MockMediaCacheManager();

  // Stub common methods to return null (cache miss)
  when(() => mockCache.getCachedFileSync(any())).thenReturn(null);
  // Note: downloadFile is not stubbed because it returns non-nullable
  // FileInfo. The FullscreenFeedBloc uses unawaited() for background
  // caching, so this won't block tests. If a test needs it, stub with
  // a real FileInfo mock.

  return mockCache;
}

/// Creates a properly stubbed MockProfileRepository for testing
MockProfileRepository createMockProfileRepository() {
  final mockRepo = MockProfileRepository();

  when(
    () => mockRepo.getCachedProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);
  when(
    () => mockRepo.fetchFreshProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);
  when(() => mockRepo.isConfirmedMissing(any())).thenReturn(false);
  when(
    () => mockRepo.watchProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) => Stream.value(null));
  // Surfaces that show counts read `profile_statistics` rather than the
  // profile, so anything pumping them needs this stubbed or the provider
  // throws `MissingStubError` before the widget builds.
  when(
    () => mockRepo.watchProfileStats(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) => Stream.value(null));

  return mockRepo;
}

/// Creates a properly stubbed MockNip05VerificationService for testing
MockNip05VerificationService createMockNip05VerificationService() {
  final mockService = MockNip05VerificationService();

  when(() => mockService.getCachedStatus(any())).thenReturn(null);
  when(
    () => mockService.getVerificationStatus(any(), any()),
  ).thenAnswer((_) async => Nip05VerificationStatus.none);
  when(() => mockService.addListener(any())).thenReturn(null);
  when(() => mockService.removeListener(any())).thenReturn(null);

  return mockService;
}

/// Creates a properly stubbed MockFollowRepository for testing
///
/// Stubs all getters and the [watchMyFollowingCached] stream so widgets that
/// embed [VideoFollowButton] do not crash with [LateInitializationError] from
/// the real [CacheSync] DAO.
MockFollowRepository createMockFollowRepository({
  List<String> followingPubkeys = const [],
}) {
  final mock = MockFollowRepository();

  when(() => mock.followingPubkeys).thenReturn(followingPubkeys);
  when(() => mock.isInitialized).thenReturn(true);
  when(() => mock.followingCount).thenReturn(followingPubkeys.length);
  when(
    () => mock.followingStream,
  ).thenAnswer((_) => Stream.value(followingPubkeys));
  when(() => mock.isFollowing(any())).thenReturn(false);
  when(
    mock.watchMyFollowingCached,
  ).thenAnswer((_) => const Stream<CacheResult<FollowingSnapshot>>.empty());
  when(
    () => mock.watchOthersFollowingCached(
      any(),
      forceRefresh: any(named: 'forceRefresh'),
    ),
  ).thenAnswer((_) => const Stream<CacheResult<FollowingSnapshot>>.empty());

  return mock;
}

/// Creates a properly stubbed MockModerationLabelService for testing
///
/// This mock avoids the real NIP-05 HTTP call that
/// `ModerationLabelService.initialize()` triggers via `Nip05Validor.getPubkey`,
/// which creates pending Dio timers that break `pumpAndSettle`.
MockModerationLabelService createMockModerationLabelService() {
  final mock = MockModerationLabelService();

  when(
    () => mock.divineModerationPubkeyHex,
  ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
  when(() => mock.subscribedLabelers).thenReturn({});
  when(() => mock.isDivineLabelerSubscribed).thenReturn(false);
  when(() => mock.customLabelers).thenReturn({});
  when(() => mock.isFollowingModerationEnabled).thenReturn(false);
  when(mock.initialize).thenAnswer((_) async {});
  when(() => mock.getContentWarnings(any())).thenReturn([]);
  when(() => mock.getContentWarningsByAddressableId(any())).thenReturn([]);
  when(() => mock.getContentWarningsByHash(any())).thenReturn([]);
  when(() => mock.getLabelsForPubkey(any())).thenReturn([]);
  when(() => mock.getAIDetectionResult(any())).thenReturn(null);
  when(() => mock.getAIDetectionByHash(any())).thenReturn(null);
  when(() => mock.hasContentWarning(any())).thenReturn(false);
  when(() => mock.subscribeToLabeler(any())).thenAnswer((_) async {});
  when(() => mock.addLabeler(any())).thenAnswer((_) async {});
  when(() => mock.removeLabeler(any())).thenAnswer((_) async {});
  when(
    () => mock.setFollowingModerationEnabled(
      any(),
      followedPubkeys: any(named: 'followedPubkeys'),
    ),
  ).thenAnswer((_) async {});
  when(() => mock.syncFollowedLabelers(any())).thenAnswer((_) async {});

  return mock;
}

MockVideoEventService createMockVideoEventService() {
  return MockVideoEventService();
}

/// Standard provider overrides that fix most ProviderException failures
List<dynamic> getStandardTestOverrides({
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  AnalyticsService? analyticsService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ProfileRepository? mockProfileRepository,
  Nip05VerificationService? mockNip05VerificationService,
  ModerationLabelService? mockModerationLabelService,
  FollowRepository? mockFollowRepository,
}) {
  final mockPrefs = mockSharedPreferences ?? createMockSharedPreferences();
  final mockAuth = mockAuthService ?? createMockAuthService();
  if (mockAuthService != null) {
    _stubSessionCleanupRegistration(mockAuth);
  }
  final mockNostr = mockNostrService ?? createMockNostrService();
  final mockSub = mockSubscriptionManager ?? createMockSubscriptionManager();
  final mockBlossom = mockBlossomAuthService ?? createMockBlossomAuthService();
  final mockCache = mockMediaCacheManager ?? createMockMediaCacheManager();
  final mockProfile = mockProfileRepository ?? createMockProfileRepository();
  final mockNip05 =
      mockNip05VerificationService ?? createMockNip05VerificationService();
  final mockModeration =
      mockModerationLabelService ?? createMockModerationLabelService();
  final mockFollow = mockFollowRepository ?? createMockFollowRepository();

  return [
    // Mirror DeviceScope's required bootstrap overrides for test containers.
    appVersionProvider.overrideWithValue('test'),
    documentsPathProvider.overrideWithValue('/documents'),
    // Analytics has its own focused tests. Other widget tests must not create
    // its transport, timers, or session listeners as an incidental side effect.
    analyticsServiceProvider.overrideWithValue(
      analyticsService ?? TestAnalyticsService(),
    ),
    // Override sharedPreferencesProvider which throws in production
    sharedPreferencesProvider.overrideWithValue(mockPrefs),

    // Always override NostrClient and SubscriptionManager with stubbed mocks
    // so FollowRepository never gets null Stream<Event> or
    // Future<List<String>>.
    nostrServiceProvider.overrideWithValue(mockNostr),
    subscriptionManagerProvider.overrideWithValue(mockSub),

    // Always override BlossomAuthService to avoid 15-minute cleanup timer
    blossomAuthServiceProvider.overrideWithValue(mockBlossom),

    // Always override MediaCacheManager for PooledFullscreenVideoFeedScreen
    mediaCacheProvider.overrideWithValue(mockCache),

    // Always override ModerationLabelService to avoid NIP-05 HTTP calls
    // from initialize() → _resolveModerationPubkey() → Nip05Validor.getPubkey
    moderationLabelServiceProvider.overrideWithValue(mockModeration),

    // Override NIP-05 verification service to avoid opening Drift/SQLite in
    // widget tests that only care about badge presence, not verification.
    nip05VerificationServiceProvider.overrideWithValue(mockNip05),

    // Always override FollowRepository to prevent LateInitializationError from
    // CacheSync._dao (uninitialized Drift DAO) when VideoFollowButton calls
    // MyFollowingBloc which calls watchMyFollowingCached().
    followRepositoryProvider.overrideWithValue(mockFollow),

    // Always override the NIP-62 vanish lookup. It reads the Drift database,
    // which widget tests do not wire, and the inbox surfaces watch it on every
    // build. Tests that exercise the deleted-account treatment override it
    // again with `additionalOverrides`.
    profileVanishedProvider.overrideWith((ref, pubkey) => false),
    profileVanishedSnapshotProvider.overrideWith((ref, pubkey) async => false),
    // Existing widget fixtures provide profiles through their original
    // reactive/one-shot provider. Keep the new derived loading signal settled
    // by default; loading-specific tests override this provider explicitly.
    profileIdentityResolvingProvider.overrideWith((ref, pubkey) => false),

    // ONLY override other service providers if explicitly requested
    if (mockAuthService != null)
      authServiceProvider.overrideWithValue(mockAuth),
    if (mockProfileRepository != null) ...[
      profileRepositoryProvider.overrideWithValue(mockProfile),
      // Display code reads the identity-known-gated handle, not the
      // relay-gated one (#6423). ProfileRepository implements ProfileReader,
      // so the same mock serves both; overriding only the tight provider
      // leaves every profile read resolving to null.
      profileReadRepositoryProvider.overrideWithValue(mockProfile),
    ],
  ];
}

/// Widget wrapper that provides all necessary provider overrides for testing
///
/// Use this instead of raw ProviderScope in widget tests to avoid
/// ProviderException.
///
/// Example:
/// ```dart
/// testWidgets('my test', (tester) async {
///   await tester.pumpWidget(
///     testProviderScope(
///       child: MyWidget(),
///     ),
///   );
/// });
/// ```
Widget testProviderScope({
  required Widget child,
  List<dynamic>? additionalOverrides,
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  AnalyticsService? analyticsService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ProfileRepository? mockProfileRepository,
  Nip05VerificationService? mockNip05VerificationService,
  ModerationLabelService? mockModerationLabelService,
  FollowRepository? mockFollowRepository,
  VideoEventService? mockVideoEventService,
}) {
  return ProviderScope(
    overrides: [
      ...getStandardTestOverrides(
        mockSharedPreferences: mockSharedPreferences,
        mockAuthService: mockAuthService,
        analyticsService: analyticsService,
        mockNostrService: mockNostrService,
        mockSubscriptionManager: mockSubscriptionManager,
        mockBlossomAuthService: mockBlossomAuthService,
        mockMediaCacheManager: mockMediaCacheManager,
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        mockModerationLabelService: mockModerationLabelService,
        mockFollowRepository: mockFollowRepository,
      ),
      if (!_overridesProvider(additionalOverrides, videoEventServiceProvider))
        videoEventServiceProvider.overrideWithValue(
          mockVideoEventService ?? createMockVideoEventService(),
        ),
      ...?additionalOverrides,
    ],
    child: child,
  );
}

bool _overridesProvider(List<dynamic>? overrides, Object provider) {
  final providerPrefix = '$provider.';
  return overrides?.any((override) => '$override'.startsWith(providerPrefix)) ??
      false;
}

/// MaterialApp wrapper with provider overrides for widget tests
///
/// Use this for tests that need both MaterialApp and ProviderScope.
///
/// Example:
/// ```dart
/// testWidgets('my test', (tester) async {
///   await tester.pumpWidget(
///     testMaterialApp(
///       home: MyScreen(),
///     ),
///   );
/// });
/// ```
Widget testMaterialApp({
  Widget? home,
  Map<String, WidgetBuilder>? routes,
  String? initialRoute,
  List<dynamic>? additionalOverrides,
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  AnalyticsService? analyticsService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ProfileRepository? mockProfileRepository,
  Nip05VerificationService? mockNip05VerificationService,
  ModerationLabelService? mockModerationLabelService,
  FollowRepository? mockFollowRepository,
  VideoEventService? mockVideoEventService,
  ThemeData? theme,
  Locale? locale,
}) {
  return testProviderScope(
    additionalOverrides: additionalOverrides,
    mockSharedPreferences: mockSharedPreferences,
    mockAuthService: mockAuthService,
    analyticsService: analyticsService,
    mockNostrService: mockNostrService,
    mockSubscriptionManager: mockSubscriptionManager,
    mockBlossomAuthService: mockBlossomAuthService,
    mockMediaCacheManager: mockMediaCacheManager,
    mockProfileRepository: mockProfileRepository,
    mockNip05VerificationService: mockNip05VerificationService,
    mockModerationLabelService: mockModerationLabelService,
    mockFollowRepository: mockFollowRepository,
    mockVideoEventService: mockVideoEventService,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      routes: routes ?? {},
      initialRoute: initialRoute,
      theme: theme ?? ThemeData.dark(),
    ),
  );
}
