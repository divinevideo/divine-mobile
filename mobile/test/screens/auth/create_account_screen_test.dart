// ABOUTME: Tests for CreateAccountScreen
// ABOUTME: Verifies form rendering, submit interaction,
// ABOUTME: and skip button behavior

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

import '../../helpers/autofill_context_mock.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _RecordingRegistrationAnalyticsService extends AnalyticsService {
  _RecordingRegistrationAnalyticsService()
    : super(backgroundActivityManager: BackgroundActivityManager());

  final entryPoints = <ProductAnalyticsV2RegistrationEntryPoint>[];

  @override
  Future<String?> recordRegistrationStarted({
    required ProductAnalyticsV2RegistrationEntryPoint entryPoint,
  }) async {
    entryPoints.add(entryPoint);
    return 'registration-id';
  }
}

void main() {
  late _MockKeycastOAuth mockOAuth;
  late _MockAuthService mockAuthService;
  late _MockPendingVerificationService mockPendingVerification;

  setUp(() {
    mockOAuth = _MockKeycastOAuth();
    mockAuthService = _MockAuthService();
    mockPendingVerification = _MockPendingVerificationService();

    when(
      () => mockAuthService.createAnonymousAccount(),
    ).thenAnswer((_) async {});
  });

  Widget createTestWidget({
    AnalyticsService? analyticsService,
    TextScaler? textScaler,
  }) {
    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(
          mockAuthService: mockAuthService,
          analyticsService:
              analyticsService ??
              AnalyticsService(
                backgroundActivityManager: BackgroundActivityManager(),
                disableNostrPublishing: true,
              ),
        ),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerification,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const CreateAccountScreen(),
      ),
    );
  }

  group(CreateAccountScreen, () {
    testWidgets('records landing registration entry once', (tester) async {
      final analytics = _RecordingRegistrationAnalyticsService();

      await tester.pumpWidget(
        createTestWidget(analyticsService: analytics),
      );
      await tester.pump();

      expect(analytics.entryPoints, [
        ProductAnalyticsV2RegistrationEntryPoint.landing,
      ]);
    });

    group('renders', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == 'Create account' &&
                widget.style?.fontSize == 32,
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
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

      testWidgets('displays confirm password field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Confirm password'),
          findsOneWidget,
        );
      });

      testWidgets('displays create account button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Create account'),
          findsOneWidget,
        );
      });

      testWidgets('displays skip button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextButton, 'Use Divine with no backup'),
          findsOneWidget,
        );
        // The identifier has to sit on the node that also announces and
        // activates the button. A bare Semantics wrapper over a TextButton
        // yields a separate, non-focusable node that iOS never exposes as an
        // accessibility element, so `find.bySemanticsIdentifier` alone would
        // stay green while Maestro's `tapOn: id:` found nothing on device.
        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier(SemanticIds.authUseWithoutBackupButton),
          ),
          isSemantics(
            identifier: SemanticIds.authUseWithoutBackupButton,
            label: 'Use Divine with no backup',
            isButton: true,
            hasTapAction: true,
          ),
        );
      });

      testWidgets('displays dog sticker', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsAtLeast(1));
      });
    });

    group('interactions', () {
      testWidgets('tapping skip shows confirmation bottom sheet', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.widgetWithText(
          TextButton,
          'Use Divine with no backup',
        );
        await tester.ensureVisible(skipButton);
        await tester.pumpAndSettle();
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        expect(find.text('One last thing...'), findsOneWidget);
        expect(
          find.widgetWithText(DivineButton, 'Add email & password'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Use this device only'),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier(SemanticIds.authUseDeviceOnlyButton),
          ),
          isSemantics(
            identifier: SemanticIds.authUseDeviceOnlyButton,
            label: 'Use this device only',
            isButton: true,
            hasTapAction: true,
          ),
        );
      });

      testWidgets('tapping Use this device only calls createAnonymousAccount', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.widgetWithText(
          TextButton,
          'Use Divine with no backup',
        );
        await tester.ensureVisible(skipButton);
        await tester.pumpAndSettle();
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        final deviceOnlyButton = find.widgetWithText(
          TextButton,
          'Use this device only',
        );
        await tester.ensureVisible(deviceOnlyButton);
        await tester.pumpAndSettle();
        await tester.tap(deviceOnlyButton);
        // Use pump() instead of pumpAndSettle() because the loading
        // spinner animates indefinitely after createAnonymousAccount is called.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(() => mockAuthService.createAnonymousAccount()).called(1);
      });

      testWidgets(
        'tapping Add email & password dismisses sheet without skipping',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final skipButton = find.widgetWithText(
            TextButton,
            'Use Divine with no backup',
          );
          await tester.ensureVisible(skipButton);
          await tester.pumpAndSettle();
          await tester.tap(skipButton);
          await tester.pumpAndSettle();

          await tester.tap(
            find.widgetWithText(DivineButton, 'Add email & password'),
          );
          await tester.pumpAndSettle();

          expect(find.text('One last thing...'), findsNothing);
          verifyNever(() => mockAuthService.createAnonymousAccount());
        },
      );

      testWidgets(
        'calls TextInput.finishAutofillContext on $DivineAuthEmailVerification',
        (tester) async {
          final recorder = AutofillContextRecorder.install();

          // Return verification-required result so the cubit emits
          // DivineAuthEmailVerification.
          when(
            () => mockOAuth.headlessRegister(
              email: any(named: 'email'),
              password: any(named: 'password'),
              scope: any(named: 'scope'),
              marketingConsent: any(named: 'marketingConsent'),
              appVersion: any(named: 'appVersion'),
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
            ),
          ).thenAnswer((_) async {});

          // Build with a GoRouter so context.go() in the listener succeeds.
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => ProviderScope(
                  overrides: [
                    ...getStandardTestOverrides(
                      mockAuthService: mockAuthService,
                      analyticsService: AnalyticsService(
                        backgroundActivityManager: BackgroundActivityManager(),
                        disableNostrPublishing: true,
                      ),
                    ),
                    oauthClientProvider.overrideWithValue(mockOAuth),
                    pendingVerificationServiceProvider.overrideWithValue(
                      mockPendingVerification,
                    ),
                  ],
                  child: const CreateAccountScreen(),
                ),
              ),
              GoRoute(
                path: '/verify-email',
                builder: (_, _) => const Scaffold(),
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              theme: VineTheme.theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
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

          await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(recorder.didFinishAutofillContext, isTrue);
        },
      );

      testWidgets(
        'navigates to sign in when registration reports duplicate email',
        (tester) async {
          when(
            () => mockOAuth.headlessRegister(
              email: any(named: 'email'),
              password: any(named: 'password'),
              scope: any(named: 'scope'),
              marketingConsent: any(named: 'marketingConsent'),
              appVersion: any(named: 'appVersion'),
            ),
          ).thenAnswer(
            (_) async => (
              HeadlessRegisterResult.error(
                'This email is already registered.',
                code: 'CONFLICT',
              ),
              'test-verifier',
            ),
          );

          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => ProviderScope(
                  overrides: [
                    ...getStandardTestOverrides(
                      mockAuthService: mockAuthService,
                      analyticsService: AnalyticsService(
                        backgroundActivityManager: BackgroundActivityManager(),
                        disableNostrPublishing: true,
                      ),
                    ),
                    oauthClientProvider.overrideWithValue(mockOAuth),
                    pendingVerificationServiceProvider.overrideWithValue(
                      mockPendingVerification,
                    ),
                  ],
                  child: const CreateAccountScreen(),
                ),
              ),
              GoRoute(
                path: WelcomeScreen.loginOptionsPath,
                builder: (_, state) => Scaffold(
                  body: Text(
                    'login:${state.uri.queryParameters['email'] ?? ''}|'
                    'error:${state.uri.queryParameters['error'] ?? ''}',
                  ),
                ),
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              theme: VineTheme.theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();

          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Email'),
              matching: find.byType(TextField),
            ),
            'person@example.com',
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

          await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'login:person@example.com|error:'
              'This email is already registered. Please sign in instead.',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('blocks password mismatch before network submission', (
        tester,
      ) async {
        // Stub headlessRegister so submit proceeds
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
            marketingConsent: any(named: 'marketingConsent'),
            appVersion: any(named: 'appVersion'),
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

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );

        // Enter password
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

        await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text("Passwords don't match"), findsOneWidget);
        verifyNever(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
            marketingConsent: any(named: 'marketingConsent'),
            appVersion: any(named: 'appVersion'),
          ),
        );
      });

      testWidgets('blocks malformed email before network submission', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
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

        // Tap create account
        await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email'), findsOneWidget);
        verifyNever(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
            marketingConsent: any(named: 'marketingConsent'),
            appVersion: any(named: 'appVersion'),
          ),
        );
      });

      testWidgets('calls submit on create account tap', (tester) async {
        // Stub headlessRegister so submit proceeds
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
            marketingConsent: any(named: 'marketingConsent'),
            appVersion: any(named: 'appVersion'),
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

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );

        // Enter password
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        // Confirm password
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        // Tap create account
        await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify the cubit called headlessRegister (via submit)
        verify(
          () => mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            scope: 'policy:full',
            marketingConsent: false,
            appVersion: 'test',
          ),
        ).called(1);
      });

      // A duplicate register mints a second pending row with its own token,
      // killing the first email's link and orphaning the first keypair.
      // Measured in prod on 2026-08-10 (two registers 2.9s apart, one signup).
      testWidgets('double-tapping create account registers only once', (
        tester,
      ) async {
        final registered = Completer<(HeadlessRegisterResult, String)>();
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
            marketingConsent: any(named: 'marketingConsent'),
            appVersion: any(named: 'appVersion'),
          ),
        ).thenAnswer((_) => registered.future);

        await tester.pumpWidget(createTestWidget());
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

        final button = find.widgetWithText(DivineButton, 'Create account');
        await tester.tap(button);
        // No pump between the taps: the request is still in flight, which is
        // exactly when an impatient second tap lands.
        await tester.tap(button, warnIfMissed: false);
        await tester.pump();

        // The button must show it is busy. Without this the cubit guard alone
        // still swallows the second call, so a regression to an always-enabled
        // button would go unnoticed here.
        expect(
          find.descendant(
            of: find.byType(DivineButton),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        verify(
          () => mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            scope: 'policy:full',
            marketingConsent: false,
            appVersion: 'test',
          ),
        ).called(1);

        registered.complete((
          HeadlessRegisterResult(
            success: true,
            pubkey: 'test-pubkey',
            verificationRequired: false,
            email: 'test@example.com',
          ),
          'test-verifier',
        ));
        await tester.pumpAndSettle();
      });
    });

    group('marketing opt-in', () {
      DivineCheckbox optInCheckbox(WidgetTester tester) =>
          tester.widget<DivineCheckbox>(find.byType(DivineCheckbox));

      testWidgets('renders unchecked by default', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.authCreateAccountMarketingOptIn),
          findsOneWidget,
        );
        expect(optInCheckbox(tester).state, DivineCheckboxState.unselected);
      });

      testWidgets('checks when the user taps it', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.authCreateAccountMarketingOptIn));
        await tester.pumpAndSettle();

        expect(optInCheckbox(tester).state, DivineCheckboxState.selected);
      });

      testWidgets('renders without overflow at 2x text scale', (tester) async {
        await tester.pumpWidget(
          createTestWidget(textScaler: const TextScaler.linear(2)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.authCreateAccountMarketingOptIn),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });
  });
}
