// ABOUTME: Tests the large-screen layout classes and the orientation policy
// ABOUTME: the adaptive layout scope applies with the flag on

import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/large_screen_orientation_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _duoInnerPortrait = Size(669, 951);
const _duoInnerLandscape = Size(951, 669);
const _phone = Size(402, 874);
const _duoOuter = Size(466, 678);
const _tabletLandscape = Size(1280, 800);

void main() {
  group(AdaptiveLayout, () {
    group('isLargeScreen', () {
      test('is off with the flag off, however wide the window', () {
        const layout = AdaptiveLayout(enabled: false, size: Size(1376, 1032));

        expect(layout.isLargeScreen, isFalse);
      });

      test('is on from the large breakpoint with the flag on', () {
        expect(
          const AdaptiveLayout(enabled: true, size: _phone).isLargeScreen,
          isFalse,
        );
        expect(
          const AdaptiveLayout(
            enabled: true,
            size: _duoInnerPortrait,
          ).isLargeScreen,
          isTrue,
        );
      });
    });

    group('isWideLandscape', () {
      test('needs a window both wide and wider than tall', () {
        expect(
          const AdaptiveLayout(
            enabled: true,
            size: _duoInnerLandscape,
          ).isWideLandscape,
          isTrue,
        );
        // An iPad 13" in portrait is wide, but taller than wide.
        expect(
          const AdaptiveLayout(
            enabled: true,
            size: Size(1032, 1376),
          ).isWideLandscape,
          isFalse,
        );
        // Wider than tall, but narrower than the wide breakpoint.
        expect(
          const AdaptiveLayout(
            enabled: true,
            size: Size(800, 402),
          ).isWideLandscape,
          isFalse,
        );
      });

      test('is off with the flag off', () {
        expect(
          const AdaptiveLayout(
            enabled: false,
            size: _duoInnerLandscape,
          ).isWideLandscape,
          isFalse,
        );
      });
    });

    group('statusBarColumn', () {
      const layout = AdaptiveLayout(enabled: true, size: Size(466, 678));

      test('finds the iPhone Duo status bar down the right edge', () {
        expect(
          layout.statusBarColumn(const EdgeInsets.only(right: 84, bottom: 34)),
          equals((width: 84.0, onRight: true)),
        );
      });

      test('finds it down the left edge', () {
        expect(
          layout.statusBarColumn(const EdgeInsets.only(left: 84)),
          equals((width: 84.0, onRight: false)),
        );
      });

      test('is none where the status bar runs along the top', () {
        expect(
          layout.statusBarColumn(
            const EdgeInsets.only(top: 82, right: 84, bottom: 34),
          ),
          isNull,
        );
      });

      test('is none for a rounded corner inset', () {
        expect(
          layout.statusBarColumn(const EdgeInsets.only(right: 20)),
          isNull,
        );
      });

      test('is none with the flag off', () {
        const off = AdaptiveLayout(enabled: false, size: Size(466, 678));

        expect(off.statusBarColumn(const EdgeInsets.only(right: 84)), isNull);
      });
    });

    group('gridColumns', () {
      test('keeps the phone count with the flag off', () {
        const layout = AdaptiveLayout(enabled: false, size: Size.zero);

        expect(layout.gridColumns(compact: 3, width: 1300), equals(3));
      });

      test("keeps a grid's own large-window count with the flag off", () {
        const phone = AdaptiveLayout(enabled: false, size: Size(599, 900));
        const tablet = AdaptiveLayout(enabled: false, size: Size(1300, 900));

        expect(
          phone.gridColumns(compact: 2, width: 599, largeColumnsWithoutFlag: 3),
          equals(2),
        );
        expect(
          tablet.gridColumns(
            compact: 2,
            width: 1300,
            largeColumnsWithoutFlag: 3,
          ),
          equals(3),
        );
      });

      test('reads the window, not the grid, with the flag off', () {
        // A 600 pt tablet whose grid is padded below 600 kept its tablet
        // count before the flag existed.
        const layout = AdaptiveLayout(enabled: false, size: Size(600, 960));

        expect(
          layout.gridColumns(
            compact: 2,
            width: 592,
            largeColumnsWithoutFlag: 3,
          ),
          equals(3),
        );
      });

      test("reads the grid's own width with the flag on", () {
        // The side navigation leaves a 1440 pt window's grid under 1200.
        const layout = AdaptiveLayout(enabled: true, size: Size(1440, 900));

        expect(layout.gridColumns(compact: 2, width: 1150), equals(4));
      });

      test('ignores the flag-off count with the flag on', () {
        const layout = AdaptiveLayout(enabled: true, size: Size.zero);

        expect(
          layout.gridColumns(
            compact: 2,
            width: 1300,
            largeColumnsWithoutFlag: 3,
          ),
          equals(5),
        );
      });

      test('adds a column at each breakpoint the grid crosses', () {
        const layout = AdaptiveLayout(enabled: true, size: Size.zero);

        expect(layout.gridColumns(compact: 3, width: 402), equals(3));
        expect(layout.gridColumns(compact: 3, width: 669), equals(4));
        expect(layout.gridColumns(compact: 3, width: 863), equals(5));
        expect(layout.gridColumns(compact: 3, width: 1288), equals(6));
      });
    });
  });

  group(AdaptiveLayoutScope, () {
    late List<List<String>> orientationCalls;
    late List<bool> reportedFlags;

    setUp(() {
      orientationCalls = [];
      reportedFlags = [];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationCalls.add(List<String>.from(call.arguments as List));
        }
        return null;
      });
      messenger.setMockMethodCallHandler(largeScreenLayoutChannel, (
        call,
      ) async {
        if (call.method == 'setEnabled') {
          reportedFlags.add(call.arguments as bool);
        }
        return null;
      });
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(largeScreenLayoutChannel, null);
    });

    Future<void> pumpScope(
      WidgetTester tester, {
      required bool enabled,
      required Size size,
      bool ignoresOrientationLock = false,
      Size? display,
      Widget child = const SizedBox.shrink(),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (display != null) {
        tester.view.display.size = display;
        tester.view.display.devicePixelRatio = 1;
        addTearDown(tester.view.display.reset);
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(enabled),
            ignoresOrientationLockOnLargeScreensProvider.overrideWithValue(
              ignoresOrientationLock,
            ),
          ],
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: AdaptiveLayoutScope(child: child),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('reads as disabled with no scope above', (tester) async {
        late AdaptiveLayout layout;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: _duoInnerLandscape),
            child: Builder(
              builder: (context) {
                layout = context.adaptiveLayout;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(layout.enabled, isFalse);
        expect(layout.isWideLandscape, isFalse);
      });

      testWidgets('publishes the flag and the window size', (tester) async {
        late AdaptiveLayout layout;
        await pumpScope(
          tester,
          enabled: true,
          size: _duoInnerLandscape,
          child: Builder(
            builder: (context) {
              layout = context.adaptiveLayout;
              return const SizedBox.shrink();
            },
          ),
        );

        expect(layout.enabled, isTrue);
        expect(layout.size, equals(_duoInnerLandscape));
        expect(layout.isWideLandscape, isTrue);
      });

      testWidgets(
        'turns the layouts on with the flag off on a large display that '
        'ignores the portrait lock',
        (tester) async {
          late AdaptiveLayout layout;
          await pumpScope(
            tester,
            enabled: false,
            size: _tabletLandscape,
            ignoresOrientationLock: true,
            display: _tabletLandscape,
            child: Builder(
              builder: (context) {
                layout = context.adaptiveLayout;
                return const SizedBox.shrink();
              },
            ),
          );

          expect(layout.enabled, isTrue);
          expect(layout.isWideLandscape, isTrue);
        },
      );

      testWidgets(
        'turns the layouts on for a narrow window on a large display that '
        'ignores the portrait lock',
        (tester) async {
          late AdaptiveLayout layout;
          await pumpScope(
            tester,
            enabled: false,
            size: _phone,
            ignoresOrientationLock: true,
            display: _tabletLandscape,
            child: Builder(
              builder: (context) {
                layout = context.adaptiveLayout;
                return const SizedBox.shrink();
              },
            ),
          );

          expect(layout.enabled, isTrue);
        },
      );

      testWidgets(
        'keeps the layouts off on a phone that ignores the portrait lock',
        (tester) async {
          late AdaptiveLayout layout;
          await pumpScope(
            tester,
            enabled: false,
            size: _phone,
            ignoresOrientationLock: true,
            display: _phone,
            child: Builder(
              builder: (context) {
                layout = context.adaptiveLayout;
                return const SizedBox.shrink();
              },
            ),
          );

          expect(layout.enabled, isFalse);
        },
      );

      testWidgets(
        'keeps the layouts off with the flag off where the portrait lock '
        'holds',
        (tester) async {
          late AdaptiveLayout layout;
          await pumpScope(
            tester,
            enabled: false,
            size: _tabletLandscape,
            display: _tabletLandscape,
            child: Builder(
              builder: (context) {
                layout = context.adaptiveLayout;
                return const SizedBox.shrink();
              },
            ),
          );

          expect(layout.enabled, isFalse);
        },
      );
    });

    group('orientation', () {
      testWidgets('leaves startup portrait lock alone with the flag off', (
        tester,
      ) async {
        await pumpScope(tester, enabled: false, size: _duoInnerPortrait);

        expect(orientationCalls, isEmpty);
      });

      testWidgets('does not request rotation when only the layout is forced', (
        tester,
      ) async {
        await pumpScope(
          tester,
          enabled: false,
          size: _tabletLandscape,
          display: _tabletLandscape,
          ignoresOrientationLock: true,
        );

        expect(orientationCalls, isEmpty);
      });

      testWidgets('allows rotation on a large screen with the flag on', (
        tester,
      ) async {
        await pumpScope(tester, enabled: true, size: _duoInnerPortrait);

        expect(orientationCalls, hasLength(1));
        expect(orientationCalls.single, hasLength(4));
      });

      testWidgets("leaves a phone in startup's portrait with the flag on", (
        tester,
      ) async {
        await pumpScope(tester, enabled: true, size: _phone);

        expect(orientationCalls, isEmpty);
      });

      testWidgets('makes no orientation call for the camera with the flag '
          'off', (tester) async {
        await pumpScope(
          tester,
          enabled: false,
          size: _duoInnerPortrait,
          child: const PortraitOrientationLock(child: SizedBox.shrink()),
        );
        await pumpScope(tester, enabled: false, size: _duoInnerPortrait);

        expect(orientationCalls, isEmpty);
      });

      testWidgets(
        'leaves keeping small screens in portrait to the app delegate on iOS',
        (tester) async {
          // Folding the open iPhone Duo and opening it again: the inner
          // display, the outer one, then the inner one again.
          await pumpScope(tester, enabled: true, size: _duoInnerLandscape);
          await pumpScope(tester, enabled: true, size: _duoOuter);
          await pumpScope(tester, enabled: true, size: _duoInnerLandscape);

          // Never portrait, or iOS would turn the opened Duo to portrait
          // and refuse to turn it back.
          expect(orientationCalls, hasLength(1));
          expect(orientationCalls.single, hasLength(4));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'locks portrait while a $PortraitOrientationLock is mounted',
        (
          tester,
        ) async {
          await pumpScope(
            tester,
            enabled: true,
            size: _duoInnerPortrait,
            child: const PortraitOrientationLock(child: SizedBox.shrink()),
          );

          expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);

          await pumpScope(tester, enabled: true, size: _duoInnerPortrait);

          expect(orientationCalls.last, hasLength(4));
        },
      );

      testWidgets(
        'reports the flag to the app delegate on iOS',
        (tester) async {
          await pumpScope(tester, enabled: true, size: _duoOuter);
          await pumpScope(tester, enabled: true, size: _duoInnerLandscape);
          await pumpScope(tester, enabled: false, size: _duoInnerLandscape);

          expect(reportedFlags, [true, false]);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'reports nothing to the app delegate with the flag off',
        (tester) async {
          await pumpScope(tester, enabled: false, size: _duoInnerLandscape);

          expect(reportedFlags, isEmpty);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'reports a build that turns the flag on by default, with no '
        'override stored',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          tester.view.physicalSize = _duoInnerLandscape;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                buildConfigurationProvider.overrideWithValue(
                  const _LargeScreenLayoutByDefault(),
                ),
              ],
              child: const MediaQuery(
                data: MediaQueryData(size: _duoInnerLandscape),
                child: AdaptiveLayoutScope(child: SizedBox.shrink()),
              ),
            ),
          );

          expect(prefs.containsKey('ff_largeScreenLayout'), isFalse);
          expect(reportedFlags, [true]);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets('reports nothing to an app delegate outside iOS', (
        tester,
      ) async {
        await pumpScope(tester, enabled: true, size: _duoInnerLandscape);

        expect(reportedFlags, isEmpty);
      });

      testWidgets('lets a page pushed over the camera rotate, and locks '
          'portrait again when it pops', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        await pumpScope(
          tester,
          enabled: true,
          size: _duoInnerPortrait,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PortraitOrientationLock(child: SizedBox.expand()),
          ),
        );
        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);

        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
        );
        await tester.pumpAndSettle();

        expect(orientationCalls.last, hasLength(4));

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();

        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
      });

      Future<GlobalKey<NavigatorState>> pumpCamera(WidgetTester tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        await pumpScope(
          tester,
          enabled: true,
          size: _duoInnerPortrait,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PortraitOrientationLock(child: SizedBox.expand()),
          ),
        );
        return navigatorKey;
      }

      testWidgets('lets the editor pushed over the go_router camera rotate', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/camera',
          routes: [
            GoRoute(
              path: '/camera',
              // As the recorder's route builds it.
              pageBuilder: (_, state) => fadeUpwardsPage(
                state: state,
                child: const PortraitOrientationLock(
                  child: SizedBox.expand(),
                ),
              ),
            ),
            GoRoute(
              path: '/editor',
              builder: (_, _) => const SizedBox.expand(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await pumpScope(
          tester,
          enabled: true,
          size: _duoInnerPortrait,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);

        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();

        expect(orientationCalls.last, hasLength(4));

        router.pop();
        await tester.pumpAndSettle();

        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
      });

      testWidgets('keeps portrait while a sheet covers the camera', (
        tester,
      ) async {
        final navigatorKey = await pumpCamera(tester);

        unawaited(
          showModalBottomSheet<void>(
            context: navigatorKey.currentContext!,
            builder: (_) => const SizedBox(height: 200),
          ),
        );
        await tester.pumpAndSettle();

        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
      });

      testWidgets('keeps portrait while a dialog covers the camera', (
        tester,
      ) async {
        final navigatorKey = await pumpCamera(tester);

        unawaited(
          showDialog<void>(
            context: navigatorKey.currentContext!,
            builder: (_) => const SizedBox(height: 200),
          ),
        );
        await tester.pumpAndSettle();

        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
      });

      testWidgets('restores portrait when the flag is turned off', (
        tester,
      ) async {
        await pumpScope(tester, enabled: true, size: _duoInnerPortrait);
        await pumpScope(tester, enabled: false, size: _duoInnerPortrait);

        expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
      });
    });
  });

  group(StatusBarColumnSafeArea, () {
    const outerDisplay = Size(466, 678);
    const contentKey = Key('content');

    Future<void> pumpSafeArea(
      WidgetTester tester, {
      required bool enabled,
      required EdgeInsets padding,
    }) async {
      tester.view.physicalSize = outerDisplay;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
      tester.view.viewPadding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(enabled),
          ],
          child: MediaQuery.fromView(
            view: tester.view,
            child: const AdaptiveLayoutScope(
              child: StatusBarColumnSafeArea(
                child: SizedBox.expand(key: contentKey),
              ),
            ),
          ),
        ),
      );
    }

    Rect content(WidgetTester tester) => tester.getRect(find.byKey(contentKey));

    group('renders', () {
      testWidgets('ends the content before a status bar column', (
        tester,
      ) async {
        await pumpSafeArea(
          tester,
          enabled: true,
          padding: const EdgeInsets.only(right: 84, bottom: 34),
        );

        expect(content(tester), equals(const Rect.fromLTRB(0, 0, 382, 678)));
        expect(
          MediaQuery.paddingOf(tester.element(find.byKey(contentKey))).right,
          equals(0),
        );
      });

      testWidgets('starts the content after a status bar column on the left', (
        tester,
      ) async {
        await pumpSafeArea(
          tester,
          enabled: true,
          padding: const EdgeInsets.only(left: 84, bottom: 34),
        );

        expect(content(tester).left, equals(84));
        expect(content(tester).right, equals(outerDisplay.width));
      });

      testWidgets('leaves a status bar along the top alone', (tester) async {
        await pumpSafeArea(
          tester,
          enabled: true,
          padding: const EdgeInsets.only(top: 62, right: 84, bottom: 34),
        );

        expect(content(tester), equals(Offset.zero & outerDisplay));
      });

      testWidgets('leaves the column alone with the flag off', (tester) async {
        await pumpSafeArea(
          tester,
          enabled: false,
          padding: const EdgeInsets.only(right: 84, bottom: 34),
        );

        expect(content(tester), equals(Offset.zero & outerDisplay));
      });
    });
  });

  group(StatusBarColumnFrame, () {
    const innerDisplay = Size(951, 669);
    const contentKey = Key('content');

    Future<void> pumpFrame(
      WidgetTester tester, {
      required EdgeInsets padding,
      bool enabled = true,
      Widget child = const SizedBox.expand(key: contentKey),
    }) async {
      final fakePadding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
      tester.view.physicalSize = innerDisplay;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = fakePadding;
      tester.view.viewPadding = fakePadding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(enabled),
          ],
          child: MediaQuery.fromView(
            view: tester.view,
            child: Theme(
              data: VineTheme.theme,
              child: AdaptiveLayoutScope(
                child: StatusBarColumnFrame(child: child),
              ),
            ),
          ),
        ),
      );
    }

    Rect content(WidgetTester tester) => tester.getRect(find.byKey(contentKey));

    /// The strips the frame paints in the navigation color.
    Iterable<Rect> navStrips(WidgetTester tester) => tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color == VineTheme.darkColors.nav)
        .map((box) => tester.getRect(find.byWidget(box)))
        .where((rect) => rect.width > 0);

    group('renders', () {
      testWidgets('ends the page before a status bar column, painted in the '
          'navigation color', (tester) async {
        await pumpFrame(
          tester,
          padding: const EdgeInsets.only(right: 84, bottom: 34),
        );

        expect(content(tester), equals(const Rect.fromLTRB(0, 0, 867, 669)));
        expect(navStrips(tester), [const Rect.fromLTRB(867, 0, 951, 669)]);
        final padding = MediaQuery.paddingOf(
          tester.element(find.byKey(contentKey)),
        );
        expect(padding.right, equals(0));
        expect(padding.bottom, equals(34));
      });

      testWidgets('starts the page after a status bar column on the left', (
        tester,
      ) async {
        await pumpFrame(
          tester,
          padding: const EdgeInsets.only(left: 84, bottom: 34),
        );

        expect(content(tester), equals(const Rect.fromLTRB(84, 0, 951, 669)));
        expect(navStrips(tester), [const Rect.fromLTRB(0, 0, 84, 669)]);
      });

      testWidgets('leaves a status bar along the top alone', (tester) async {
        await pumpFrame(
          tester,
          padding: const EdgeInsets.only(top: 82, bottom: 34),
        );

        expect(content(tester), equals(Offset.zero & innerDisplay));
        expect(navStrips(tester), isEmpty);
      });

      testWidgets('leaves the page alone with the flag off', (tester) async {
        await pumpFrame(
          tester,
          enabled: false,
          padding: const EdgeInsets.only(right: 84, bottom: 34),
        );

        expect(content(tester), equals(Offset.zero & innerDisplay));
        expect(navStrips(tester), isEmpty);
        expect(
          MediaQuery.paddingOf(tester.element(find.byKey(contentKey))).right,
          equals(84),
        );
      });
    });

    group('interactions', () {
      testWidgets('keeps the page state when a status bar column appears', (
        tester,
      ) async {
        await pumpFrame(
          tester,
          padding: const EdgeInsets.only(top: 82, bottom: 34),
          child: const _Counter(key: contentKey),
        );
        await tester.tap(find.byKey(contentKey));
        await tester.pump();
        expect(find.text('1'), findsOneWidget);

        await pumpFrame(
          tester,
          padding: const EdgeInsets.only(right: 84, bottom: 34),
          child: const _Counter(key: contentKey),
        );

        expect(content(tester).right, equals(867));
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('keeps the page state when the layouts turn on', (
        tester,
      ) async {
        const padding = EdgeInsets.only(right: 84, bottom: 34);
        await pumpFrame(
          tester,
          enabled: false,
          padding: padding,
          child: const _Counter(key: contentKey),
        );
        await tester.tap(find.byKey(contentKey));
        await tester.pump();

        await pumpFrame(
          tester,
          padding: padding,
          child: const _Counter(key: contentKey),
        );

        expect(content(tester).right, equals(867));
        expect(find.text('1'), findsOneWidget);
      });
    });
  });

  group(StatusBarColumnPageTransitionsBuilder, () {
    testWidgets('keeps a status bar column still while a page slides in', (
      tester,
    ) async {
      const window = Size(951, 669);
      const padding = FakeViewPadding(right: 84, bottom: 34);
      const pageKey = Key('pushed');
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(true),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme.copyWith(
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  for (final platform in TargetPlatform.values)
                    platform: const StatusBarColumnPageTransitionsBuilder(
                      CupertinoPageTransitionsBuilder(),
                    ),
                },
              ),
            ),
            builder: (context, child) => AdaptiveLayoutScope(child: child!),
            home: const SizedBox.expand(),
          ),
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.expand(key: pageKey),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final strips = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color == VineTheme.darkColors.nav)
          .map((box) => tester.getRect(find.byWidget(box)))
          .where((rect) => rect.width > 0);
      // One for each page, both where the column is.
      expect(strips, hasLength(2));
      expect(strips, everyElement(const Rect.fromLTRB(867, 0, 951, 669)));
      final page = tester.getRect(find.byKey(pageKey));
      expect(page.left, inExclusiveRange(0, 867));
      expect(page.width, moreOrLessEquals(867));
    });

    test('keeps the timing of the transition it frames', () {
      const inner = CupertinoPageTransitionsBuilder();
      const framed = StatusBarColumnPageTransitionsBuilder(inner);

      expect(framed.transitionDuration, equals(inner.transitionDuration));
      expect(
        framed.reverseTransitionDuration,
        equals(inner.reverseTransitionDuration),
      );
      expect(framed.delegatedTransition, same(inner.delegatedTransition));
    });
  });

  group('resolveIgnoresOrientationLockOnLargeScreens', () {
    late List<String> calls;

    void answerWith(Future<Object?> Function() answer) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(largeScreenLayoutChannel, (call) {
            calls.add(call.method);
            return answer();
          });
    }

    setUp(() {
      calls = [];
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(largeScreenLayoutChannel, null);
    });

    test(
      'returns the Android activity answer when it ignores the lock',
      () async {
        answerWith(() async => true);

        expect(await resolveIgnoresOrientationLockOnLargeScreens(), isTrue);
        expect(calls, equals(['ignoresOrientationLockOnLargeScreens']));
      },
    );

    test('returns the Android activity answer when the lock holds', () async {
      answerWith(() async => false);

      expect(await resolveIgnoresOrientationLockOnLargeScreens(), isFalse);
      expect(calls, equals(['ignoresOrientationLockOnLargeScreens']));
    });

    test('returns false without asking outside Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answerWith(() async => true);

      expect(await resolveIgnoresOrientationLockOnLargeScreens(), isFalse);
      expect(calls, isEmpty);
    });

    test('returns false when the activity fails to answer', () async {
      answerWith(() async => throw PlatformException(code: 'unavailable'));

      expect(await resolveIgnoresOrientationLockOnLargeScreens(), isFalse);
      expect(calls, equals(['ignoresOrientationLockOnLargeScreens']));
    });

    test('returns false when the activity has no such channel', () async {
      expect(await resolveIgnoresOrientationLockOnLargeScreens(), isFalse);
    });
  });
}

/// Counts its taps, to tell a kept state from a fresh one.
class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _taps++),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('$_taps')),
    ),
  );
}

/// A build that turns the large-screen layouts on by default, as
/// `FF_LARGE_SCREEN_LAYOUT=true` does.
class _LargeScreenLayoutByDefault extends BuildConfiguration {
  const _LargeScreenLayoutByDefault();

  @override
  bool getDefault(FeatureFlag flag) =>
      flag == FeatureFlag.largeScreenLayout || super.getDefault(flag);
}
