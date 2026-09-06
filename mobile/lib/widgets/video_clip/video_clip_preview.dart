// ABOUTME: Bottom sheet for previewing video clips with playback controls
// ABOUTME: Shows looping video player with clip info, save-to-gallery,
// ABOUTME: and dismiss

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_clip/video_clip_hero.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;
import 'package:unified_logger/unified_logger.dart';

class VideoClipPreview extends ConsumerStatefulWidget {
  const VideoClipPreview({required this.clip, this.onDelete, super.key});

  /// The clip to preview, containing file path, duration, and other metadata.
  final DivineVideoClip clip;

  /// Called when the delete button is tapped. If null, delete button is hidden.
  final VoidCallback? onDelete;

  @override
  ConsumerState<VideoClipPreview> createState() =>
      _VideoClipPreviewSheetState();
}

class _VideoClipPreviewSheetState extends ConsumerState<VideoClipPreview> {
  /// Video player controller for the clip, null until initialized.
  DivineVideoPlayerController? _controller;
  StreamSubscription<DivineVideoPlayerState>? _stateSubscription;

  /// Whether the video player has reported non-zero dimensions.
  bool _hasDimensions = false;

  /// Whether a gallery save operation is currently in progress.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  /// Initializes the video player and starts playback.
  ///
  /// Checks if the video file exists, creates a
  /// [DivineVideoPlayerController], initializes it, enables looping,
  /// and starts playback automatically.
  Future<void> _initializePlayer() async {
    // Stop-motion clips are rendered frame-by-frame by [StopMotionPlayer];
    // there is no video file to load into the native player.
    if (widget.clip.isStopMotion) return;

    final video = widget.clip.video;
    if (video == null) {
      if (mounted) context.pop();
      return;
    }
    final file = File(await video.safeFilePath());
    if (!file.existsSync()) {
      if (mounted) context.pop();
      return;
    }

    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'clip_preview',
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setSource(VideoClip.file(file.path));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(looping: true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Clip preview player failed to load',
        name: 'VideoClipPreview',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(controller.dispose());
      return;
    }

    // Rebuild once video dimensions become available.
    _controller = controller;
    _stateSubscription = controller.stateStream.listen((state) {
      if (mounted && state.videoWidth > 0 && !_hasDimensions) {
        _hasDimensions = true;
        setState(() {});
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Saves the current clip to the device gallery/camera roll.
  ///
  /// Shows a snackbar with the result and handles permission denied.
  Future<void> _saveToGallery() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    DivineVideoClip? materialized;
    try {
      final gallerySaveService = ref.read(gallerySaveServiceProvider);
      // Stop-motion clips render their mp4 on demand; a normal clip passes
      // through unchanged.
      try {
        materialized = await StopMotionRenderService.materialize(widget.clip);
      } on RenderCanceledException {
        materialized = null;
      }
      if (!mounted) return;
      if (materialized == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VineTheme.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label: context.l10n.videoClipSaveFailed,
              error: true,
            ),
          ),
        );
        return;
      }
      final result = await gallerySaveService.saveVideoToGallery(
        materialized.requireVideo,
      );

      if (!mounted) return;

      if (result case GallerySaveFailure(:final reason)) {
        Log.warning('Failed to save clip to gallery: $reason');
      }

      final l10n = context.l10n;
      final destination = GallerySaveService.destinationName;
      final (message, isError) = switch (result) {
        GallerySaveSuccess() => (
          l10n.libraryClipsSavedToDestination(1, destination),
          false,
        ),
        GallerySavePermissionDenied() => (
          l10n.libraryGalleryPermissionDenied(destination),
          true,
        ),
        GallerySaveFailure() => (l10n.videoClipSaveFailed, true),
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(DivineSnackbarContainer.snackBar(message, error: isError));

      context.pop();
    } catch (e, s) {
      Log.error('Failed to save clip to gallery', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoClipSaveFailed,
            error: true,
          ),
        );
      }
    } finally {
      await StopMotionRenderService.cleanupMaterializedOutput(
        sourceClip: widget.clip,
        materializedClip: materialized,
      );
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.l10n.videoMetadataClosePreviewSemanticLabel,
      button: true,
      onTap: context.pop,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: context.pop,
        behavior: .translucent,
        child: ColoredBox(
          color: VineTheme.scrim65,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const .all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 48,
                  children: [
                    // Video preview
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: widget.clip.targetAspectRatio.value,
                        child: ClipRRect(
                          borderRadius: .circular(16),
                          child: _ClipHero(
                            clip: widget.clip,
                            child: _ClipMedia(
                              clip: widget.clip,
                              controller: _controller,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (widget.clip.libraryTitle case final title?)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.onSurface,
                        ),
                      ),

                    // Action buttons row
                    _ActionButtonsRow(
                      isSaving: _isSaving,
                      onSave: _saveToGallery,
                      onDelete: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the grid → preview [Hero] mounted for the preview's whole lifetime.
///
/// The hero used to sit inside [DivineVideoPlayer]'s placeholder, which is
/// dropped from the tree once the first video frame renders — so by the time
/// the user closed the preview there was no hero left to fly back from. The
/// shuttle renders the still thumbnail in both directions, which also keeps
/// the native video surface out of the hero overlay.
class _ClipHero extends StatelessWidget {
  const _ClipHero({required this.clip, required this.child});

  final DivineVideoClip clip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = clip.thumbnailPath;
    if (thumbnailPath == null) return child;

    final cacheHeight = _stillCacheHeight(context);
    return Hero(
      tag: videoClipPreviewHeroTag(clip.id),
      flightShuttleBuilder: (_, _, _, _, _) => ClipThumbnailImage(
        path: thumbnailPath,
        fit: BoxFit.cover,
        cacheHeight: cacheHeight,
        excludeFromSemantics: true,
        placeholder: const VideoClipThumbnailPlaceholder(),
      ),
      child: child,
    );
  }
}

/// Decode bound (physical pixels) for every still the preview renders.
///
/// A stop-motion clip's thumbnail is a full-resolution camera frame; decoded
/// unbounded it costs tens of MB and evicts the rest of the image cache. The
/// shuttle, the video placeholder and [StopMotionPlayer] all share this bound
/// so they resolve to one cache entry instead of three.
int _stillCacheHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * MediaQuery.devicePixelRatioOf(context))
        .round();

/// The clip itself: stop-motion stills, or the video surface with a thumbnail
/// placeholder bridging the decode gap.
class _ClipMedia extends StatelessWidget {
  const _ClipMedia({required this.clip, required this.controller});

  final DivineVideoClip clip;

  /// `null` until the player has been created and initialized.
  final DivineVideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final cacheHeight = _stillCacheHeight(context);
    if (clip.stopMotionFrames case final frames?) {
      return StopMotionPlayer(frames: frames, cacheHeight: cacheHeight);
    }

    final player = DivineVideoPlayer(
      controller: controller,
      placeholder: Stack(
        fit: .expand,
        children: [
          if (clip.thumbnailPath case final thumbnailPath?)
            ClipThumbnailImage(
              path: thumbnailPath,
              fit: BoxFit.cover,
              cacheHeight: cacheHeight,
            ),
          const Center(
            child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        ],
      ),
    );

    final vw = controller?.state.videoWidth ?? 0;
    final vh = controller?.state.videoHeight ?? 0;
    if (vw == 0 || vh == 0) return player;

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: vw.toDouble(),
        height: vh.toDouble(),
        child: player,
      ),
    );
  }
}

/// Row of action buttons displayed below the video preview.
///
/// Contains a save-to-gallery button and an optional delete button.
/// Absorbs taps to prevent dismissing the preview overlay.
class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({
    required this.isSaving,
    required this.onSave,
    this.onDelete,
  });

  static const double _buttonPadding = 12;

  /// Whether a save operation is currently in progress.
  final bool isSaving;

  /// Called when the save button is tapped.
  final VoidCallback onSave;

  /// Called when the delete button is tapped. If null, delete button is hidden.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: .transparency,
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        spacing: 32,
        children: [
          // Save to gallery button
          Semantics(
            button: true,
            label: context.l10n.videoClipSaveTo(
              GallerySaveService.destinationName,
            ),
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.all(_buttonPadding),
                decoration: ShapeDecoration(
                  color: VineTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const DivineIcon(
                  icon: DivineIconName.downloadSimple,
                  color: VineTheme.onPrimary,
                ),
              ),
            ),
          ),
          if (onDelete != null)
            // Delete button
            Semantics(
              button: true,
              label: context.l10n.videoClipDelete,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(_buttonPadding),
                  decoration: ShapeDecoration(
                    color: VineTheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const DivineIcon(
                    icon: DivineIconName.trash,
                    color: VineTheme.whiteText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
