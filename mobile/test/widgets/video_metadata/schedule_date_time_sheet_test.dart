// ABOUTME: Widget tests for ScheduleDateTimeSheet: opens on a valid slot,
// ABOUTME: pops the chosen time as UTC, and pops null on cancel.

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDatePicker;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group(ScheduleDateTimeSheet, () {
    final noon = DateTime(2026, 9, 22, 12, 3);

    /// Pumps a host page whose button opens the sheet and records the result.
    Future<List<DateTime?>> pumpHost(
      WidgetTester tester, {
      DateTime? initialTime,
    }) async {
      final results = <DateTime?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => DivineButton(
                label: 'open',
                onPressed: () async {
                  results.add(
                    await ScheduleDateTimeSheet.show(
                      context,
                      initialTime: initialTime,
                      now: noon,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('opens on the earliest slot with the title', (tester) async {
      await pumpHost(tester);

      expect(
        find.text(_l10n.videoMetadataSchedulePickerTitle),
        findsOneWidget,
      );
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.initialDateTime, DateTime(2026, 9, 22, 12, 20));
      expect(picker.minimumDate, DateTime(2026, 9, 22, 12, 20));
      expect(picker.minuteInterval, 5);
    });

    testWidgets('opens on a given time, snapped to the step', (tester) async {
      await pumpHost(tester, initialTime: DateTime(2026, 10, 1, 9, 32).toUtc());

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.initialDateTime, DateTime(2026, 10, 1, 9, 35));
    });

    testWidgets('confirm pops the time as UTC', (tester) async {
      final results = await pumpHost(
        tester,
        initialTime: DateTime(2026, 10, 1, 9, 30).toUtc(),
      );

      await tester.tap(
        find.bySemanticsLabel(_l10n.videoMetadataScheduleButton),
      );
      await tester.pumpAndSettle();

      expect(results, [DateTime(2026, 10, 1, 9, 30).toUtc()]);
      expect(results.single!.isUtc, isTrue);
      expect(find.byType(ScheduleDateTimeSheet), findsNothing);
    });

    testWidgets('cancel pops null', (tester) async {
      final results = await pumpHost(tester);

      await tester.tap(find.bySemanticsLabel(_l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.byType(ScheduleDateTimeSheet), findsNothing);
    });
  });
}
