// ABOUTME: Tests the countdown reminder cubit: which reminder a countdown
// ABOUTME: sticker sets, and what a tap on it did.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/countdown_reminder/countdown_reminder_cubit.dart';
import 'package:openvine/services/notification_service.dart';

class _MockNotificationService extends Mock implements NotificationService {}

VideoStickerRegion _countdown(DateTime end, {String label = 'Summer'}) =>
    VideoStickerRegion(
      kind: VideoStickerKind.countdown,
      target: '${end.millisecondsSinceEpoch ~/ 1000}',
      centerX: 0.5,
      centerY: 0.5,
      width: 0.5,
      height: 0.2,
      style: 'light',
      label: label,
    );

final _video = VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
);

void main() {
  group(CountdownReminderCubit, () {
    late _MockNotificationService notifications;

    setUpAll(() => registerFallbackValue(DateTime(2000)));

    setUp(() => notifications = _MockNotificationService());

    void reminderAnswers(ReminderToggle result) => when(
      () => notifications.toggleReminder(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        at: any(named: 'at'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => result);

    group('reminderIdFor', () {
      test('tells countdowns apart by their end and title', () {
        final end = DateTime.utc(2027, 6, 21, 18);
        final id = CountdownReminderCubit.reminderIdFor(
          _video,
          _countdown(end),
        );

        expect(
          id,
          equals(CountdownReminderCubit.reminderIdFor(_video, _countdown(end))),
        );
        expect(
          id,
          isNot(
            CountdownReminderCubit.reminderIdFor(
              _video,
              _countdown(end, label: 'Winter'),
            ),
          ),
        );
        expect(
          id,
          isNot(
            CountdownReminderCubit.reminderIdFor(
              _video,
              _countdown(end.add(const Duration(hours: 1))),
            ),
          ),
        );
        expect(id, inInclusiveRange(0, 0x7fffffff));
      });
    });

    group('reminderToggled', () {
      final upcoming = _countdown(
        DateTime.now().add(const Duration(days: 3)),
      );

      Future<void> toggle(
        CountdownReminderCubit cubit,
        VideoStickerRegion region,
      ) => cubit.reminderToggled(
        video: _video,
        region: region,
        title: 'Summer',
        body: 'It is time',
      );

      blocTest<CountdownReminderCubit, CountdownReminderState>(
        'sets a reminder for the moment the countdown ends',
        setUp: () => reminderAnswers(ReminderToggle.scheduled),
        build: () => CountdownReminderCubit(notifications: notifications),
        act: (cubit) => toggle(cubit, upcoming),
        expect: () => const [
          CountdownReminderState(
            status: CountdownReminderStatus.scheduled,
            taps: 1,
          ),
        ],
        verify: (_) => verify(
          () => notifications.toggleReminder(
            id: CountdownReminderCubit.reminderIdFor(_video, upcoming),
            title: 'Summer',
            body: 'It is time',
            at: upcoming.countdownEnd!,
            payload: any(named: 'payload', that: contains(_video.id)),
          ),
        ).called(1),
      );

      blocTest<CountdownReminderCubit, CountdownReminderState>(
        'says so each time a tap removes or cannot set the reminder',
        setUp: () => reminderAnswers(ReminderToggle.cancelled),
        build: () => CountdownReminderCubit(notifications: notifications),
        act: (cubit) async {
          await toggle(cubit, upcoming);
          reminderAnswers(ReminderToggle.denied);
          await toggle(cubit, upcoming);
          await toggle(cubit, upcoming);
        },
        expect: () => const [
          CountdownReminderState(
            status: CountdownReminderStatus.cancelled,
            taps: 1,
          ),
          CountdownReminderState(
            status: CountdownReminderStatus.notificationsOff,
            taps: 2,
          ),
          CountdownReminderState(
            status: CountdownReminderStatus.notificationsOff,
            taps: 3,
          ),
        ],
      );

      blocTest<CountdownReminderCubit, CountdownReminderState>(
        'sets nothing for a countdown that is over',
        build: () => CountdownReminderCubit(notifications: notifications),
        act: (cubit) => toggle(cubit, _countdown(DateTime.utc(2025, 6, 21))),
        expect: () => const [
          CountdownReminderState(
            status: CountdownReminderStatus.over,
            taps: 1,
          ),
        ],
        verify: (_) => verifyNever(
          () => notifications.toggleReminder(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            at: any(named: 'at'),
            payload: any(named: 'payload'),
          ),
        ),
      );
    });
  });
}
