// ABOUTME: Sounds section for the metadata expanded sheet.
// ABOUTME: Shows audio info for all videos - shared audio or "Original sound".

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_credit.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:unified_logger/unified_logger.dart';

/// Sounds section showing audio attribution in the metadata sheet.
///
/// Two modes:
/// - **Shared audio**: Video has a Kind 1063 audio event — shows sound name,
///   artist, and tapping navigates to [SoundDetailScreen].
/// - **Original sound**: No audio event — shows "Original sound - @creator"
///   as display-only info.
class MetadataSoundsSection extends ConsumerWidget {
  const MetadataSoundsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If video has an explicit audio reference, show the fetched audio info
    if (video.hasAudioReference && video.audioEventId != null) {
      return _SharedAudioSection(video: video);
    }

    // Otherwise show "Original sound - @creator"
    return _OriginalSoundSection(video: video);
  }
}

/// Section for videos with an explicit Kind 1063 audio reference.
class _SharedAudioSection extends ConsumerWidget {
  const _SharedAudioSection({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioAsync = ref.watch(soundByIdProvider(video.audioEventId!));

    return audioAsync.when(
      data: (audio) {
        if (audio == null) {
          // The shared audio event couldn't be resolved (e.g. the source
          // video isn't reachable by id). This video still reused a sound, so
          // credit the reused sound's original creator rather than the
          // reusing user.
          return _OriginalSoundSection(
            video: video,
            reusedCreatorPubkey: AudioAttributionCredit.reusedCreatorPubkeyFor(
              video,
            ),
          );
        }
        return MetadataSection(
          label: context.l10n.metadataSoundsLabel,
          child: _SoundListItem(audio: audio, sourceVideo: video),
        );
      },
      loading: () => MetadataSection(
        label: context.l10n.metadataSoundsLabel,
        child: const _SoundSkeleton(),
      ),
      error: (error, stack) {
        Log.error(
          'Failed to load audio for metadata sheet: $error',
          name: 'MetadataSoundsSection',
          category: LogCategory.ui,
        );
        return _OriginalSoundSection(
          video: video,
          reusedCreatorPubkey: AudioAttributionCredit.reusedCreatorPubkeyFor(
            video,
          ),
        );
      },
    );
  }
}

/// Section showing "Original sound - @creator" for videos without shared
/// audio.
///
/// The row is always shown for attribution, but it is only a reuse entry point
/// (tappable into [SoundDetailScreen]) when the sound may be reused — see
/// [_canReuseSound]. When it may not, the row is display-only credit, so a
/// creator who left audio sharing off is not silently made reusable.
class _OriginalSoundSection extends ConsumerWidget {
  const _OriginalSoundSection({required this.video, this.reusedCreatorPubkey});

  final VideoEvent video;

  /// When set, the audio was reused from another creator (resolved via the
  /// video's inspired-by source) but the shared audio event couldn't be
  /// fetched. This pubkey is credited instead of the reusing user.
  final String? reusedCreatorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorPubkey = reusedCreatorPubkey ?? video.pubkey;
    final creatorProfile = ref
        .watch(userProfileReactiveProvider(creatorPubkey))
        .value;
    final creatorName = AudioAttributionCredit.creatorNameFor(
      video: video,
      creatorProfile: creatorProfile,
      reusedCreatorPubkey: reusedCreatorPubkey,
    );

    return MetadataSection(
      label: context.l10n.metadataSoundsLabel,
      child: _OriginalSoundRow(
        creatorName: creatorName,
        onTap: _canReuseSound(ref)
            ? () => _navigateToSoundDetail(context, creatorName)
            : null,
      ),
    );
  }

  /// Whether the viewer may reuse this original sound.
  ///
  /// This section is reached in two shapes. When the video has an audio
  /// reference it reused a sound we couldn't resolve (the
  /// [_SharedAudioSection] fallback): the referenced source's reuse consent
  /// can't be confirmed offline, so fail closed — attribution still shows but
  /// the sound isn't offered for reuse (an owner-saved private sound must not
  /// leak this way). Otherwise this is the video's own original sound, reusable
  /// when its creator enabled audio reuse, when an exact verified archive
  /// record receives Divine's legacy reuse presumption, or when the viewer is
  /// that creator. The archive presumption is not affirmative creator consent.
  bool _canReuseSound(WidgetRef ref) {
    if (video.hasAudioReference) return false;
    final knownTerms = originalSoundReuseTerms(video);
    if (knownTerms == true) return true;
    // Re-evaluate on auth restore/logout/account-switch so the owner exception
    // can't go stale (authServiceProvider alone is a stable instance).
    ref.watch(currentAuthStateProvider);
    final viewerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    if (viewerPubkey != null && viewerPubkey == video.pubkey) return true;
    return knownTerms ?? false;
  }

