import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

void main() {
  group('VineBottomNav interaction targets', () {
    late MockAuthService mockAuth;
    late _MockDmUnreadCountCubit dmUnreadCubit;
    late _MockNotificationBadgeCubit notifBadgeCubit;
    late HomeFeedRetapCubit retapCubit;

    setUp(() {
      mockAuth = createMockAuthService();
      dmUnreadCubit = _MockDmUnreadCountCubit();
      notifBadgeCubit = _MockNotificationBadgeCubit();
      retapCubit = HomeFeedRetapCubit();
      whenListen(dmUnreadCubit, const Stream<int>.empty(), initialState: 0);
      whenListen(notifBadgeCubit, const Stream<int>.empty(), initialState: 0);
    });

    tearDown(() => retapCubit.close());

    Widget withBadgeProviders(Widget child) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<DmUnreadCountCubit>.value(value: dmUnreadCubit),
          BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
          BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
        ],
        child: child,
      );
    }

    Future<void> pumpSubject(WidgetTester tester) async {
      await tester.pumpWidget(
        withBadgeProviders(
          testProviderScope(
            mockAuthService: mockAuth,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VineBottomNav(currentIndex: 0)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> pumpReducedMotionSubject(WidgetTester tester) async {
      await tester.pumpWidget(
        withBadgeProviders(
          testProviderScope(
            mockAuthService: mockAuth,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: Scaffold(body: VineBottomNav(currentIndex: 0)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> pumpSubjectWithRouter(
      WidgetTester tester,
      MockGoRouter router,
    ) async {
      await tester.pumpWidget(
        withBadgeProviders(
          testProviderScope(
            mockAuthService: mockAuth,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MockGoRouterProvider(
                goRouter: router,
                child: const Scaffold(body: VineBottomNav(currentIndex: 0)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('icon and profile tabs have minimum interactive dimensions', (
      tester,
    ) async {
      await pumpSubject(tester);

      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where(
            (box) =>
                box.width == kMinInteractiveDimension &&
                box.height == kMinInteractiveDimension,
          )
          .toList();

      expect(sizedBoxes, hasLength(4));
    });

    testWidgets('all five tabs use opaque gesture hit behavior', (
      tester,
    ) async {
      await pumpSubject(tester);

      final opaqueDetectors = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .where((detector) => detector.behavior == HitTestBehavior.opaque)
          .toList();

      // Home / Explore / Camera / Inbox / Profile — each owns an opaque
      // GestureDetector that fills its slice of the row so taps in the
      // surrounding gap also route to the right tab.
      expect(opaqueDetectors, hasLength(5));
    });

    testWidgets(
      'shows the refresh arrow when mounted while a home retap refresh is '
      'already active',
      (tester) async {
        retapCubit.request();

        await pumpReducedMotionSubject(tester);

        final arrowOpacity = tester.widget<Opacity>(
          find.byWidgetPredicate((widget) {
            if (widget is! Opacity) return false;
            final scale = widget.child;
            if (scale is! Transform) return false;
            final rotate = scale.child;
            if (rotate is! Transform) return false;
            final icon = rotate.child;
            return icon is DivineIcon &&
                icon.icon == DivineIconName.arrowClockwise;
          }),
        );
        expect(arrowOpacity.opacity, 1);
      },
    );

    testWidgets(
      'tapping the top-left corner of the home-tab hit target triggers the '
      'home retap refresh',
      (tester) async {
        final router = MockGoRouter();

        await pumpSubjectWithRouter(tester, router);

        final rect = tester.getRect(find.bySemanticsIdentifier('home_tab'));
        // Tap 2 px inside the top-left corner — the hit target must respond
        // here, not just at the centre where the icon is drawn. Home is the
        // active tab, so the tap requests a feed refresh instead of
        // navigating.
        await tester.tapAt(rect.topLeft + const Offset(2, 2));
        await tester.pump();

        expect(retapCubit.state.isRefreshing, isTrue);
        verifyNever(() => router.go(any()));
      },
    );

    testWidgets(
      'tab hit targets divide the inter-icon gap so taps just past an '
      'icon still route to that tab',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final homeRect = tester.getRect(find.bySemanticsIdentifier('home_tab'));
        final exploreRect = tester.getRect(
          find.bySemanticsIdentifier('explore_tab'),
        );

        // The two slots must touch (no dead zone between them).
        expect(homeRect.right, exploreRect.left);
        // And each must be wider than the bare 48 px icon container —
        // otherwise the gap was not absorbed.
        expect(homeRect.width, greaterThan(kMinInteractiveDimension));
        expect(exploreRect.width, greaterThan(kMinInteractiveDimension));

        // Tap inside the home slot, just to the right of the home icon
        // (i.e. inside the inter-icon half-gap, not on the icon itself).
        // Home is the active tab, so the tap requests a feed refresh.
        final justPastHomeIcon = Offset(
          homeRect.left + kMinInteractiveDimension + 1,
          homeRect.center.dy,
        );
        await tester.tapAt(justPastHomeIcon);
        await tester.pump();

        expect(retapCubit.state.isRefreshing, isTrue);
        verifyNever(() => router.go(any()));
      },
    );

    testWidgets(
      'tab hit targets extend above the icon row so taps in the strip '
      'above the icons still route to the tab below',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final homeRect = tester.getRect(find.bySemanticsIdentifier('home_tab'));

        // The slot is taller than a bare 48 px icon container — extra
        // height above the icon is part of the hit target.
        expect(homeRect.height, greaterThan(kMinInteractiveDimension));

        // Tap 2 px below the slot's top edge — well above where the
        // icon is drawn. The strip above the icon container is part of
        // the slot, not dead space. Home is the active tab, so the tap
        // requests a feed refresh.
        await tester.tapAt(homeRect.topLeft + const Offset(8, 2));
        await tester.pump();

        expect(retapCubit.state.isRefreshing, isTrue);
        verifyNever(() => router.go(any()));
      },
    );

    testWidgets('home and profile slots reach the screen edges so taps in the '
        'edge strip still route to the adjacent tab', (tester) async {
      final router = MockGoRouter();
      await pumpSubjectWithRouter(tester, router);

      final navRect = tester.getRect(find.byType(VineBottomNav));
      final homeRect = tester.getRect(find.bySemanticsIdentifier('home_tab'));
      final profileRect = tester.getRect(
        find.bySemanticsIdentifier('profile_tab'),
      );

      // Outer edges of Home / Profile slots align with the bottom
      // nav's left / right edges — no horizontal dead zone.
      expect(homeRect.left, navRect.left);
      expect(profileRect.right, navRect.right);

      // Tap 2 px in from the screen's left edge — inside the home
      // slot's outer edge inset, not on the icon itself. Home is the
      // active tab, so the tap requests a feed refresh.
      await tester.tapAt(Offset(navRect.left + 2, homeRect.center.dy));
      await tester.pump();

      expect(retapCubit.state.isRefreshing, isTrue);
      verifyNever(() => router.go(any()));
    });

    testWidgets(
      'tab hit targets extend below the icon row so taps in the strip '
      'below the icons still route to the tab above',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final navRect = tester.getRect(find.byType(VineBottomNav));
        final homeRect = tester.getRect(find.bySemanticsIdentifier('home_tab'));

        // The slot's bottom edge meets the bottom nav's bottom edge.
        // (No bottom safe area inset is applied in the test environment,
        // so the two are exactly equal — on real devices [SafeArea]
        // separates them by [MediaQuery.viewPadding.bottom].)
        expect(homeRect.bottom, navRect.bottom);

        // Tap 2 px above the slot's bottom edge — well below where the
        // icon is drawn (the icon is centred in a 72 px slot, so its
        // bottom edge sits 12 px above the slot's bottom). The strip
        // below the icon container is part of the slot. Home is the
        // active tab, so the tap requests a feed refresh.
        await tester.tapAt(Offset(homeRect.center.dx, homeRect.bottom - 2));
        await tester.pump();

        expect(retapCubit.state.isRefreshing, isTrue);
        verifyNever(() => router.go(any()));
      },
    );

    testWidgets('retapping the active home tab is a no-op while a refresh is '
        'already in flight', (tester) async {
      final router = MockGoRouter();
      await pumpSubjectWithRouter(tester, router);

      final rect = tester.getRect(find.bySemanticsIdentifier('home_tab'));
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(retapCubit.state.isRefreshing, isTrue);

      // A second retap while refreshing neither navigates nor restarts
      // the refresh.
      await tester.tapAt(rect.center);
      await tester.pump();

      expect(retapCubit.state.isRefreshing, isTrue);
      verifyNever(() => router.go(any()));
    });
  });
}
