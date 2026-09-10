// ABOUTME: Routed regression coverage for the /profile/me placeholder.
// ABOUTME: Verifies the real GoRouter wiring resolves it to the signed-in user.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_list_repository_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  group('ProfileScreenRouter /profile/me redirect', () {
    testWidgets('routes the signed-in user to their indexed profile feed', (
      tester,
    ) async {
      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: syntheticTestPubkey,
      );
      when(() => authService.userRelays).thenReturn(const []);
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
      when(() => authService.isRpcUpgradeInProgress).thenReturn(false);
      final nostrService = createMockNostrService();
      when(() => nostrService.relayStatuses).thenReturn(const {});
      when(
        () => nostrService.relayStatusStream,
      ).thenAnswer((_) => const Stream.empty());
      when(nostrService.getRelayPoolCounters).thenReturn(const {});
      when(() => nostrService.defaultRelayUrl).thenReturn('wss://relay.test');
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(
            mockAuthService: authService,
            mockNostrService: nostrService,
          ),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          relayStatisticsBridgeProvider.overrideWith((ref) {}),
          relaySetChangeBridgeProvider.overrideWith((ref) {}),
          relayListDirtyPublishBridgeProvider.overrideWith((ref) {}),
          contactListDirtyBroadcastBridgeProvider.overrideWith((ref) {}),
          blocklistSyncBridgeProvider.overrideWith((ref) {}),
          blockedFollowReconcilerProvider.overrideWith((ref) {}),
        ],
      );
      await container.read(currentMinorAccountReviewStatusProvider.future);

      final dmUnreadCountCubit = _MockDmUnreadCountCubit();
      when(() => dmUnreadCountCubit.state).thenReturn(0);
      final notificationBadgeCubit = _MockNotificationBadgeCubit();
      when(() => notificationBadgeCubit.state).thenReturn(0);
      final appUpdateBloc = _MockAppUpdateBloc();
      when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());
      final backgroundPublishBloc = _MockBackgroundPublishBloc();
      whenListen(
        backgroundPublishBloc,
        const Stream<BackgroundPublishState>.empty(),
        initialState: const BackgroundPublishState(),
      );
      final peopleListsBloc = _MockPeopleListsBloc();
      whenListen(
        peopleListsBloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<DmUnreadCountCubit>.value(value: dmUnreadCountCubit),
            BlocProvider<NotificationBadgeCubit>.value(
              value: notificationBadgeCubit,
            ),
            BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
            BlocProvider<BackgroundPublishBloc>.value(
              value: backgroundPublishBloc,
            ),
            BlocProvider<PeopleListsBloc>.value(value: peopleListsBloc),
            BlocProvider<HomeFeedRetapCubit>(
              create: (_) => HomeFeedRetapCubit(),
            ),
          ],
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(goRouterProvider);
      router.go(ProfileScreenRouter.pathForIndex('me', 0));
      await tester.pump();
      await tester.pump();

      final actualLocation = router.routeInformationProvider.value.uri
          .toString();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));

      expect(actualLocation, equals('/profile/$syntheticTestNpub/0'));
    });
  });
}
