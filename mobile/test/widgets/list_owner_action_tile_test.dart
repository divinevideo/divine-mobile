// ABOUTME: Tests for ListOwnerActionTile, the option row shared by the
// ABOUTME: video-list and people-list owner sheets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/list_owner_action_tile.dart';

enum _Action { edit, delete }

void main() {
  group(ListOwnerActionTile, () {
    /// Opens a sheet with an editable row and a destructive row, and returns
    /// the future the sheet completes with.
    Future<Future<_Action?>> pumpSheet(
      WidgetTester tester, {
      bool editEnabled = true,
    }) async {
      late Future<_Action?> result;
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    result = VineBottomSheet.show<_Action>(
                      context: context,
                      expanded: false,
                      scrollable: false,
                      children: [
                        ListOwnerActionTile(
                          identifier: 'edit_option',
                          label: 'Edit',
                          icon: DivineIconName.pencilSimple,
                          action: _Action.edit,
                          enabled: editEnabled,
                        ),
                        const ListOwnerActionTile(
                          identifier: 'delete_option',
                          label: 'Delete',
                          icon: DivineIconName.trash,
                          action: _Action.delete,
                          isDestructive: true,
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('pops the sheet with its action when tapped', (tester) async {
      final result = await pumpSheet(tester);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(await result, _Action.edit);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('stays inert and reads as disabled when not enabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final result = await pumpSheet(tester, editEnabled: false);

      final node = find.semantics
          .byPredicate((node) => node.identifier == 'edit_option')
          .evaluate()
          .single;
      expect(node, isSemantics(hasEnabledState: true, isEnabled: false));

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await result, _Action.delete);
      semantics.dispose();
    });
  });
}
