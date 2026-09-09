// ABOUTME: Immutable state for the device-local saved sounds library.
// ABOUTME: Owns search and hashtag filtering across private and source metadata.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/saved_sound.dart';

enum SavedSoundsStatus { initial, loading, loaded }

class SavedSoundsState extends Equatable {
  const SavedSoundsState({
    this.status = SavedSoundsStatus.initial,
    this.sounds = const [],
    this.query = '',
    this.selectedHashtag,
    this.unsavedSoundIds = const {},
    this.missingFileSoundIds = const {},
  });

  final SavedSoundsStatus status;
  final List<SavedSound> sounds;
  final String query;
  final String? selectedHashtag;
  final Set<String> unsavedSoundIds;

  /// Sounds whose device-local audio file is no longer on disk.
  ///
  /// Such an entry stays in the library and used to play silence, with nothing
  /// telling the user why (#8023). Only device-local sounds can land here; a
  /// network or asset source is not something this library can lose.
  ///
  /// "Missing" is a statement about *this* device only. The record syncs
  /// across a creator's devices but the audio file does not, so an entry can
  /// be unplayable here and fine on the phone it was imported on — which is
  /// why nothing built on this set advises removing the entry.
  final Set<String> missingFileSoundIds;

  /// Whether [sound]'s audio file has gone missing from the device.
  bool isMissingFile(SavedSound sound) =>
      missingFileSoundIds.contains(sound.audio.id);

  List<SavedSound> get visibleSounds {
    final normalizedQuery = query.trim().toLowerCase();
    return sounds
        .where((sound) {
          final matchesTag =
              selectedHashtag == null ||
              sound.personalHashtags.contains(selectedHashtag);
          return matchesTag &&
              (normalizedQuery.isEmpty ||
                  _searchableValues(sound).any(
                    (value) => value.toLowerCase().contains(normalizedQuery),
                  ));
        })
        .toList(growable: false);
  }

  SavedSoundsState copyWith({
    SavedSoundsStatus? status,
    List<SavedSound>? sounds,
    String? query,
    Object? selectedHashtag = _unset,
    Set<String>? unsavedSoundIds,
    Set<String>? missingFileSoundIds,
  }) => SavedSoundsState(
    status: status ?? this.status,
    sounds: sounds ?? this.sounds,
    query: query ?? this.query,
    selectedHashtag: identical(selectedHashtag, _unset)
        ? this.selectedHashtag
        : selectedHashtag as String?,
    unsavedSoundIds: unsavedSoundIds ?? this.unsavedSoundIds,
    missingFileSoundIds: missingFileSoundIds ?? this.missingFileSoundIds,
  );

  @override
  List<Object?> get props => [
    status,
    sounds,
    query,
    selectedHashtag,
    unsavedSoundIds,
    missingFileSoundIds,
  ];
}

const _unset = Object();

Iterable<String> _searchableValues(SavedSound sound) sync* {
  final source = sound.sourceContext;
  final nullableValues = [
    sound.personalLabel,
    sound.audio.title,
    source?.title,
    source?.creatorName,
    source?.description,
    source?.transcript,
  ];
  yield* nullableValues.whereType<String>();
  yield* sound.personalHashtags;
  yield* sound.catalogTags;
}
