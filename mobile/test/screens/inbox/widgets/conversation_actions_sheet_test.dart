// ABOUTME: Widget tests for ConversationActionsSheet.
// ABOUTME: Verifies that all action tiles render and return the correct
// ABOUTME: ConversationAction when tapped.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/widgets/conversation_actions_sheet.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(ConversationActionsSheet, () {
    Widget buildSubject({
      required ValueChanged<ConversationAction?> onResult,
      bool isMuted = false,
      bool isBlocked = false,
      String displayName = 'Alice',
      bool isVanished = false,
      bool isGroup = false,
      bool canRemove = true,
      Locale? locale,
    }) {
      return testMaterialApp(
        locale: locale,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final result = await ConversationActionsSheet.show(
                    context,
                    displayName: displayName,
                    isVanished: isVanished,
                    isMuted: isMuted,
                    isBlocked: isBlocked,
                    isGroup: isGroup,
                    canRemove: canRemove,
                  );
                  onResult(result);
                },
                child: const Text('Show sheet'),
              ),
            );
          },
        ),
      );
    }

    group('renders', () {
      testWidgets('renders all four action tiles', (tester) async {
        await tester.pumpWidget(buildSubject(onResult: (_) {}));

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Mute conversation'), findsOneWidget);
        expect(find.text('Report Alice'), findsOneWidget);
        expect(find.text('Block Alice'), findsOneWidget);
        expect(find.text('Remove conversation'), findsOneWidget);
      });

      testWidgets('renders Unblock label when user is blocked', (tester) async {
        await tester.pumpWidget(
          buildSubject(onResult: (_) {}, isBlocked: true),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Unblock Alice'), findsOneWidget);
        expect(find.text('Block Alice'), findsNothing);
      });

      testWidgets('keeps safety actions with identity-neutral vanished copy', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            onResult: (_) {},
            displayName: 'Deleted account',
            isVanished: true,
          ),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.inboxActionReportVanishedAccount),
          findsOneWidget,
        );
        expect(
          find.text(l10n.inboxActionBlockVanishedAccount),
          findsOneWidget,
        );
        expect(
          find.text(l10n.inboxActionReport(l10n.profileDeletedAccountName)),
          findsNothing,
        );
        expect(
          find.text(l10n.inboxActionBlock(l10n.profileDeletedAccountName)),
          findsNothing,
        );
      });

      testWidgets('localizes vanished actions as complete sentences', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('fil'));
        await tester.pumpWidget(
          buildSubject(
            onResult: (_) {},
            displayName: 'Deleted account',
            isVanished: true,
            locale: const Locale('fil'),
          ),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.inboxActionReportVanishedAccount),
          findsOneWidget,
        );
        expect(
          find.text(l10n.inboxActionReport('ang account na ito')),
          findsNothing,
        );
      });

      testWidgets('renders $SwitchListTile for mute toggle', (tester) async {
        await tester.pumpWidget(buildSubject(onResult: (_) {}));

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(SwitchListTile), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('returns toggleMute when mute tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mute conversation'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.toggleMute));
      });

      testWidgets('returns report when report tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Report Alice'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.report));
      });

      testWidgets('returns block when block tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Block Alice'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.block));
      });

      testWidgets('returns remove when remove tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove conversation'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.remove));
      });

      testWidgets('returns null when dismissed by tapping scrim', (
        tester,
      ) async {
        ConversationAction? result;
        var callbackCalled = false;
        await tester.pumpWidget(
          buildSubject(
            onResult: (action) {
              callbackCalled = true;
              result = action;
            },
          ),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        // Tap the scrim (top-left corner, outside the bottom sheet)
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();

        expect(callbackCalled, isTrue);
        expect(result, isNull);
      });
    });

    // A group sheet has no way to say WHICH account Report and Block would
    // act on, so it offers neither. Conversation-scoped actions stay.
    // Only reachable once BOTH withdrawals apply: a group thread whose
    // members include a removal-protected account (#8391) loses Report,
    // Block and Remove, leaving Mute alone. Neither change creates this on
    // its own.
    testWidgets('a group with nothing removable keeps only Mute', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        buildSubject(onResult: (_) {}, isGroup: true, canRemove: false),
      );
      await tester.tap(find.text('Show sheet'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.inboxActionMute), findsOneWidget);
      expect(find.text(l10n.inboxActionRemove), findsNothing);
      expect(find.text(l10n.inboxActionReport('Alice')), findsNothing);
      expect(find.text(l10n.inboxActionBlock('Alice')), findsNothing);
    });

    group('a group conversation', () {
      testWidgets('offers only the conversation-scoped actions', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(onResult: (_) {}, isGroup: true),
        );
        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.inboxActionMute), findsOneWidget);
        expect(find.text(l10n.inboxActionRemove), findsOneWidget);
        expect(find.text(l10n.inboxActionReport('Alice')), findsNothing);
        expect(find.text(l10n.inboxActionBlock('Alice')), findsNothing);
      });

      testWidgets('a 1:1 still offers both', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(buildSubject(onResult: (_) {}));
        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.inboxActionReport('Alice')), findsOneWidget);
        expect(find.text(l10n.inboxActionBlock('Alice')), findsOneWidget);
      });
    });
  });
}
