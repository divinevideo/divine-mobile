// ABOUTME: Caption track model for the video editor.
// ABOUTME: Cues are timed text with word timings; the track carries burn-in,
// ABOUTME: preset, language.

import 'package:caption_generator/caption_generator.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/services/subtitle_service.dart';

/// A single caption cue: one piece of timed text on the video timeline.
class CaptionCue extends Equatable {
  /// Creates a cue with a stable [id] covering [start] to [end].
  const CaptionCue({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.words = const [],
  });

  /// Decodes a cue from its [toJson] map.
  ///
  /// Throws a [FormatException] when required keys are missing or mistyped.
  factory CaptionCue.fromJson(Map<Object?, Object?> json) {
    final id = json['id'];
    final text = json['text'];
    final startMs = json['startMs'];
    final endMs = json['endMs'];
    if (id is! String || text is! String || startMs is! int || endMs is! int) {
      throw FormatException('Malformed caption cue: $json');
    }
    return CaptionCue(
      id: id,
      text: text,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
      words: _wordsFromJson(json['words']),
    );
  }

  /// Creates a cue from a recognizer [segment] with the given [id], keeping
  /// the segment's word timings.
  factory CaptionCue.fromSegment(CaptionSegment segment, {required String id}) {
    return CaptionCue(
      id: id,
      text: segment.text,
      start: segment.start,
      end: segment.end,
      words: segment.words,
    );
  }

  /// Decodes stored [words], or none when they are absent or malformed:
  /// [wordTimings] can always spread the text again, so a damaged word list
  /// must not cost the whole caption track.
  static List<CaptionSegment> _wordsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final words = <CaptionSegment>[];
    for (final word in raw) {
      if (word is! Map<Object?, Object?>) return const [];
      try {
        words.add(CaptionSegment.fromMap(word));
      } on FormatException {
        return const [];
      }
    }
    return words;
  }

  /// Stable identifier, used to address the cue from timeline items.
  final String id;

  /// The caption text shown while the cue is active.
  final String text;

  /// Where the cue starts on the video timeline.
  final Duration start;

  /// Where the cue ends on the video timeline.
  final Duration end;

  /// When each word of [text] is spoken, in timeline order, as the
  /// recognizer reported it. Empty for cues without recognized timings — typed
  /// by hand, heavily edited, or from drafts saved before word timings were
  /// kept; [wordTimings] then spreads the text over the cue.
  final List<CaptionSegment> words;

  /// How long the cue is visible.
  Duration get duration => end - start;

  /// The words of [text] with their timings: [words] while they match the
  /// text, otherwise the text spread over the cue by word length.
  List<CaptionSegment> get wordTimings {
    final texts = splitCaptionWords(text);
    final matches =
        words.length == texts.length &&
        words.indexed.every((entry) => entry.$2.text == texts[entry.$1]);
    return matches ? words : spreadCaptionWords(text, start: start, end: end);
  }

  /// This cue showing [text].
  ///
  /// An edit that keeps the number of words, such as fixing a misheard word,
  /// keeps every word's recognized timing. Any other edit cannot tell which
  /// word went where, so the cue falls back to spreading its words.
  CaptionCue withText(String text) {
    final texts = splitCaptionWords(text);
    return CaptionCue(
      id: id,
      text: text,
      start: start,
      end: end,
      words: words.length == texts.length
          ? [
              for (final (index, word) in words.indexed)
                CaptionSegment(
                  text: texts[index],
                  start: word.start,
                  end: word.end,
                ),
            ]
          : const [],
    );
  }

  /// This cue shown from [start] to [end].
  ///
  /// Moving the whole cue moves its words along, since the move lines the
  /// caption up with the speech. Trimming or extending it leaves the words
  /// where they are spoken: a word that starts after the new end never lights
  /// up, and the last word that started before the new start stays lit from
  /// the first frame until the next one begins.
  CaptionCue withTiming({Duration? start, Duration? end}) {
    final newStart = start ?? this.start;
    final newEnd = end ?? this.end;
    final shift = newStart - this.start;
    final moved = shift != Duration.zero && newEnd - newStart == duration;
    return CaptionCue(
      id: id,
      text: text,
      start: newStart,
      end: newEnd,
      words: moved
          ? [
              for (final word in words)
                CaptionSegment(
                  text: word.text,
                  start: word.start + shift,
                  end: word.end + shift,
                ),
            ]
          : words,
    );
  }

  /// This cue as a [SubtitleCue] for the VTT pipeline.
  SubtitleCue toSubtitleCue() => SubtitleCue(
    start: start.inMilliseconds,
    end: end.inMilliseconds,
    text: text,
  );

  /// Encodes this cue for draft/history storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'text': text,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
    if (words.isNotEmpty) 'words': [for (final word in words) word.toMap()],
  };

  /// Copy with the given fields replaced. The words are kept as they are;
  /// use [withText] and [withTiming] to keep them in step with an edit.
  CaptionCue copyWith({
    String? text,
    Duration? start,
    Duration? end,
    List<CaptionSegment>? words,
  }) => CaptionCue(
    id: id,
    text: text ?? this.text,
    start: start ?? this.start,
    end: end ?? this.end,
    words: words ?? this.words,
  );

  @override
  List<Object?> get props => [id, text, start, end, words];
}

