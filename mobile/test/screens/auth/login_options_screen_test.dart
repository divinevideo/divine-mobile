// ABOUTME: Tests for LoginOptionsScreen
// ABOUTME: Verifies form rendering, sign-in flow, forgot password,
// ABOUTME: and alternative login method buttons

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

/// The options hint renders its two-color copy in a [RichText] (via
/// `Text.rich`), which `find.text` cannot match — match on the plain text.
Finder _optionsHint(String cta) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(cta),
);

void main() {
  late _MockKeycastOAuth mockOAuth;
  late _MockAuthService mockAuthService;
  late _MockPendingVerificationService mockPendingVerification;

  setUp(() {
    mockOAuth = _MockKeycastOAuth();
    mockAuthService = _MockAuthService();
    mockPendingVerification = _MockPendingVerificationService();
    when(() => mockAuthService.isNip07Available).thenReturn(false);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Widget createTestWidget({String initialLocation = LoginOptionsScreen.path}) {
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
        theme: VineTheme.theme,
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Scaffold()),
            GoRoute(
              path: LoginOptionsScreen.path,
              builder: (_, state) => LoginOptionsScreen(
                initialEmail: state.uri.queryParameters['email'],
                initialError: state.uri.queryParameters['error'],
              ),
            ),
            GoRoute(
              path: '/import-key',
              builder: (_, _) => const Scaffold(body: Text('Key Import')),
            ),
            GoRoute(
              path: '/nostr-connect',
              builder: (_, _) => const Scaffold(body: Text('Nostr Connect')),
            ),
            GoRoute(
              path: '/verify-email',
              builder: (_, _) =>
                  const Scaffold(body: Text('Email Verification')),
            ),
            GoRoute(
              path: SupportCenterScreen.path,
              builder: (_, _) => const Scaffold(body: Text('Support Center')),
            ),
          ],
        ),
      ),
    );
  }

  group(LoginOptionsScreen, () {
    group('renders', () {
      testWidgets('displays Sign in title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == 'Sign in' &&
                widget.style?.fontSize == 28,
          ),
          findsOneWidget,
        );
      });

      testWidgets('prefills email and shows recovery error from query params', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            initialLocation:
                '${LoginOptionsScreen.path}?email=person%40example.com&error=This%20email%20is%20already%20registered.%20Please%20sign%20in%20instead.',
          ),
        );
        await tester.pumpAndSettle();

        final emailField = find.descendant(
          of: find.widgetWithText(DivineAuthTextField, 'Email'),
          matching: find.byType(TextField),
        );
        final emailTextField = tester.widget<TextField>(emailField);
        expect(emailTextField.controller?.text, 'person@example.com');

        expect(
          find.text(
            'This email is already registered. Please sign in instead.',
          ),
          findsOneWidget,
        );
        expect(
          _optionsHint(
            lookupAppLocalizations(const Locale('en')).authSignInOptionsHintCta,
          ),
          findsNothing,
        );
      });

      testWidgets('displays email field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Email'),
          findsOneWidget,
        );
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsOneWidget,
        );
      });

      testWidgets('wraps login fields in Form and AutofillGroup', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(DivineAuthTextField, 'Email');
        final passwordField = find.widgetWithText(
          DivineAuthTextField,
          'Password',
        );

        expect(
          find.ancestor(of: emailField, matching: find.byType(Form)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: emailField, matching: find.byType(AutofillGroup)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: passwordField, matching: find.byType(Form)),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: passwordField,
            matching: find.byType(AutofillGroup),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays sign in button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineButton), findsAtLeastNWidgets(1));
      });

      testWidgets('displays forgot password link', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Forgot password?'), findsOneWidget);
      });

      testWidgets('displays contact support link', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Contact support'),
          findsOneWidget,
        );
      });

      testWidgets('displays Import Nostr key button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Import Nostr key'),
          findsOneWidget,
        );
      });

      testWidgets('displays Connect with a signer app button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Connect with a signer app'),
          findsOneWidget,
        );
      });

      testWidgets(
        'hides browser-extension button when NIP-07 is unavailable',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          expect(
            find.widgetWithText(
              DivineButton,
              'Sign in with browser extension',
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows browser-extension button when NIP-07 is available',
        (tester) async {
          when(() => mockAuthService.isNip07Available).thenReturn(true);

          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          expect(
            find.widgetWithText(
              DivineButton,
              'Sign in with browser extension',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
      });

      testWidgets('displays info button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.info), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping info button shows info bottom sheet', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(_divineIcon(DivineIconName.info));
        await tester.pumpAndSettle();

        expect(find.text('Sign-in options'), findsOneWidget);
        expect(find.text('Email & Password'), findsOneWidget);
        expect(find.text('Signer App'), findsOneWidget);
      });

      testWidgets(
        'info sheet includes browser-extension entry when NIP-07 is available',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          when(() => mockAuthService.isNip07Available).thenReturn(true);

          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          await tester.tap(_divineIcon(DivineIconName.info));
          await tester.pumpAndSettle();

          await tester.scrollUntilVisible(
            find.text('Browser Extension'),
            120,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();

          expect(find.text('Browser Extension'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping browser-extension button calls connectWithNip07',
        (tester) async {
          when(() => mockAuthService.isNip07Available).thenReturn(true);
          when(
            () => mockAuthService.connectWithNip07(),
          ).thenAnswer((_) async => AuthResult.failure('extension declined'));

          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final button = find.widgetWithText(
            DivineButton,
            'Sign in with browser extension',
          );
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          verify(() => mockAuthService.connectWithNip07()).called(1);
        },
      );

      testWidgets('tapping forgot password shows dialog', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsOneWidget);
      });

      testWidgets('tapping contact support opens the Support Center', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, 'Contact support'));
        await tester.pumpAndSettle();

        expect(find.text('Support Center'), findsOneWidget);
      });

      testWidgets('failed password reset keeps dialog open without success', (
        tester,
      ) async {
        when(() => mockOAuth.sendPasswordResetEmail(any())).thenAnswer(
          (_) async => ForgotPasswordResult(success: false, error: 'API error'),
        );
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.text(l10n.authForgotPassword));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).last,
          'user@example.com',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);
        expect(find.text(l10n.authPasswordResetSent), findsNothing);
      });

      testWidgets('accepted password reset shows neutral confirmation', (
        tester,
      ) async {
        when(
          () => mockOAuth.sendPasswordResetEmail(any()),
        ).thenAnswer((_) async => ForgotPasswordResult(success: true));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.text(l10n.authForgotPassword));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).last,
          'user@example.com',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsNothing);
        expect(find.text(l10n.authPasswordResetSent), findsOneWidget);
      });

      testWidgets('calls headlessLogin on sign in tap with valid input', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessLoginResult(
              success: false,
              errorCode: 'test',
              errorDescription: 'test error',
            ),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter valid email and password
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

        // Tap sign in
        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockOAuth.headlessLogin(
            email: 'test@example.com',
            password: 'SecurePass123!',
            scope: 'policy:full',
          ),
        ).called(1);
      });

      testWidgets(
        'shows localized error + options hint on a failed sign in',
        (tester) async {
          when(
            () => mockOAuth.headlessLogin(
              email: any(named: 'email'),
              password: any(named: 'password'),
              scope: any(named: 'scope'),
            ),
          ).thenAnswer(
            (_) async => (
              HeadlessLoginResult(
                success: false,
                errorCode: 'INVALID_CREDENTIALS',
                errorDescription: 'Invalid email or password',
              ),
              'test-verifier',
            ),
          );

          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          // Hint is absent before any failure.
          expect(_optionsHint(l10n.authSignInOptionsHintCta), findsNothing);

          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Email'),
              matching: find.byType(TextField),
            ),
            'user@example.com',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Password'),
              matching: find.byType(TextField),
            ),
            'Password123!',
          );

          await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Localized copy, not the raw server message, and not the old
          // hardcoded "Login failed" literal.
          expect(
            find.text(l10n.authSignInErrorInvalidCredentials),
            findsOneWidget,
          );
          expect(find.text('Invalid email or password'), findsNothing);
          expect(find.text('Login failed'), findsNothing);
          // The nudge toward every sign-in option appears.
          expect(_optionsHint(l10n.authSignInOptionsHintCta), findsOneWidget);
        },
      );

      testWidgets('shows localized rate-limit copy on a 429 sign in', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessLoginResult(
              success: false,
              errorCode: 'TOO_MANY_ATTEMPTS',
              errorDescription: 'Too many sign-in attempts',
            ),
            'test-verifier',
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'user@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'Password123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(l10n.accountCredentialsRateLimited), findsOneWidget);
        expect(find.text('Too many sign-in attempts'), findsNothing);
        expect(find.text(l10n.authSignInErrorGeneric), findsNothing);
      });

      testWidgets(
        'tapping the options hint opens the sign-in options sheet',
        (tester) async {
          when(
            () => mockOAuth.headlessLogin(
              email: any(named: 'email'),
              password: any(named: 'password'),
              scope: any(named: 'scope'),
            ),
          ).thenAnswer(
            (_) async => (
              HeadlessLoginResult(
                success: false,
                errorCode: 'INVALID_CREDENTIALS',
                errorDescription: 'Invalid email or password',
              ),
              'test-verifier',
            ),
          );

          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Email'),
              matching: find.byType(TextField),
            ),
            'user@example.com',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Password'),
              matching: find.byType(TextField),
            ),
            'Password123!',
          );

          await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          await tester.tap(_optionsHint(l10n.authSignInOptionsHintCta));
          await tester.pumpAndSettle();

          expect(find.text(l10n.authSignInOptionsTitle), findsOneWidget);
          expect(find.text(l10n.authInfoEmailPasswordTitle), findsOneWidget);
        },
      );

      testWidgets('shows email validation error for empty form', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap sign in without entering anything
        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Validation errors should appear (email required, password required)
        verifyNever(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        );
      });
    });

    group('autofill', () {
      late StreamController<AuthState> authStates;
      late List<MethodCall> textInputCalls;

      late bool isAuthenticated;

      setUp(() {
        authStates = StreamController<AuthState>.broadcast();
        textInputCalls = <MethodCall>[];
        // The screen re-samples the flag on each auth event rather than
        // reading the enum off the stream, so the stub is what decides.
        isAuthenticated = false;
        when(
          () => mockAuthService.isAuthenticated,
        ).thenAnswer((_) => isAuthenticated);
        addTearDown(authStates.close);
      });

      /// Starts recording `flutter/textinput` traffic.
      ///
      /// Must run *after* `pumpWidget`: the test binding installs its own
      /// [TestTextInput] handler on that channel while bringing the widget
      /// tree up, which would otherwise replace this one.
      void recordTextInputCalls() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
              textInputCalls.add(call);
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.textInput, null),
        );
      }

      bool committedAutofill() => textInputCalls.any(
        (call) => call.method == 'TextInput.finishAutofillContext',
      );

      /// Pumps the screen with a controllable auth stream, then submits the
      /// email/password form. [mockOAuth] is stubbed so `headlessLogin` never
      /// completes, which holds the cubit mid-flight the way a real sign-in
      /// does while `AuthService` flips underneath it.
      Future<void> submitSignIn(WidgetTester tester) async {
        when(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer((_) => Completer<(HeadlessLoginResult, String)>().future);

        final widget = createTestWidget();
        when(
          () => mockAuthService.authStateStream,
        ).thenAnswer((_) => authStates.stream);
        await tester.pumpWidget(widget);
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
        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        recordTextInputCalls();
      }

      testWidgets(
        'commits the autofill context when the session authenticates, even '
        'though the redirect closes the cubit before it can emit success',
        (tester) async {
          await submitSignIn(tester);

          isAuthenticated = true;
          authStates.add(AuthState.authenticated);
          await tester.pump();

          expect(
            committedAutofill(),
            isTrue,
            reason:
                'The password-manager save prompt must not depend on '
                'DivineAuthSuccess, which the post-sign-in redirect races',
          );
        },
      );

      testWidgets(
        'does not commit the autofill context while unauthenticated',
        (
          tester,
        ) async {
          await submitSignIn(tester);

          authStates.add(AuthState.unauthenticated);
          await tester.pump();

          expect(committedAutofill(), isFalse);
        },
      );

      testWidgets('does not commit the autofill context without a submitted '
          'credential form', (tester) async {
        final widget = createTestWidget();
        when(
          () => mockAuthService.authStateStream,
        ).thenAnswer((_) => authStates.stream);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();
        recordTextInputCalls();

        // e.g. Amber or a browser extension authenticating from this screen.
        isAuthenticated = true;
        authStates.add(AuthState.authenticated);
        await tester.pump();

        expect(committedAutofill(), isFalse);
      });
    });
  });
}
