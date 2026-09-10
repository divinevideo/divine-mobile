// ABOUTME: Tests for SecureAccountScreen
// ABOUTME: Verifies registration form, validation, and email verification flow

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/providers/route_normalization_provider.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../../helpers/autofill_context_mock.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _MockEmailVerificationCubit extends MockCubit<EmailVerificationState>
    implements EmailVerificationCubit {}

class _MockInviteApiClient extends Mock implements InviteApiClient {}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(SecureAccountScreen, () {
    const automaticOwnerPublicKeyHex =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;
    late _MockPendingVerificationService mockPendingVerification;
    late StreamController<AuthState> authStateController;

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      mockPendingVerification = _MockPendingVerificationService();
      authStateController = StreamController<AuthState>.broadcast();

      // Default stubs
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(true);
      when(() => mockAuthService.isRegistered).thenReturn(false);
      when(() => mockAuthService.currentNpub).thenReturn('npub1test...');
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(automaticOwnerPublicKeyHex);
      when(
        () => mockAuthService.exportNsec(),
      ).thenAnswer((_) async => 'nsec1testabc123xyz');
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);
      when(() => mockPendingVerification.clear()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await authStateController.close();
    });

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          oauthClientProvider.overrideWithValue(mockOAuth),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
        child: BlocProvider<EmailVerificationCubit>(
          create: (_) => EmailVerificationCubit(
            oauthClient: mockOAuth,
            authService: mockAuthService,
          ),
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SecureAccountScreen(),
          ),
        ),
      );
    }

    Future<void> setRegistrationTestSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    group('Form Display', () {
      testWidgets('displays email field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays confirm password field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays Secure account button', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Secure account'),
          findsOneWidget,
        );
      });

      testWidgets('displays back button', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.caretLeft), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('shows error for invalid email', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Enter invalid email
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'invalid-email',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'password123',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'password123',
        );

        // Tap submit
        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.textContaining('valid email'), findsOneWidget);
      });

      testWidgets('shows error for malformed email domain', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'person@gmail..com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email'), findsOneWidget);
        verifyNever(() => mockAuthService.exportNsec());
      });

      testWidgets('shows error for password mismatch', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'DifferentPass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text("Passwords don't match"), findsOneWidget);
        verifyNever(() => mockAuthService.exportNsec());
      });
    });

    group('Password Visibility Toggle', () {
      testWidgets('toggles password visibility', (tester) async {
        await setRegistrationTestSurface(tester);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // DivineAuthTextField uses DivineIcon (SVG) for password visibility
        // toggles. The password and confirmation fields each have one.
        expect(
          find.descendant(
            of: find.byType(DivineAuthTextField),
            matching: find.byType(DivineIcon),
          ),
          findsNWidgets(2),
        );

        // Password should be obscured initially
        final textField = tester.widget<TextField>(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
        );
        expect(textField.obscureText, isTrue);

        // Tap the visibility toggle (GestureDetector wrapping DivineIcon)
        await tester.tap(
          find
              .descendant(
                of: find.byType(DivineAuthTextField),
                matching: find.byType(DivineIcon),
              )
              .first,
        );
        await tester.pumpAndSettle();

        // Password should now be visible
        final textFieldAfter = tester.widget<TextField>(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
        );
        expect(textFieldAfter.obscureText, isFalse);
      });
    });

    group('Registration Flow', () {
      testWidgets(
        'verification-required registration reaches shared PIN and resend flow '
        'without routing credentials',
        (tester) async {
          await setRegistrationTestSurface(tester);
          await LogCaptureService().clearAllLogs();
          final autofillRecorder = AutofillContextRecorder.install();
          final verificationCubit = _MockEmailVerificationCubit();
          final inviteApiClient = _MockInviteApiClient();
          const verificationState = EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'test@example.com',
          );
          when(() => verificationCubit.state).thenReturn(verificationState);
          whenListen(
            verificationCubit,
            const Stream<EmailVerificationState>.empty(),
            initialState: verificationState,
          );
          when(
            () => mockOAuth.headlessRegister(
              email: any(named: 'email'),
              password: any(named: 'password'),
              nsec: any(named: 'nsec'),
              scope: any(named: 'scope'),
            ),
          ).thenAnswer(
            (_) async => (
              HeadlessRegisterResult(
                success: true,
                pubkey: 'test-pubkey',
                verificationRequired: true,
                deviceCode: 'test-device-code',
                email: 'test@example.com',
              ),
              'test-verifier',
            ),
          );
          when(
            () => mockPendingVerification.save(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
              inviteCode: any(named: 'inviteCode'),
              ownerPublicKeyHex: any(named: 'ownerPublicKeyHex'),
            ),
          ).thenAnswer((_) async {});
          when(() => mockPendingVerification.load()).thenAnswer(
            (_) async => PendingVerification(
              deviceCode: 'test-device-code',
              verifier: 'test-verifier',
              email: 'test@example.com',
              createdAt: DateTime.now(),
              ownerPublicKeyHex: automaticOwnerPublicKeyHex,
            ),
          );

          final router = GoRouter(
            initialLocation: '/welcome',
            routes: [
              GoRoute(
                path: '/welcome',
                builder: (_, _) => const SecureAccountScreen(),
              ),
              GoRoute(
                path: EmailVerificationScreen.path,
                builder: (_, state) {
                  final params = state.uri.queryParameters;
                  return EmailVerificationScreen(
                    deviceCode: params['deviceCode'],
                    verifier: params['verifier'],
                    email: params['email'],
                    restored: params['restored'] == 'true',
                  );
                },
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
                oauthClientProvider.overrideWithValue(mockOAuth),
                authServiceProvider.overrideWithValue(mockAuthService),
                pendingVerificationServiceProvider.overrideWithValue(
                  mockPendingVerification,
                ),
                goRouterProvider.overrideWithValue(router),
              ],
              child: Consumer(
                builder: (context, ref, _) {
                  ref.watch(routeNormalizationProvider);
                  return RepositoryProvider<InviteApiClient>.value(
                    value: inviteApiClient,
                    child: BlocProvider(
                      create: (_) =>
                          InviteGateBloc(inviteApiClient: inviteApiClient),
                      child: BlocProvider<EmailVerificationCubit>.value(
                        value: verificationCubit,
                        child: MaterialApp.router(
                          theme: VineTheme.theme,
                          localizationsDelegates: appLocalizationsDelegates,
                          supportedLocales: AppLocalizations.supportedLocales,
                          routerConfig: router,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Email'),
              matching: find.byType(TextField),
            ),
            'test@example.com',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Password'),
              matching: find.byType(TextField),
            ),
            'SecurePass123!',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
              matching: find.byType(TextField),
            ),
            'SecurePass123!',
          );

          await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          verify(
            () => mockPendingVerification.save(
              deviceCode: 'test-device-code',
              verifier: 'test-verifier',
              email: 'test@example.com',
              ownerPublicKeyHex: automaticOwnerPublicKeyHex,
            ),
          ).called(1);
          final location = router.routeInformationProvider.value.uri.toString();
          expect(location, startsWith('/verify-email?'));
          expect(location, contains('restored=true'));
          expect(location, isNot(contains('test-device-code')));
          expect(location, isNot(contains('test-verifier')));
          final normalizationLogs = LogCaptureService()
              .getRecentLogs()
              .where((entry) => entry.name == 'RouteNormalizationProvider')
              .map((entry) => entry.message)
              .join('\n');
          expect(normalizationLogs, isNotEmpty);
          expect(normalizationLogs, isNot(contains('test-device-code')));
          expect(normalizationLogs, isNot(contains('test-verifier')));
          verify(
            () => verificationCubit.startPolling(
              deviceCode: 'test-device-code',
              verifier: 'test-verifier',
              email: 'test@example.com',
            ),
          ).called(1);
          expect(
            find.text('Or enter the 6-digit code from your email'),
            findsOneWidget,
          );
          expect(find.text('Resend'), findsOneWidget);
          expect(find.text('Continue to App'), findsNothing);
          expect(autofillRecorder.didFinishAutofillContext, isTrue);

          clearInteractions(verificationCubit);
          router.go('/welcome');
          await tester.pumpAndSettle();
          final coldStartLocation = pendingEmailVerificationStartupLocation(
            pending: PendingVerification(
              deviceCode: 'test-device-code',
              verifier: 'test-verifier',
              email: 'test@example.com',
              createdAt: DateTime.now(),
              ownerPublicKeyHex: automaticOwnerPublicKeyHex,
            ),
            authState: AuthState.authenticated,
            isAnonymous: true,
            currentPublicKeyHex: automaticOwnerPublicKeyHex,
            currentPath: '/welcome',
          );
          expect(coldStartLocation, isNotNull);
          expect(coldStartLocation, isNot(contains('test-device-code')));
          expect(coldStartLocation, isNot(contains('test-verifier')));

          router.go(coldStartLocation!);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          verify(
            () => verificationCubit.startPolling(
              deviceCode: 'test-device-code',
              verifier: 'test-verifier',
              email: 'test@example.com',
            ),
          ).called(1);
        },
      );

      testWidgets('calls headlessRegister on valid form submission', (
        tester,
      ) async {
        // Use verificationRequired: false to avoid triggering polling
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult(
              success: true,
              pubkey: 'test-pubkey',
              verificationRequired: false,
              email: 'test@example.com',
            ),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        // Use pump() instead of pumpAndSettle() to avoid timer issues
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            nsec: any(named: 'nsec'),
            scope: 'policy:full',
          ),
        ).called(1);
      });

      testWidgets('shows error message on registration failure', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult.error('Email already registered'),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'existing@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text('Email already registered'), findsOneWidget);
      });

      testWidgets('shows error when nsec export fails', (tester) async {
        when(() => mockAuthService.exportNsec()).thenAnswer((_) async => null);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to access your keys. Please try again.'),
          findsOneWidget,
        );
      });
    });

    group('Key conflict recovery', () {
      Future<GoRouter> pumpConflict(WidgetTester tester) async {
        await setRegistrationTestSurface(tester);
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult.error(
              'This Nostr key is already registered. '
              'Please log in instead or use a different key.',
              code: 'CONFLICT',
            ),
            'test-verifier',
          ),
        );

        final router = GoRouter(
          initialLocation: '/welcome',
          routes: [
            GoRoute(
              path: '/welcome',
              builder: (_, _) => const SecureAccountScreen(),
            ),
            GoRoute(
              path: '/welcome/login-options',
              builder: (_, state) =>
                  Text('login-options:${state.uri.queryParameters['email']}'),
            ),
            GoRoute(
              path: '/support-center',
              builder: (_, _) => const Text('support-center-stub'),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...getStandardTestOverrides(),
              oauthClientProvider.overrideWithValue(mockOAuth),
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'existing@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(
          find.widgetWithText(
            DivineButton,
            lookupAppLocalizations(const Locale('en')).authSecureAccountTitle,
          ),
        );
        // Settle the exportNsec microtask + headlessRegister future without
        // pumpAndSettle (avoids a hang on the loading spinner).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        return router;
      }

      testWidgets(
        'shows in-place recovery choices instead of navigating away',
        (tester) async {
          final router = await pumpConflict(tester);
          final l10n = lookupAppLocalizations(const Locale('en'));

          // Stays on the screen and offers recovery choices rather than
          // auto-bouncing.
          expect(router.routeInformationProvider.value.uri.path, '/welcome');
          expect(
            find.text(l10n.authSecureAccountAlreadyRegistered),
            findsOneWidget,
          );
          // Retry stays available (form is not locked) alongside the
          // sign-in and contact-support doors.
          expect(
            find.widgetWithText(DivineButton, l10n.authSecureAccountTitle),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(DivineButton, l10n.authSignInButton),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(DivineButton, l10n.authContactSupport),
            findsOneWidget,
          );
          // The form stays editable so a different email can be tried in place.
          final emailField = tester.widget<TextField>(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Email'),
              matching: find.byType(TextField),
            ),
          );
          expect(emailField.enabled, isTrue);
          // The raw server sentence never reaches the user.
          expect(find.textContaining('Nostr key'), findsNothing);
        },
      );

      testWidgets('editing the email clears the conflict for a fresh retry', (
        tester,
      ) async {
        await pumpConflict(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(
          find.text(l10n.authSecureAccountAlreadyRegistered),
          findsOneWidget,
        );

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'different@example.com',
        );
        await tester.pump();

        // The conflict message and its recovery doors clear on edit.
        expect(
          find.text(l10n.authSecureAccountAlreadyRegistered),
          findsNothing,
        );
        expect(
          find.widgetWithText(DivineButton, l10n.authContactSupport),
          findsNothing,
        );
      });

      testWidgets(
        'resubmitting clears stale recovery actions and renders the new result',
        (tester) async {
          await pumpConflict(tester);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final retry = Completer<(HeadlessRegisterResult, String)>();
          when(
            () => mockOAuth.headlessRegister(
              email: any(named: 'email'),
              password: any(named: 'password'),
              nsec: any(named: 'nsec'),
              scope: any(named: 'scope'),
            ),
          ).thenAnswer((_) => retry.future);

          await tester.tap(
            find.widgetWithText(DivineButton, l10n.authSecureAccountTitle),
          );
          await tester.pump();

          expect(
            find.text(l10n.authSecureAccountAlreadyRegistered),
            findsNothing,
          );
          expect(
            find.widgetWithText(DivineButton, l10n.authSignInButton),
            findsNothing,
          );
          expect(
            find.widgetWithText(DivineButton, l10n.authContactSupport),
            findsNothing,
          );

          retry.complete((
            HeadlessRegisterResult(
              success: true,
              pubkey: 'test-pubkey',
              verificationRequired: false,
              email: 'existing@example.com',
            ),
            'test-verifier',
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text(l10n.authRegistrationComplete), findsOneWidget);
          expect(
            find.widgetWithText(DivineButton, l10n.authSignInButton),
            findsNothing,
          );
          expect(
            find.widgetWithText(DivineButton, l10n.authContactSupport),
            findsNothing,
          );
        },
      );

      testWidgets('Sign in routes to the recovery hub with the email', (
        tester,
      ) async {
        await pumpConflict(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(DivineButton, l10n.authSignInButton),
        );
        await tester.pumpAndSettle();

        expect(find.text('login-options:existing@example.com'), findsOneWidget);
      });

      testWidgets('Contact support routes to the support center', (
        tester,
      ) async {
        await pumpConflict(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(DivineButton, l10n.authContactSupport),
        );
        await tester.pumpAndSettle();

        expect(find.text('support-center-stub'), findsOneWidget);
      });
    });
  });
}
