// ABOUTME: Tests that tapping explore tab navigates to grid mode, not feed mode
// ABOUTME: Verifies default explore navigation is /explore (grid) not /explore/0 (feed)

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

import '../helpers/test_provider_overrides.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

void main() {
  group('Explore Tab Tap Navigation Test', () {
    testWidgets(
      'tapping explore tab navigates to /explore (grid mode), not /explore/0',
      (tester) async {
        final container = ProviderContainer(
          overrides: getStandardTestOverrides(),
        );
        addTearDown(container.dispose);

        final dmUnreadCubit = _MockDmUnreadCountCubit();
        whenListen(dmUnreadCubit, const Stream<int>.empty(), initialState: 0);
        final notifBadgeCubit = _MockNotificationBadgeCubit();
        whenListen(notifBadgeCubit, const Stream<int>.empty(), initialState: 0);
        final appUpdateBloc = _MockAppUpdateBloc();
        when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<DmUnreadCountCubit>.value(value: dmUnreadCubit),
              BlocProvider<NotificationBadgeCubit>.value(
                value: notifBadgeCubit,
              ),
              BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
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

        // Start at home
        container.read(goRouterProvider).go(VideoFeedPage.pathForIndex(0));
        await tester.pumpAndSettle();

        expect(
          container
              .read(goRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .toString(),
          equals(VideoFeedPage.pathForIndex(0)),
        );

        // Tap the explore tab through its semantics identifier: the shell's
        // nav is a VineBottomNav inside a Column, not Scaffold.bottomNavigationBar,
        // so there is no BottomNavigationBar.onTap to invoke.
        await tester.tap(find.bySemanticsIdentifier(SemanticIds.exploreTab));
        await tester.pumpAndSettle();

        final exploreLocation = container
            .read(goRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .toString();

        // Unmount before asserting: the shell starts a periodic relay-status
        // timer that outlives the tree and trips the pending-timer check.
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));

        expect(
          exploreLocation,
          equals(ExploreScreen.path),
          reason:
              'Tapping explore tab should navigate to grid mode (/explore), '
              'not feed mode (/explore/0)',
        );
      },
    );
  });
}
