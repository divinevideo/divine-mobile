// ABOUTME: Pins the two app-wide side-effect activation hosts and their split.
// ABOUTME: Root tier runs without the shell; shell tier stays deferred.

import 'dart:async';
import 'dart:io';

import 'package:analytics/analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/relay_list_repository_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/providers/route_normalization_provider.dart';
import 'package:openvine/router/providers/support_route_trail_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/startup/app_side_effects.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProductEventQueue extends Mock implements ProductEventQueue {}

class _EmptySupportRouteTrail extends SupportRouteTrail {
  @override
  List<RouteType> build() => const [];
}

class _RecordingAnalytics implements AnalyticsEventSink {
  final userIds = <String?>[];

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

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

// Full-length Nostr pubkey — never truncated.
const String _pubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  late _MockAuthService authService;
  late StreamController<AuthState> authStates;
  late _RecordingAnalytics analytics;
  late List<String?> crashUserIds;

  setUp(() {
    authStates = StreamController<AuthState>.broadcast();
    addTearDown(authStates.close);

    authService = _MockAuthService();
    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
    when(() => authService.authStateStream)
        .thenAnswer((_) => authStates.stream);

    analytics = _RecordingAnalytics();
    crashUserIds = <String?>[];
  });

  /// Overrides that neutralize everything except the identity mirrors, so a
  /// test observes activation rather than the services behind it.
  List<Override> baseOverrides({
    void Function()? onRelayStatisticsBuilt,
    void Function()? onRelaySetChangeBuilt,
    void Function()? onBlockedFollowReconcilerBuilt,
    void Function()? onNotificationPreferencesSyncBuilt,
    void Function()? onPushNotificationSyncBuilt,
  }) => [
    authServiceProvider.overrideWithValue(authService),
    analyticsIdentityCoordinatorProvider.overrideWithValue(
      AnalyticsIdentityCoordinator(
        analytics: analytics,
        setCrashUserId: (userId) async => crashUserIds.add(userId),
      ),
    ),
    // Root tier, stubbed: neither reaches the identity mirrors under test.
    routeNormalizationProvider.overrideWithValue(null),
    supportRouteTrailProvider.overrideWith(_EmptySupportRouteTrail.new),
    connectivityRelayReconnectProvider.overrideWithValue(
      const Stream<ConnectivityTransition>.empty(),
    ),
    outgoingDmRetryServiceProvider.overrideWithValue(null),
    dmReactionRetryServiceProvider.overrideWithValue(null),
    viewEventRetryServiceProvider.overrideWithValue(null),
    productEventQueueProvider.overrideWithValue(_MockProductEventQueue()),
    profileSaveRetryServiceProvider.overrideWithValue(null),
    zendeskIdentitySyncProvider.overrideWithValue(null),
    supporterRecoveryProvider.overrideWithValue(null),
    // Shell tier. The three that construct real services record instead.
    relayStatisticsBridgeProvider.overrideWith(
      (ref) => onRelayStatisticsBuilt?.call(),
    ),
    relaySetChangeBridgeProvider.overrideWith(
      (ref) => onRelaySetChangeBuilt?.call(),
    ),
    blockedFollowReconcilerProvider.overrideWith(
      (ref) => onBlockedFollowReconcilerBuilt?.call(),
    ),
    relayListDirtyPublishBridgeProvider.overrideWithValue(null),
    contactListDirtyBroadcastBridgeProvider.overrideWithValue(null),
    notificationPreferencesDirtySyncBridgeProvider.overrideWith((ref) {
      onNotificationPreferencesSyncBuilt?.call();
      return (_) {};
    }),
    pushNotificationSyncProvider.overrideWith((ref) {
      onPushNotificationSyncBuilt?.call();
      return null;
    }),
    blocklistSyncBridgeProvider.overrideWithValue(null),
  ];

