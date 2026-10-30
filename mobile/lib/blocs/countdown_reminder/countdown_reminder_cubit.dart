// ABOUTME: Sets or removes the reminder for a countdown sticker a viewer taps
// ABOUTME: on a playing video, and says which it did so the player can tell.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent, VideoStickerRegion;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/notification_helpers.dart'
    show NotificationPayloadKeys;
import 'package:openvine/services/notification_service.dart';

part 'countdown_reminder_state.dart';

/// Sets and removes the reminders of the countdown stickers on a video.
class CountdownReminderCubit extends Cubit<CountdownReminderState>
    with CloseGuardedEmit<CountdownReminderState> {
  CountdownReminderCubit({required NotificationService notifications})
    : _notifications = notifications,
      super(const CountdownReminderState());

  final NotificationService _notifications;

  /// The id of the reminder for the countdown [region] on [video], the same
  /// every time the app runs, so a second tap finds the reminder the first
  /// set. A countdown is told apart by its creator, end and title, which
  /// stay the same when the video is edited.
  static int reminderIdFor(VideoEvent video, VideoStickerRegion region) {
    // FNV-1a: String.hashCode may differ from one run of the app to the next.
    var hash = 0x811c9dc5;
    final key = '${video.pubkey}|${region.target}|${region.label ?? ''}';
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    // Notification ids are 32-bit signed integers on Android.
    return hash & 0x7fffffff;
  }

  /// Sets a reminder showing [title] and [body] for when the countdown
  /// [region] on [video] ends, or removes the one set before. A tap on the
  /// reminder opens [video].
  Future<void> reminderToggled({
    required VideoEvent video,
    required VideoStickerRegion region,
    required String title,
    required String body,
  }) async {
    final end = region.countdownEnd;
    if (end == null) return;
    if (!end.isAfter(clock.now())) {
      emit(state._next(CountdownReminderStatus.over));
      return;
    }
    final result = await _notifications.toggleReminder(
      id: reminderIdFor(video, region),
      title: title,
      body: body,
      at: end,
      payload: jsonEncode({
        NotificationPayloadKeys.referencedEventId: video.id,
        NotificationPayloadKeys.referencedAddress: ?video.addressableId,
      }),
    );
    emitIfOpen(
      state._next(switch (result) {
        ReminderToggle.scheduled => CountdownReminderStatus.scheduled,
        ReminderToggle.cancelled => CountdownReminderStatus.cancelled,
        ReminderToggle.denied => CountdownReminderStatus.notificationsOff,
        ReminderToggle.failed => CountdownReminderStatus.failed,
      }),
    );
  }
}
