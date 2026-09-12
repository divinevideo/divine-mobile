// ABOUTME: Bottom sheet with sub-editor actions for the video editor.
// ABOUTME: Opened via FAB, provides access to text, draw, effects, and more.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';

/// Bottom sheet that shows video editor sub-editor actions.
///
/// Uses [_ItemButton] for each action and closes the sheet after
/// an action is selected.
class VideoEditorMainActionsSheet extends StatelessWidget {
  const VideoEditorMainActionsSheet({required this.scope, super.key});

  static const _maxItemWidth = 72.0;
  static const _itemHeight = 112.0;
  static const _itemMainSpacing = 16.0;
  static const _itemCrossSpacing = 24.0;

  /// The editor scope captured before opening the sheet.
  final VideoEditorScope scope;

  /// Opens the actions bottom sheet.
  static Future<void> show(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    final videoEditorMainBloc = context.read<VideoEditorMainBloc>();
    final clipEditorBloc = context.read<ClipEditorBloc>();
    final tuneBloc = context.read<VideoEditorTuneBloc>();

    return VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      title: Text(context.l10n.videoEditorAddTitle),
      children: [
        // The sheet opens on a separate route, outside the editor's
        // MultiBlocProvider, so re-provide every bloc the actions read —
        // including the tune bloc the Adjust action needs.
        MultiBlocProvider(
          providers: [
            BlocProvider<VideoEditorMainBloc>.value(
              value: videoEditorMainBloc,
            ),
            BlocProvider<ClipEditorBloc>.value(value: clipEditorBloc),
            BlocProvider<VideoEditorTuneBloc>.value(value: tuneBloc),
          ],
          child: VideoEditorMainActionsSheet(scope: scope),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = context.select(
      (ClipEditorBloc b) => b.state.totalDuration,
    );
    final isStopMotion = context.select(
      (ClipEditorBloc b) => isStopMotionComposition(b.state.clips),
    );
    return Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          GridView(
            primary: false,
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _maxItemWidth,
              mainAxisExtent: _itemHeight,
              mainAxisSpacing: _itemMainSpacing,
              crossAxisSpacing: _itemCrossSpacing,
            ),
            children: [
              _ItemButton(
                icon: .camera,
                label: context.l10n.videoEditorCameraLabel,
                semanticLabel: context.l10n.videoEditorOpenCameraSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenCamera();
                },
              ),
              _ItemButton(
                icon: .images,
                label: context.l10n.videoEditorLibraryLabel,
                semanticLabel: context.l10n.videoEditorOpenLibrarySemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenClipsEditor();
                },
              ),
              _ItemButton(
                icon: .waveform,
                label: context.l10n.videoEditorAudioLabel,
                semanticLabel: context.l10n.videoEditorOpenAudioSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenMusicLibrary();
                },
              ),
              _ItemButton(
                icon: .microphone,
                label: context.l10n.videoEditorVoiceOverLabel,
                semanticLabel:
                    context.l10n.videoEditorOpenVoiceOverSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenVoiceOver();
                },
              ),
              _ItemButton(
                icon: .textAa,
                label: context.l10n.videoEditorTextLabel,
                semanticLabel: context.l10n.videoEditorOpenTextSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.editor?.openTextEditor();
                },
              ),
              _ItemButton(
                icon: .circlesThree,
                label: context.l10n.videoEditorFilterLabel,
                semanticLabel: context.l10n.videoEditorOpenFilterSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.editor?.openFilterEditor();
                },
              ),
              _ItemButton(
                icon: .slidersHorizontal,
                label: context.l10n.videoEditorTuneLabel,
                semanticLabel: context.l10n.videoEditorOpenTuneSemanticLabel,
                onTap: () {
                  final mainBloc = context.read<VideoEditorMainBloc>();
                  final tuneBloc = context.read<VideoEditorTuneBloc>();
                  Navigator.pop(context);
                  openTuneEditor(mainBloc, tuneBloc, scope);
                },
              ),
              _ItemButton(
                icon: .scribble,
                label: context.l10n.videoEditorDrawLabel,
                semanticLabel: context.l10n.videoEditorOpenDrawSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.editor?.openPaintEditor();
                },
              ),
              _ItemButton(
                icon: .sticker,
                label: context.l10n.videoEditorStickers,
                semanticLabel: context.l10n.videoEditorOpenStickerSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.onAddStickers();
                },
              ),
              _ItemButton(
                icon: .closedCaptioning,
                label: context.l10n.videoEditorCaptionsLabel,
                semanticLabel:
                    context.l10n.videoEditorOpenCaptionsSemanticLabel,
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenCaptions();
                },
              ),
              // Timeline markers anchor to video playback positions; on a
              // frames-first stop-motion composition the stills themselves
              // are the granularity, so the option is hidden.
              if (!isStopMotion)
                _ItemButton(
                  icon: .bookmarkPlus,
                  label: context.l10n.videoEditorMarkerLabel,
                  semanticLabel:
                      context.l10n.videoEditorAddTimelineMarkerSemanticLabel,
                  onTap: () {
                    Navigator.pop(context);
                    if (totalDuration <= Duration.zero) return;

                    // Enter marker mode instead of dropping a single marker, so
                    // the bottom bar exposes add/delete-marker controls and the
                    // user can keep marking beats while playback runs.
                    context.read<VideoEditorMainBloc>().add(
                      const VideoEditorMarkerModeChanged(isActive: true),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemButton extends StatelessWidget {
  const _ItemButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.semanticLabel,
  });

  final VoidCallback onTap;
  final DivineIconName icon;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Semantics(
          label: semanticLabel,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: context.vineColors.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 2,
                      color: context.vineColors.outlineMuted,
                    ),
                    borderRadius: .circular(24),
                  ),
                ),
                child: Center(
                  child: DivineIcon(
                    icon: icon,
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          excludeSemantics: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: chipLabelTextScaleLimit,
            child: Text(
              label,
              maxLines: 1,
              textAlign: .center,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
