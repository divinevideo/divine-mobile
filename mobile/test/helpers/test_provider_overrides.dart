// ABOUTME: Centralized provider overrides for widget tests to fix ProviderException failures
// ABOUTME: Provides mock implementations of all providers that throw UnimplementedError in production

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/subscription_manager.dart';

// Generate mocks for test dependencies
@GenerateMocks([
  SharedPreferences,
  SocialService,
  AuthService,
  INostrService,
  UserProfileService,
  SubscriptionManager,
])
import 'test_provider_overrides.mocks.dart';

/// Creates a properly stubbed MockSharedPreferences for testing
MockSharedPreferences createMockSharedPreferences() {
  final mockPrefs = MockSharedPreferences();

  // Stub all FeatureFlag methods to return sensible defaults
  for (final flag in FeatureFlag.values) {
    when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
    when(
      mockPrefs.setBool('ff_${flag.name}', any),
    ).thenAnswer((_) async => true);
    when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
    when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
  }

  // Add common SharedPreferences stubs that tests might need
  when(mockPrefs.getString(any)).thenReturn(null);
  when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
  when(mockPrefs.getInt(any)).thenReturn(null);
  when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
  when(mockPrefs.getStringList(any)).thenReturn(null);
  when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
  when(mockPrefs.remove(any)).thenAnswer((_) async => true);
  when(mockPrefs.clear()).thenAnswer((_) async => true);

  return mockPrefs;
}

/// Creates a properly stubbed MockAuthService for testing
MockAuthService createMockAuthService() {
  final mockAuth = MockAuthService();

  // Stub common auth methods with sensible defaults
  when(mockAuth.isAuthenticated).thenReturn(false);
  when(mockAuth.currentPublicKeyHex).thenReturn(null);

  return mockAuth;
}

/// Creates a properly stubbed MockSocialService for testing
MockSocialService createMockSocialService() {
  final mockSocial = MockSocialService();

  // Stub common methods to return empty results by default
  when(
    mockSocial.getFollowerStats(any),
  ).thenAnswer((_) async => {'followers': 0, 'following': 0});
  when(mockSocial.getUserVideoCount(any)).thenAnswer((_) async => 0);

  return mockSocial;
}

/// Creates a properly stubbed MockUserProfileService for testing
MockUserProfileService createMockUserProfileService() {
  final mockProfile = MockUserProfileService();

  // Stub common methods
  when(mockProfile.getCachedProfile(any)).thenReturn(null);
  when(mockProfile.fetchProfile(any)).thenAnswer((_) async => null);

  return mockProfile;
}

/// Creates a properly stubbed MockINostrService for testing
MockINostrService createMockNostrService() {
  final mockNostr = MockINostrService();

  // Stub common properties
  when(mockNostr.isInitialized).thenReturn(true);
  when(mockNostr.connectedRelayCount).thenReturn(1);

  return mockNostr;
}

/// Creates a properly stubbed MockSubscriptionManager for testing
MockSubscriptionManager createMockSubscriptionManager() {
  final mockSub = MockSubscriptionManager();

  // Stub common methods - subscriptions return empty streams by default

  return mockSub;
}

/// Standard provider overrides that fix most ProviderException failures
List<dynamic> getStandardTestOverrides({
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  SocialService? mockSocialService,
  UserProfileService? mockUserProfileService,
  INostrService? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
}) {
  final mockPrefs = mockSharedPreferences ?? createMockSharedPreferences();
  final mockAuth = mockAuthService ?? createMockAuthService();
  final mockSocial = mockSocialService ?? createMockSocialService();
  final mockProfile = mockUserProfileService ?? createMockUserProfileService();
  final mockNostr = mockNostrService ?? createMockNostrService();
  final mockSub = mockSubscriptionManager ?? createMockSubscriptionManager();

  return [
    // Override sharedPreferencesProvider which throws in production
    sharedPreferencesProvider.overrideWithValue(mockPrefs),

    // ONLY override service providers if explicitly requested
    // Many tests provide their own service mocks, so don't override by default
    if (mockAuthService != null)
      authServiceProvider.overrideWithValue(mockAuth),
    if (mockSocialService != null)
      socialServiceProvider.overrideWithValue(mockSocial),
    if (mockUserProfileService != null)
      userProfileServiceProvider.overrideWithValue(mockProfile),
    if (mockNostrService != null)
      nostrServiceProvider.overrideWithValue(mockNostr),
    if (mockSubscriptionManager != null)
      subscriptionManagerProvider.overrideWithValue(mockSub),
  ];
}

/// Widget wrapper that provides all necessary provider overrides for testing
///
/// Use this instead of raw ProviderScope in widget tests to avoid ProviderException.
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
  SocialService? mockSocialService,
  UserProfileService? mockUserProfileService,
  INostrService? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
}) {
  return ProviderScope(
    overrides: [
      ...getStandardTestOverrides(
        mockSharedPreferences: mockSharedPreferences,
        mockAuthService: mockAuthService,
        mockSocialService: mockSocialService,
        mockUserProfileService: mockUserProfileService,
        mockNostrService: mockNostrService,
        mockSubscriptionManager: mockSubscriptionManager,
      ),
      ...?additionalOverrides,
    ],
    child: child,
  );
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
  SocialService? mockSocialService,
  UserProfileService? mockUserProfileService,
  INostrService? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  ThemeData? theme,
}) {
  return testProviderScope(
    additionalOverrides: additionalOverrides,
    mockSharedPreferences: mockSharedPreferences,
    mockAuthService: mockAuthService,
    mockSocialService: mockSocialService,
    mockUserProfileService: mockUserProfileService,
    mockNostrService: mockNostrService,
    mockSubscriptionManager: mockSubscriptionManager,
    child: MaterialApp(
      home: home,
      routes: routes ?? {},
      initialRoute: initialRoute,
      theme: theme ?? ThemeData.dark(),
    ),
  );
}
