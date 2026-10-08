// ABOUTME: Cubit backing the subtitle-translation tiles in
// ABOUTME: ContentPreferencesScreen. Wraps SubtitleLanguagePreferenceService
// ABOUTME: and snapshots it after each write.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/subtitle_language_setting/subtitle_language_setting_state.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';

/// Cubit backing the subtitle-translation tiles in `ContentPreferencesScreen`.
///
/// Listens for account-boundary reloads as well as setting changes.
class SubtitleLanguageSettingCubit extends Cubit<SubtitleLanguageSettingState>
    with CloseGuardedEmit<SubtitleLanguageSettingState> {
  SubtitleLanguageSettingCubit({
    required SubtitleLanguagePreferenceService service,
  }) : _service = service,
       super(const SubtitleLanguageSettingState()) {
    _service.addListener(_emitSnapshot);
  }

  final SubtitleLanguagePreferenceService _service;

  @override
  Future<void> close() {
    _service.removeListener(_emitSnapshot);
    return super.close();
  }

  Future<void> load() async {
    await _service.initialize();
    _emitSnapshot();
  }

  /// Sets the translation target; `null` follows the app language.
  Future<void> setTargetLanguage(String? languageCode) async {
    await _service.setTargetLanguage(languageCode);
    _emitSnapshot();
  }

  /// Adds [languageCode] to the languages kept in the original, or removes it.
  ///
  /// Emits the new selection before the write lands, so the picker repaints at
  /// once and a quick second tap builds on the first instead of undoing it.
  Future<void> toggleKeepOriginalLanguage(String languageCode) async {
    final next = {...state.keepOriginalLanguages};
    if (!next.add(languageCode)) next.remove(languageCode);
    emitIfOpen(
      SubtitleLanguageSettingState(
        status: state.status,
        targetLanguage: state.targetLanguage,
        keepOriginalLanguages: _sorted(next),
      ),
    );
    await _service.setKeepOriginalLanguages(next);
    _emitSnapshot();
  }

  void _emitSnapshot() {
    emitIfOpen(
      SubtitleLanguageSettingState(
        status: SubtitleLanguageSettingStatus.ready,
        targetLanguage: _service.targetLanguage,
        keepOriginalLanguages: _sorted(_service.keepOriginalLanguages),
      ),
    );
  }

  static List<String> _sorted(Iterable<String> codes) => codes.toList()..sort();
}
