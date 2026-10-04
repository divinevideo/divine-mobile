// ABOUTME: Tests for ListPickerRow: how a picker row reads to assistive tech,
// ABOUTME: picked and unpicked, and that a tap reaches its callback.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/list_picker_row.dart';

void main() {
  group(ListPickerRow, () {
    Widget buildSubject({required bool isSelected, VoidCallback? onTap}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListPickerRow(
            media: const SizedBox(height: 40),
            title: 'Close Friends',
            meta: '1 member',
            isSelected: isSelected,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    group('semantics', () {
      testWidgets('reads a picked row as one checked item, not an image', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isSelected: true));

        expect(
          tester.getSemantics(find.byType(ListPickerRow)),
          isSemantics(
            label: 'Close Friends\n1 member',
            hasCheckedState: true,
            isChecked: true,
            isImage: false,
            hasTapAction: true,
          ),
        );
      });

      testWidgets('reads an unpicked row as one unchecked item', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isSelected: false));

        expect(
          tester.getSemantics(find.byType(ListPickerRow)),
          isSemantics(
            label: 'Close Friends\n1 member',
            hasCheckedState: true,
            isChecked: false,
            isImage: false,
            hasTapAction: true,
          ),
        );
      });
    });

    group('interactions', () {
      testWidgets('tapping the row calls onTap', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          buildSubject(isSelected: false, onTap: () => taps++),
        );

        await tester.tap(find.text('Close Friends'));

        expect(taps, equals(1));
      });
    });
  });
}
