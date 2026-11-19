// ABOUTME: The two sample cues a caption style preview loops through: the
// ABOUTME: video's first two captions, otherwise Divine's tagline.

import 'package:equatable/equatable.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/video_editor/caption_track.dart';

/// The two cues a caption style preview shows one after the other.
///
/// Previewing a video's own captions shows each style with the cues it will
/// burn in, each one whole, as the editor shows it. The loop needs two cues
/// to show one handing over to the next, so the tagline stands in until the
/// video has two captions.
class CaptionPreviewCues extends Equatable {
  /// Creates the cues from their texts.
  const CaptionPreviewCues(this.first, this.second);

  /// The first two cues of [cues] that have text, given in timeline order, or
  /// [fallback] while fewer than two have text.
  factory CaptionPreviewCues.fromCues(List<CaptionCue> cues) {
    final captions = [
      for (final cue in cues)
        if (cue.text.trim() case final text when text.isNotEmpty) text,
    ];
    return switch (captions) {
      [final first, final second, ...] => CaptionPreviewCues(first, second),
      _ => fallback,
    };
  }

  /// The sample shown without two captions to preview: a Vine wordplay
  /// tagline, deliberately English everywhere since it is the brand's line,
  /// not copy that goes through l10n.
  static const fallback = CaptionPreviewCues('Do It For', AppConfig.appName);

  /// The cue shown first.
  final String first;

  /// The cue shown second.
  final String second;

  @override
  List<Object?> get props => [first, second];
}
