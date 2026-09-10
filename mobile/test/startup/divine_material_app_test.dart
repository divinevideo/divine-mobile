import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/startup/divine_material_app.dart';

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockAppearanceCubit extends MockCubit<AppearanceMode>
    implements AppearanceCubit {}

class _RecordingCrashReportingService extends Fake
    implements CrashReportingService {
  final List<String?> reasons = [];

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    reasons.add(reason);
  }
}

GoRouter _shellRouter({required bool withRetiredRoute}) => GoRouter(
  initialLocation: '/home',
  errorBuilder: (_, _) => const Text('not found'),
  routes: <RouteBase>[
    if (withRetiredRoute)
      GoRoute(path: '/retired', builder: (_, _) => const Text('retired')),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => shell,
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          ],
        ),
      ],
    ),
  ],
);

/// A route state the running router cannot decode: its root location is gone
/// and the page pushed on top resolves through the shell (#7869).
Future<RouteInformation> _undecodableState(WidgetTester tester) async {
  final previous = _shellRouter(withRetiredRoute: true);
  addTearDown(previous.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: previous,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  previous.go('/retired');
  await tester.pumpAndSettle();
  // The pushed route never pops, so its future never completes.
  unawaited(previous.push('/home'));
  await tester.pumpAndSettle();
  final state = previous.routeInformationParser.restoreRouteInformation(
    previous.routerDelegate.currentConfiguration,
  );
  await tester.pumpWidget(const SizedBox());
  return state!;
}

void main() {
  group(DivineMaterialApp, () {
    testWidgets('survives a remount whose router state no longer decodes', (
      tester,
    ) async {
      final stale = await _undecodableState(tester);
      final router = _shellRouter(withRetiredRoute: false);
      addTearDown(router.dispose);
      final crashReporting = _RecordingCrashReportingService();
      final localeCubit = _MockLocaleCubit();
      when(() => localeCubit.state).thenReturn(const LocaleState());
      final appearanceCubit = _MockAppearanceCubit();
      when(() => appearanceCubit.state).thenReturn(AppearanceMode.dark);

      Widget app(Key key) => ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          crashReportingServiceProvider.overrideWithValue(crashReporting),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<LocaleCubit>.value(value: localeCubit),
            BlocProvider<AppearanceCubit>.value(value: appearanceCubit),
          ],
          child: DivineMaterialApp(key: key),
        ),
      );

      await tester.pumpWidget(app(const ValueKey(1)));
      await tester.pumpAndSettle();
      // A re-keyed ancestor mounts the Router again over the same GoRouter,
      // which then decodes the state it last reported.
      router.routeInformationProvider.routerReportsNewRouteInformation(stale);
      await tester.pumpWidget(app(const ValueKey(2)));
      await tester.pumpAndSettle();

      expect(find.byType(Navigator), findsWidgets);
      expect(find.text('not found'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/retired',
      );
      expect(tester.takeException(), isNull);
      expect(crashReporting.reasons, [
        'RestorationSafeRouter.parseRouteInformation',
      ]);
    });
  });

  group('PlatformBrightnessStatusBar', () {
    testWidgets('updates the overlay style when platform brightness changes', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

      await tester.pumpWidget(
        const PlatformBrightnessStatusBar(child: SizedBox()),
      );

      SystemUiOverlayStyle overlayStyle() => tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .value;

      expect(overlayStyle(), VineTheme.statusBarStyle);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();

      expect(overlayStyle(), VineTheme.lightStatusBarStyle);
    });
  });
}
