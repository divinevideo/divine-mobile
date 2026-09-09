// ABOUTME: Rich vertical card for a private device-local saved sound record.
// ABOUTME: Shows source context, waveform, and private organization at a glance.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Edge length of the source thumbnail leading each card.
const _thumbnailSize = 64.0;

class SavedSoundCard extends StatelessWidget {
  const SavedSoundCard({
    required this.sound,
    required this.onTap,
    required this.onPreview,
    required this.onEdit,
    required this.onRemove,
    this.isMissingFile = false,
    this.isPlaying = false,
    this.progress,
    this.progressValue = 0,
    super.key,
  });

  final SavedSound sound;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// Whether the device-local audio file behind this entry is gone.
  ///
  /// The entry stays listed — it still carries the label, hashtags and source
  /// context the user wrote — but it cannot play, so the card says so and
  /// takes the preview away instead of starting a silent one (#8023).
  final bool isMissingFile;

  /// Whether this sound is actively playing (not paused).
  final bool isPlaying;

  /// Playback position of the running preview as a 0–1 fraction.
  ///
  /// Null while this sound is not the one being previewed, which leaves the
  /// waveform unfilled. Non-null while paused still counts as the active
  /// preview so the partial fill and resume affordance stay visible.
  final Stream<double>? progress;

  /// Last known [progress] fraction, used when the waveform remounts while a
  /// preview is still active and the position stream is quiet (e.g. paused).
  final double progressValue;

  String _displayTitle(BuildContext context) =>
      sound.personalLabel ??
      sound.sourceContext?.title ??
      sound.audio.title ??
      context.l10n.savedSoundFallbackTitle;

  String _previewSemanticLabel(BuildContext context) {
    if (isPlaying) return context.l10n.savedSoundPausePreviewAction;
    if (progress != null) return context.l10n.savedSoundResumePreviewAction;
    return context.l10n.savedSoundPreviewAction;
  }

  @override
  Widget build(BuildContext context) {
    final source = sound.sourceContext;
    final duration = sound.audio.formattedDuration;
    final displayTitle = _displayTitle(context);
    final unavailableNotice = context.l10n.savedSoundFileMissing;
    return Semantics(
      label: [
        displayTitle,
        if (duration.isNotEmpty) duration,
        if (isMissingFile) unavailableNotice,
      ].join(', '),
      button: !isMissingFile,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isMissingFile ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      _SavedSoundThumbnail(url: source?.thumbnailUrl),
                      Expanded(
                        child: _SavedSoundText(
                          displayTitle: displayTitle,
                          sound: sound,
                        ),
                      ),
                    ],
                  ),
                  if (isMissingFile)
                    Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DivineIcon(
                          icon: .warning,
                          size: 16,
                          color: context.vineColors.onErrorContainer,
                        ),
                        Expanded(
                          child: Text(
                            unavailableNotice,
                            style: VineTheme.bodySmallFont(
                              color: context.vineColors.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!isMissingFile && sound.waveformSamples.isNotEmpty)
                    _SavedSoundWaveform(
                      sound: sound,
                      progress: progress,
                      progressValue: progressValue,
                    ),
                  if (sound.personalHashtags.isNotEmpty ||
                      sound.catalogTags.isNotEmpty)
                    _SavedSoundTags(sound: sound),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      // No preview button at all rather than a disabled
                      // one: there is nothing to wait for. Edit and remove
                      // stay, so the entry is still the user's to keep or
                      // drop.
                      if (!isMissingFile)
                        DivineIconButton(
                          key: const Key('saved_sound_preview'),
                          icon: isPlaying
                              ? DivineIconName.pause
                              : DivineIconName.play,
                          semanticLabel: _previewSemanticLabel(context),
                          size: DivineIconButtonSize.small,
                          type: DivineIconButtonType.secondary,
                          onPressed: onPreview,
                        ),
                      DivineIconButton(
                        key: const Key('saved_sound_edit'),
                        icon: DivineIconName.pencilSimple,
                        semanticLabel: context.l10n.savedSoundEditAction,
                        size: DivineIconButtonSize.small,
                        type: DivineIconButtonType.secondary,
                        onPressed: onEdit,
                      ),
                      DivineIconButton(
                        key: const Key('saved_sound_remove'),
                        icon: DivineIconName.trash,
                        semanticLabel: context.l10n.savedSoundRemoveAction,
                        size: DivineIconButtonSize.small,
                        type: DivineIconButtonType.error,
                        onPressed: onRemove,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedSoundThumbnail extends StatelessWidget {
  const _SavedSoundThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const _SavedSoundThumbnailFallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: VineCachedImage(
        key: const Key('saved_sound_thumbnail'),
        imageUrl: imageUrl,
        width: _thumbnailSize,
        height: _thumbnailSize,
        memCacheWidth: (_thumbnailSize * 2).round(),
        memCacheHeight: (_thumbnailSize * 2).round(),
        placeholder: (_, _) => const _SavedSoundThumbnailFallback(),
        errorWidget: (_, _, _) => const _SavedSoundThumbnailFallback(),
      ),
    );
  }
}

class _SavedSoundThumbnailFallback extends StatelessWidget {
  const _SavedSoundThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const Key('saved_sound_thumbnail_fallback'),
      dimension: _thumbnailSize,
      child: ColoredBox(
        color: context.vineColors.surfaceContainer,
        child: Center(
          child: DivineIcon(
            icon: DivineIconName.waveform,
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SavedSoundText extends StatelessWidget {
  const _SavedSoundText({required this.displayTitle, required this.sound});

  final String displayTitle;
  final SavedSound sound;

  @override
  Widget build(BuildContext context) {
    final source = sound.sourceContext;
    final secondaryTitle = sound.personalLabel == null
        ? null
        : source?.title ?? sound.audio.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
        ),
        if (secondaryTitle != null && secondaryTitle != displayTitle)
          Text(
            secondaryTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        if (source?.creatorName case final creator?)
          Text(
            context.l10n.soundCreatorBy(creator),
            style: VineTheme.labelMediumFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        if (source?.description case final description?)
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        if (source?.transcript case final transcript?) ...[
          const SizedBox(height: 4),
          Text(
            transcript,
            key: const Key('saved_sound_transcript'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedSoundWaveform extends StatelessWidget {
  const _SavedSoundWaveform({
    required this.sound,
    required this.progress,
    required this.progressValue,
  });

  final SavedSound sound;
  final Stream<double>? progress;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    final stream = progress;
    if (stream == null) {
      return _WaveformBars(sound: sound, progress: 0);
    }
    return StreamBuilder<double>(
      stream: stream,
      initialData: progressValue,
      builder: (context, snapshot) => _WaveformBars(
        sound: sound,
        progress: snapshot.data ?? progressValue,
      ),
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

class _SavedSoundTags extends StatelessWidget {
  const _SavedSoundTags({required this.sound});

  final SavedSound sound;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final hashtag in sound.personalHashtags)
          _SavedSoundTag(label: '#$hashtag', isPersonal: true),
        for (final tag in sound.catalogTags)
          _SavedSoundTag(label: tag, isPersonal: false),
      ],
    );
  }
}

class _SavedSoundTag extends StatelessWidget {
  const _SavedSoundTag({required this.label, required this.isPersonal});

  final String label;
  final bool isPersonal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPersonal
            ? VineTheme.vineGreen.withValues(alpha: 0.16)
            : context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: VineTheme.labelSmallFont(
            color: isPersonal
                ? context.vineColors.accentPositive
                : context.vineColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
