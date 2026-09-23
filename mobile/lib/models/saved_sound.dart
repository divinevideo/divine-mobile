// ABOUTME: Device-local metadata for sounds explicitly saved to the library.
// ABOUTME: Keeps private organization separate from publishable AudioEvent data.

import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent, matchesSearchTerms;

const _unsetSavedSoundValue = Object();

@immutable
class SavedSoundLibraryPayload {
  const SavedSoundLibraryPayload({
    required this.schemaVersion,
    required this.sounds,
  });

  factory SavedSoundLibraryPayload.fromJson(Map<String, dynamic> json) {
    final rawSounds = json['sounds'];
    if (rawSounds is! List) {
      throw const FormatException('Saved sound payload missing sounds');
    }
    return SavedSoundLibraryPayload(
      schemaVersion: json['schemaVersion'] as int,
      sounds: rawSounds
          .whereType<Map>()
          .map(
            (entry) => SavedSound.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
    );
  }

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final List<SavedSound> sounds;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'sounds': sounds.map((sound) => sound.toJson()).toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      other is SavedSoundLibraryPayload &&
      other.schemaVersion == schemaVersion &&
      _listEquals(other.sounds, sounds);

  @override
  int get hashCode => Object.hash(schemaVersion, Object.hashAll(sounds));
}

@immutable
class SavedSound {
  const SavedSound({
    required this.audio,
    required this.personalHashtags,
    required this.catalogTags,
    required this.waveformSamples,
    this.savedAt,
    this.personalLabel,
    this.sourceContext,
  });

  factory SavedSound.fromLegacy(AudioEvent audio) => SavedSound(
    audio: audio,
    personalHashtags: const [],
    catalogTags: const [],
    waveformSamples: const [],
  );

  factory SavedSound.fromJson(Map<String, dynamic> json) {
    final audioJson = json['audio'];
    if (audioJson is! Map) {
      throw const FormatException('Saved sound missing audio');
    }
    final savedAt = json['savedAt'];
    final sourceJson = json['sourceContext'];
    return SavedSound(
      audio: AudioEvent.fromJson(Map<String, dynamic>.from(audioJson)),
      savedAt: savedAt is String ? DateTime.tryParse(savedAt)?.toUtc() : null,
      personalLabel: _nonBlank(json['personalLabel'] as String?),
      personalHashtags: normalizeSavedSoundHashtags(
        _stringList(json['personalHashtags']),
      ),
      catalogTags: _normalizeCatalogTags(_stringList(json['catalogTags'])),
      waveformSamples: switch (json['waveformSamples']) {
        final List values =>
          values
              .whereType<num>()
              .map((value) => value.toDouble())
              .toList(growable: false),
        _ => const [],
      },
      sourceContext: sourceJson is Map
          ? SavedSoundSourceContext.fromJson(
              Map<String, dynamic>.from(sourceJson),
            )
          : null,
    );
  }

  final AudioEvent audio;
  final DateTime? savedAt;
  final String? personalLabel;
  final List<String> personalHashtags;
  final SavedSoundSourceContext? sourceContext;
  final List<String> catalogTags;
  final List<double> waveformSamples;

  String get id => audio.id;

  /// Every value a library search may match on this saved sound.
  ///
  /// The private half comes from this record — the label and hashtags the
  /// user typed, plus the context of the video it was lifted from — and the
  /// public half is [AudioEvent.searchableValues], so the published tags that
  /// found this sound in the picker find it here too.
  Iterable<String> get searchableValues sync* {
    final source = sourceContext;
    yield* [
      personalLabel,
      source?.title,
      source?.creatorName,
      source?.description,
      source?.transcript,
    ].nonNulls;
    yield* personalHashtags;
    yield* catalogTags;
    yield* audio.searchableValues;
  }

  /// Whether [query] matches this sound's [searchableValues].
  ///
  /// See [matchesSearchTerms] for how a multi-word query is split and ANDed.
  bool matchesSearch(String query) =>
      matchesSearchTerms(query, searchableValues);

