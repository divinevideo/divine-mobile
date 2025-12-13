// ABOUTME: Riverpod state management for sound selection in video editing
// ABOUTME: Tracks selected sound, playback state, search query, and filtered results

import 'package:openvine/models/vine_sound.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sound_picker_provider.g.dart';

class SoundPickerState {
  SoundPickerState({
    this.selectedSoundId,
    this.isPlaying = false,
    this.searchQuery = '',
    this.filteredSounds = const [],
  });

  final String? selectedSoundId;
  final bool isPlaying;
  final String searchQuery;
  final List<VineSound> filteredSounds;

  SoundPickerState copyWith({
    String? selectedSoundId,
    bool? clearSelection,
    bool? isPlaying,
    String? searchQuery,
    List<VineSound>? filteredSounds,
  }) {
    return SoundPickerState(
      selectedSoundId: clearSelection == true
          ? null
          : (selectedSoundId ?? this.selectedSoundId),
      isPlaying: isPlaying ?? this.isPlaying,
      searchQuery: searchQuery ?? this.searchQuery,
      filteredSounds: filteredSounds ?? this.filteredSounds,
    );
  }
}

@riverpod
class SoundPicker extends _$SoundPicker {
  List<VineSound> _allSounds = [];

  @override
  SoundPickerState build() {
    return SoundPickerState();
  }

  void selectSound(String soundId) {
    state = state.copyWith(selectedSoundId: soundId);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  void togglePlayback() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredSounds: _filterSounds(query),
    );
  }

  void setSounds(List<VineSound> sounds) {
    _allSounds = sounds;
    state = state.copyWith(filteredSounds: _filterSounds(state.searchQuery));
  }

  List<VineSound> _filterSounds(String query) {
    if (query.trim().isEmpty) {
      return _allSounds;
    }

    return _allSounds.where((sound) => sound.matchesSearch(query)).toList();
  }
}
