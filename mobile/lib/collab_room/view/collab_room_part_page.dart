// ABOUTME: Where a room member hands in their edited part: waits for the
// ABOUTME: editor's render, then sends it and returns to the room

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/bloc/collab_room_part_cubit.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/collab_room_page.dart';
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
      child: BlocListener<CollabRoomPartCubit, CollabRoomPartStatus>(
        listener: (context, status) {
          switch (status) {
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
    );
  }

  /// Ends the part flow and goes back to the room, below the camera and the
  /// editor.
  void _returnToRoom(BuildContext context, WidgetRef ref) {
    ref.read(collabRoomPartProvider.notifier).clear();
    runDetached(
      ref.read(videoPublishProvider.notifier).clearAll(),
      'clear the collab room part session',
      logName: 'CollabRoomPartPage',
      category: LogCategory.video,
    );
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == CollabRoomPage.routeName || route.isFirst,
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
    final status = context.watch<CollabRoomPartCubit>().state;
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
                    (final clip?, _) => _PartStill(clip: clip),
                  },
                ),
              ),
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

class _PartStill extends StatelessWidget {
  const _PartStill({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final thumbnail = clip.thumbnailPath;
    return AspectRatio(
      aspectRatio: clip.targetAspectRatio.value,
      child: ClipRRect(
        borderRadius: .circular(12),
        child: thumbnail == null
            ? ColoredBox(color: context.vineColors.surfaceContainer)
            : ExcludeSemantics(
                child: Image.file(File(thumbnail), fit: .cover),
              ),
      ),
    );
  }
}
