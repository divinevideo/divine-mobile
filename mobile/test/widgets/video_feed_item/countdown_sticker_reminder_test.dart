// ABOUTME: Tests what a countdown sticker shows and says in the player: the
// ABOUTME: time left, and what a tap did with its reminder.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/widgets/video_feed_item/countdown_sticker_reminder.dart';
import 'package:openvine/widgets/video_feed_item/video_sticker_tap_areas.dart';

class _MockNotificationService extends Mock implements NotificationService {}

VideoStickerRegion _countdown(DateTime end) => VideoStickerRegion(
  kind: VideoStickerKind.countdown,
  target: '${end.millisecondsSinceEpoch ~/ 1000}',
  centerX: 0.5,
  centerY: 0.5,
  width: 0.5,
  height: 0.2,
  style: 'light',
  label: 'Summer',
);

final _video = VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
);

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

  group(CountdownReminderScope, () {
    late _MockNotificationService notifications;

    setUpAll(() => registerFallbackValue(DateTime(2000)));

    setUp(() => notifications = _MockNotificationService());

    /// Taps a countdown to [end] the way the player opens it, below a scope.
    Future<void> tap(WidgetTester tester, DateTime end) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CountdownReminderScope(
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        openVideoSticker(context, _countdown(end), _video),
                    child: const Text('tap'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap'));
      await tester.pump();
    }

    testWidgets('tells the viewer the reminder is set', (tester) async {
      when(
        () => notifications.toggleReminder(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          at: any(named: 'at'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => ReminderToggle.scheduled);

      await tap(tester, DateTime.now().add(const Duration(days: 3)));

      expect(find.text(l10n.videoStickerCountdownReminderSet), findsOneWidget);
      verify(
        () => notifications.toggleReminder(
          id: any(named: 'id'),
          title: 'Summer',
          body: l10n.videoStickerCountdownReminderBody,
          at: any(named: 'at'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    testWidgets('tells the viewer a countdown is over', (tester) async {
      await tap(tester, DateTime.utc(2025, 6, 21));

      expect(find.text(l10n.videoStickerCountdownOver), findsOneWidget);
    });
  });
}
