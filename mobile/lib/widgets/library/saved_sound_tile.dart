// ABOUTME: A sound saved to My Sounds as a row shaped like the sound picker's,
// ABOUTME: and the fuller view of it that heads its actions menu.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/divine_sound_extensions.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/audio/sound_list_tile.dart';
import 'package:openvine/widgets/audio/sound_progress_bar.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';

/// Where the row's text starts: [ListTile]'s start padding, the cover and the
/// gap after it. The progress under a previewing row lines up with it.
const double _textInset = 16 + 48 + 16;

/// A sound saved to My Sounds, as a row like the sound picker's.
///
/// Tapping it previews the sound; its actions sit behind the trailing menu
/// button. While it previews, its waveform, or a line for a sound without
/// one, shows under it and fills as the sound plays.
class SavedSoundTile extends StatelessWidget {
  const SavedSoundTile({
    required this.sound,
    required this.onPreview,
    required this.onOpenMore,
    this.cover,
    this.isCoverPending = false,
    this.isMissingFile = false,
    this.cannotBeReused = false,
    this.isPreviewing = false,
    this.isPlaying = false,
    this.progress,
    this.progressValue = 0,
    super.key,
  });

  final SavedSound sound;

  /// Starts the preview, or pauses or resumes it while [isPreviewing].
  final VoidCallback onPreview;

  /// Opens the sound's actions.
  final VoidCallback onOpenMore;

  /// Artwork leading the row, or `null` for the colour tile.
  final SoundCover? cover;

  /// Whether [cover] is still being looked up.
  final bool isCoverPending;

  /// Whether the device-local audio file behind this entry is gone.
  ///
  /// The entry stays listed — it still carries the label, hashtags and source
  /// context the user wrote — but it cannot play, so the row says so and
  /// takes no tap instead of starting a silent preview (#8023).
  final bool isMissingFile;

  /// Whether the sound can no longer be used in a new video, its source
  /// video being gone or no longer letting others reuse its sound.
  ///
  /// The sound picker leaves such a sound out. Here it stays, saying why, so
  /// the user can still find and remove it.
  final bool cannotBeReused;

  /// Whether this sound is the one previewing, playing or paused.
  final bool isPreviewing;

  /// Whether the preview is playing rather than paused.
  final bool isPlaying;

  /// Playback position of the running preview as a 0–1 fraction, while
  /// [isPreviewing].
  final Stream<double>? progress;

  /// Last known [progress] fraction, used when the progress remounts while a
  /// preview is still active and the position stream is quiet (e.g. paused).
  final double progressValue;

  String _previewHint(BuildContext context) {
    if (isPlaying) return context.l10n.savedSoundPausePreviewAction;
    if (isPreviewing) return context.l10n.savedSoundResumePreviewAction;
    return context.l10n.savedSoundPreviewAction;
  }

