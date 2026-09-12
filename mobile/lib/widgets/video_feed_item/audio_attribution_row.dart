// ABOUTME: Audio attribution row widget for displaying sound info on video feed.
// ABOUTME: Shows shared sound name or "Original sound - @creator" with tap navigation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_credit.dart';
import 'package:unified_logger/unified_logger.dart';

/// A tappable row showing audio attribution on every video in the feed.
///
/// Three display modes:
/// - **Shared audio**: `♪ Sound name · Creator` → taps to [SoundDetailScreen]
/// - **Original sound**: `♪ Original sound - @creator` → taps to
///   [OriginalSoundDetailScreen]
/// - **Unresolved reference**: `♪ Sound unavailable · Creator`, display-only —
///   the video reuses a sound whose event can't be fetched (#6185)
class AudioAttributionRow extends ConsumerWidget {
  /// Creates an AudioAttributionRow.
  const AudioAttributionRow({required this.video, super.key});

  /// The video event to display audio attribution for.
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show for videos with shared/bundled audio, not original sounds.
    // Original sound info is available in the metadata "more info" sheet.
    if (!video.hasAudioReference || video.audioEventId == null) {
      return const SizedBox.shrink();
    }

    // Watch the shared audio event asynchronously
    final audioAsync = ref.watch(soundByIdProvider(video.audioEventId!));

    return audioAsync.when(
      data: (audio) {
        if (audio == null) {
          return _UnresolvedAudioAttribution(video: video);
        }

        return _AudioAttributionContent(audio: audio, sourceVideo: video);
      },
      loading: () => const _AudioAttributionSkeleton(),
      error: (error, stack) => _UnresolvedAudioAttribution(video: video),
    );
  }
}

/// The actual content showing audio attribution.
class _AudioAttributionContent extends ConsumerWidget {
  const _AudioAttributionContent({
    required this.audio,
    required this.sourceVideo,
  });

  final AudioEvent audio;
  final VideoEvent sourceVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundName = audio.title ?? context.l10n.audioAttributionOriginalSound;
    final String publisherName;

    if (audio.isBundled) {
      // For bundled sounds, use the source field (e.g. "ThePauny via Freesound")
      publisherName = audio.source ?? 'Divine';
    } else {
      // The Kind 1063 signer may be sharing another creator's work.
      final publisherProfile = ref
          .watch(userProfileReactiveProvider(audio.pubkey))
          .value;
      publisherName = AudioAttributionCredit.publisherNameFor(
        audio: audio,
        publisherProfile: publisherProfile,
      );
    }
    final creditedCreator = audio.creatorName;
    final creditText = [
      if (creditedCreator == null)
        publisherName
      else ...[
        context.l10n.soundCreatorBy(creditedCreator),
        if (audio.creatorPubkey == null || audio.creatorPubkey != audio.pubkey)
          context.l10n.soundSharedBy(publisherName),
      ],
      ?audio.licenseName,
      ...audio.publicTags.map((tag) => '#$tag'),
    ].join(' · ');

    return _AudioAttributionPill(
      soundName: soundName,
      creatorName: creditText,
      semanticLabel: context.l10n.audioAttributionRowSemanticLabel(
        soundName,
        creditText,
      ),
      onTap: () => _navigateToSoundDetail(context, audio),
    );
  }

  void _navigateToSoundDetail(BuildContext context, AudioEvent audio) {
    Log.info(
      'Navigating to sound detail: ${audio.id}',
      name: 'AudioAttributionRow',
      category: LogCategory.ui,
    );

    context.pushWithVideoPause(
      SoundDetailScreen.pathForId(audio.id),
      extra: <String, dynamic>{'sound': audio, 'sourceVideo': sourceVideo},
    );
  }
}

/// Display-only credit shown when the referenced audio event can't be
/// resolved — an unreachable relay, or a source video whose event id was
/// replaced by an edit.
///
/// The video *did* reuse a sound, so collapsing to nothing drops the signal
/// entirely and reads to the publisher as "my sound never got attached"
/// (#6185). The credit selection mirrors `MetadataSoundsSection`, but the
/// sound label stays neutral because the referenced event may be a named shared
/// sound rather than the author's original sound. Stays display-only — reuse
/// consent can't be confirmed without the source event, so this must not become
/// a reuse entry point.
class _UnresolvedAudioAttribution extends ConsumerWidget {
  const _UnresolvedAudioAttribution({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only reached with an audio reference, so inspired-by is the best
    // available credit for the sound here.
    final reusedCreatorPubkey = AudioAttributionCredit.reusedCreatorPubkeyFor(
      video,
    );
    final creatorPubkey = reusedCreatorPubkey ?? video.pubkey;
    final creatorProfile = ref
        .watch(userProfileReactiveProvider(creatorPubkey))
        .value;

    return _AudioAttributionPill(
      soundName: context.l10n.audioAttributionUnavailableSound,
      creatorName: AudioAttributionCredit.creatorNameFor(
        video: video,
        creatorProfile: creatorProfile,
        reusedCreatorPubkey: reusedCreatorPubkey,
      ),
    );
  }
}

/// The attribution pill itself: music note, `Sound · Creator`, and — only when
/// [onTap] is set — a trailing chevron and button semantics.
class _AudioAttributionPill extends StatelessWidget {
  const _AudioAttributionPill({
    required this.soundName,
    required this.creatorName,
    this.semanticLabel,
    this.onTap,
  });

  final String soundName;
  final String creatorName;

  /// Screen-reader label for the tappable form. Null for the display-only
  /// form, where the rendered text is already the whole content.
  final String? semanticLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const DivineIcon(
            icon: DivineIconName.musicNote,
            size: 14,
            color: VineTheme.vineGreen,
          ),
          Flexible(
            child: Text(
              '$soundName · $creatorName',
              style: VineTheme.labelMediumFont(
                color: VineTheme.whiteText,
              ).copyWith(shadows: [const Shadow(blurRadius: 4)]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null)
            const DivineIcon(
              icon: DivineIconName.caretRight,
              size: 14,
              color: VineTheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    return Semantics(
      identifier: 'audio_attribution_row',
      button: onTap != null,
      label: semanticLabel,
      child: onTap == null ? pill : GestureDetector(onTap: onTap, child: pill),
    );
  }
}

/// Skeleton loading state for audio attribution.
class _AudioAttributionSkeleton extends StatelessWidget {
  const _AudioAttributionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineIcon(
            icon: DivineIconName.musicNote,
            size: 14,
            color: VineTheme.lightText,
          ),
          const SizedBox(width: 4),
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: VineTheme.lightText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
