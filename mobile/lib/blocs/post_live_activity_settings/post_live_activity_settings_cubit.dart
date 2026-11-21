// ABOUTME: Cubit behind the post Live Activity row in Notification settings.
// ABOUTME: Reads the in-app toggle, follows the iPhone setting, writes through.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/post_live_activity_settings/post_live_activity_settings_state.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

export 'package:openvine/blocs/post_live_activity_settings/post_live_activity_settings_state.dart';

/// Drives the post Live Activity switch: the in-app toggle plus whether iOS
/// allows Live Activities for the app at all.
class PostLiveActivitySettingsCubit extends Cubit<PostLiveActivitySettingsState>
    with CloseGuardedEmit<PostLiveActivitySettingsState> {
  /// Creates the cubit over the device-level [repository].
  PostLiveActivitySettingsCubit({
    required PostLiveActivityRepository repository,
  }) : _repository = repository,
       super(const PostLiveActivitySettingsState());

  final PostLiveActivityRepository _repository;
  StreamSubscription<bool>? _systemSubscription;

  /// Reads the toggle and the system switch, then follows system changes.
  Future<void> load() async {
    // Subscribe before the read so a change made while it is in flight is not
    // lost to the gap between the two.
    await _systemSubscription?.cancel();
    _systemSubscription = _repository.systemEnabledChanges.listen(
      (enabled) => emitIfOpen(state.copyWith(systemEnabled: enabled)),
    );
    final systemEnabled = await _repository.isSystemEnabled();
    emitIfOpen(
      state.copyWith(
        toggleOn: _repository.isToggleOn,
        systemEnabled: systemEnabled,
      ),
    );
  }

  /// Turns the in-app toggle on or off, writing through to the repository.
  // The switch callback hands a positional bool; a named flag would not read
  // better at the call site.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setToggleOn(bool on) async {
    await _repository.setToggleOn(on);
    emitIfOpen(state.copyWith(toggleOn: on));
  }

  @override
  Future<void> close() async {
    await _systemSubscription?.cancel();
    return super.close();
  }
}
