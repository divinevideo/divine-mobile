// ABOUTME: Widget tests for the repository-backed crossposting settings screen.
// ABOUTME: Covers compact platform controls, OAuth feedback, and lifecycle refresh.

import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCrosspostingRepository extends Mock
    implements CrosspostingRepository {}

final _testAuthStateProvider = StateProvider<AuthState>(
  (_) => AuthState.authenticated,
);

class _TestCurrentAuthState extends CurrentAuthState {
  @override
  AuthState build() => ref.watch(_testAuthStateProvider);
}

void main() {
  group(CrosspostingSettingsScreen, () {
    late _MockAuthService authService;
    late _MockCrosspostingRepository repository;
    late AppLocalizations l10n;

    setUpAll(() {
      registerFallbackValue(CrosspostingPlatform.instagram);
      registerFallbackValue(CrosspostingMode.disabled);
      registerFallbackValue(Uri());
    });

    setUp(() {
      authService = _MockAuthService();
      repository = _MockCrosspostingRepository();
      l10n = lookupAppLocalizations(const Locale('en'));
      when(() => authService.currentPublicKeyHex).thenReturn('pubkeyhex');
      when(() => authService.isRegistered).thenReturn(true);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.automatic);
      when(repository.loadSettings).thenAnswer((_) async => _defaultEntries);
    });

    Widget buildApp({
      CrosspostingOAuthLauncher launchOAuth = _cancelOAuth,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      final router = GoRouter(
        initialLocation: CrosspostingSettingsScreen.path,
        routes: [
          GoRoute(
            path: CrosspostingSettingsScreen.path,
            builder: (_, _) => CrosspostingSettingsScreen(
              launchOAuth: launchOAuth,
              nonceGenerator: () => 'test-nonce',
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(_TestCurrentAuthState.new),
          crosspostingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
      );
    }

    testWidgets('shows a localized signed-out state without loading', (
      tester,
    ) async {
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingSignInRequired), findsOneWidget);
      verifyNever(repository.loadSettings);
    });

    testWidgets('requires a Divine OAuth account', (tester) async {
      when(() => authService.isRegistered).thenReturn(false);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingSignInRequired), findsOneWidget);
      verifyNever(repository.loadSettings);
    });

    testWidgets('reacts to mounted sign-out and sign-in transitions', (
      tester,
    ) async {
      String? publicKey = 'first-pubkey';
      when(
        () => authService.currentPublicKeyHex,
      ).thenAnswer((_) => publicKey);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Instagram'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CrosspostingSettingsScreen)),
      );
      publicKey = null;
      container.read(_testAuthStateProvider.notifier).state =
          AuthState.unauthenticated;
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingSignInRequired), findsOneWidget);

      publicKey = 'second-pubkey';
      container.read(_testAuthStateProvider.notifier).state =
          AuthState.authenticated;
      await tester.pumpAndSettle();

      expect(find.text('Instagram'), findsOneWidget);
      verify(repository.loadSettings).called(2);
    });

    testWidgets('shows loading while the repository read is pending', (
      tester,
    ) async {
      final load = Completer<List<CrosspostingPlatformSettings>>();
      when(repository.loadSettings).thenAnswer((_) => load.future);

      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      load.complete(const []);
      await tester.pump();
    });

    testWidgets('renders compact connected, disconnected, and reauth rows', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('TikTok'), findsNothing);
      expect(find.text('divine.creator'), findsOneWidget);
      expect(find.text('old.creator'), findsOneWidget);
      expect(find.text(l10n.crosspostingNotConnected), findsOneWidget);
      expect(find.text(l10n.crosspostingNeedsReconnect), findsOneWidget);
      expect(find.text(l10n.crosspostingDisconnect), findsOneWidget);
      expect(find.text(l10n.crosspostingConnect), findsOneWidget);
      expect(find.text(l10n.crosspostingReconnect), findsOneWidget);
    });

    testWidgets('uses external account ID when a connected name is absent', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => const [
          CrosspostingPlatformSettings(
            platform: CrosspostingPlatform.x,
            supportsAutomatic: true,
            mode: CrosspostingMode.disabled,
            connection: CrosspostingConnection(
              id: 'x-connection',
              platform: CrosspostingPlatform.x,
              status: CrosspostingConnectionStatus.connected,
              externalAccountId: 'external-x-123',
            ),
          ),
        ],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('external-x-123'), findsOneWidget);
    });

    testWidgets('uses localized Connected when account identity is absent', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => const [
          CrosspostingPlatformSettings(
            platform: CrosspostingPlatform.instagram,
            supportsAutomatic: true,
            mode: CrosspostingMode.disabled,
            connection: CrosspostingConnection(
              id: 'nameless-connection',
              platform: CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.connected,
            ),
          ),
        ],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingConnected), findsOneWidget);
      expect(find.text(l10n.crosspostingNotConnected), findsNothing);
    });

    testWidgets('shows all modes and only the selected Manual copy', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => [_connected(mode: CrosspostingMode.manual)],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingModeOff), findsOneWidget);
      expect(find.text(l10n.crosspostingModeManual), findsOneWidget);
      expect(find.text(l10n.crosspostingModeAutomatic), findsOneWidget);
      expect(
        find.text(l10n.crosspostingModeManualSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.crosspostingModeAutomaticSubtitle),
        findsNothing,
      );
    });

    testWidgets('omits Automatic when the platform does not support it', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => [
          _connected(
            platform: CrosspostingPlatform.x,
            supportsAutomatic: false,
          ),
        ],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingModeOff), findsOneWidget);
      expect(find.text(l10n.crosspostingModeManual), findsOneWidget);
      expect(find.text(l10n.crosspostingModeAutomatic), findsNothing);
    });

    testWidgets(
      'clamps stale automatic mode to manual on an unsupported platform',
      (tester) async {
        // The repository guarantees a stale automatic preference degrades to
        // manual before reaching the UI, so the screen surfaces Manual as the
        // selected mode and never offers the unsupported Automatic chip.
        when(repository.loadSettings).thenAnswer(
          (_) async => [
            _connected(
              platform: CrosspostingPlatform.x,
              supportsAutomatic: false,
              mode: CrosspostingMode.manual,
            ),
          ],
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        final manualButton = tester.widget<DivineButton>(
          find.byKey(const ValueKey('crossposting-mode-x-manual')),
        );
        expect(manualButton.type, DivineButtonType.primary);
        expect(find.text(l10n.crosspostingModeManual), findsOneWidget);
        expect(find.text(l10n.crosspostingModeAutomatic), findsNothing);
        expect(
          find.text(l10n.crosspostingModeAutomaticSubtitle),
          findsNothing,
        );
      },
    );

    testWidgets('changes selected copy for Automatic and hides it for Off', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer(
        (_) async => [_connected(mode: CrosspostingMode.manual)],
      );
      when(
        () => repository.setMode(any(), any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('crossposting-mode-instagram-automatic'),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.setMode(
          CrosspostingPlatform.instagram,
          CrosspostingMode.automatic,
        ),
      ).called(1);
      expect(
        find.text(l10n.crosspostingModeAutomaticSubtitle),
        findsOneWidget,
      );
      expect(find.text(l10n.crosspostingModeManualSubtitle), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('crossposting-mode-instagram-disabled')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.crosspostingModeAutomaticSubtitle),
        findsNothing,
      );
      expect(find.text(l10n.crosspostingModeManualSubtitle), findsNothing);
    });

    testWidgets('connect launches OAuth and refreshes the row', (tester) async {
      var loadCount = 0;
      when(repository.loadSettings).thenAnswer((_) async {
        loadCount++;
        return loadCount == 1 ? [_disconnected()] : [_connected()];
      });
      when(
        () => repository.startConnection(
          any(),
          returnUrl: any(named: 'returnUrl'),
        ),
      ).thenAnswer(
        (_) async => CrosspostingStart(
          authorizationUrl: Uri.parse('https://provider.example/oauth'),
          state: 'oauth-state',
        ),
      );
      Uri? launchedUrl;

      await tester.pumpWidget(
        buildApp(
          launchOAuth: (url) async {
            launchedUrl = url;
            return Uri.parse(
              'https://divine.video/app/callback'
              '?app_state=test-nonce'
              '&connection=connected&platform=instagram',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      await tester.pumpAndSettle();

      expect(launchedUrl, Uri.parse('https://provider.example/oauth'));
      verify(
        () => repository.startConnection(
          CrosspostingPlatform.instagram,
          returnUrl: Uri.parse(
            'https://divine.video/app/callback?app_state=test-nonce',
          ),
        ),
      ).called(1);
      expect(find.text(l10n.crosspostingDisconnect), findsOneWidget);
    });

    testWidgets('reconnect uses the same OAuth start flow', (tester) async {
      when(repository.loadSettings).thenAnswer((_) async => [_needsReauth()]);
      when(
        () => repository.startConnection(
          any(),
          returnUrl: any(named: 'returnUrl'),
        ),
      ).thenAnswer(
        (_) async => CrosspostingStart(
          authorizationUrl: Uri.parse('https://provider.example/reauth'),
          state: 'oauth-state',
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-youtube')),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.startConnection(
          CrosspostingPlatform.youtube,
          returnUrl: Uri.parse(
            'https://divine.video/app/callback?app_state=test-nonce',
          ),
        ),
      ).called(1);
    });

    testWidgets('disconnects the current connection and refreshes', (
      tester,
    ) async {
      var loadCount = 0;
      when(repository.loadSettings).thenAnswer((_) async {
        loadCount++;
        return loadCount == 1 ? [_connected()] : [_disconnected()];
      });
      when(
        () => repository.disconnect(any(), any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.disconnect(
          CrosspostingPlatform.instagram,
          'instagram-connection',
        ),
      ).called(1);
      expect(find.text(l10n.crosspostingConnect), findsOneWidget);
    });

    testWidgets('shows a clear empty state when no platforms are enabled', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer((_) async => const []);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingNoPlatforms), findsOneWidget);
    });

    testWidgets('shows load failure and Retry reloads settings', (
      tester,
    ) async {
      var loadCount = 0;
      when(repository.loadSettings).thenAnswer((_) async {
        loadCount++;
        if (loadCount == 1) {
          throw const CrosspostingApiException('down', statusCode: 500);
        }
        return [_disconnected()];
      });

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingLoadFailed), findsOneWidget);
      expect(find.text(l10n.crosspostingGenericError), findsNothing);
      await tester.tap(find.text(l10n.crosspostingRetry));
      await tester.pumpAndSettle();

      expect(find.text('Instagram'), findsOneWidget);
      verify(repository.loadSettings).called(2);
    });

    for (final scenario in <_OutcomeScenario>[
      _OutcomeScenario(
        name: 'connected',
        callbackQuery: 'connection=connected&platform=instagram',
        expectedMessage: (l10n) =>
            l10n.crosspostingConnectionSuccess('Instagram'),
      ),
      _OutcomeScenario(
        name: 'denied',
        callbackQuery:
            'connection=failed&platform=instagram&reason=provider_denied',
        expectedMessage: (l10n) =>
            l10n.crosspostingConnectionDenied('Instagram'),
      ),
      _OutcomeScenario(
        name: 'failed',
        callbackQuery: 'connection=failed&platform=instagram',
        expectedMessage: (l10n) =>
            l10n.crosspostingConnectionFailed('Instagram'),
      ),
    ]) {
      testWidgets('shows and acknowledges ${scenario.name} OAuth outcome', (
        tester,
      ) async {
        when(repository.loadSettings).thenAnswer(
          (_) async => [_disconnected()],
        );
        when(
          () => repository.startConnection(
            any(),
            returnUrl: any(named: 'returnUrl'),
          ),
        ).thenAnswer(
          (_) async => CrosspostingStart(
            authorizationUrl: Uri.parse('https://provider.example/oauth'),
            state: 'oauth-state',
          ),
        );

        await tester.pumpWidget(
          buildApp(
            launchOAuth: (_) async => Uri.parse(
              'https://divine.video/app/callback'
              '?app_state=test-nonce&${scenario.callbackQuery}',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('crossposting-action-instagram')),
        );
        await tester.pumpAndSettle();

        expect(find.text(scenario.expectedMessage(l10n)), findsOneWidget);
      });
    }

    testWidgets('shows and acknowledges a localized action error', (
      tester,
    ) async {
      when(repository.loadSettings).thenAnswer((_) async => [_disconnected()]);
      when(
        () => repository.startConnection(
          any(),
          returnUrl: any(named: 'returnUrl'),
        ),
      ).thenThrow(
        const CrosspostingApiException('down', statusCode: 500),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.crosspostingGenericError), findsOneWidget);
    });

    testWidgets('a new snackbar replaces the current snackbar', (
      tester,
    ) async {
      var startCount = 0;
      when(repository.loadSettings).thenAnswer((_) async => [_disconnected()]);
      when(
        () => repository.startConnection(
          any(),
          returnUrl: any(named: 'returnUrl'),
        ),
      ).thenAnswer((_) async {
        startCount++;
        if (startCount == 2) {
          throw const CrosspostingApiException('down', statusCode: 500);
        }
        return CrosspostingStart(
          authorizationUrl: Uri.parse('https://provider.example/oauth'),
          state: 'oauth-state',
        );
      });

      await tester.pumpWidget(
        buildApp(
          launchOAuth: (_) async => Uri.parse(
            'https://divine.video/app/callback'
            '?app_state=test-nonce'
            '&connection=failed&platform=instagram&reason=provider_denied',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      await tester.pumpAndSettle();
      final denied = l10n.crosspostingConnectionDenied('Instagram');
      expect(find.text(denied), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      await tester.pumpAndSettle();

      expect(find.text(denied), findsNothing);
      expect(find.text(l10n.crosspostingGenericError), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('global busy disables every control and marks pending row', (
      tester,
    ) async {
      final disconnect = Completer<void>();
      when(repository.loadSettings).thenAnswer(
        (_) async => [
          _connected(mode: CrosspostingMode.manual),
          _disconnected(platform: CrosspostingPlatform.x),
        ],
      );
      when(
        () => repository.disconnect(any(), any()),
      ).thenAnswer((_) => disconnect.future);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      await tester.pump();

      final instagramButton = tester.widget<DivineButton>(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      final xButton = tester.widget<DivineButton>(
        find.byKey(const ValueKey('crossposting-action-x')),
      );
      expect(instagramButton.onPressed, isNull);
      expect(instagramButton.isLoading, isTrue);
      expect(xButton.onPressed, isNull);
      expect(xButton.isLoading, isFalse);
      for (final mode in CrosspostingMode.values) {
        final modeButton = tester.widget<DivineButton>(
          find.byKey(
            ValueKey('crossposting-mode-instagram-${mode.wireName}'),
          ),
        );
        expect(modeButton.onPressed, isNull);
      }
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      disconnect.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('resume refresh visibly disables controls until it completes', (
      tester,
    ) async {
      final refreshStarted = Completer<void>();
      final refreshed = Completer<List<CrosspostingPlatformSettings>>();
      var loadCount = 0;
      when(repository.loadSettings).thenAnswer((_) {
        loadCount++;
        if (loadCount == 1) return Future.value(_defaultEntries);
        refreshStarted.complete();
        return refreshed.future;
      });

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      for (final lifecycleState in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycleState);
        await tester.pump();
      }
      await refreshStarted.future;
      await tester.pump();

      final action = tester.widget<DivineButton>(
        find.byKey(const ValueKey('crossposting-action-instagram')),
      );
      final mode = tester.widget<DivineButton>(
        find.byKey(
          const ValueKey('crossposting-mode-instagram-manual'),
        ),
      );
      expect(action.onPressed, isNull);
      expect(mode.onPressed, isNull);

      refreshed.complete(_defaultEntries);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DivineButton>(
              find.byKey(
                const ValueKey('crossposting-action-instagram'),
              ),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('mode save progress stays on the selected mode control', (
      tester,
    ) async {
      final saved = Completer<void>();
      when(repository.loadSettings).thenAnswer(
        (_) async => [_connected(mode: CrosspostingMode.manual)],
      );
      when(
        () => repository.setMode(any(), any()),
      ).thenAnswer((_) => saved.future);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('crossposting-mode-instagram-automatic'),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<DivineButton>(
              find.byKey(
                const ValueKey('crossposting-action-instagram'),
              ),
            )
            .isLoading,
        isFalse,
      );
      expect(
        tester
            .widget<DivineButton>(
              find.byKey(
                const ValueKey(
                  'crossposting-mode-instagram-automatic',
                ),
              ),
            )
            .isLoading,
        isTrue,
      );
      final savingSemantics = tester.getSemantics(
        find.byKey(
          const ValueKey(
            'crossposting-mode-semantics-instagram-automatic',
          ),
        ),
      );
      expect(
        savingSemantics.flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      expect(
        savingSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      saved.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('actions and modes use accessible small tap targets', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      const keys = [
        'crossposting-action-instagram',
        'crossposting-action-x',
        'crossposting-action-youtube',
        'crossposting-mode-instagram-disabled',
        'crossposting-mode-instagram-manual',
        'crossposting-mode-instagram-automatic',
      ];
      for (final key in keys) {
        final finder = find.byKey(ValueKey(key));
        final button = tester.widget<DivineButton>(finder);
        expect(button.size, DivineButtonSize.small, reason: key);
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason: key,
        );
      }

      final semantics = tester.getSemantics(
        find.byKey(
          const ValueKey(
            'crossposting-mode-semantics-instagram-manual',
          ),
        ),
      );
      expect(semantics.label, contains(l10n.crosspostingModeManual));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
      expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('narrow viewport and enlarged text do not overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildApp(textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.crosspostingModeOff), findsOneWidget);
      expect(find.text(l10n.crosspostingModeManual), findsOneWidget);
      expect(find.text(l10n.crosspostingModeAutomatic), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('crossposting-mode-instagram-automatic'),
              ),
            )
            .height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
    });

    testWidgets('loaded state exposes an in-screen refresh action', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, 'Refresh'));
      await tester.pumpAndSettle();

      verify(repository.loadSettings).called(2);
    });

    testWidgets('refreshes settings when the app resumes', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      for (final lifecycleState in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycleState);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      verify(repository.loadSettings).called(2);
    });
  });

  group(GeneralSettingsScreen, () {
    testWidgets('shows Crossposting copy and navigates to its route', (
      tester,
    ) async {
      final authService = _MockAuthService();
      when(() => authService.isRegistered).thenReturn(true);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.automatic);
      when(
        () => authService.currentPublicKeyHex,
      ).thenReturn('pubkeyhex');
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(400, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l10n = lookupAppLocalizations(const Locale('en'));
      final router = GoRouter(
        initialLocation: GeneralSettingsScreen.path,
        routes: [
          GoRoute(
            path: GeneralSettingsScreen.path,
            builder: (_, _) => const GeneralSettingsScreen(),
          ),
          GoRoute(
            path: CrosspostingSettingsScreen.path,
            builder: (_, _) =>
                const Scaffold(body: Text('crossposting-destination')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(
              AuthState.authenticated,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsCrosspostingTitle), findsOneWidget);
      expect(find.text(l10n.settingsCrosspostingSubtitle), findsOneWidget);

      await tester.tap(find.text(l10n.settingsCrosspostingTitle));
      await tester.pumpAndSettle();

      expect(find.text('crossposting-destination'), findsOneWidget);
    });
  });
}

const _defaultEntries = <CrosspostingPlatformSettings>[
  CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.instagram,
    supportsAutomatic: true,
    mode: CrosspostingMode.manual,
    connection: CrosspostingConnection(
      id: 'instagram-connection',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
      externalAccountName: 'divine.creator',
    ),
  ),
  CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.x,
    supportsAutomatic: false,
    mode: CrosspostingMode.disabled,
  ),
  CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.youtube,
    supportsAutomatic: true,
    mode: CrosspostingMode.disabled,
    connection: CrosspostingConnection(
      id: 'youtube-connection',
      platform: CrosspostingPlatform.youtube,
      status: CrosspostingConnectionStatus.needsReauth,
      externalAccountName: 'old.creator',
    ),
  ),
];

CrosspostingPlatformSettings _connected({
  CrosspostingPlatform platform = CrosspostingPlatform.instagram,
  bool supportsAutomatic = true,
  CrosspostingMode mode = CrosspostingMode.disabled,
}) {
  return CrosspostingPlatformSettings(
    platform: platform,
    supportsAutomatic: supportsAutomatic,
    mode: mode,
    connection: CrosspostingConnection(
      id: '${platform.wireName}-connection',
      platform: platform,
      status: CrosspostingConnectionStatus.connected,
      externalAccountName: '${platform.wireName}.creator',
    ),
  );
}

CrosspostingPlatformSettings _disconnected({
  CrosspostingPlatform platform = CrosspostingPlatform.instagram,
}) {
  return CrosspostingPlatformSettings(
    platform: platform,
    supportsAutomatic: true,
    mode: CrosspostingMode.disabled,
  );
}

CrosspostingPlatformSettings _needsReauth() {
  return const CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.youtube,
    supportsAutomatic: true,
    mode: CrosspostingMode.disabled,
    connection: CrosspostingConnection(
      id: 'youtube-connection',
      platform: CrosspostingPlatform.youtube,
      status: CrosspostingConnectionStatus.needsReauth,
      externalAccountName: 'old.creator',
    ),
  );
}

Future<Uri?> _cancelOAuth(Uri _) async => null;

class _OutcomeScenario {
  const _OutcomeScenario({
    required this.name,
    required this.callbackQuery,
    required this.expectedMessage,
  });

  final String name;
  final String callbackQuery;
  final String Function(AppLocalizations l10n) expectedMessage;
}
