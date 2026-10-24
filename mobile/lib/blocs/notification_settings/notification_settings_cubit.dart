// ABOUTME: Screen-scoped Cubit for the notification settings screen.
// ABOUTME: Owns the notification preferences, persisting changes via
// ABOUTME: NotificationPreferencesService, and runs the mark-all-as-read
// ABOUTME: action against NotificationRepository.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

/// Cubit backing `NotificationSettingsScreen`.
///
/// Holds the notification [NotificationSettingsState.preferences] and writes
/// mutations through [NotificationPreferencesService]. A null
/// [NotificationRepository] — the signed-out case — leaves the
/// mark-all-as-read action permanently
/// [MarkAllAsReadStatus.unavailable].
class NotificationSettingsCubit extends Cubit<NotificationSettingsState>
    with CloseGuardedEmit<NotificationSettingsState> {
  NotificationSettingsCubit({
    required NotificationPreferencesService preferencesService,
    NotificationRepository? notificationRepository,
  }) : _preferencesService = preferencesService,
       _notificationRepository = notificationRepository,
       super(
         NotificationSettingsState(
           markAllAsReadStatus: notificationRepository == null
               ? MarkAllAsReadStatus.unavailable
               : MarkAllAsReadStatus.idle,
         ),
       ) {
    _preferenceSubscription = _preferencesService.changes?.listen(
      (_) => _preferencesChanged(),
    );
  }

  StreamSubscription<void>? _preferenceSubscription;

  void _preferencesChanged() => unawaited(_reloadPreferences());
  Future<void> _reloadPreferences() async {
    final preferences = await _preferencesService.loadPreferences();
    emitIfOpen(state.copyWith(preferences: preferences));
  }

  @override
  Future<void> close() {
    unawaited(_preferenceSubscription?.cancel());
    return super.close();
  }

  final NotificationPreferencesService _preferencesService;
  final NotificationRepository? _notificationRepository;

  /// Loads the persisted preferences. `loadPreferences` is itself defensive
  /// (returns defaults on storage/decoding errors), so this does not throw.
  Future<void> load() async {
    emit(state.copyWith(status: NotificationSettingsStatus.loading));
    final preferences = await _preferencesService.loadPreferences();
    emitIfOpen(
      state.copyWith(
        status: NotificationSettingsStatus.ready,
        preferences: preferences,
      ),
    );
  }

  /// Marks every notification as read, ignoring taps that arrive while a
  /// previous call is still in flight.
  Future<void> markAllAsRead() async {
    final repository = _notificationRepository;
    if (repository == null || !state.canMarkAllAsRead) return;
    emit(
      state.copyWith(markAllAsReadStatus: MarkAllAsReadStatus.inProgress),
    );
    try {
      await repository.markAllAsRead();
      emitIfOpen(
        state.copyWith(markAllAsReadStatus: MarkAllAsReadStatus.success),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(markAllAsReadStatus: MarkAllAsReadStatus.failure),
      );
    }
  }

  /// Persists only the changed choice before refreshing the displayed state.
  Future<void> setPreference(
    NotificationPreference preference,
    bool enabled,
  ) async {
    await _preferencesService.updatePreference(preference, enabled);
    await _reloadPreferences();
  }

  /// Resets preferences to their defaults and persists them.
  Future<void> resetToDefaults() async {
    await _preferencesService.resetToDefaults();
    await _reloadPreferences();
  }
}
