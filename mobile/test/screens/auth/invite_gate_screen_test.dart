import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

const _resolvedInviteRequired = InviteAvailabilityState(
  hasResolved: true,
  serverMode: OnboardingMode.inviteCodeRequired,
  config: InviteClientConfig(
    mode: OnboardingMode.inviteCodeRequired,
    supportEmail: 'support@divine.video',
  ),
);

void main() {
  late _MockInviteApiClient mockInviteApiClient;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockInviteApiClient = _MockInviteApiClient();
  });

  Widget createTestWidget({
    InviteApiClient? inviteApiClient,
    InviteAvailabilityState? availabilitySeed = _resolvedInviteRequired,
    String initialLocation = WelcomeScreen.inviteGatePath,
  }) {
    final client = inviteApiClient ?? mockInviteApiClient;

    return RepositoryProvider<InviteApiClient>.value(
      value: client,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => InviteAvailabilityCubit(
              repository: InviteAvailabilityRepository(
                client: client,
                seed: availabilitySeed,
              ),
            )..load(),
          ),
          BlocProvider(create: (_) => InviteGateBloc(inviteApiClient: client)),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: GoRouter(
            initialLocation: initialLocation,
            routes: [
              GoRoute(
                path: WelcomeScreen.path,
                builder: (context, state) =>
                    const Scaffold(body: Text('Welcome')),
                routes: [
                  GoRoute(
                    path: 'invite',
                    builder: (context, state) => InviteGateScreen(
                      initialCode: state.uri.queryParameters['code'],
                      initialError: state.uri.queryParameters['error'],
                      initialErrorReason: InviteGateError.fromQuery(
                        state.uri.queryParameters['errorReason'],
                      ),
                      initialSourceSlug:
                          state.uri.queryParameters['sourceSlug'],
                    ),
                  ),
                  GoRoute(
                    path: 'create-account',
                    builder: (context, state) => Scaffold(
                      body: Column(
                        children: [
                          const Text('Create Account'),
                          if (state.uri.queryParameters['code']
                              case final code?)
                            Text('Code: $code'),
                          if (state.uri.queryParameters['error']
                              case final error?)
                            Text('Error: $error'),
                          if (state.uri.queryParameters['sourceSlug']
                              case final sourceSlug?)
                            Text('Source: $sourceSlug'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('InviteGateScreen', () {
    testWidgets('maps legacy waitlist-only mode to invite entry flow', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => InviteClientConfig(
          mode: parseOnboardingMode('waitlist_only'),
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          availabilitySeed: InviteAvailabilityState(
            hasResolved: true,
            serverMode: parseOnboardingMode('waitlist_only'),
            config: InviteClientConfig(
              mode: parseOnboardingMode('waitlist_only'),
              supportEmail: 'support@divine.video',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add your invite code'), findsOneWidget);
      expect(find.text('Join waitlist'), findsOneWidget);
    });

    testWidgets('bypasses the gate when client config is unavailable', (
      tester,
    ) async {
      when(
        () => mockInviteApiClient.getClientConfig(),
      ).thenThrow(const InviteApiException('unavailable'));

      await tester.pumpWidget(createTestWidget(availabilitySeed: null));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Add your invite code'), findsNothing);
    });

    testWidgets('bypasses the gate while client config is unresolved', (
      tester,
    ) async {
      final pendingConfig = Completer<InviteClientConfig>();
      when(
        () => mockInviteApiClient.getClientConfig(),
      ).thenAnswer((_) => pendingConfig.future);

      await tester.pumpWidget(
        createTestWidget(
          availabilitySeed: null,
          initialLocation:
              '${WelcomeScreen.inviteGatePath}?code=AB12-EF34'
              '&error=Invite%20problem&sourceSlug=creator',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Code: AB12-EF34'), findsOneWidget);
      expect(find.text('Error: Invite problem'), findsOneWidget);
      expect(find.text('Source: creator'), findsOneWidget);
      expect(find.text('Add your invite code'), findsNothing);
    });

    testWidgets('bypasses the gate when server onboarding mode is open', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.open,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(createTestWidget(availabilitySeed: null));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Add your invite code'), findsNothing);
    });

    testWidgets(
      'preview bypass continues past invite gate when server requires invites',
      (tester) async {
        final mockClient = _MockHttpClient();
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(
          jsonEncode({
            'onboarding_mode': 'invite_code_required',
            'support_email': 'support@divine.video',
          }),
        );
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => response);

        final previewInviteApiClient = InviteApiClient(
          baseUrl: 'https://invite.example.com',
          client: mockClient,
          forceOpenOnboarding: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            inviteApiClient: previewInviteApiClient,
            availabilitySeed: null,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsOneWidget);
      },
    );

    testWidgets('valid code continues to create account', (tester) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );
      when(() => mockInviteApiClient.validateCode(any())).thenAnswer(
        (_) async => const InviteValidationResult(
          valid: true,
          used: false,
          code: 'AB12-EF34',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add your invite code'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ab12ef34');
      await tester.tap(find.widgetWithText(DivineButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      verify(() => mockInviteApiClient.validateCode('AB12-EF34')).called(1);
    });

    testWidgets('code entry carries stable test anchors', (tester) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Account creation is gated here, so the E2E suite has to drive this
      // screen. Both anchors are on the critical path of every sign-up flow.
      expect(
        find.bySemanticsIdentifier(SemanticIds.authInviteCodeField),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(SemanticIds.authInviteSubmitButton),
        findsOneWidget,
      );
    });

    testWidgets('typing the fourth invite character shows dash hint', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ab12');
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.controller.text, 'AB12-');
    });

    // #3591: this used to assert `find.text('Invite problem')` — i.e. that the
    // ?error= query parameter rendered VERBATIM inside the auth error box, on
    // a pre-auth screen, in whatever words the link chose. The trusted in-app
    // recovery flow uses a separate allowlisted reason
    // parameter. The signal survives; attacker-controlled payload does not.
    testWidgets(
      'renders a generic error for an inbound ?error= link, never the '
      'text the link chose',
      (tester) async {
        when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
          (_) async => const InviteClientConfig(
            mode: OnboardingMode.inviteCodeRequired,
            supportEmail: 'support@divine.video',
          ),
        );

        await tester.pumpWidget(
          RepositoryProvider<InviteApiClient>.value(
            value: mockInviteApiClient,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => InviteAvailabilityCubit(
                    repository: InviteAvailabilityRepository(
                      client: mockInviteApiClient,
                      seed: _resolvedInviteRequired,
                    ),
                  )..load(),
                ),
                BlocProvider(
                  create: (_) =>
                      InviteGateBloc(inviteApiClient: mockInviteApiClient),
                ),
              ],
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                routerConfig: GoRouter(
                  initialLocation:
                      '${WelcomeScreen.inviteGatePath}?code=AB12-EF34'
                      '&error=Invite%20problem',
                  routes: [
                    GoRoute(
                      path: WelcomeScreen.path,
                      builder: (context, state) =>
                          const Scaffold(body: Text('Welcome')),
                      routes: [
                        GoRoute(
                          path: 'invite',
                          builder: (context, state) => InviteGateScreen(
                            initialCode: state.uri.queryParameters['code'],
                            initialError: state.uri.queryParameters['error'],
                            initialSourceSlug:
                                state.uri.queryParameters['sourceSlug'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.authInviteGateErrorUnknown), findsOneWidget);
        expect(find.text('Invite problem'), findsNothing);
        expect(find.text(l10n.authAddInviteCode), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets('preserves a trusted in-app recovery reason', (tester) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      final location = WelcomeScreen.inviteGatePathWithCode(
        'AB12-EF34',
        errorReason: InviteGateError.inviteUnavailable,
      );
      await tester.pumpWidget(createTestWidget(initialLocation: location));
      await tester.pumpAndSettle();

      expect(find.text(l10n.authInviteGateErrorUnavailable), findsOneWidget);
      expect(find.text(l10n.authInviteGateErrorUnknown), findsNothing);
    });

    testWidgets('preserves creator source slug when joining waitlist', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );
      when(
        () => mockInviteApiClient.joinWaitlist(
          contact: any(named: 'contact'),
          sourceSlug: any(named: 'sourceSlug'),
          newsletterOptIn: any(named: 'newsletterOptIn'),
        ),
      ).thenAnswer(
        (_) async =>
            const WaitlistJoinResult(id: 'waitlist-entry-1', message: 'Joined'),
      );

      await tester.pumpWidget(
        RepositoryProvider<InviteApiClient>.value(
          value: mockInviteApiClient,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => InviteAvailabilityCubit(
                  repository: InviteAvailabilityRepository(
                    client: mockInviteApiClient,
                    seed: _resolvedInviteRequired,
                  ),
                )..load(),
              ),
              BlocProvider(
                create: (_) =>
                    InviteGateBloc(inviteApiClient: mockInviteApiClient),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                initialLocation:
                    '${WelcomeScreen.inviteGatePath}?code=LELE-PONS'
                    '&error=This%20creator%27s%20invites%20are%20full'
                    '&sourceSlug=lele-pons',
                routes: [
                  GoRoute(
                    path: WelcomeScreen.path,
                    builder: (context, state) =>
                        const Scaffold(body: Text('Welcome')),
                    routes: [
                      GoRoute(
                        path: 'invite',
                        builder: (context, state) => InviteGateScreen(
                          initialCode: state.uri.queryParameters['code'],
                          initialError: state.uri.queryParameters['error'],
                          initialSourceSlug:
                              state.uri.queryParameters['sourceSlug'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, 'Join waitlist'));
      await tester.pumpAndSettle();
      expect(find.byType(DivineCheckbox), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'fan@example.com');
      await tester.tap(find.widgetWithText(DivineButton, 'Join waitlist').last);
      await tester.pumpAndSettle();

      verify(
        () => mockInviteApiClient.joinWaitlist(
          contact: 'fan@example.com',
          sourceSlug: 'lele-pons',
          newsletterOptIn: true,
        ),
      ).called(1);
    });

    testWidgets('passes newsletterOptIn false when checkbox is unchecked', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );
      when(
        () => mockInviteApiClient.joinWaitlist(
          contact: any(named: 'contact'),
          sourceSlug: any(named: 'sourceSlug'),
          newsletterOptIn: any(named: 'newsletterOptIn'),
        ),
      ).thenAnswer(
        (_) async =>
            const WaitlistJoinResult(id: 'waitlist-entry-2', message: 'Joined'),
      );

      await tester.pumpWidget(
        RepositoryProvider<InviteApiClient>.value(
          value: mockInviteApiClient,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => InviteAvailabilityCubit(
                  repository: InviteAvailabilityRepository(
                    client: mockInviteApiClient,
                    seed: _resolvedInviteRequired,
                  ),
                )..load(),
              ),
              BlocProvider(
                create: (_) =>
                    InviteGateBloc(inviteApiClient: mockInviteApiClient),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                initialLocation:
                    '${WelcomeScreen.inviteGatePath}?code=LELE-PONS'
                    '&error=This%20creator%27s%20invites%20are%20full'
                    '&sourceSlug=lele-pons',
                routes: [
                  GoRoute(
                    path: WelcomeScreen.path,
                    builder: (context, state) =>
                        const Scaffold(body: Text('Welcome')),
                    routes: [
                      GoRoute(
                        path: 'invite',
                        builder: (context, state) => InviteGateScreen(
                          initialCode: state.uri.queryParameters['code'],
                          initialError: state.uri.queryParameters['error'],
                          initialSourceSlug:
                              state.uri.queryParameters['sourceSlug'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, 'Join waitlist'));
      await tester.pumpAndSettle();
      expect(find.byType(DivineCheckbox), findsOneWidget);
      await tester.tap(find.text(l10n.authJoinWaitlistNewsletterOptIn));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'fan@example.com');
      await tester.tap(find.widgetWithText(DivineButton, 'Join waitlist').last);
      await tester.pumpAndSettle();

      verify(
        () => mockInviteApiClient.joinWaitlist(
          contact: 'fan@example.com',
          sourceSlug: 'lele-pons',
          // The explicit false value is the opt-in behavior under verification.
          // ignore: avoid_redundant_argument_values
          newsletterOptIn: false,
        ),
      ).called(1);
    });
  });
}
