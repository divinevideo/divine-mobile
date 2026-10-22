// ABOUTME: Cubit backing the Mirror front camera toggle in Create & Share.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/front_camera_mirror/front_camera_mirror_state.dart';
import 'package:openvine/services/front_camera_mirror_preference_service.dart';

/// Cubit backing the `MirrorFrontCameraSetting` tile.
class FrontCameraMirrorCubit extends Cubit<FrontCameraMirrorState>
    with CloseGuardedEmit<FrontCameraMirrorState> {
  FrontCameraMirrorCubit({required FrontCameraMirrorPreferenceService service})
    : _service = service,
      super(const FrontCameraMirrorState());

  final FrontCameraMirrorPreferenceService _service;

  void load() {
    emit(state.copyWith(isEnabled: _service.isEnabled));
  }

  Future<void> setEnabled(bool value) async {
    await _service.setEnabled(value);
    // The write crosses an await; leaving the settings screen mid-toggle
    // closes this cubit before it resumes.
    emitIfOpen(state.copyWith(isEnabled: _service.isEnabled));
  }
}