  void _navigateToSoundDetail(BuildContext context, String creatorName) {
    Log.info(
      'Navigating to original sound detail for video: ${video.id}',
      name: 'MetadataSoundsSection',
      category: LogCategory.ui,
    );

    // Only reached for the video's own original sound (the reused-but-
    // unresolved fallback is display-only), so build from this video directly.
    final syntheticAudio = AudioEvent.fromVideoOriginalSound(
      video,
      creatorName: creatorName,
    );

    // Dismiss the sheet first, then navigate from the root navigator
    // context.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero).then((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(
        SoundDetailScreen.pathForId(syntheticAudio.id),
        extra: <String, dynamic>{'sound': syntheticAudio, 'sourceVideo': video},
      );
    });
  }
}

/// The "Original sound - @creator" row.
///
/// When [onTap] is non-null the row is a reuse entry point: tappable, with a
/// trailing chevron and button semantics. When null it is display-only
/// attribution — the sound may not be reused, so viewers see the credit but no
/// affordance to adopt it.
class _OriginalSoundRow extends StatelessWidget {
  const _OriginalSoundRow({required this.creatorName, required this.onTap});

  final String creatorName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final row = Row(
      spacing: 16,
      children: [
        DivineIcon(
          icon: DivineIconName.waveform,
          color: context.vineColors.onSurfaceVariant,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.metadataOriginalSound,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              Text(
                creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          DivineIcon(
            icon: DivineIconName.caretRight,
            color: context.vineColors.onSurfaceVariant,
            size: 20,
          ),
      ],
    );

    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: context.l10n.metadataSoundsOriginalSoundSemantics(creatorName),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// A list item showing audio cover, title, and artist name.
/// Tapping navigates to the [SoundDetailScreen].
class _SoundListItem extends ConsumerWidget {
  const _SoundListItem({required this.audio, required this.sourceVideo});

  final AudioEvent audio;
  final VideoEvent sourceVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundName = audio.title ?? context.l10n.metadataOriginalSound;
    final String publisherName;

    if (audio.isBundled) {
      publisherName = audio.source ?? 'Divine';
    } else {
      final publisherProfile = ref
          .watch(userProfileReactiveProvider(audio.pubkey))
          .value;
      publisherName = AudioAttributionCredit.publisherNameFor(
        audio: audio,
        publisherProfile: publisherProfile,
      );
    }
    final creatorName = audio.creatorName;
    final creditText = creatorName == null
        ? publisherName
        : [
            context.l10n.soundCreatorBy(creatorName),
            if (audio.creatorPubkey == null ||
                audio.creatorPubkey != audio.pubkey)
              context.l10n.soundSharedBy(publisherName),
          ].join(' · ');
    // Null while legacy terms are still being verified. The badge states the
    // sound's public terms, not the current viewer's permission to reuse it.
    final knownReuseTerms = audioReuseTermsFromEvent(audio);
    final reuseAllowed =
        knownReuseTerms ?? ref.watch(audioReuseTermsProvider(audio)).value;

    return Semantics(
      button: true,
      label: context.l10n.metadataSoundsSharedSoundSemantics(
        soundName,
        creditText,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToSoundDetail(context),
        child: Row(
          spacing: 16,
          children: [
            DivineIcon(
              icon: DivineIconName.waveform,
              color: context.vineColors.onSurfaceVariant,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soundName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  Text(
                    creditText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                  if (reuseAllowed != null)
                    Text(
                      reuseAllowed
                          ? context.l10n.soundRemixingAllowed
                          : context.l10n.soundCreditOnly,
                      style: VineTheme.labelSmallFont(
                        color: reuseAllowed
                            ? context.vineColors.accentPositive
                            : context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  if (audio.licenseName case final license?)
                    Text(
                      license,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.labelSmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  if (audio.source case final source?)
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.labelSmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  if (audio.publicTags.isNotEmpty)
                    Text(
                      audio.publicTags.map((tag) => '#$tag').join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.labelSmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            DivineIcon(
              icon: DivineIconName.caretRight,
              color: context.vineColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSoundDetail(BuildContext context) {
    Log.info(
      'Navigating to sound detail from metadata: ${audio.id}',
      name: 'MetadataSoundsSection',
      category: LogCategory.ui,
    );

    // Dismiss the sheet first, then navigate from the root navigator context.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero).then((_) {
      if (!hostContext.mounted) return;
      // Pass the resolved sound via `extra` (like [_OriginalSoundSection]):
      // a reused original sound's synthetic `video_<id>` id can't be
      // re-fetched by the detail loader, so without this it dead-ends at
      // "Sound not found".
      hostContext.pushWithVideoPause(
        SoundDetailScreen.pathForId(audio.id),
        extra: <String, dynamic>{'sound': audio, 'sourceVideo': sourceVideo},
      );
    });
  }
}

/// Loading skeleton for the sound list item.
class _SoundSkeleton extends StatelessWidget {
  const _SoundSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 16,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
