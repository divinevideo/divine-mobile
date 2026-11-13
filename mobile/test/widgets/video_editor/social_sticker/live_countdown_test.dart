// ABOUTME: Tests the countdown that counts down every second in the player and
// ABOUTME: on the editor canvas, and how it writes the time left.

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/social_sticker/live_countdown.dart';

/// What the countdown shows for its date in these tests.
const _date = 'date';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('countdownTimeLeft', () {
    test('writes whole days before the hours, minutes and seconds', () {
      expect(
        countdownTimeLeft(
          l10n,
          const Duration(days: 12, hours: 4, minutes: 3, seconds: 9),
        ),
        equals('12 days 04:03:09'),
      );
      expect(
        countdownTimeLeft(l10n, const Duration(days: 1, minutes: 1)),
        equals('1 day 00:01:00'),
      );
    });

    test('leaves the days out on the last day', () {
      expect(
        countdownTimeLeft(l10n, const Duration(hours: 23, seconds: 59)),
        equals('23:00:59'),
      );
    });
  });

  group(LiveCountdown, () {
    Future<void> pump(
      WidgetTester tester, {
      required DateTime? end,
      ValueListenable<bool>? showDate,
    }) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LiveCountdown(
          end: end,
          showDate: showDate,
          builder: (_, timeLeft) => Text(timeLeft ?? _date),
        ),
      ),
    );

    group('renders', () {
      testWidgets('the time left, one second less every second', (
        tester,
      ) async {
        final end = clock.now().add(
          const Duration(days: 1, hours: 2, minutes: 3, seconds: 5),
        );
        await pump(tester, end: end);

        expect(find.text('1 day 02:03:05'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1 day 02:03:04'), findsOneWidget);

        await tester.pump(const Duration(seconds: 2));
        expect(find.text('1 day 02:03:02'), findsOneWidget);
      });

      testWidgets('the date once it is over', (tester) async {
        await pump(
          tester,
          end: clock.now().add(const Duration(seconds: 2)),
        );
        expect(find.text('00:00:02'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('00:00:01'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text(_date), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        expect(find.text(_date), findsOneWidget);
      });

      testWidgets('the date without an end', (tester) async {
        await pump(tester, end: null);

        expect(find.text(_date), findsOneWidget);
      });

      testWidgets('the date while it is asked to, and the time left again '
          'after', (tester) async {
        final showDate = ValueNotifier<bool>(false);
        addTearDown(showDate.dispose);
        final end = clock.now().add(const Duration(minutes: 1));
        await pump(tester, end: end, showDate: showDate);
        expect(find.text('00:01:00'), findsOneWidget);

        showDate.value = true;
        await tester.pump();
        expect(find.text(_date), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text(_date), findsOneWidget);

        showDate.value = false;
        await tester.pump();
        expect(find.text('00:00:59'), findsOneWidget);
      });

      testWidgets('the time left again once an ended countdown is moved to '
          'a later end', (tester) async {
        await pump(
          tester,
          end: clock.now().subtract(const Duration(minutes: 1)),
        );
        expect(find.text(_date), findsOneWidget);

        await pump(
          tester,
          end: clock.now().add(const Duration(minutes: 1)),
        );
        expect(find.text('00:01:00'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('00:00:59'), findsOneWidget);
      });
    });
  });
}