  group(AppRootSideEffects, () {
    testWidgets(
      'mirrors the restored identity without the bottom-nav shell mounted',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: baseOverrides(),
            child: const AppRootSideEffects(child: SizedBox.shrink()),
          ),
        );
        await tester.pump();

        // The regression this host exists for: before it, both mirrors were
        // activated from AppShell.build(), so every pre-shell crash report and
        // analytics event was anonymous even for a restored identity.
        expect(analytics.userIds, [_pubkey]);
        expect(crashUserIds, [_pubkey]);
      },
    );

    testWidgets('clears the identity on logout', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: const AppRootSideEffects(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      when(() => authService.currentPublicKeyHex).thenReturn(null);
      authStates.add(AuthState.unauthenticated);
      await tester.pump();

      expect(analytics.userIds, [_pubkey, null]);
      expect(crashUserIds, [_pubkey, null]);
    });

    testWidgets('mirrors an identity restored after the first frame', (
      tester,
    ) async {
      // The path the fix actually runs on at the root. This host builds during
      // the first frame, while AuthService.initialize() runs in the post-frame
      // essential startup phase — so auth still reports `checking` here and the
      // restored pubkey arrives on authStateStream, not through the provider's
      // eager branch. The test above covers that eager branch, which is what
      // used to run at shell-mount time.
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: const AppRootSideEffects(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      expect(analytics.userIds, isEmpty);
      expect(crashUserIds, isEmpty);

      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
      authStates.add(AuthState.authenticated);
      await tester.pump();

      expect(analytics.userIds, [_pubkey]);
      expect(crashUserIds, [_pubkey]);
    });

    testWidgets('does not construct the deferred shell-tier services', (
      tester,
    ) async {
      var relayStatistics = false;
      var relaySetChange = false;
      var blockedFollowReconciler = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            onRelayStatisticsBuilt: () => relayStatistics = true,
            onRelaySetChangeBuilt: () => relaySetChange = true,
            onBlockedFollowReconcilerBuilt: () =>
                blockedFollowReconciler = true,
          ),
          child: const AppRootSideEffects(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      // A signed-out launch sits on /welcome with no shell. Activating these
      // there would build videoEventService / followRepository and start a 3s
      // relay-counter timer for a user who has no session yet.
      expect(relayStatistics, isFalse);
      expect(relaySetChange, isFalse);
      expect(blockedFollowReconciler, isFalse);
    });

    testWidgets('owns push lifecycle without the bottom-nav shell', (
      tester,
    ) async {
      var notificationPreferencesSyncBuilds = 0;
      var pushNotificationSyncBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            onNotificationPreferencesSyncBuilt: () {
              notificationPreferencesSyncBuilds += 1;
            },
            onPushNotificationSyncBuilt: () {
              pushNotificationSyncBuilds += 1;
            },
          ),
          child: const AppRootSideEffects(child: SizedBox.shrink()),
        ),
      );

      expect(notificationPreferencesSyncBuilds, 1);
      expect(pushNotificationSyncBuilds, 1);
    });
  });

  group(AppShellSideEffects, () {
    testWidgets('activates the deferred shell-tier services', (tester) async {
      var relayStatistics = false;
      var relaySetChange = false;
      var blockedFollowReconciler = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            onRelayStatisticsBuilt: () => relayStatistics = true,
            onRelaySetChangeBuilt: () => relaySetChange = true,
            onBlockedFollowReconcilerBuilt: () =>
                blockedFollowReconciler = true,
          ),
          child: const AppShellSideEffects(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      expect(relayStatistics, isTrue);
      expect(relaySetChange, isTrue);
      expect(blockedFollowReconciler, isTrue);
    });

    testWidgets('does not own the identity mirrors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: const AppShellSideEffects(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      // The mirrors belong to the root tier alone. Re-adding them here would
      // reintroduce the shell-mount dependency this split removed.
      expect(analytics.userIds, isEmpty);
      expect(crashUserIds, isEmpty);
    });

    testWidgets('does not own root-tier push lifecycle', (tester) async {
      var notificationPreferencesSyncBuilds = 0;
      var pushNotificationSyncBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            onNotificationPreferencesSyncBuilt: () {
              notificationPreferencesSyncBuilds += 1;
            },
            onPushNotificationSyncBuilt: () {
              pushNotificationSyncBuilds += 1;
            },
          ),
          child: const AppShellSideEffects(child: SizedBox.shrink()),
        ),
      );

      expect(notificationPreferencesSyncBuilds, isZero);
      expect(pushNotificationSyncBuilds, isZero);
    });
  });

  group('activation ownership', () {
    // Activating an app-wide side effect from a screen or from the app root
    // directly is what this file replaced: sixteen `ref.watch` calls spread
    // across main.dart and app_shell.dart, each its own undocumented decision
    // about when the effect starts. New ones belong in a host above, where the
    // tier rule is written down and the split is covered by tests.
    const hosts = {'lib/startup/app_side_effects.dart'};
    const activationOnlyProviders = <String>[
      'routeNormalizationProvider',
      'supportRouteTrailProvider',
      'connectivityRelayReconnectProvider',
      'outgoingDmRetryServiceProvider',
      'dmReactionRetryServiceProvider',
      'viewEventRetryServiceProvider',
      'productEventQueueProvider',
      'profileSaveRetryServiceProvider',
      'zendeskIdentitySyncProvider',
      'analyticsIdentitySyncProvider',
      'supporterRecoveryProvider',
      'relayStatisticsBridgeProvider',
      'relaySetChangeBridgeProvider',
      'relayListDirtyPublishBridgeProvider',
      'contactListDirtyBroadcastBridgeProvider',
      'notificationPreferencesDirtySyncBridgeProvider',
      'pushNotificationSyncProvider',
      'blocklistSyncBridgeProvider',
      'blockedFollowReconcilerProvider',
    ];

    for (final path in const [
      'lib/main.dart',
      'lib/router/app_shell.dart',
      'lib/router/routes/shell.dart',
    ]) {
      test('$path activates no app-wide side effect of its own', () {
        final source = File(path).readAsStringSync();

        for (final provider in activationOnlyProviders) {
          expect(
            source,
            isNot(contains('ref.watch($provider)')),
            reason:
                '$path activates $provider directly. App-wide side effects '
                'are activated from AppRootSideEffects or AppShellSideEffects '
                'in ${hosts.single}, which documents why each one starts when '
                'it does.',
          );
        }
      });
    }
  });
}
