// ABOUTME: Error overlay for the pooled video player path.
// ABOUTME: Differentiates moderation-restricted (403), age-gated (401),
// ABOUTME: missing (404), and generic playback errors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/extensions/video_event_content_type_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Error overlay for videos playing through the pooled video player.
///
/// Shows different UI based on the [VideoErrorType] from the controller:
/// - [VideoErrorType.forbidden] for Divine URLs: Shield icon +
///   "Content restricted" (no retry)
/// - [VideoErrorType.forbidden] for third-party URLs: Error icon +
///   "Video playback error" + Retry
/// - [VideoErrorType.notFound] with moderation status: Shield icon +
///   "Content restricted" (no retry)
/// - [VideoErrorType.ageRestricted]: Lock icon + "Age-restricted content" +
///   Verify Age
/// - [VideoErrorType.notFound]: Error icon + "Video not found" + Retry
/// - [VideoErrorType.generic]: Error icon + "Video playback error" + Retry
class PooledVideoErrorOverlay extends ConsumerStatefulWidget {
  const PooledVideoErrorOverlay({
    required this.video,
    required this.onRetry,
    required this.errorType,
    this.onSkip,
    this.onVerifyAge,
    this.isVerifying = false,
    this.isAuthRetryExhausted = false,
    this.shouldPortraitExpand = true,
    this.isSquare = false,
    super.key,
  });

  final VideoEvent video;
  final VoidCallback onRetry;
  final VoidCallback? onSkip;
  final VoidCallback? onVerifyAge;

  /// Whether an age-verification retry is in flight. Shows the Verify age
  /// button's loading state (which also disables it, preventing double taps).
  final bool isVerifying;

  /// Whether authenticated retry already failed for this video in this session.
  final bool isAuthRetryExhausted;

  final VideoErrorType? errorType;

  /// Mirrors `InfiniteVideoFeed.shouldPortraitExpand`. When `false`, the
  /// thumbnail uses [BoxFit.contain] regardless of orientation so square
  /// or letterboxed videos are not cropped.
  final bool shouldPortraitExpand;

  /// Whether the video is square (1:1). When `true` the thumbnail uses
  /// [BoxFit.contain] to avoid stretching it across the full feed
  /// viewport.
  final bool isSquare;

  @override
  ConsumerState<PooledVideoErrorOverlay> createState() =>
      _PooledVideoErrorOverlayState();
}

