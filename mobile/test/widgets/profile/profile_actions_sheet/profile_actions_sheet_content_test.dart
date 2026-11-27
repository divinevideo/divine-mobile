// ABOUTME: Widget tests for ProfileActionsSheetContent
// ABOUTME: Verifies prompt rendering, state transitions, and dismiss behavior

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/go_router.dart';

class _MockEmailConfirmationCubit extends MockCubit<EmailConfirmationState>
    implements EmailConfirmationCubit {}

void main() {
  group(ProfileActionsSheetContent, () {
    Widget buildApp({
      required List<ProfileActionType> actions,
      void Function(ProfileActionType action)? onMaybeLater,
      MockGoRouter? goRouter,
      EmailConfirmationCubit? emailConfirmationCubit,
    }) {
      // The button sits in a nested navigator, like a tab of the app shell,
      // so a sheet shown on the nearest navigator would stay inside it.
      final app = ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    unawaited(
                      showProfileActionsSheet(
                        context: context,
                        actions: actions,
                        onMaybeLater: onMaybeLater,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      final scoped = emailConfirmationCubit == null
          ? app
          : BlocProvider<EmailConfirmationCubit>.value(
              value: emailConfirmationCubit,
              child: app,
            );
      if (goRouter == null) return scoped;
      return MockGoRouterProvider(goRouter: goRouter, child: scoped);
    }

    group('presentation', () {
      testWidgets('opens on the root navigator, above the tab shell', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildApp(actions: [ProfileActionType.completeProfile]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final rootNavigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        expect(
          Navigator.of(tester.element(find.byType(ProfileActionsSheetContent))),
          same(rootNavigator),
        );
      });

      testWidgets('holds the bottom-sheet video owner while it is open', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildApp(actions: [ProfileActionType.completeProfile]),
        );
        final overlay = ProviderScope.containerOf(
          tester.element(find.text('Open')),
          listen: false,
        );
        expect(
          overlay.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          overlay.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(
          find.text(
            lookupAppLocalizations(const Locale('en')).profileMaybeLaterLabel,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileActionsSheetContent), findsNothing);
        expect(
          overlay.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      });
    });

    group('primary action', () {
      late MockGoRouter goRouter;

      setUp(() {
        goRouter = MockGoRouter();
        when(() => goRouter.push<void>(any())).thenAnswer((_) async {});
      });

      final l10n = lookupAppLocalizations(const Locale('en'));
      final destinations = [
        (
          action: ProfileActionType.accountRestricted,
          title: l10n.profileAccountRestricted,
          primaryLabel: l10n.accountStatusTitle,
          route: AccountStatusScreen.path,
        ),
        (
          action: ProfileActionType.secureAccount,
          title: l10n.profileSecureYourAccount,
          primaryLabel: l10n.profileSecurePrimaryButton,
          route: SecureAccountScreen.path,
        ),
        (
          action: ProfileActionType.completeProfile,
          title: l10n.profileCompleteYourProfile,
          primaryLabel: l10n.profileCompletePrimaryButton,
          route: ProfileSetupScreen.setupPath,
        ),
        (
          action: ProfileActionType.addEmail,
          title: l10n.emailConfirmationAddEmailTitle,
          primaryLabel: l10n.emailConfirmationAddEmailButton,
          route: const ChangeEmailRouteData().location,
        ),
      ];

      for (final destination in destinations) {
        testWidgets('${destination.action.name} closes the sheet and opens '
            '${destination.route}', (tester) async {
          await tester.pumpWidget(
            buildApp(actions: [destination.action], goRouter: goRouter),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          await tester.tap(find.text(destination.primaryLabel));
          await tester.pumpAndSettle();

          expect(find.text(destination.title), findsNothing);
          verify(() => goRouter.push<void>(destination.route)).called(1);
        });
      }
    });

    group('secureAccount only', () {
      testWidgets('renders secure account prompt', (tester) async {
        await tester.pumpWidget(
          buildApp(actions: [ProfileActionType.secureAccount]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Secure Your Account'), findsOneWidget);
        expect(find.text('Add Email & Password'), findsOneWidget);
        expect(find.text('Maybe Later'), findsOneWidget);
        expect(
          find.text(
            'Add email & password to recover your account on any device',
          ),
          findsOneWidget,
        );
      });

      testWidgets('Maybe Later dismisses sheet when only action', (
        tester,
      ) async {
        final dismissed = <ProfileActionType>[];
        await tester.pumpWidget(
          buildApp(
            actions: [ProfileActionType.secureAccount],
            onMaybeLater: dismissed.add,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Maybe Later'));
        await tester.pumpAndSettle();

        // Sheet should be dismissed
        expect(find.text('Secure Your Account'), findsNothing);
        expect(dismissed, [ProfileActionType.secureAccount]);
      });
    });

    group('confirmEmail', () {
      late _MockEmailConfirmationCubit emailConfirmationCubit;
      const account =
          'a3c1e0b6f7d2948e5c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d4c';
      const email = 'you@example.com';

      setUp(() {
        emailConfirmationCubit = _MockEmailConfirmationCubit();
        when(() => emailConfirmationCubit.state).thenReturn(
          const EmailConfirmationState(
            account: account,
            status: EmailConfirmationStatus.unconfirmed,
            email: email,
          ),
        );
        when(
          () => emailConfirmationCubit.resend(account: account),
        ).thenAnswer((_) async {});
      });

      testWidgets('steps on to the next action once the email is confirmed', (
        tester,
      ) async {
        final states = StreamController<EmailConfirmationState>();
        addTearDown(states.close);
        const unconfirmed = EmailConfirmationState(
          account: account,
          status: EmailConfirmationStatus.unconfirmed,
          email: email,
        );
        whenListen(
          emailConfirmationCubit,
          states.stream,
          initialState: unconfirmed,
        );
        await tester.pumpWidget(
          buildApp(
            actions: [
              ProfileActionType.confirmEmail,
              ProfileActionType.completeProfile,
            ],
            emailConfirmationCubit: emailConfirmationCubit,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.emailConfirmationTitle), findsOneWidget);

        states.add(
          const EmailConfirmationState(
            account: account,
            status: EmailConfirmationStatus.confirmed,
            email: email,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.emailConfirmationTitle), findsNothing);
        expect(find.text(l10n.profileCompleteYourProfile), findsOneWidget);
      });

      testWidgets('names the address waiting for confirmation', (tester) async {
        await tester.pumpWidget(
          buildApp(
            actions: [ProfileActionType.confirmEmail],
            emailConfirmationCubit: emailConfirmationCubit,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.emailConfirmationTitle), findsOneWidget);
        expect(
          find.text(l10n.emailConfirmationProfileSubtitle(email)),
          findsOneWidget,
        );
      });

      testWidgets('gives instructions when the address is unknown', (
        tester,
      ) async {
        when(() => emailConfirmationCubit.state).thenReturn(
          const EmailConfirmationState(
            account: account,
            status: EmailConfirmationStatus.unconfirmed,
          ),
        );

        await tester.pumpWidget(
          buildApp(
            actions: [ProfileActionType.confirmEmail],
            emailConfirmationCubit: emailConfirmationCubit,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.emailConfirmationCheckInbox), findsOneWidget);
        expect(
          find.text(l10n.emailConfirmationProfileSubtitle('')),
          findsNothing,
        );
        expect(find.text(l10n.emailConfirmationResendButton), findsOneWidget);
      });

      testWidgets('shows resend feedback inside the open sheet', (
        tester,
      ) async {
        final states = StreamController<EmailConfirmationState>();
        addTearDown(states.close);
        final initial = emailConfirmationCubit.state;
        whenListen(
          emailConfirmationCubit,
          states.stream,
          initialState: initial,
        );
        await tester.pumpWidget(
          buildApp(
            actions: [ProfileActionType.confirmEmail],
            emailConfirmationCubit: emailConfirmationCubit,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.emailConfirmationResendButton));
        states.add(
          initial.copyWith(resendStatus: EmailConfirmationResendStatus.failed),
        );
        await tester.pumpAndSettle();

        verify(() => emailConfirmationCubit.resend(account: account)).called(1);
        expect(find.text(l10n.emailConfirmationTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ProfileActionsSheetContent),
            matching: find.text(l10n.emailConfirmationResendFailed),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.emailConfirmationResendButton));
        states.add(
          initial.copyWith(resendStatus: EmailConfirmationResendStatus.sent),
        );
        await tester.pumpAndSettle();

        verify(() => emailConfirmationCubit.resend(account: account)).called(1);
        expect(find.text(l10n.emailConfirmationResendFailed), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ProfileActionsSheetContent),
            matching: find.text(l10n.emailConfirmationResendSent),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Maybe Later'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.emailConfirmationTitle), findsOneWidget);
        expect(find.text(l10n.emailConfirmationResendSent), findsNothing);
      });
    });

    group('completeProfile only', () {
      testWidgets('renders complete profile prompt', (tester) async {
        await tester.pumpWidget(
          buildApp(actions: [ProfileActionType.completeProfile]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Complete Your Profile'), findsOneWidget);
        expect(find.text('Update Your Profile'), findsOneWidget);
        expect(find.text('Maybe Later'), findsOneWidget);
        expect(
          find.text('Add your name, bio, and picture to get started'),
          findsOneWidget,
        );
      });

      testWidgets('Maybe Later dismisses sheet when only action', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildApp(actions: [ProfileActionType.completeProfile]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Maybe Later'));
        await tester.pumpAndSettle();

        expect(find.text('Complete Your Profile'), findsNothing);
      });
    });

    group('both actions', () {
      testWidgets('shows secureAccount first', (tester) async {
        await tester.pumpWidget(
          buildApp(
            actions: [
              ProfileActionType.secureAccount,
              ProfileActionType.completeProfile,
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Secure Your Account'), findsOneWidget);
        expect(find.text('Complete Your Profile'), findsNothing);
      });

      testWidgets('Maybe Later on first action transitions to second action', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildApp(
            actions: [
              ProfileActionType.secureAccount,
              ProfileActionType.completeProfile,
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap Maybe Later on first action
        await tester.tap(find.text('Maybe Later'));
        // Pump through the 600ms animation
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Second action should now be visible
        expect(find.text('Complete Your Profile'), findsOneWidget);
        expect(find.text('Update Your Profile'), findsOneWidget);
      });

      testWidgets('Maybe Later on second action dismisses sheet', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildApp(
            actions: [
              ProfileActionType.secureAccount,
              ProfileActionType.completeProfile,
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Skip to second action
        await tester.tap(find.text('Maybe Later'));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Dismiss second action
        await tester.tap(find.text('Maybe Later'));
        await tester.pumpAndSettle();

        // Sheet should be fully dismissed
        expect(find.text('Complete Your Profile'), findsNothing);
        expect(find.text('Secure Your Account'), findsNothing);
      });
    });

    group('becomeSupporter', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      late SupporterRepository repository;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        repository = SupporterRepository(
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          validator: StubEntitlementValidator(),
          prefs: await SharedPreferences.getInstance(),
        );
        addTearDown(repository.dispose);
      });

      Widget buildSupporterApp({
        required List<ProfileActionType> actions,
        void Function(ProfileActionType action)? onMaybeLater,
      }) => ProviderScope(
        overrides: [
          supporterRepositoryProvider.overrideWithValue(repository),
          supporterStoreBillingAvailableProvider.overrideWithValue(true),
        ],
        child: buildApp(actions: actions, onMaybeLater: onMaybeLater),
      );

      testWidgets('opens the tall sheet on the root navigator too', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSupporterApp(actions: [ProfileActionType.becomeSupporter]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final rootNavigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        expect(
          Navigator.of(tester.element(find.byType(ProfileActionsSheetContent))),
          same(rootNavigator),
        );
      });

      group('sheet size', () {
        double sheetHeightFraction(WidgetTester tester) {
          final screen =
              tester.view.physicalSize / tester.view.devicePixelRatio;
          return tester.getSize(find.byType(VineBottomSheet)).height /
              screen.height;
        }

        testWidgets('opens tall when it starts on the supporter invitation', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSupporterApp(actions: [ProfileActionType.becomeSupporter]),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(
            sheetHeightFraction(tester),
            moreOrLessEquals(
              ProfileActionsSheetSizing.tallInitial,
              epsilon: 0.05,
            ),
          );
        });

        testWidgets('stays sized to a short prompt', (tester) async {
          await tester.pumpWidget(
            buildSupporterApp(
              actions: [
                ProfileActionType.completeProfile,
                ProfileActionType.becomeSupporter,
              ],
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(sheetHeightFraction(tester), lessThan(0.8));
        });
      });

      testWidgets('shows the Supporter screen content in the sheet', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSupporterApp(actions: [ProfileActionType.becomeSupporter]),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(SupporterContent), findsOneWidget);
        expect(find.text(l10n.supporterHeroTitle), findsOneWidget);
        expect(find.text(l10n.supporterRestorePurchases), findsOneWidget);
        expect(find.text(l10n.profileMaybeLaterLabel), findsOneWidget);
      });

      testWidgets('Maybe Later reports the dismissal and closes the sheet', (
        tester,
      ) async {
        final dismissed = <ProfileActionType>[];
        await tester.pumpWidget(
          buildSupporterApp(
            actions: [ProfileActionType.becomeSupporter],
            onMaybeLater: dismissed.add,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.profileMaybeLaterLabel));
        await tester.pumpAndSettle();

        expect(find.byType(SupporterContent), findsNothing);
        expect(dismissed, [ProfileActionType.becomeSupporter]);
      });

      testWidgets('comes after a pending setup action', (tester) async {
        await tester.pumpWidget(
          buildSupporterApp(
            actions: [
              ProfileActionType.completeProfile,
              ProfileActionType.becomeSupporter,
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.profileCompleteYourProfile), findsOneWidget);
        expect(find.byType(SupporterContent), findsNothing);

        await tester.tap(find.text(l10n.profileMaybeLaterLabel));
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileCompleteYourProfile), findsNothing);
        expect(find.byType(SupporterContent), findsOneWidget);
      });
    });
  });
}
