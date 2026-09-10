// ABOUTME: Widget tests for ProfileActionsSheetContent
// ABOUTME: Verifies prompt rendering, state transitions, and dismiss behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';

void main() {
  group(ProfileActionsSheetContent, () {
    Widget buildApp({
      required List<ProfileActionType> actions,
      void Function(ProfileActionType action)? onMaybeLater,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  VineBottomSheet.show<void>(
                    context: context,
                    scrollable: false,
                    showHeaderDivider: false,
                    body: ProfileActionsSheetContent(
                      actions: actions,
                      onMaybeLater: onMaybeLater,
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
    }

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
