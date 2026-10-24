// ABOUTME: Cubit backing the audio-sharing toggle in ContentPreferencesScreen.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_state.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';

/// Cubit backing the `_AudioSharingToggle` tile in `ContentPreferencesScreen`.
class AudioSharingCubit extends Cubit<AudioSharingState> {
  AudioSharingCubit({required AudioSharingPreferenceService service})
    : _service = service,
      super(const AudioSharingState()) {
    _preferenceSubscription = _service.changes?.listen(
      (_) => _refreshPreferences(),
    );
  }

  void _refreshPreferences() {
    if (!isClosed) load();
  }

  @override
  Future<void> close() {
    unawaited(_preferenceSubscription?.cancel());
    return super.close();
  }

  StreamSubscription<void>? _preferenceSubscription;
  final AudioSharingPreferenceService _service;

  void load() {
    emit(
      state.copyWith(
        status: AudioSharingStatus.ready,
        isEnabled: _service.isAudioSharingEnabled,
      ),
    );
  }

  Future<void> setEnabled(bool value) async {
    await _service.setAudioSharingEnabled(value);
    if (isClosed) return;
    emit(state.copyWith(isEnabled: _service.isAudioSharingEnabled));
  }
}
