// ABOUTME: Tests for CreateAccountScreen
// ABOUTME: Verifies form rendering, submit interaction,
// ABOUTME: and skip button behavior

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _FakeSecureKeyContainer extends Fake implements SecureKeyContainer {}

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

class _SeededInviteGateBloc extends InviteGateBloc {
  _SeededInviteGateBloc({
    required super.inviteApiClient,
    required InviteGateState initialState,
  }) : _state = initialState;

  final InviteGateState _state;

  @override
  InviteGateState get state => _state;
}

void main() {
  late _MockKeycastOAuth mockOAuth;
  late _MockAuthService mockAuthService;
  late _MockPendingVerificationService mockPendingVerification;
  late _MockInviteApiClient mockInviteApiClient;

  setUpAll(() {
    registerFallbackValue(_FakeSecureKeyContainer());
  });

  setUp(() {
    mockOAuth = _MockKeycastOAuth();
    mockAuthService = _MockAuthService();
    mockPendingVerification = _MockPendingVerificationService();
    mockInviteApiClient = _MockInviteApiClient();

    when(
      () => mockAuthService.createAnonymousAccount(),
    ).thenAnswer((_) async {});
  });

  Widget createTestWidget({
    InviteAccessGrant? inviteAccessGrant,
    AnalyticsService? analyticsService,
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
      child: RepositoryProvider<InviteApiClient>.value(
        value: mockInviteApiClient,
        child: BlocProvider<InviteGateBloc>(
          create: (_) => inviteAccessGrant == null
              ? InviteGateBloc(inviteApiClient: mockInviteApiClient)
              : _SeededInviteGateBloc(
                  inviteApiClient: mockInviteApiClient,
                  initialState: InviteGateState(accessGrant: inviteAccessGrant),
                ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const CreateAccountScreen(),
          ),
        ),
      ),
    );
  }

  group(CreateAccountScreen, () {
    testWidgets('records invite registration entry once', (tester) async {
      final analytics = _RecordingRegistrationAnalyticsService();
      final grant = InviteAccessGrant(
        code: 'invite-code',
        validatedAt: DateTime(2026, 8, 20),
        creatorSlug: 'creator',
      );

      await tester.pumpWidget(
        createTestWidget(inviteAccessGrant: grant, analyticsService: analytics),
      );
      await tester.pump();

      expect(analytics.entryPoints, [
        ProductAnalyticsV2RegistrationEntryPoint.invite,
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

      testWidgets('shows creator invite context when present', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            inviteAccessGrant: InviteAccessGrant(
              code: 'LELE-PONS',
              validatedAt: DateTime(2026, 4, 24),
              creatorSlug: 'lele-pons',
              creatorDisplayName: 'Lele Pons',
              remaining: 842,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Lele Pons invited you'), findsOneWidget);
        expect(find.textContaining('842 invites left'), findsOneWidget);
      });

      testWidgets('displays skip button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextButton, 'Use Divine with no backup'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.authUseWithoutBackupButton),
          findsOneWidget,
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
          find.bySemanticsIdentifier(SemanticIds.authUseDeviceOnlyButton),
          findsOneWidget,
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
                  child: RepositoryProvider<InviteApiClient>.value(
                    value: mockInviteApiClient,
                    child: BlocProvider(
                      create: (_) =>
                          InviteGateBloc(inviteApiClient: mockInviteApiClient),
                      child: const CreateAccountScreen(),
                    ),
                  ),
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
                  child: RepositoryProvider<InviteApiClient>.value(
                    value: mockInviteApiClient,
                    child: BlocProvider(
                      create: (_) =>
                          InviteGateBloc(inviteApiClient: mockInviteApiClient),
                      child: const CreateAccountScreen(),
                    ),
                  ),
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  });
}
