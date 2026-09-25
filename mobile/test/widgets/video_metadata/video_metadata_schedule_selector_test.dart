// ABOUTME: Widget tests for VideoMetadataScheduleSelector: the tile value,
// ABOUTME: the option menu with reachable presets, and the writes to the
// ABOUTME: editor state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_schedule_selector.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group(VideoMetadataScheduleSelector, () {
    final noon = DateTime(2026, 9, 22, 12);

    Future<_MockVideoEditorNotifier> pump(
      WidgetTester tester, {
      DateTime? scheduledAt,
      DateTime? now,
    }) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final notifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(scheduledAt: scheduledAt),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataScheduleSelector(now: () => now ?? noon),
            ),
          ),
        ),
      );
      return notifier;
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(
        find.bySemanticsLabel(_l10n.videoMetadataSelectScheduleSemanticLabel),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows "Now" by default', (tester) async {
      await pump(tester);

      expect(find.text(_l10n.videoMetadataScheduleLabel), findsOneWidget);
      expect(find.text(_l10n.videoMetadataScheduleNow), findsOneWidget);
    });

    testWidgets('shows the scheduled time in the device locale', (
      tester,
    ) async {
      await pump(tester, scheduledAt: DateTime(2026, 10, 1, 9, 30).toUtc());

      expect(find.textContaining('Oct 1'), findsOneWidget);
      expect(find.textContaining('9:30'), findsOneWidget);
      expect(find.text(_l10n.videoMetadataScheduleNow), findsNothing);
    });

    testWidgets('offers now, the reachable presets and a custom pick', (
      tester,
    ) async {
      await pump(tester);

      await openMenu(tester);

      expect(find.text(_l10n.videoMetadataScheduleNow), findsWidgets);
      expect(find.textContaining('Tonight at'), findsOneWidget);
      expect(find.textContaining('Tomorrow at'), findsOneWidget);
      expect(
        find.text(_l10n.videoMetadataSchedulePickDateTime),
        findsOneWidget,
      );
    });

    testWidgets('hides "tonight" once 8 PM is too close', (tester) async {
      await pump(tester, now: DateTime(2026, 9, 22, 19, 50));

      await openMenu(tester);

      expect(find.textContaining('Tonight at'), findsNothing);
      expect(find.textContaining('Tomorrow at'), findsOneWidget);
    });

    testWidgets('a preset writes its time to the editor state', (
      tester,
    ) async {
      final notifier = await pump(tester);

      await openMenu(tester);
      await tester.tap(find.textContaining('Tomorrow at'));
      await tester.pumpAndSettle();

      expect(notifier.scheduledAtCalls, [DateTime(2026, 9, 23, 9).toUtc()]);
      expect(find.textContaining('Sep 23'), findsOneWidget);
    });

    testWidgets('"Now" clears a scheduled time', (tester) async {
      final notifier = await pump(
        tester,
        scheduledAt: DateTime(2026, 10, 1, 9, 30).toUtc(),
      );

      await openMenu(tester);
      await tester.tap(find.text(_l10n.videoMetadataScheduleNow).last);
      await tester.pumpAndSettle();

      expect(notifier.scheduledAtCalls, [null]);
      expect(find.text(_l10n.videoMetadataScheduleNow), findsOneWidget);
    });

    testWidgets('the custom option opens the date picker and keeps the old '
        'time when it is dismissed', (tester) async {
      final notifier = await pump(
        tester,
        scheduledAt: DateTime(2026, 10, 1, 9, 30).toUtc(),
      );

      await openMenu(tester);
      await tester.tap(find.text(_l10n.videoMetadataSchedulePickDateTime));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleDateTimeSheet), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(_l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleDateTimeSheet), findsNothing);
      expect(notifier.scheduledAtCalls, isEmpty);
      expect(find.textContaining('Oct 1'), findsOneWidget);
    });

    testWidgets('confirming the date picker writes the picked time', (
      tester,
    ) async {
      final notifier = await pump(tester);

      await openMenu(tester);
      await tester.tap(find.text(_l10n.videoMetadataSchedulePickDateTime));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel(_l10n.videoMetadataScheduleButton),
      );
      await tester.pumpAndSettle();

      // The wheel opens on the earliest slot: noon + 15 min, on the step.
      expect(notifier.scheduledAtCalls, [
        DateTime(2026, 9, 22, 12, 15).toUtc(),
      ]);
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;
  final scheduledAtCalls = <DateTime?>[];

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setScheduledAt(DateTime? scheduledAt) {
    scheduledAtCalls.add(scheduledAt?.toUtc());
    state = scheduledAt == null
        ? state.copyWith(clearScheduledAt: true)
        : state.copyWith(scheduledAt: scheduledAt);
  }
}