/// The video's caption track as stored in editor history meta.
///
/// [cues] is always the source of truth: captions are always published as a
/// WebVTT closed-caption track (Blossom VTT + kind 39307 + `text-track`
/// tags). [burnIn] is an additional choice — when `true` the cues are *also*
/// rasterized into the exported video, styled either by the built-in
/// [presetId] or, when set, the user-defined [customStyle].
class CaptionTrack extends Equatable {
  /// Creates a caption track.
  const CaptionTrack({
    required this.presetId,
    required this.languageTag,
    this.burnIn = false,
    this.customStyle,
    this.cues = const [],
  });

  /// Decodes a track from its [toJson] map.
  ///
  /// Throws a [FormatException] when the map is malformed.
  factory CaptionTrack.fromJson(Map<Object?, Object?> json) {
    final presetId = json['presetId'];
    final languageTag = json['languageTag'];
    final rawCues = json['cues'];
    if (presetId is! String || languageTag is! String || rawCues is! List) {
      throw FormatException('Malformed caption track: $json');
    }
    final rawBurnIn = json['burnIn'];
    return CaptionTrack(
      // Legacy drafts stored a `mode` string instead of a `burnIn` bool.
      burnIn: rawBurnIn is bool ? rawBurnIn : json['mode'] == 'burnIn',
      presetId: presetId,
      languageTag: languageTag,
      customStyle: CaptionCustomStyle.fromJson(json['customStyle']),
      cues: [
        for (final cue in rawCues)
          CaptionCue.fromJson(cue! as Map<Object?, Object?>),
      ],
    );
  }

  /// Whether the cues are additionally burned into the exported video.
  final bool burnIn;

  /// The built-in style/animation preset id (see `CaptionStylePreset`). Used
  /// for the burned-in look when [customStyle] is `null`.
  final String presetId;

  /// The user-defined style, taking precedence over [presetId] when set.
  final CaptionCustomStyle? customStyle;

  /// BCP-47 tag of the caption language (e.g. `en-US`).
  final String languageTag;

  /// The cues, ordered by start time.
  final List<CaptionCue> cues;

  /// Encodes this track for draft/history storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'burnIn': burnIn,
    'presetId': presetId,
    'languageTag': languageTag,
    if (customStyle != null) 'customStyle': customStyle!.toJson(),
    'cues': [for (final cue in cues) cue.toJson()],
  };

  /// Copy with the given fields replaced. Pass [clearCustomStyle] to drop a
  /// custom style (selecting a built-in preset again).
  CaptionTrack copyWith({
    bool? burnIn,
    String? presetId,
    String? languageTag,
    CaptionCustomStyle? customStyle,
    bool clearCustomStyle = false,
    List<CaptionCue>? cues,
  }) => CaptionTrack(
    burnIn: burnIn ?? this.burnIn,
    presetId: presetId ?? this.presetId,
    languageTag: languageTag ?? this.languageTag,
    customStyle: clearCustomStyle ? null : (customStyle ?? this.customStyle),
    cues: cues ?? this.cues,
  );

  @override
  List<Object?> get props => [
    burnIn,
    presetId,
    customStyle,
    languageTag,
    cues,
  ];
}