  @override
  Widget build(BuildContext context) {
    final unavailableReason = savedSoundUnavailableReason(
      context,
      isMissingFile: isMissingFile,
      cannotBeReused: cannotBeReused,
    );
    final title = savedSoundTitle(context, sound);
    final showsProgress = isPreviewing && unavailableReason == null;
    return Column(
      mainAxisSize: .min,
      children: [
        Semantics(
          onTapHint: unavailableReason == null ? _previewHint(context) : null,
          child: _SavedSoundListTile(
            sound: sound,
            title: title,
            cover: cover,
            isCoverPending: isCoverPending,
            isActive: isPreviewing,
            isPlaying: isPlaying,
            unavailableReason: unavailableReason,
            trailing: DivineIconButton(
              key: const Key('saved_sound_more'),
              icon: DivineIconName.dotsThreeVertical,
              type: DivineIconButtonType.ghostSecondary,
              size: DivineIconButtonSize.small,
              semanticLabel: context.l10n
                  .libraryScheduledMoreActionsSemanticLabel(title),
              onPressed: onOpenMore,
            ),
            onTap: onPreview,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200).autoReduceMotion(context),
          alignment: .topCenter,
          child: showsProgress
              ? Padding(
                  padding: const .fromSTEB(_textInset, 0, 24, 12),
                  child: _PreviewProgress(
                    sound: sound,
                    progress: progress,
                    progressValue: progressValue,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// [sound] as a fuller view than its row: the row itself, then the source
/// video's title, description and transcript and the sound's catalog tags.
///
/// Heads the sound's actions menu, where there is room for them.
class SavedSoundMenuHeader extends StatelessWidget {
  const SavedSoundMenuHeader({
    required this.sound,
    this.cover,
    this.isMissingFile = false,
    this.cannotBeReused = false,
    super.key,
  });

  final SavedSound sound;
  final SoundCover? cover;

  /// See [SavedSoundTile.isMissingFile].
  final bool isMissingFile;

  /// See [SavedSoundTile.cannotBeReused].
  final bool cannotBeReused;

  @override
  Widget build(BuildContext context) {
    final source = sound.sourceContext;
    final title = savedSoundTitle(context, sound);
    // The row shows the user's label; this is what the sound is called
    // where it came from.
    final originalTitle = sound.personalLabel == null
        ? null
        : source?.title ?? sound.audio.title;
    final secondaryStyle = VineTheme.bodySmallFont(
      color: context.vineColors.onSurfaceVariant,
    );
    // The sheet header centres its title; this reads as a block instead.
    return DefaultTextStyle.merge(
      textAlign: .start,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 8,
        children: [
          _SavedSoundListTile(
            sound: sound,
            title: title,
            cover: cover,
            unavailableReason: savedSoundUnavailableReason(
              context,
              isMissingFile: isMissingFile,
              cannotBeReused: cannotBeReused,
            ),
            contentPadding: .zero,
          ),
          if (originalTitle != null && originalTitle != title)
            Text(
              originalTitle,
              maxLines: 1,
              overflow: .ellipsis,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          if (source?.description case final description?)
            Text(
              description,
              maxLines: 3,
              overflow: .ellipsis,
              style: secondaryStyle,
            ),
          if (source?.transcript case final transcript?)
            Text(
              transcript,
              key: const Key('saved_sound_transcript'),
              maxLines: 3,
              overflow: .ellipsis,
              style: secondaryStyle,
            ),
          if (sound.catalogTags.isNotEmpty)
            _CatalogTags(tags: sound.catalogTags),
        ],
      ),
    );
  }
}

/// The title [sound] is listed under: the label the user gave it, else what
/// its source video or the sound itself is called.
String savedSoundTitle(BuildContext context, SavedSound sound) =>
    sound.personalLabel ??
    sound.sourceContext?.title ??
    sound.audio.title ??
    context.l10n.savedSoundFallbackTitle;

/// Why a saved sound cannot be previewed or used, or `null` when it can.
String? savedSoundUnavailableReason(
  BuildContext context, {
  required bool isMissingFile,
  required bool cannotBeReused,
}) {
  // Worded as the sound picker words the same condition.
  if (isMissingFile) return context.l10n.videoEditorAudioFileMissing;
  if (cannotBeReused) return context.l10n.savedSoundReuseUnavailable;
  return null;
}

/// The row a [SavedSoundTile] and a [SavedSoundMenuHeader] both show.
class _SavedSoundListTile extends StatelessWidget {
  const _SavedSoundListTile({
    required this.sound,
    required this.title,
    required this.cover,
    required this.unavailableReason,
    this.isCoverPending = false,
    this.isActive = false,
    this.isPlaying = false,
    this.trailing,
    this.contentPadding,
    this.onTap,
  });

  final SavedSound sound;
  final String title;
  final SoundCover? cover;
  final String? unavailableReason;
  final bool isCoverPending;
  final bool isActive;
  final bool isPlaying;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final audio = sound.audio;
    final creator = sound.sourceContext?.creatorName;
    return SoundListTile(
      title: title,
      duration: audio.duration,
      details: [if (creator != null) context.l10n.soundCreatorBy(creator)],
      caption: sound.personalHashtags.isEmpty
          ? null
          : _Hashtags(hashtags: sound.personalHashtags),
      cover: cover,
      isCoverPending: isCoverPending,
      colorSeed: sound.id,
      isCommunitySound: !audio.isDivine && audio.attributionEventId != null,
      isActive: isActive,
      isPlaying: isPlaying,
      unavailableReason: unavailableReason,
      trailing: trailing,
      contentPadding: contentPadding,
      onTap: onTap,
    );
  }
}

/// The hashtags the user filed a sound under, on one line.
class _Hashtags extends StatelessWidget {
  const _Hashtags({required this.hashtags});

  final List<String> hashtags;

  @override
  Widget build(BuildContext context) {
    return Text(
      hashtags.map((hashtag) => '#$hashtag').join(' '),
      key: const Key('saved_sound_hashtags'),
      maxLines: 1,
      overflow: .ellipsis,
      style: VineTheme.bodyMediumFont(
        color: context.vineColors.accentPositive,
      ),
    );
  }
}

/// How far the preview has played: the sound's waveform filling, or a line
/// for a sound saved without one.
class _PreviewProgress extends StatelessWidget {
  const _PreviewProgress({
    required this.sound,
    required this.progress,
    required this.progressValue,
  });

  final SavedSound sound;
  final Stream<double>? progress;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: progress,
      initialData: progressValue,
      builder: (context, snapshot) {
        final played = snapshot.data ?? progressValue;
        return sound.waveformSamples.isEmpty
            ? SoundProgressBar(
                key: const Key('saved_sound_progress'),
                progress: played,
              )
            : _WaveformBars(sound: sound, progress: played);
      },
    );
  }
}

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.sound, required this.progress});

  final SavedSound sound;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(
      milliseconds: ((sound.audio.duration ?? 1) * 1000).round(),
    );
    return SizedBox(
      key: const Key('saved_sound_waveform'),
      height: 28,
      width: double.infinity,
      child: CustomPaint(
        painter: StereoWaveformPainter(
          leftChannel: Float32List.fromList(sound.waveformSamples),
          progress: progress,
          activeColor: context.vineColors.accentPositive,
          inactiveColor: context.vineColors.onSurfaceVariant,
          audioDuration: duration,
          maxDuration: duration,
        ),
      ),
    );
  }
}

class _CatalogTags extends StatelessWidget {
  const _CatalogTags({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 8, vertical: 4),
              child: Text(
                tag,
                style: VineTheme.labelSmallFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
