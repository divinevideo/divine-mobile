// ABOUTME: Cubit backing the content-language tile in ContentPreferencesScreen.
// ABOUTME: Wraps LanguagePreferenceService for set/clear actions and snapshots
// ABOUTME: the post-write state so the UI no longer needs setState({}).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/language_setting/language_setting_state.dart';
import 'package:openvine/services/language_preference_service.dart';

/// Cubit backing the `_LanguageSetting` tile in `ContentPreferencesScreen`.
///
/// `LanguagePreferenceService` is a plain prefs-backed singleton (no stream),
/// so the cubit re-reads the service after each mutation and emits the
/// canonical post-write snapshot — same approach as the existing settings
/// Cubits in this lane.
class LanguageSettingCubit extends Cubit<LanguageSettingState> {
  LanguageSettingCubit({required LanguagePreferenceService service})
    : _service = service,
      super(const LanguageSettingState()) {
    _service.addListener(_refreshPreferences);
  }

  void _refreshPreferences() {
    if (!isClosed) _emitSnapshot();
  }

  @override
  Future<void> close() {
    _service.removeListener(_refreshPreferences);
    return super.close();
  }

  final LanguagePreferenceService _service;

  Future<void> load() async {
    emit(state.copyWith(status: LanguageSettingStatus.loading));
    await _service.initialize();
    _emitSnapshot();
  }

  Future<void> setLanguage(String languageCode) async {
    await _service.setContentLanguage(languageCode);
    _emitSnapshot();
  }

  Future<void> clearLanguage() async {
    await _service.clearContentLanguage();
    _emitSnapshot();
  }

  void _emitSnapshot() {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: LanguageSettingStatus.ready,
        currentCode: _service.contentLanguage,
        isCustomLanguageSet: _service.isCustomLanguageSet,
      ),
    );
  }
}