  SavedSound copyWith({
    AudioEvent? audio,
    DateTime? savedAt,
    Object? personalLabel = _unsetSavedSoundValue,
    List<String>? personalHashtags,
    Object? sourceContext = _unsetSavedSoundValue,
    List<String>? catalogTags,
    List<double>? waveformSamples,
  }) {
    return SavedSound(
      audio: audio ?? this.audio,
      savedAt: savedAt ?? this.savedAt,
      personalLabel: identical(personalLabel, _unsetSavedSoundValue)
          ? this.personalLabel
          : _nonBlank(personalLabel as String?),
      personalHashtags: personalHashtags == null
          ? this.personalHashtags
          : normalizeSavedSoundHashtags(personalHashtags),
      sourceContext: identical(sourceContext, _unsetSavedSoundValue)
          ? this.sourceContext
          : sourceContext as SavedSoundSourceContext?,
      catalogTags: catalogTags == null
          ? this.catalogTags
          : _normalizeCatalogTags(catalogTags),
      waveformSamples: waveformSamples ?? this.waveformSamples,
    );
  }

  Map<String, dynamic> toJson() => {
    'audio': audio.toJson(),
    if (savedAt != null) 'savedAt': savedAt!.toUtc().toIso8601String(),
    if (personalLabel != null) 'personalLabel': personalLabel,
    'personalHashtags': personalHashtags,
    'catalogTags': catalogTags,
    'waveformSamples': waveformSamples,
    if (sourceContext != null) 'sourceContext': sourceContext!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SavedSound &&
      other.audio == audio &&
      other.savedAt == savedAt &&
      other.personalLabel == personalLabel &&
      _listEquals(other.personalHashtags, personalHashtags) &&
      other.sourceContext == sourceContext &&
      _listEquals(other.catalogTags, catalogTags) &&
      _listEquals(other.waveformSamples, waveformSamples);

  @override
  int get hashCode => Object.hash(
    audio,
    savedAt,
    personalLabel,
    Object.hashAll(personalHashtags),
    sourceContext,
    Object.hashAll(catalogTags),
    Object.hashAll(waveformSamples),
  );
}

@immutable
class SavedSoundSourceContext {
  const SavedSoundSourceContext({
    this.videoEventId,
    this.creatorPubkey,
    this.creatorName,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.transcript,
  });

  factory SavedSoundSourceContext.fromJson(Map<String, dynamic> json) {
    return SavedSoundSourceContext(
      videoEventId: _nonBlank(json['videoEventId'] as String?),
      creatorPubkey: _nonBlank(json['creatorPubkey'] as String?),
      creatorName: _nonBlank(json['creatorName'] as String?),
      title: _nonBlank(json['title'] as String?),
      description: _nonBlank(json['description'] as String?),
      thumbnailUrl: _nonBlank(json['thumbnailUrl'] as String?),
      transcript: _nonBlank(json['transcript'] as String?),
    );
  }

  final String? videoEventId;
  final String? creatorPubkey;
  final String? creatorName;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? transcript;

  Map<String, dynamic> toJson() => {
    if (videoEventId != null) 'videoEventId': videoEventId,
    if (creatorPubkey != null) 'creatorPubkey': creatorPubkey,
    if (creatorName != null) 'creatorName': creatorName,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (transcript != null) 'transcript': transcript,
  };

  @override
  bool operator ==(Object other) =>
      other is SavedSoundSourceContext &&
      other.videoEventId == videoEventId &&
      other.creatorPubkey == creatorPubkey &&
      other.creatorName == creatorName &&
      other.title == title &&
      other.description == description &&
      other.thumbnailUrl == thumbnailUrl &&
      other.transcript == transcript;

  @override
  int get hashCode => Object.hash(
    videoEventId,
    creatorPubkey,
    creatorName,
    title,
    description,
    thumbnailUrl,
    transcript,
  );
}

List<String> normalizeSavedSoundHashtags(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final raw in values) {
    final value = raw
        .trim()
        .replaceFirst(RegExp('^#+'), '')
        .trim()
        .toLowerCase();
    if (value.isNotEmpty && seen.add(value)) {
      normalized.add(value);
    }
  }
  return List.unmodifiable(normalized);
}

List<String> _normalizeCatalogTags(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final raw in values) {
    final value = raw.trim();
    if (value.isNotEmpty && seen.add(value.toLowerCase())) {
      normalized.add(value);
    }
  }
  return List.unmodifiable(normalized);
}

List<String> _stringList(Object? value) => switch (value) {
  final List values => values.whereType<String>().toList(growable: false),
  _ => const [],
};

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
