// ABOUTME: Widget tests for the shell app bar / bottom nav composition
// ABOUTME: Previously only reachable by booting the whole app (#3337)

import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/shell/shell_chrome.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ShellChrome, () {
    late MockAuthService mockAuth;
    late _MockDmUnreadCountCubit dmUnreadCubit;
    late _MockNotificationBadgeCubit notifBadgeCubit;
    late _MockAppUpdateBloc appUpdateBloc;
    late HomeFeedRetapCubit retapCubit;

    setUp(() {
      mockAuth = createMockAuthService();
      dmUnreadCubit = _MockDmUnreadCountCubit();
      notifBadgeCubit = _MockNotificationBadgeCubit();
      appUpdateBloc = _MockAppUpdateBloc();
      retapCubit = HomeFeedRetapCubit();
      whenListen(dmUnreadCubit, const Stream<int>.empty(), initialState: 0);
      whenListen(notifBadgeCubit, const Stream<int>.empty(), initialState: 0);
      when(() => appUpdateBloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.gentle,
          latestVersion: '1.0.21',
          downloadUrl: DownloadUrls.appStore,
        ),
      );
    });

    tearDown(() => retapCubit.close());

    Future<void> pumpChrome(
      WidgetTester tester, {
      required bool suppressAppBar,
      String title = 'Explore',
      RouteContext? routeContext,
      bool showBackButton = false,
      VoidCallback? onBackPressed,
      int currentIndex = 1,
      bool largeScreenLayout = false,
      Widget branch = const Text('branch content'),
    }) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<DmUnreadCountCubit>.value(value: dmUnreadCubit),
            BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
            BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
            BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
          ],
          child: testProviderScope(
            mockAuthService: mockAuth,
            additionalOverrides: [
              isFeatureEnabledProvider(
                FeatureFlag.largeScreenLayout,
              ).overrideWithValue(largeScreenLayout),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AdaptiveLayoutScope(
                child: ShellChrome(
                  currentIndex: currentIndex,
                  title: title,
                  routeContext: routeContext,
                  suppressAppBar: suppressAppBar,
                  showBackButton: showBackButton,
                  resizeToAvoidBottomInset: true,
                  onBackPressed: onBackPressed ?? () {},
                  child: branch,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('shows the resolved title in the app bar', (tester) async {
        await pumpChrome(tester, suppressAppBar: false);

        expect(
          find.descendant(
            of: find.byType(DiVineAppBar),
            matching: find.text('Explore'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders no app bar for a route that owns its header', (
        tester,
      ) async {
        await pumpChrome(tester, suppressAppBar: true);

        expect(find.byType(DiVineAppBar), findsNothing);
        expect(find.text('branch content'), findsOneWidget);
      });

      testWidgets('keeps the bottom nav even without an app bar', (
        tester,
      ) async {
        await pumpChrome(tester, suppressAppBar: true);

        expect(find.byType(VineBottomNav), findsOneWidget);
      });

      testWidgets('shows an available update on every shell tab', (
        tester,
      ) async {
        for (var index = 0; index < 4; index++) {
          await pumpChrome(tester, suppressAppBar: true, currentIndex: index);

          expect(
            find.text(l10n.updateGentleBanner),
            findsOneWidget,
          );
        }
      });

      testWidgets(
        'leaves the insets the app bar and bottom bar cover out of the branch',
        (tester) async {
          tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          EdgeInsets? branchInsets;
          await pumpChrome(
            tester,
            suppressAppBar: false,
            branch: Builder(
              builder: (context) {
                branchInsets = MediaQuery.viewPaddingOf(context);
                return const SizedBox.expand();
              },
            ),
          );

          // The feed would otherwise pad its caption clear of a home
          // indicator the bottom bar already sits over.
          expect(branchInsets, equals(EdgeInsets.zero));
        },
      );

      testWidgets('hides the back button when the route does not want one', (
        tester,
      ) async {
        await pumpChrome(tester, suppressAppBar: false);

        expect(find.bySemanticsIdentifier('back_button'), findsNothing);
      });
    });

    group('large-screen layout', () {
      void setWindow(WidgetTester tester, Size size) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      Axis navDirection(WidgetTester tester) =>
          tester.widget<VineBottomNav>(find.byType(VineBottomNav)).direction;

      testWidgets('moves the tabs into a leading rail in wide landscape', (
        tester,
      ) async {
        setWindow(tester, const Size(1194, 834));
        await pumpChrome(
          tester,
          suppressAppBar: true,
          largeScreenLayout: true,
        );

        expect(navDirection(tester), equals(Axis.vertical));
        expect(tester.getTopLeft(find.byType(VineBottomNav)).dx, equals(0));
        // Stacked: Home above Explore, in one column.
        final home = tester.getCenter(find.bySemanticsIdentifier('home_tab'));
        final explore = tester.getCenter(
          find.bySemanticsIdentifier('explore_tab'),
        );
        expect(home.dy, lessThan(explore.dy));
        expect(home.dx, equals(explore.dx));
      });

      testWidgets('keeps the bottom bar in portrait', (tester) async {
        setWindow(tester, const Size(834, 1194));
        await pumpChrome(
          tester,
          suppressAppBar: true,
          largeScreenLayout: true,
        );

        expect(navDirection(tester), equals(Axis.horizontal));
      });

      testWidgets('keeps the bottom bar with the flag off', (tester) async {
        setWindow(tester, const Size(1194, 834));
        await pumpChrome(tester, suppressAppBar: true);

        expect(navDirection(tester), equals(Axis.horizontal));
      });

      void setStatusBarColumn(WidgetTester tester) {
        tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 34);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
      }

      testWidgets(
        'moves the tabs into the status bar column in landscape',
        (tester) async {
          setWindow(tester, const Size(951, 669));
          setStatusBarColumn(tester);
          await pumpChrome(
            tester,
            suppressAppBar: true,
            largeScreenLayout: true,
          );

          expect(navDirection(tester), equals(Axis.vertical));
          expect(
            tester.getTopLeft(find.byType(VineBottomNav)).dx,
            equals(951 - 84),
          );
          // Centered on the column's height above the home indicator, clear
          // of the status bar at the top of it.
          final camera = tester.getCenter(
            find.bySemanticsIdentifier('camera_button'),
          );
          expect(camera.dy, moreOrLessEquals((669 - 34) / 2));
        },
      );

      testWidgets(
        'ends the content and the bottom bar tabs at a portrait status bar '
        'column',
        (tester) async {
          setWindow(tester, const Size(466, 678));
          setStatusBarColumn(tester);
          EdgeInsets? branchInsets;
          await pumpChrome(
            tester,
            suppressAppBar: true,
            largeScreenLayout: true,
            branch: Builder(
              builder: (context) {
                branchInsets = MediaQuery.viewPaddingOf(context);
                return const SizedBox.expand();
              },
            ),
          );

          expect(navDirection(tester), equals(Axis.horizontal));
          expect(
            tester.getRect(find.byKey(const ValueKey('shell-branches'))).right,
            equals(466 - 84),
          );
          // The tabs are centered under the content, not under the column.
          expect(
            tester.getCenter(find.bySemanticsIdentifier('camera_button')).dx,
            moreOrLessEquals((466 - 84) / 2),
          );
          expect(branchInsets, equals(EdgeInsets.zero));
        },
      );

      testWidgets(
        'keeps the home indicator inset for the branch beside the tabs in '
        'the column',
        (tester) async {
          setWindow(tester, const Size(951, 669));
          setStatusBarColumn(tester);
          EdgeInsets? branchInsets;
          await pumpChrome(
            tester,
            suppressAppBar: true,
            largeScreenLayout: true,
            branch: Builder(
              builder: (context) {
                branchInsets = MediaQuery.viewPaddingOf(context);
                return const SizedBox.expand();
              },
            ),
          );

          // No bottom bar covers the home indicator, so the branch keeps
          // clear of it; the nav in the column takes the side inset.
          expect(branchInsets, equals(const EdgeInsets.only(bottom: 34)));
        },
      );

      testWidgets('keeps the branch state when a rotation adds the rail', (
        tester,
      ) async {
        setWindow(tester, const Size(834, 1194));
        await pumpChrome(
          tester,
          suppressAppBar: true,
          largeScreenLayout: true,
          branch: const _TapCounter(),
        );
        await tester.tap(find.byType(_TapCounter));
        await tester.pump();
        expect(find.text('taps: 1'), findsOneWidget);

        setWindow(tester, const Size(1194, 834));
        await tester.pump();

        expect(navDirection(tester), equals(Axis.vertical));
        expect(find.text('taps: 1'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('runs the back policy when the back button is tapped', (
        tester,
      ) async {
        var pressed = 0;
        await pumpChrome(
          tester,
          suppressAppBar: false,
          showBackButton: true,
          onBackPressed: () => pressed++,
        );

        await tester.tap(find.bySemanticsIdentifier('back_button'));
        await tester.pump();

        expect(pressed, equals(1));
      });
    });
  });
}

/// Branch content that remembers how often it was tapped, to tell whether a
/// layout change rebuilt the branch.
class _TapCounter extends StatefulWidget {
  const _TapCounter();

  @override
  State<_TapCounter> createState() => _TapCounterState();
}

class _TapCounterState extends State<_TapCounter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _taps++),
    child: Text('taps: $_taps'),
  );
}
