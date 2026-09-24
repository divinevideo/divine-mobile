// ABOUTME: Widget tests for ProfileActionsSheetContent
// ABOUTME: Verifies prompt rendering, state transitions, and dismiss behavior

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';

import '../../../helpers/go_router.dart';

void main() {
  group(ProfileActionsSheetContent, () {
    Widget buildApp({
      required List<ProfileActionType> actions,
      void Function(ProfileActionType action)? onMaybeLater,
      MockGoRouter? goRouter,
    }) {
      final app = MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      showHeaderDivider: false,
                      body: ProfileActionsSheetContent(
                        actions: actions,
                        onMaybeLater: onMaybeLater,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      if (goRouter == null) return app;
      return MockGoRouterProvider(goRouter: goRouter, child: app);
    }

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
  });
}
