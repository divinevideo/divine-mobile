// ABOUTME: Tests for EmailVerificationScreen
// ABOUTME: Verifies polling, success, and error state rendering

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:unified_logger/unified_logger.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockEmailVerificationCubit extends MockCubit<EmailVerificationState>
    implements EmailVerificationCubit {}

class _MockAuthService extends Mock implements AuthService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  late _MockEmailVerificationCubit mockCubit;
  late _MockAuthService mockAuthService;
  late _MockKeycastOAuth mockOAuth;
  late _MockPendingVerificationService mockPendingVerification;
  late StreamController<AuthState> authStateController;

  setUp(() {
    mockCubit = _MockEmailVerificationCubit();
    mockAuthService = _MockAuthService();
    mockOAuth = _MockKeycastOAuth();
    mockPendingVerification = _MockPendingVerificationService();
    authStateController = StreamController<AuthState>.broadcast();

    // Stub authService stream
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);
    when(() => mockAuthService.isAnonymous).thenReturn(false);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

    // Stub pending verification service
    when(() => mockPendingVerification.clear()).thenAnswer((_) async {});
    when(() => mockPendingVerification.load()).thenAnswer((_) async => null);
    when(
      () => mockCubit.verifyEmailToken(
        token: any(named: 'token'),
        pendingEmail: any(named: 'pendingEmail'),
        keepPollingOnTransient: any(named: 'keepPollingOnTransient'),
      ),
    ).thenAnswer((_) async => const EmailTokenVerificationResult.success());
  });

  tearDown(() {
    authStateController.close();
  });

  Widget createTestWidget({
    String? deviceCode,
    String? verifier,
    String? email,
    String? token,
    bool restored = false,
    TargetPlatform? platform,
    EmailVerificationState initialState = const EmailVerificationState(),
    Stream<EmailVerificationState>? stateStream,
  }) {
    // Set up cubit state
    when(() => mockCubit.state).thenReturn(initialState);
    whenListen(
      mockCubit,
      stateStream ?? const Stream<EmailVerificationState>.empty(),
      initialState: initialState,
    );

    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerification,
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme.copyWith(platform: platform),
        routerConfig: GoRouter(
          initialLocation: '/verify-email',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Scaffold()),
            GoRoute(
              path: '/verify-email',
              builder: (_, _) => BlocProvider<EmailVerificationCubit>.value(
                value: mockCubit,
                child: EmailVerificationScreen(
                  deviceCode: deviceCode,
                  verifier: verifier,
                  email: email,
                  token: token,
                  restored: restored,
                ),
              ),
            ),
            GoRoute(
              path: '/login-options',
              builder: (_, _) => const Scaffold(body: Text('Login Options')),
            ),
            GoRoute(
              path: '/welcome/login-options',
              builder: (_, state) => Scaffold(
                body: Text(
                  'Login Options ${state.uri.queryParameters['email'] ?? ''}',
                ),
              ),
            ),
            GoRoute(
              path: '/explore',
              builder: (_, _) => const Scaffold(body: Text('Explore')),
            ),
            GoRoute(
              path: '/explore/tab/:tab',
              builder: (_, state) => Scaffold(
                body: Text('Explore ${state.pathParameters['tab']}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpVerificationScreen(
    WidgetTester tester, {
    String? deviceCode,
    String? verifier,
    String? email,
    String? token,
    bool restored = false,
    TargetPlatform? platform,
    Size surfaceSize = const Size(800, 1200),
    EmailVerificationState initialState = const EmailVerificationState(),
    Stream<EmailVerificationState>? stateStream,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      createTestWidget(
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
        token: token,
        restored: restored,
        platform: platform,
        initialState: initialState,
        stateStream: stateStream,
      ),
    );
  }

  group(EmailVerificationScreen, () {
    group('polling mode', () {
      testWidgets('renders polling content with email', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        expect(find.text('Complete your registration'), findsOneWidget);
        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('Waiting for verification'), findsOneWidget);
      });

      testWidgets('renders Open email app button', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineButton, 'Open email app'),
          findsOneWidget,
        );
      });

      testWidgets('renders close button', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        expect(_divineIcon(DivineIconName.x), findsOneWidget);
      });

      testWidgets('renders verification link instruction text', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        expect(find.text('We sent a verification link to:'), findsOneWidget);
      });
    });

    group('initial state', () {
      testWidgets('renders waiting content in initial state', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
          ),
        );
        await tester.pump();

        expect(find.text('Waiting for verification'), findsOneWidget);
      });
    });

    group('success state', () {
      testWidgets('renders success content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Welcome to Divine!'), findsOneWidget);
        expect(find.text('Your email has been verified.'), findsOneWidget);
      });

      testWidgets('renders Signing you in status', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Signing you in'), findsOneWidget);
      });

      testWidgets('hides close button on success', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        expect(_divineIcon(DivineIconName.x), findsNothing);
      });

      testWidgets('auth success navigates to the Popular explore tab by URL', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        authStateController.add(AuthState.authenticated);
        await tester.pumpAndSettle();

        expect(find.text('Explore popular'), findsOneWidget);
        verify(() => mockCubit.stopPolling()).called(greaterThan(0));
        verify(() => mockPendingVerification.clear()).called(greaterThan(0));
      });
    });

    group('failure state', () {
      testWidgets('renders error content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.timeout,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Uh oh.'), findsOneWidget);
      });

      testWidgets('renders Start over button', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.pollFailed,
            ),
          ),
        );
        await tester.pump();

        expect(find.widgetWithText(DivineButton, 'Start over'), findsOneWidget);
      });

      testWidgets('renders close button on failure', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.pollFailed,
            ),
          ),
        );
        await tester.pump();

        expect(_divineIcon(DivineIconName.x), findsOneWidget);
      });

      testWidgets('renders failure instruction text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.pollFailed,
            ),
          ),
        );
        await tester.pump();

        // The screen should render the localized message for pollFailed.
        // Source of truth is app_en.arb — this assertion protects the wiring
        // between state codes and the l10n mapping.
        expect(
          find.text('Verification failed. Please try again.'),
          findsOneWidget,
        );
      });

      testWidgets('renders sign-in recovery for duplicate email conflicts', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              pendingEmail: 'user@example.com',
              errorCode: EmailVerificationError.emailAlreadyRegistered,
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('This email is already registered. Sign in instead.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(DivineButton, 'Sign in'), findsOneWidget);

        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pumpAndSettle();

        expect(find.text('Login Options user@example.com'), findsOneWidget);
        verify(() => mockPendingVerification.clear()).called(greaterThan(0));
        verify(() => mockCubit.stopPolling()).called(greaterThan(0));
      });
    });

    group('interactions', () {
      testWidgets('calls stopPolling on dispose', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        // Navigate away to dispose the screen
        final router = GoRouter.of(
          tester.element(find.byType(EmailVerificationScreen)),
        );
        router.go('/');
        await tester.pumpAndSettle();

        verify(() => mockCubit.stopPolling()).called(greaterThan(0));
      });

      testWidgets(
        'calls stopPolling when widget is removed from tree without nav',
        (tester) async {
          // Distinct from the go_router-driven test above: this pins the
          // contract that the screen's own dispose() cancels polling, so a
          // future refactor that drops the GoRouter teardown path still
          // keeps zombie timers from surviving the screen.
          await pumpVerificationScreen(
            tester,
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          );
          await tester.pump();

          // Replace the widget tree entirely so the screen unmounts without
          // GoRouter being involved.
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SizedBox.shrink(),
            ),
          );
          await tester.pump();

          verify(() => mockCubit.stopPolling()).called(greaterThan(0));
        },
      );

      testWidgets('redacts persisted pending email in auto-login logs', (
        tester,
      ) async {
        await LogCaptureService().clearAllLogs();
        when(() => mockPendingVerification.load()).thenAnswer(
          (_) async => PendingVerification(
            deviceCode: 'persisted-device-code',
            verifier: 'persisted-verifier',
            email: 'user@example.com',
            createdAt: DateTime(2026),
          ),
        );
        when(
          () => mockCubit.startPolling(
            deviceCode: any(named: 'deviceCode'),
            verifier: any(named: 'verifier'),
            email: any(named: 'email'),
          ),
        ).thenReturn(null);

        await tester.pumpWidget(createTestWidget(token: 'persisted-token'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));

        final logMessage = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .lastWhere(
              (message) =>
                  message.startsWith('Found persisted verification data for '),
            );

        expect(logMessage, contains('u***@example.com'));
        expect(logMessage, isNot(contains('user@example.com')));
        verify(
          () => mockCubit.verifyEmailToken(
            token: 'persisted-token',
            pendingEmail: 'user@example.com',
          ),
        ).called(1);
        verify(
          () => mockCubit.startPolling(
            deviceCode: 'persisted-device-code',
            verifier: 'persisted-verifier',
            email: 'user@example.com',
          ),
        ).called(1);
      });

      testWidgets(
        'does not start polling after duplicate-email verify failure',
        (tester) async {
          when(() => mockPendingVerification.load()).thenAnswer(
            (_) async => PendingVerification(
              deviceCode: 'persisted-device-code',
              verifier: 'persisted-verifier',
              email: 'user@example.com',
              createdAt: DateTime(2026),
            ),
          );
          when(
            () => mockCubit.verifyEmailToken(
              token: any(named: 'token'),
              pendingEmail: any(named: 'pendingEmail'),
              keepPollingOnTransient: any(named: 'keepPollingOnTransient'),
            ),
          ).thenAnswer(
            (_) async => const EmailTokenVerificationResult.terminalFailure(
              EmailVerificationError.emailAlreadyRegistered,
            ),
          );

          await tester.pumpWidget(createTestWidget(token: 'persisted-token'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verify(
            () => mockCubit.verifyEmailToken(
              token: 'persisted-token',
              pendingEmail: 'user@example.com',
            ),
          ).called(1);
          verifyNever(
            () => mockCubit.startPolling(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
            ),
          );
          verify(() => mockPendingVerification.clear()).called(greaterThan(0));
        },
      );

      testWidgets(
        'does not start polling when disposed during persistence load',
        (tester) async {
          final loadCompleter = Completer<PendingVerification?>();
          when(
            () => mockPendingVerification.load(),
          ).thenAnswer((_) => loadCompleter.future);
          when(
            () => mockOAuth.verifyEmail(token: any(named: 'token')),
          ).thenAnswer((_) async => VerifyEmailResult(success: true));
          when(
            () => mockCubit.startPolling(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
            ),
          ).thenReturn(null);

          await tester.pumpWidget(createTestWidget(token: 'persisted-token'));
          await tester.pump();

          // Unmount the screen while the persistence load is still in flight.
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SizedBox.shrink(),
            ),
          );
          await tester.pump();

          // Resolve the load after dispose — the mounted guard must stop the
          // resumed async path from re-arming polling on a dead widget.
          loadCompleter.complete(
            PendingVerification(
              deviceCode: 'persisted-device-code',
              verifier: 'persisted-verifier',
              email: 'user@example.com',
              createdAt: DateTime(2026),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verifyNever(
            () => mockCubit.startPolling(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
            ),
          );
        },
      );

      testWidgets(
        're-verifies when token changes while already in token mode',
        (tester) async {
          final tokenNotifier = ValueNotifier<String>('token-1');
          const initialState = EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'stored@example.com',
          );

          when(() => mockCubit.state).thenReturn(initialState);
          whenListen(
            mockCubit,
            const Stream<EmailVerificationState>.empty(),
            initialState: initialState,
          );
          when(() => mockCubit.verifyEmailToken(token: 'token-1')).thenAnswer(
            (_) async => const EmailTokenVerificationResult.terminalFailure(
              EmailVerificationError.verificationLinkExpired,
            ),
          );
          when(
            () => mockCubit.verifyEmailToken(
              token: 'token-2',
              pendingEmail: 'stored@example.com',
              keepPollingOnTransient: true,
            ),
          ).thenAnswer(
            (_) async => const EmailTokenVerificationResult.success(),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(mockAuthService: mockAuthService),
                oauthClientProvider.overrideWithValue(mockOAuth),
                pendingVerificationServiceProvider.overrideWithValue(
                  mockPendingVerification,
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: BlocProvider<EmailVerificationCubit>.value(
                  value: mockCubit,
                  child: ValueListenableBuilder<String>(
                    valueListenable: tokenNotifier,
                    builder: (context, token, _) =>
                        EmailVerificationScreen(token: token),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verify(() => mockCubit.verifyEmailToken(token: 'token-1')).called(1);

          tokenNotifier.value = 'token-2';
          await tester.pump();

          verify(
            () => mockCubit.verifyEmailToken(
              token: 'token-2',
              pendingEmail: 'stored@example.com',
              keepPollingOnTransient: true,
            ),
          ).called(1);
        },
      );

      testWidgets(
        'late link click after timeout re-arms polling on verifyEmail success',
        (tester) async {
          // Start with no token: the link click below delivers the first
          // token to an already-open, timed-out screen (the real late-click).
          final tokenNotifier = ValueNotifier<String>('');
          const timedOutState = EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            pendingEmail: 'user@example.com',
          );

          when(() => mockCubit.state).thenReturn(timedOutState);
          whenListen(
            mockCubit,
            const Stream<EmailVerificationState>.empty(),
            initialState: timedOutState,
          );
          when(() => mockCubit.resumePollingAfterTimeout()).thenReturn(null);
          when(
            () => mockCubit.verifyEmailToken(
              token: any(named: 'token'),
              pendingEmail: any(named: 'pendingEmail'),
              keepPollingOnTransient: any(named: 'keepPollingOnTransient'),
            ),
          ).thenAnswer(
            (_) async => const EmailTokenVerificationResult.success(),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(mockAuthService: mockAuthService),
                oauthClientProvider.overrideWithValue(mockOAuth),
                pendingVerificationServiceProvider.overrideWithValue(
                  mockPendingVerification,
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: BlocProvider<EmailVerificationCubit>.value(
                  value: mockCubit,
                  child: ValueListenableBuilder<String>(
                    valueListenable: tokenNotifier,
                    builder: (context, token, _) =>
                        EmailVerificationScreen(token: token),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          // A late link click arrives while the screen sits in pollingTimedOut.
          tokenNotifier.value = 'token-2';
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verify(
            () => mockCubit.verifyEmailToken(
              token: 'token-2',
              pendingEmail: 'user@example.com',
              keepPollingOnTransient: true,
            ),
          ).called(1);
          verify(() => mockCubit.resumePollingAfterTimeout()).called(1);
        },
      );
    });

    group('PIN entry fallback', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      const pollingState = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'user@example.com',
      );

      testWidgets('renders the PIN field, prompt, and submit in polling mode', (
        tester,
      ) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: pollingState,
        );
        await tester.pump();

        expect(find.text(l10n.authVerificationPinPrompt), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(
          find.widgetWithText(DivineButton, l10n.authVerificationPinSubmit),
          findsOneWidget,
        );
      });

      testWidgets('submitting a 6-digit PIN dispatches submitPin', (
        tester,
      ) async {
        when(() => mockCubit.submitPin(any())).thenAnswer((_) async {});

        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: pollingState,
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '123456');
        await tester.pump();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
          reason:
              'the button tap must be exercised while the PIN field is focused',
        );
        await tester.tap(
          find.widgetWithText(DivineButton, l10n.authVerificationPinSubmit),
        );
        await tester.pump();

        verify(() => mockCubit.submitPin('123456')).called(1);
      });

      testWidgets('shows the localized error when a PIN submission failed', (
        tester,
      ) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
            pinStatus: PinSubmissionStatus.failure,
            pinErrorCode: EmailVerificationError.pinInvalid,
          ),
        );
        await tester.pump();

        expect(find.text(l10n.authVerificationErrorPinInvalid), findsOneWidget);
      });

      testWidgets('announces a PIN failure to assistive tech', (tester) async {
        final announcements = <Map<Object?, Object?>>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (Object? message) async {
                if (message is Map) announcements.add(message);
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );

        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: pollingState,
          stateStream: Stream<EmailVerificationState>.fromIterable(const [
            EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
              pinStatus: PinSubmissionStatus.failure,
              pinErrorCode: EmailVerificationError.pinInvalid,
            ),
          ]),
        );
        await tester.pump();
        await tester.pump();

        expect(
          announcements.any((message) {
            final data = message['data'];
            return message['type'] == 'announce' &&
                data is Map &&
                data['message'] == l10n.authVerificationErrorPinInvalid;
          }),
          isTrue,
        );
      });

      testWidgets('surfaces the resend cooldown countdown', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
            resendStatus: ResendStatus.cooldown,
            resendCooldownSeconds: 299,
          ),
        );
        await tester.pump();

        expect(
          find.text(l10n.authVerificationResendCooldown('4:59')),
          findsOneWidget,
        );
      });

      testWidgets('surfaces a retryable resend failure', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
            resendStatus: ResendStatus.failure,
          ),
        );
        await tester.pump();

        expect(find.text(l10n.authVerificationResendFailed), findsOneWidget);
        expect(find.text(l10n.authVerificationResend), findsOneWidget);
      });

      testWidgets('tapping resend dispatches resendVerification', (
        tester,
      ) async {
        when(() => mockCubit.resendVerification()).thenAnswer((_) async {});

        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: pollingState,
        );
        await tester.pump();

        await tester.tap(find.text(l10n.authVerificationResend));
        await tester.pump();

        verify(() => mockCubit.resendVerification()).called(1);
      });

      testWidgets(
        'an unavailable resend endpoint says so but stays retryable',
        (tester) async {
          when(() => mockCubit.resendVerification()).thenAnswer((_) async {});

          await pumpVerificationScreen(
            tester,
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
              resendStatus: ResendStatus.unavailable,
            ),
          );
          await tester.pump();

          expect(
            find.text(l10n.authVerificationResendUnavailable),
            findsOneWidget,
          );
          // Not the generic "try again" copy — retrying cannot help here.
          expect(find.text(l10n.authVerificationResendFailed), findsNothing);

          // The route is missing from this server build, not from the app.
          // A session spanning the deploy that adds it must be able to retry.
          await tester.tap(find.text(l10n.authVerificationResend));
          await tester.pump();

          verify(() => mockCubit.resendVerification()).called(1);
        },
      );

      testWidgets('an expired registration says to start again', (
        tester,
      ) async {
        when(() => mockCubit.resendVerification()).thenAnswer((_) async {});

        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
            resendStatus: ResendStatus.expired,
          ),
        );
        await tester.pump();

        expect(find.text(l10n.authVerificationResendExpired), findsOneWidget);
        expect(find.text(l10n.authVerificationResendFailed), findsNothing);

        await tester.tap(find.text(l10n.authVerificationResend));
        await tester.pump();

        verifyNever(() => mockCubit.resendVerification());
      });

      testWidgets('pollingTimedOut keeps PIN entry but drops the spinner', (
        tester,
      ) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        expect(find.text(l10n.authVerificationPinPrompt), findsOneWidget);
        expect(find.text(l10n.authWaitingForVerification), findsNothing);
      });

      // Without this the spinner just vanishes at the 15-minute mark and the
      // screen looks identical to one that is still working.
      testWidgets('pollingTimedOut explains why the spinner disappeared', (
        tester,
      ) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            pendingEmail: 'user@example.com',
          ),
        );
        await tester.pump();

        expect(find.text(l10n.authVerificationPollingStopped), findsOneWidget);
      });

      testWidgets(
        'token-mode polling timeout still explains the stopped poll',
        (tester) async {
          await pumpVerificationScreen(
            tester,
            token: 'verification-token',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
              pendingEmail: 'user@example.com',
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          expect(find.text(l10n.authWaitingForVerification), findsNothing);
          expect(
            find.text(l10n.authVerificationPollingStopped),
            findsOneWidget,
          );
        },
      );
    });

    group('cold-start restore escape hatch', () {
      const pollingState = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'user@example.com',
      );

      testWidgets('restored polling mode shows the PIN field', (tester) async {
        await pumpVerificationScreen(
          tester,
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          restored: true,
          initialState: pollingState,
        );
        await tester.pump();

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).authVerificationPinPrompt,
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'closing in restored mode clears the pending record and returns home',
        (tester) async {
          await pumpVerificationScreen(
            tester,
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            restored: true,
            initialState: pollingState,
          );
          await tester.pump();

          await tester.tap(_divineIcon(DivineIconName.x));
          await tester.pumpAndSettle();

          verify(() => mockPendingVerification.clear()).called(1);
          expect(find.byType(EmailVerificationScreen), findsNothing);
        },
      );

      testWidgets(
        'closing in normal (non-restored) mode keeps the pending record',
        (tester) async {
          await pumpVerificationScreen(
            tester,
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: pollingState,
          );
          await tester.pump();

          await tester.tap(_divineIcon(DivineIconName.x));
          await tester.pumpAndSettle();

          verifyNever(() => mockPendingVerification.clear());
        },
      );

      testWidgets(
        'Start Over from a terminal failure clears the pending record',
        (tester) async {
          await pumpVerificationScreen(
            tester,
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.pollFailed,
            ),
          );
          await tester.pump();

          await tester.tap(find.widgetWithText(DivineButton, 'Start over'));
          await tester.pumpAndSettle();

          verify(() => mockPendingVerification.clear()).called(greaterThan(0));
        },
      );

      testWidgets(
        'restore rehydrates deviceCode/verifier from the record, not the URL',
        (tester) async {
          when(() => mockPendingVerification.load()).thenAnswer(
            (_) async => PendingVerification(
              deviceCode: 'record-device',
              verifier: 'record-verifier',
              email: 'user@example.com',
              createdAt: DateTime.now(),
            ),
          );
          when(
            () => mockCubit.startPolling(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
            ),
          ).thenReturn(null);

          // The restore URL carries only email + restored=true; the secrets
          // must come from the persisted record.
          await pumpVerificationScreen(
            tester,
            email: 'user@example.com',
            restored: true,
            initialState: pollingState,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verify(
            () => mockCubit.startPolling(
              deviceCode: 'record-device',
              verifier: 'record-verifier',
              email: 'user@example.com',
            ),
          ).called(1);
        },
      );

      testWidgets(
        'restore does not poll an owner-bound record for another identity',
        (tester) async {
          const recordOwner =
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
          const activeOwner =
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
          when(
            () => mockAuthService.authState,
          ).thenReturn(AuthState.authenticated);
          when(() => mockAuthService.isAnonymous).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(activeOwner);
          when(() => mockPendingVerification.load()).thenAnswer(
            (_) async => PendingVerification(
              deviceCode: 'record-device',
              verifier: 'record-verifier',
              email: 'user@example.com',
              createdAt: DateTime.now(),
              ownerPublicKeyHex: recordOwner,
            ),
          );
          when(
            () => mockCubit.startPolling(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
            ),
          ).thenReturn(null);

          await pumpVerificationScreen(
            tester,
            email: 'user@example.com',
            restored: true,
            initialState: pollingState,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verifyNever(
            () => mockCubit.startPolling(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
            ),
          );
        },
      );
    });
  });

  group('screen-reader announcements', () {
    // Regression for a level-triggered listener: a single listener over the
    // union of status, pinStatus and resendStatus re-announced every message
    // that happened to be true whenever any one field moved. A resend after
    // polling had already stopped therefore repeated "we stopped checking"
    // on each resend transition and then interrupted itself.
    testWidgets(
      'announces polling-stopped once, not again on later resend transitions',
      (tester) async {
        final announced = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (Object? message) async {
                if (message is Map) {
                  final data = message['data'];
                  if (data is Map && data['message'] is String) {
                    announced.add(data['message'] as String);
                  }
                }
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpVerificationScreen(
          tester,
          deviceCode: 'device-code',
          verifier: 'verifier',
          email: 'someone@example.test',
          stateStream: Stream<EmailVerificationState>.fromIterable(const [
            EmailVerificationState(status: EmailVerificationStatus.polling),
            EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
            ),
            EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
              resendStatus: ResendStatus.sending,
            ),
            EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
              resendStatus: ResendStatus.unavailable,
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(
          announced.where((m) => m == l10n.authVerificationPollingStopped),
          hasLength(1),
          reason:
              'polling-stopped must announce on entry only, not on every '
              'later resend transition while the status is unchanged',
        );
        expect(
          announced.where((m) => m == l10n.authVerificationResendUnavailable),
          hasLength(1),
        );
      },
    );

    // `failure` and `expired` both render red error text after the same async
    // resend, so both need the announcement `unavailable` already gets.
    // Otherwise the mildest outcome is the only one spoken.
    for (final (status, label) in <(ResendStatus, String)>[
      (ResendStatus.failure, 'failure'),
      (ResendStatus.expired, 'expired'),
    ]) {
      testWidgets('announces a resend $label to screen readers', (
        tester,
      ) async {
        final announced = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (Object? message) async {
                if (message is Map) {
                  final data = message['data'];
                  if (data is Map && data['message'] is String) {
                    announced.add(data['message'] as String);
                  }
                }
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final expected = status == ResendStatus.failure
            ? l10n.authVerificationResendFailed
            : l10n.authVerificationResendExpired;

        await pumpVerificationScreen(
          tester,
          deviceCode: 'device-code',
          verifier: 'verifier',
          email: 'someone@example.test',
          // Ends on pollingTimedOut so the polling spinner is gone and
          // pumpAndSettle can settle.
          stateStream: Stream<EmailVerificationState>.fromIterable([
            const EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
            ),
            const EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
              resendStatus: ResendStatus.sending,
            ),
            EmailVerificationState(
              status: EmailVerificationStatus.pollingTimedOut,
              resendStatus: status,
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(
          announced.where((m) => m == expected),
          hasLength(1),
          reason:
              'a resend $label swaps in red error text after an async '
              'transition that moves no focus, so it must be announced',
        );
      });
    }

    // Guards the edge trigger specifically: widening listenWhen to a union of
    // fields would re-announce the failure every time any unrelated field
    // moved while resendStatus stayed put. That regression already happened
    // once on this branch.
    testWidgets('does not repeat the failure announcement while the status '
        'stays failure', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            (Object? message) async {
              if (message is Map) {
                final data = message['data'];
                if (data is Map && data['message'] is String) {
                  announced.add(data['message'] as String);
                }
              }
              return null;
            },
          );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpVerificationScreen(
        tester,
        deviceCode: 'device-code',
        verifier: 'verifier',
        email: 'someone@example.test',
        stateStream: Stream<EmailVerificationState>.fromIterable(const [
          EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            resendStatus: ResendStatus.sending,
          ),
          EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            resendStatus: ResendStatus.failure,
          ),
          EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            resendStatus: ResendStatus.failure,
            resendCooldownSeconds: 42,
          ),
          EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
            resendStatus: ResendStatus.failure,
            resendCooldownSeconds: 41,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        announced.where((m) => m == l10n.authVerificationResendFailed),
        hasLength(1),
        reason:
            'the resend listeners must be edge-triggered on resendStatus '
            'alone, not on any field of the state',
      );
    });
  });

  group('close affordance', () {
    // The only exit from the polling screen, and the expired-resend copy tells
    // the user to start again without an icon-only X being able to say which
    // control does that.
    testWidgets('names the close action for assistive tech', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpVerificationScreen(
        tester,
        deviceCode: 'device-code',
        verifier: 'verifier',
        email: 'someone@example.test',
        initialState: const EmailVerificationState(
          status: EmailVerificationStatus.polling,
        ),
      );
      await tester.pump();

      expect(
        find.ancestor(
          of: _divineIcon(DivineIconName.x),
          matching: find.bySemanticsLabel(l10n.commonClose),
        ),
        findsOneWidget,
        reason:
            'an icon-only X carries no meaning on its own; without '
            '`semanticLabel` a screen reader reaches an unnamed tap target',
      );
      handle.dispose();
    });

    testWidgets('names it Start over once verification has failed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpVerificationScreen(
        tester,
        deviceCode: 'device-code',
        verifier: 'verifier',
        email: 'someone@example.test',
        initialState: const EmailVerificationState(
          status: EmailVerificationStatus.failure,
          errorCode: EmailVerificationError.pinFailed,
        ),
      );
      await tester.pump();

      // Scoped to the X: the failure screen also renders a labelled "Start
      // over" button, so an unscoped finder passes with the icon unlabeled.
      expect(
        find.ancestor(
          of: _divineIcon(DivineIconName.x),
          matching: find.bySemanticsLabel(l10n.authStartOver),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('keyboard reachability', () {
    // The screen sets `resizeToAvoidBottomInset: false`, so the layout does
    // not shrink when the keyboard opens. Unless the scroll view owns the
    // inset itself, the PIN field's submit button sits under the keyboard
    // with no gesture that can reach it.
    testWidgets('scrolls the PIN submit button clear of the keyboard', (
      tester,
    ) async {
      const viewport = Size(390, 760);
      const keyboardExtent = 300.0;
      final l10n = lookupAppLocalizations(const Locale('en'));

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardExtent);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestWidget(
          deviceCode: 'test-device-code',
          verifier: 'test-verifier',
          email: 'user@example.com',
          initialState: const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'user@example.com',
          ),
        ),
      );
      await tester.pump();

      final submit = find.widgetWithText(
        DivineButton,
        l10n.authVerificationPinSubmit,
      );
      expect(submit, findsOneWidget);

      await tester.dragUntilVisible(
        submit,
        find.byType(CustomScrollView),
        const Offset(0, -80),
      );
      await tester.pump();

      expect(
        tester.getRect(submit).bottom,
        lessThanOrEqualTo(viewport.height - keyboardExtent),
        reason: 'the submit button must come to rest above the keyboard',
      );
    });

    // The floating close button clears the content by a padding derived from
    // the button's own box, which follows the icon text scale. A fixed value
    // lets the button sit on the content once the scale grows.
    testWidgets('keeps the close button clear of the content at large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 560);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getRect(find.byType(DivineIconButton)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(DivineSticker)).top),
        reason: 'the close button must not overlap the content it floats over',
      );
    });

    // Success and error are `Spacer`-centred columns. Before the screen owned
    // the scrolling they had no scroll view at all, so a short viewport at a
    // large text scale overflowed instead of scrolling.
    testWidgets('scrolls the failure state instead of overflowing', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.pollFailed,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  group('keyboard dismissal', () {
    const pollingState = EmailVerificationState(
      status: EmailVerificationStatus.polling,
      pendingEmail: 'user@example.com',
    );

    testWidgets('unfocuses the PIN field when tapping the content outside it', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpVerificationScreen(
        tester,
        deviceCode: 'test-device-code',
        verifier: 'test-verifier',
        email: 'user@example.com',
        initialState: pollingState,
      );
      await tester.pump();

      final editable = find.byType(EditableText);
      await tester.tap(editable);
      await tester.pump();
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

      await tester.tap(find.text(l10n.authVerificationPinPrompt));
      await tester.pump();

      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isFalse);
    });

    testWidgets('unfocuses the PIN field when dragging the screen', (
      tester,
    ) async {
      await pumpVerificationScreen(
        tester,
        deviceCode: 'test-device-code',
        verifier: 'test-verifier',
        email: 'user@example.com',
        platform: TargetPlatform.iOS,
        surfaceSize: const Size(1200, 2600),
        initialState: pollingState,
      );
      await tester.pump();

      final editable = find.byType(EditableText);
      await tester.tap(editable);
      await tester.pump();
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
      await tester.pump();

      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isFalse);
    });
  });

  group('token mode', () {
    // Reachable via token + persisted record: the screen latches token mode,
    // then `_initTokenModeWithPersistenceCheck` calls `startPolling`, arming
    // the 15-minute timeout. The URL carries no deviceCode, so `isPollingMode`
    // is false and the timed-out screen used to render nothing at all.
    testWidgets('explains why polling stopped in token mode', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      when(() => mockPendingVerification.load()).thenAnswer(
        (_) async => PendingVerification(
          deviceCode: 'persisted-device-code',
          verifier: 'persisted-verifier',
          email: 'someone@example.test',
          createdAt: DateTime.utc(2026),
        ),
      );

      await pumpVerificationScreen(
        tester,
        token: 'verification-token',
        stateStream: Stream<EmailVerificationState>.fromIterable(const [
          EmailVerificationState(status: EmailVerificationStatus.polling),
          EmailVerificationState(
            status: EmailVerificationStatus.pollingTimedOut,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.authVerificationPollingStopped), findsOneWidget);
    });
  });

  group('resend affordance', () {
    // `Semantics(button: true)` wrapping `ExcludeSemantics(child:
    // GestureDetector(onTap: ...))` drops the detector's own
    // `SemanticsAction.tap` along with the subtree, so the node announces a
    // button VoiceOver cannot activate. `tester.tap` does not catch it — a
    // real touch still reaches the handler — so assert the action itself.
    testWidgets('exposes a tap action to assistive tech', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpVerificationScreen(
        tester,
        deviceCode: 'device-code',
        verifier: 'verifier',
        email: 'someone@example.test',
        initialState: const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: 'someone@example.test',
        ),
      );
      await tester.pump();

      final resend = tester.getSemantics(
        find.bySemanticsLabel(l10n.authVerificationResend),
      );
      expect(
        resend.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'the resend link announces itself as a button, so it has to carry '
            'the tap action that activating it depends on',
      );
      handle.dispose();
    });

    // The cooldown state deliberately drops the action: the node stays
    // labelled and flagged disabled rather than silently tappable.
    testWidgets('drops the tap action while cooling down', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpVerificationScreen(
        tester,
        deviceCode: 'device-code',
        verifier: 'verifier',
        email: 'someone@example.test',
        initialState: const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: 'someone@example.test',
          resendStatus: ResendStatus.cooldown,
          resendCooldownSeconds: 120,
        ),
      );
      await tester.pump();

      final resend = tester.getSemantics(
        find.bySemanticsLabel(l10n.authVerificationResendCooldown('2:00')),
      );
      expect(
        resend.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      handle.dispose();
    });
  });
}
