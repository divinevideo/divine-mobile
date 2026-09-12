// ABOUTME: Widget tests for account-bound in-app review orchestration.
// ABOUTME: Ensures an async evaluation cannot survive sign-out.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/app_review/app_review_coordinator.dart';
import 'package:openvine/features/app_review/app_review_coordinator_cubit.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _RecordingReviewPlatform implements AppReviewPlatform {
  int availabilityChecks = 0;
  int requests = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return true;
  }

  @override
  Future<void> requestReview() async {
    requests++;
  }
}

class _ImmediateFrameScheduler implements AppReviewFrameScheduler {
  @override
  Future<bool> waitForStableFrame() async => true;
}

class _NoopAnalytics implements AnalyticsEventSink {
  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AppReviewCoordinator, () {
    testWidgets('does not prompt after the active account signs out', (
      tester,
    ) async {
      const pubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      var authState = AuthState.authenticated;
      String? activePubkey = pubkey;
      final authService = _MockAuthService();
      when(() => authService.authState).thenAnswer((_) => authState);
      when(
        () => authService.currentPublicKeyHex,
      ).thenAnswer((_) => activePubkey);

      final statsController = StreamController<ProfileStats?>();
      addTearDown(statsController.close);
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.watchProfileStats(pubkey: pubkey),
      ).thenAnswer((_) => statsController.stream);

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppEngagementStore.sessionCountKey: 20,
        AppEngagementStore.firstLaunchAtKey: DateTime(
          2026,
        ).millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      final reviewPlatform = _RecordingReviewPlatform();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsEventSinkProvider.overrideWithValue(_NoopAnalytics()),
            appReviewFrameSchedulerProvider.overrideWithValue(
              _ImmediateFrameScheduler(),
            ),
            appReviewPlatformProvider.overrideWithValue(reviewPlatform),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            installSourceProvider.overrideWithValue(InstallSource.playStore),
            profileReadRepositoryProvider.overrideWithValue(profileRepository),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(home: AppReviewCoordinator()),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppReviewCoordinator)),
      );
      container.read(appForegroundProvider.notifier).setForeground(false);
      await tester.pump();
      container.read(appForegroundProvider.notifier).setForeground(true);
      await tester.pump();

      authState = AuthState.unauthenticated;
      activePubkey = null;
      statsController.add(
        ProfileStats(
          pubkey: pubkey,
          videoCount: 50,
          lastUpdated: DateTime(2026, 7, 26),
        ),
      );
      await tester.pumpAndSettle();

      expect(reviewPlatform.availabilityChecks, 0);
      expect(reviewPlatform.requests, 0);
      expect(prefs.getInt('review_prompt_attempted_at_$pubkey'), isNull);
    });
  });
}
