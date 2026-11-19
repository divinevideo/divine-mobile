// ABOUTME: Where a room member hands in their edited part: plays the editor's
// ABOUTME: render, uploads it meanwhile, then sends it and returns to the room

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/bloc/collab_room_part_cubit.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/collab_room_page.dart';
import 'package:openvine/extensions/divine_video_clip_player_mapping.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Wires the editor's render and a [CollabRoomPartCubit] for [roomId].
class CollabRoomPartPage extends ConsumerWidget {
  /// Creates the part page.
  const CollabRoomPartPage({required this.roomId, super.key});

  /// Route name for this screen.
  static const String routeName = 'collab-room-part';

  /// Path pattern for this route.
  static const String path = RoutePaths.collabRoomPart;

  /// The room the part is for.
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(collabRoomServiceProvider);
    final (:clip, :failed) = ref.watch(
      videoEditorProvider.select(
        (s) => (clip: s.finalRenderedClip, failed: s.renderFailed),
      ),
    );
    return BlocProvider(
      key: ValueKey((service, roomId)),
      create: (_) => CollabRoomPartCubit(service: service, roomId: roomId),
      child: BlocListener<CollabRoomPartCubit, CollabRoomPartState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          switch (state.status) {
            case CollabRoomPartStatus.sent:
              _returnToRoom(context, ref);
            case CollabRoomPartStatus.failed:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.collabRoomPartSendFailed)),
              );
            case CollabRoomPartStatus.idle:
            case CollabRoomPartStatus.sending:
              break;
          }
        },
        // Back to the editor drops the render, as the post screen does: the
        // next Done renders the edits made meanwhile.
        child: PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            runDetached(
              ref.read(videoEditorProvider.notifier).cancelRenderVideo(),
              'cancel the collab room part render',
              logName: 'CollabRoomPartPage',
              category: LogCategory.video,
            );
          },
          child: _UploadsAhead(
            videoPath: clip?.video?.file?.path,
            child: CollabRoomPartView(
              renderedClip: clip,
              renderFailed: failed,
              onRetryRender: () => runDetached(
                ref.read(videoEditorProvider.notifier).startRenderVideo(),
                'render the collab room part again',
                logName: 'CollabRoomPartPage',
                category: LogCategory.video,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ends the part flow and goes back to the room, below the camera and the
  /// editor.
  void _returnToRoom(BuildContext context, WidgetRef ref) {
    // Finished, not cleared: the recorder animating out keeps its cell
    // instead of rebuilding as a plain camera that offers a draft back.
    ref.read(collabRoomPartProvider.notifier).finish();
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == CollabRoomPage.routeName || route.isFirst,
    );
    // The part session never autosaved, so the draft kept is the user's own.
    runDetached(
      ref
          .read(videoPublishProvider.notifier)
          .clearAll(keepAutosavedDraft: true),
      'clear the collab room part session',
      logName: 'CollabRoomPartPage',
      category: LogCategory.video,
    );
  }
}

/// The part's still and the send button, once the editor rendered it.
class CollabRoomPartView extends StatelessWidget {
  /// Creates the view.
  const CollabRoomPartView({
    required this.renderedClip,
    required this.renderFailed,
    required this.onRetryRender,
    super.key,
  });

  /// The rendered part, once ready.
  final DivineVideoClip? renderedClip;

  /// Whether the render failed.
  final bool renderFailed;

  /// Starts the render again.
  final VoidCallback onRetryRender;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final status = context.select(
      (CollabRoomPartCubit cubit) => cubit.state.status,
    );
    final clip = renderedClip;
    final videoPath = clip?.video?.file?.path;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DiVineAppBar(
        title: l10n.collabRoomPartTitle,
        showBackButton: true,
        backButtonSemanticLabel: l10n.commonBack,
      ),
      body: SafeArea(
        child: Padding(
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 16,
            children: [
              Expanded(
                child: Center(
                  child: switch ((clip, renderFailed)) {
                    (_, true) when clip == null => Text(
                      l10n.collabRoomPartRenderFailed,
                      textAlign: .center,
                      style: VineTheme.bodyLargeFont(
                        color: colors.secondaryText,
                      ),
                    ),
                    (null, _) => Column(
                      mainAxisSize: .min,
                      spacing: 16,
                      children: [
                        const DivineCircularProgressIndicator(),
                        Text(
                          l10n.collabRoomPartRendering,
                          style: VineTheme.bodyMediumFont(
                            color: colors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    (final clip?, _) => _PartPreview(clip: clip),
                  },
                ),
              ),
              if (clip != null) const _UploadProgress(),
              if (clip == null && renderFailed)
                DivineButton(
                  label: l10n.commonRetry,
                  onPressed: onRetryRender,
                )
              else
                DivineButton(
                  label: l10n.collabRoomPartSendButton,
                  leadingIcon: DivineIconName.paperPlaneRight,
                  isLoading: status == CollabRoomPartStatus.sending,
                  onPressed:
                      videoPath == null ||
                          status == CollabRoomPartStatus.sending ||
                          status == CollabRoomPartStatus.sent
                      ? null
                      : () => context.read<CollabRoomPartCubit>().send(
                          File(videoPath),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How far the part's upload got, so the wait before Send can be read.
class _UploadProgress extends StatelessWidget {
  const _UploadProgress();

  @override
  Widget build(BuildContext context) {
    final progress = context.select(
      (CollabRoomPartCubit cubit) => cubit.state.uploadProgress,
    );
    if (progress == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final done = progress >= 1;
    // Whole percents, rounded down so 100% only shows once it is all up.
    final shown = (progress * 100).floor() / 100;
    final label = done
        ? l10n.collabRoomPartUploaded
        : l10n.collabRoomPartUploading(
            NumberFormat.percentPattern(l10n.localeName).format(shown),
          );
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            DivineLinearProgressIndicator(value: progress),
            Text(
              label,
              textAlign: .center,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Starts uploading the rendered part at [videoPath] as soon as there is one,
/// so Send only has to hand it in.
class _UploadsAhead extends StatefulWidget {
  const _UploadsAhead({required this.videoPath, required this.child});

  final String? videoPath;
  final Widget child;

  @override
  State<_UploadsAhead> createState() => _UploadsAheadState();
}

class _UploadsAheadState extends State<_UploadsAhead> {
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(_UploadsAhead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) _prepare();
  }

  void _prepare() {
    final path = widget.videoPath;
    if (path != null) context.read<CollabRoomPartCubit>().prepare(File(path));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The rendered part playing on a loop, its still until the player is ready.
class _PartPreview extends StatefulWidget {
  const _PartPreview({required this.clip});

  final DivineVideoClip clip;

  @override
  State<_PartPreview> createState() => _PartPreviewState();
}

class _PartPreviewState extends State<_PartPreview> {
  /// The player, once it plays: a resource this screen owns and disposes.
  DivineVideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    runDetached(
      _play(),
      'play the collab room part preview',
      logName: 'CollabRoomPartPage',
      category: LogCategory.video,
    );
  }

  Future<void> _play() async {
    final source = widget.clip.toPlayerVideoClip();
    if (source == null) return;
    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'collab_room_part',
    );
    try {
      await controller.initialize();
      await controller.setSource(source);
      await controller.setLooping(looping: true);
      await controller.play();
    } on Object catch (error) {
      // The still stays: the part can be sent without seeing it move.
      Log.warning(
        'Could not play the collab room part: $error',
        name: 'CollabRoomPartPage',
        category: LogCategory.video,
      );
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      runDetached(
        controller.dispose(),
        'release the collab room part preview',
        logName: 'CollabRoomPartPage',
        category: LogCategory.video,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = widget.clip.thumbnailPath;
    final controller = _controller;
    return AspectRatio(
      aspectRatio: widget.clip.targetAspectRatio.value,
      child: ClipRRect(
        borderRadius: .circular(12),
        child: Stack(
          fit: .expand,
          children: [
            if (thumbnail == null)
              ColoredBox(color: context.vineColors.surfaceContainer)
            else
              ExcludeSemantics(child: Image.file(File(thumbnail), fit: .cover)),
            if (controller != null)
              CollabRoomPartPreviewToggle(
                controller: controller,
                child: DivineVideoPlayer(controller: controller),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pauses [controller] on a tap and plays it again on the next, with a play
/// button over the picture while it is paused.
@visibleForTesting
class CollabRoomPartPreviewToggle extends StatelessWidget {
  /// Creates the toggle over [child], the picture of [controller].
  const CollabRoomPartPreviewToggle({
    required this.controller,
    required this.child,
    super.key,
  });

  /// The preview's player.
  final DivineVideoPlayerController controller;

  /// The player's picture.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<DivineVideoPlayerState>(
      stream: controller.stateStream,
      initialData: controller.state,
      builder: (context, snapshot) {
        // Only a pause the user asked for shows the button, not a moment of
        // buffering.
        final paused = snapshot.data?.status.isPaused ?? false;
        return Semantics(
          button: true,
          label: paused
              ? l10n.videoMetadataPlayPreviewSemanticLabel
              : l10n.videoMetadataPausePreviewSemanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => runDetached(
              paused ? controller.play() : controller.pause(),
              paused
                  ? 'play the collab room part preview'
                  : 'pause the collab room part preview',
              logName: 'CollabRoomPartPage',
              category: LogCategory.video,
            ),
            child: ExcludeSemantics(
              child: Stack(
                fit: .expand,
                children: [
                  child,
                  if (paused)
                    const Center(
                      child: DecoratedBox(
                        // Fixed media chrome over the video.
                        decoration: BoxDecoration(
                          color: VineTheme.scrim65,
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: DivineIcon(
                            icon: DivineIconName.playFill,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
