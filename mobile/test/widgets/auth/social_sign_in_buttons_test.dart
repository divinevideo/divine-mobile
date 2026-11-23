// ABOUTME: Tests for the Google/Apple sign-in buttons: what they offer, what a
// ABOUTME: tap does, and how a failure reaches the person.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show SocialProvider;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/social_sign_in/social_sign_in_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_sign_in_providers.dart';
import 'package:openvine/repositories/social_sign_in_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/auth/social_sign_in_buttons.dart';

class _MockSocialSignInCubit extends MockCubit<SocialSignInState>
    implements SocialSignInCubit {}

class _MockRepository extends Mock implements SocialSignInRepository {}

class _MockAuthService extends Mock implements AuthService {}

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget child) => MaterialApp(
  theme: VineTheme.theme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

DivineButton _button(WidgetTester tester, String label) =>
    tester.widget<DivineButton>(find.widgetWithText(DivineButton, label));

void main() {
  group(SocialSignInButtons, () {
    late _MockSocialSignInCubit cubit;

    const bothProviders = SocialSignInState(
      availableProviders: [SocialProvider.apple, SocialProvider.google],
    );

    setUp(() {
      cubit = _MockSocialSignInCubit();
      when(() => cubit.signIn(any())).thenAnswer((_) async {});
    });

    setUpAll(() => registerFallbackValue(SocialProvider.google));

    Future<void> pumpButtons(WidgetTester tester) => tester.pumpWidget(
      _app(
        BlocProvider<SocialSignInCubit>.value(
          value: cubit,
          child: const SocialSignInButtons(),
        ),
      ),
    );

    group('renders', () {
      testWidgets('nothing when no provider is offered', (tester) async {
        when(
          () => cubit.state,
        ).thenReturn(const SocialSignInState(availableProviders: []));

        await pumpButtons(tester);

        expect(find.byType(DivineButton), findsNothing);
      });

      testWidgets('Apple above Google', (tester) async {
        when(() => cubit.state).thenReturn(bothProviders);

        await pumpButtons(tester);

        final apple = tester.getTopLeft(
          find.text(_l10n.authContinueWithApple),
        );
        final google = tester.getTopLeft(
          find.text(_l10n.authContinueWithGoogle),
        );
        expect(apple.dy, lessThan(google.dy));
      });

      testWidgets('a spinner on the running provider and no other taps', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          bothProviders.copyWith(
            status: SocialSignInStatus.inProgress,
            activeProvider: SocialProvider.google,
          ),
        );

        await pumpButtons(tester);

        expect(_button(tester, _l10n.authContinueWithGoogle).isLoading, isTrue);
        expect(_button(tester, _l10n.authContinueWithApple).onPressed, isNull);
      });
    });

    group('interactions', () {
      testWidgets('signs in with the tapped provider', (tester) async {
        when(() => cubit.state).thenReturn(bothProviders);

        await pumpButtons(tester);
        await tester.tap(find.text(_l10n.authContinueWithGoogle));

        verify(() => cubit.signIn(SocialProvider.google)).called(1);
      });

      testWidgets('explains a failure in a snackbar', (tester) async {
        whenListen(
          cubit,
          Stream.value(
            bothProviders.copyWith(
              status: SocialSignInStatus.failed,
              activeProvider: SocialProvider.google,
              failureReason: SocialSignInFailureReason.accountLinkRequired,
            ),
          ),
          initialState: bothProviders,
        );

        await pumpButtons(tester);
        await tester.pump();

        expect(
          find.text(_l10n.authSocialSignInAccountLinkRequired),
          findsOneWidget,
        );
      });
    });
  });

  group(SocialSignInScope, () {
    late _MockRepository repository;

    setUp(() => repository = _MockRepository());

    setUpAll(() => registerFallbackValue(SocialProvider.google));

    Future<void> pumpScope(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialSignInRepositoryProvider.overrideWithValue(repository),
          authServiceProvider.overrideWithValue(_MockAuthService()),
        ],
        child: _app(const SocialSignInScope(child: SocialSignInButtons())),
      ),
    );

    testWidgets('offers the providers this device supports', (tester) async {
      when(() => repository.isAvailable(any())).thenReturn(true);

      await pumpScope(tester);

      expect(find.text(_l10n.authContinueWithApple), findsOneWidget);
      expect(find.text(_l10n.authContinueWithGoogle), findsOneWidget);
    });

    testWidgets('offers nothing on a device that supports neither', (
      tester,
    ) async {
      when(() => repository.isAvailable(any())).thenReturn(false);

      await pumpScope(tester);

      expect(find.byType(DivineButton), findsNothing);
    });
  });

  group(socialSignInFailureMessage, () {
    test('has copy for every failure', () {
      final messages = {
        for (final reason in SocialSignInFailureReason.values)
          socialSignInFailureMessage(_l10n, reason),
      };

      expect(messages, hasLength(SocialSignInFailureReason.values.length));
      expect(messages, everyElement(isNotEmpty));
    });
  });
}