class _PooledVideoErrorOverlayState
    extends ConsumerState<PooledVideoErrorOverlay> {
  BoxFit _resolveBoxFit() {
    if (!widget.shouldPortraitExpand) return BoxFit.contain;
    return widget.isSquare ? BoxFit.contain : BoxFit.cover;
  }

  void _maybeAutoRetryAgeRestricted({required bool showVerifyAge}) {
    if (!showVerifyAge || widget.isVerifying || widget.onVerifyAge == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final playbackStatusCubit = context.read<VideoPlaybackStatusCubit>();
      if (!await playbackStatusCubit.consumeAgeRestrictedAutoRetryIfEligible(
        widget.video.id,
        isAgeRestricted: showVerifyAge,
        hasVerifyAction: widget.onVerifyAge != null,
        isConsumerActive: () => mounted,
      )) {
        return;
      }
      widget.onVerifyAge?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.errorType ?? VideoErrorType.generic;
    final shouldEnrichNotFoundWithModeration = type == VideoErrorType.notFound;
    final isDivineUrl = VideoModerationStatusService.shouldCheckModeration(
      widget.video.videoUrl,
    );

    // For divine URLs, check moderation status to enrich 404/notFound
    // errors with moderation context.
    final sha256 = isDivineUrl && shouldEnrichNotFoundWithModeration
        ? VideoModerationStatusService.resolveSha256(
            explicitSha256: widget.video.sha256,
            videoUrl: widget.video.videoUrl,
          )
        : null;

    final moderationAsync = sha256 != null
        ? ref.watch(videoModerationStatusProvider(sha256))
        : null;

    final moderationStatus = moderationAsync?.whenOrNull(
      data: (status) => status,
    );
    final isModerationStatusLoading = moderationAsync?.isLoading ?? false;
    final isModerationAgeRestricted =
        shouldEnrichNotFoundWithModeration &&
        moderationStatus != null &&
        moderationStatus.ageRestricted;
    final isModerationRestricted =
        (type == VideoErrorType.forbidden && isDivineUrl) ||
        (shouldEnrichNotFoundWithModeration &&
            moderationStatus != null &&
            moderationStatus.isUnavailableDueToModeration);
    final isUnavailableAfterAuthRetry = widget.isAuthRetryExhausted;
    final isAgeRestricted =
        !isUnavailableAfterAuthRetry &&
        (type == VideoErrorType.ageRestricted || isModerationAgeRestricted);

    final DivineIconName icon = switch ((
      type,
      isUnavailableAfterAuthRetry,
      isAgeRestricted,
      isModerationRestricted,
    )) {
      (_, true, _, _) => DivineIconName.warningCircle,
      (_, false, true, _) => DivineIconName.lockSimple,
      (VideoErrorType.notFound, false, false, true) =>
        DivineIconName.shieldCheck,
      (VideoErrorType.notFound, false, false, false) =>
        DivineIconName.warningCircle,
      (_, false, false, true) => DivineIconName.shieldCheck,
      _ => DivineIconName.warningCircle,
    };

    final message = switch ((
      type,
      isUnavailableAfterAuthRetry,
      isAgeRestricted,
      isModerationRestricted,
    )) {
      (_, true, _, _) => context.l10n.videoErrorUnavailable,
      (_, false, true, _) => context.l10n.videoErrorAgeRestricted,
      (VideoErrorType.notFound, false, false, true) =>
        context.l10n.videoErrorContentRestricted,
      (VideoErrorType.notFound, false, false, false) =>
        context.l10n.videoErrorNotFound,
      (VideoErrorType.forbidden, false, false, true) =>
        context.l10n.videoErrorContentRestricted,
      (VideoErrorType.forbidden, false, false, false) =>
        context.l10n.videoErrorPlayback,
      // Unreachable: `isAgeRestricted` is true whenever the type is
      // ageRestricted and the auth retry is not exhausted. Present only to
      // keep the switch exhaustive.
      (VideoErrorType.ageRestricted, false, false, _) =>
        context.l10n.videoErrorAgeRestricted,
      (VideoErrorType.generic, false, false, _) =>
        context.l10n.videoErrorPlayback,
    };
    final body = isUnavailableAfterAuthRetry
        ? context.l10n.videoErrorUnavailableBody
        : isAgeRestricted
        ? context.l10n.videoErrorVerifyAgeBody
        : isModerationRestricted
        ? context.l10n.videoErrorContentRestrictedBody
        : null;
    final showVerifyAge = isAgeRestricted && widget.onVerifyAge != null;
    final showSkip =
        (isUnavailableAfterAuthRetry ||
            (isModerationRestricted && !isAgeRestricted)) &&
        widget.onSkip != null;
    final showRetry =
        (!isModerationRestricted || (isAgeRestricted && !showVerifyAge)) &&
        !isUnavailableAfterAuthRetry &&
        !showSkip &&
        !showVerifyAge;
    _maybeAutoRetryAgeRestricted(showVerifyAge: showVerifyAge);

    // Hard-walled states (forbidden / moderation-blocked / age-restricted)
    // withhold the frame entirely. While a Divine notFound moderation lookup is
    // pending, fail closed for the preview layers too: suppress both the event
    // blurhash and thumbnail so no frame-derived preview leaks before the
    // moderation result lands. Plain notFound / generic failures keep the event
    // blurhash and thumbnail fallback. #6242
    final suppressPreviewMedia =
        isModerationStatusLoading ||
        isModerationRestricted ||
        isAgeRestricted ||
        isUnavailableAfterAuthRetry;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: context.vineColors.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurhash preview beneath the thumbnail so expired or missing
              // media degrades to a soft placeholder instead of a bare color,
              // matching the feed grid's fallback. #6242
              BlurhashDisplay(
                blurhash: suppressPreviewMedia ? null : widget.video.blurhash,
                contentType: widget.video.blurhashContentType,
              ),
              if (!suppressPreviewMedia &&
                  widget.video.thumbnailUrl != null &&
                  widget.video.thumbnailUrl!.isNotEmpty)
                VineCachedImage(
                  imageUrl: widget.video.thumbnailUrl!,
                  fit: _resolveBoxFit(),
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  // On a failed/expired thumbnail, reveal the blurhash beneath
                  // rather than collapsing to a bare color.
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        ColoredBox(
          color: VineTheme.scrim50,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                DivineIcon(icon: icon, color: VineTheme.whiteText, size: 48),
                Text(
                  message,
                  style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
                  textAlign: TextAlign.center,
                ),
                if (body != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      body,
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.whiteText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (showVerifyAge)
                  DivineButton(
                    label: context.l10n.videoErrorVerifyAgeButton,
                    type: DivineButtonType.tertiary,
                    size: DivineButtonSize.small,
                    // Disabled while a retry is in flight so a second tap
                    // can't kick off a duplicate verification.
                    onPressed: widget.isVerifying ? null : widget.onVerifyAge,
                    isLoading: widget.isVerifying,
                  ),
                if (showRetry)
                  DivineButton(
                    label: context.l10n.videoErrorRetry,
                    type: DivineButtonType.tertiary,
                    size: DivineButtonSize.small,
                    onPressed: widget.onRetry,
                  ),
                if (showSkip)
                  DivineButton(
                    label: context.l10n.videoErrorSkip,
                    type: DivineButtonType.tertiary,
                    size: DivineButtonSize.small,
                    onPressed: widget.onSkip,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
