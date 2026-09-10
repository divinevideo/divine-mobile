import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';
import 'package:openvine/screens/auth/invite_protected_create_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

void main() {
  late _MockInviteApiClient mockInviteApiClient;
  late _MockKeycastOAuth mockOAuth;
  late _MockPendingVerificationService mockPendingVerificationService;
  late _MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockInviteApiClient = _MockInviteApiClient();
    mockOAuth = _MockKeycastOAuth();
    mockPendingVerificationService = _MockPendingVerificationService();
    mockAuthService = _MockAuthService();

    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Widget createTestWidget({
    bool hasAccessGrant = false,
    InviteApiClient? inviteApiClient,
    String initialLocation = WelcomeScreen.createAccountPath,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerificationService,
        ),
      ],
    );
    final client = inviteApiClient ?? mockInviteApiClient;
    final inviteGateBloc = InviteGateBloc(inviteApiClient: client);

    if (hasAccessGrant) {
      inviteGateBloc.add(
        InviteGateAccessGranted(
          InviteAccessGrant(
            code: 'AB12-EF34',
            validatedAt: DateTime(2026, 3, 6),
          ),
        ),
      );
    }

    return UncontrolledProviderScope(
      container: container,
      child: RepositoryProvider<InviteApiClient>.value(
        value: client,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => InviteAvailabilityCubit(
                repository: InviteAvailabilityRepository(client: client),
              )..load(),
            ),
            BlocProvider.value(value: inviteGateBloc),
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
                      builder: (context, state) => Scaffold(
                        body: Column(
                          children: [
                            const Text('Invite Gate'),
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
                    GoRoute(
                      path: 'create-account',
                      builder: (context, state) =>
                          InviteProtectedCreateAccountScreen(
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
  }

  group('InviteProtectedCreateAccountScreen', () {
    testWidgets('redirects to invite gate without access grant', (
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

      expect(find.text('Invite Gate'), findsOneWidget);
    });

    testWidgets('preserves a deep-linked code when invites become required', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          initialLocation:
              '${WelcomeScreen.createAccountPath}?code=AB12-EF34'
              '&error=Invite%20problem&sourceSlug=creator',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invite Gate'), findsOneWidget);
      expect(find.text('Code: AB12-EF34'), findsOneWidget);
      expect(find.text('Error: Invite problem'), findsOneWidget);
      expect(find.text('Source: creator'), findsOneWidget);
    });

    testWidgets('allows create-account when server onboarding mode is open', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.open,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(DivineAuthTextField, 'Email'), findsOneWidget);
    });

    testWidgets('allows create-account while client config is unresolved', (
      tester,
    ) async {
      final pendingConfig = Completer<InviteClientConfig>();
      when(
        () => mockInviteApiClient.getClientConfig(),
      ).thenAnswer((_) => pendingConfig.future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.widgetWithText(DivineAuthTextField, 'Email'), findsOneWidget);
    });

    testWidgets(
      'preview bypass allows direct create-account access without invite grant',
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
          createTestWidget(inviteApiClient: previewInviteApiClient),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Email'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows create-account flow when access grant exists', (
      tester,
    ) async {
      when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(createTestWidget(hasAccessGrant: true));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(DivineAuthTextField, 'Email'), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, 'Create account'),
        findsOneWidget,
      );
    });
  });
}
