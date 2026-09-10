// ABOUTME: Scrim-30 capsule with three playback toggles
// ABOUTME: (compilations / mute / closed-captions). Rendered both as
// ABOUTME: the body of the top-bar settings popover and above the play
// ABOUTME: affordance in the paused-video overlay. Compilations and
// ABOUTME: captions confirm their new state in a snackbar.

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';

/// Scrim-30 backdrop-blurred capsule housing the three playback toggles:
/// auto-advance ("compilations"), audio mute, and closed-captions.
///
/// Auto-advance and audio mute are feed-wide controls. Captions are scoped to
/// [videoId] when a feed surface has current-video context; otherwise the
/// captions button falls back to the global Settings preference.
class FeedPlaybackTogglesPill extends StatelessWidget {
  const FeedPlaybackTogglesPill({super.key, this.videoId});

  final String? videoId;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    // The pill floats over video, so light mode gets the light chrome
    // treatment; dark mode keeps the scrim-30 capsule unchanged.
    final isLight = Theme.of(context).brightness == Brightness.light;
    final chromeBackground = isLight ? colors.mediaChrome : VineTheme.scrim30;
    final chromeForeground = isLight
        ? colors.mediaChromeForeground
        : VineTheme.onSurface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chromeBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VineTheme.scrim15),
            boxShadow: const [
              BoxShadow(color: VineTheme.shadow25, blurRadius: 4),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _PlaybackModeToggle(foregroundColor: chromeForeground),
                _AudioToggle(foregroundColor: chromeForeground),
                _CaptionsToggle(
                  foregroundColor: chromeForeground,
                  videoId: videoId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto-advance ("compilations") toggle. Confirms its new state in a
/// snackbar. Hidden when the OS-level
/// reduced-motion preference is set — auto-advance is unavailable in
/// that state. Also hidden when no [FeedAutoAdvanceCubit] is provided
/// in the surrounding scope, so the pill can be rendered in any
/// surface without requiring callers to wire up the cubit when they
/// don't use auto-advance.
class _PlaybackModeToggle extends StatelessWidget {
  const _PlaybackModeToggle({required this.foregroundColor});

  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    final cubit = _maybeReadFeedAutoAdvanceCubit(context);
    if (cubit == null) return const SizedBox.shrink();

    return BlocSelector<FeedAutoAdvanceCubit, FeedAutoAdvanceState, bool>(
      bloc: cubit,
      selector: (state) => state.enabled,
      builder: (context, enabled) {
        return _PopoverToggle(
          isOn: enabled,
          semanticLabel: enabled
              ? context.l10n.videoActionDisableAutoAdvance
              : context.l10n.videoActionEnableAutoAdvance,
          onTap: () {
            cubit.toggle();
            if (!cubit.state.isEffectivelyActive) {
              cubit.clearPendingPaginationAdvance();
            }
            // The snackbar is a live region, so it carries the screen-reader
            // announcement on its own — no separate `sendAnnouncement`, which
            // would make a reader speak twice with two different strings.
            _showToggleFeedback(
              context,
              cubit.state.enabled
                  ? context.l10n.videoSettingsAutoAdvanceOn
                  : context.l10n.videoSettingsAutoAdvanceOff,
            );
          },
          child: DivineIcon(
            icon: enabled
                ? DivineIconName.playbackModeOn
                : DivineIconName.playbackModeOff,
            color: foregroundColor,
          ),
        );
      },
    );
  }
}

/// Audio mute toggle. Drives [VideoVolumeCubit] directly.
class _AudioToggle extends StatelessWidget {
  const _AudioToggle({required this.foregroundColor});

  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final isMuted = context.select((VideoVolumeCubit c) => c.state.volume == 0);
    return _PopoverToggle(
      isOn: isMuted,
      semanticLabel: isMuted
          ? context.l10n.videoPlayerUnmute
          : context.l10n.videoPlayerMute,
      onTap: () {
        context.read<VideoVolumeCubit>().onPlaybackVolumeChanged(
          isMuted ? 1 : 0,
        );
        SemanticsService.sendAnnouncement(
          View.of(context),
          isMuted
              ? context.l10n.videoPlayerUnmute
              : context.l10n.videoPlayerMute,
          Directionality.of(context),
        );
      },
      child: DivineIcon(
        icon: isMuted
            ? DivineIconName.speakerSimpleSlash
            : DivineIconName.speakerSimpleHigh,
        color: foregroundColor,
      ),
    );
  }
}

/// Closed-captions toggle. Active state means subtitles are visible.
/// Confirms its new state in a snackbar.
class _CaptionsToggle extends ConsumerWidget {
  const _CaptionsToggle({required this.foregroundColor, this.videoId});

  final Color foregroundColor;
  final String? videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoId = this.videoId;
    final enabled = videoId == null
        ? ref.watch(subtitleVisibilityProvider)
        : ref.watch(subtitleVisibilityForVideoProvider(videoId));
    return _PopoverToggle(
      isOn: enabled,
      semanticLabel: enabled
          ? context.l10n.videoSettingsCaptionsDisable
          : context.l10n.videoSettingsCaptionsEnable,
      onTap: () {
        if (videoId == null) {
          ref.read(subtitleVisibilityProvider.notifier).toggle();
        } else {
          ref
              .read(subtitleVisibilityOverrideProvider.notifier)
              .toggleForVideo(videoId);
        }
        _showToggleFeedback(
          context,
          videoId == null
              ? enabled
                    ? context.l10n.videoSettingsCaptionsOff
                    : context.l10n.videoSettingsCaptionsOn
              : enabled
              ? context.l10n.videoSettingsCaptionsOffForVideo
              : context.l10n.videoSettingsCaptionsOnForVideo,
        );
      },
      child: DivineIcon(
        icon: enabled
            ? DivineIconName.closedCaptioningFill
            : DivineIconName.closedCaptioning,
        color: foregroundColor,
      ),
    );
  }
}

/// 48 px touch target wrapping a 12 px-padded scrim button (40 px
/// visible at 20 px radius). Background flips between scrim-15 (off)
/// and scrim-50 (on).
class _PopoverToggle extends StatelessWidget {
  const _PopoverToggle({
    required this.isOn,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool isOn;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bg = isOn ? VineTheme.scrim50 : VineTheme.scrim15;
    return Semantics(
      button: true,
      toggled: isOn,
      label: semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox.square(dimension: 24, child: child),
          ),
        ),
      ),
    );
  }
}

FeedAutoAdvanceCubit? _maybeReadFeedAutoAdvanceCubit(BuildContext context) =>
    context.read<FeedAutoAdvanceCubit?>();

/// Confirms a toggle's new state in a snackbar.
///
/// The icons alone don't say what auto-advance and captions actually do, and
/// unlike mute neither has an immediately perceivable effect, so the banner
/// names the state the tap just produced. Any banner still on screen is
/// replaced rather than queued, so rapid toggling always shows the current
/// state.
///
/// Uses `removeCurrentSnackBar` rather than `hideCurrentSnackBar`: hiding only
/// *starts* the exit animation, and the entry leaves `ScaffoldMessenger`'s
/// queue when that animation reports `dismissed`, so the banner shown next
/// lands behind the departing one. Removing drops it in the same frame, which
/// is what makes this a replace instead of a queue.
void _showToggleFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      DivineSnackbarContainer.snackBar(
        message,
        duration: _FeedPlaybackToggles.feedbackDuration,
      ),
    );
}

abstract class _FeedPlaybackToggles {
  /// Long enough to read two words, short enough not to sit over the video.
  static const feedbackDuration = Duration(seconds: 2);
}
