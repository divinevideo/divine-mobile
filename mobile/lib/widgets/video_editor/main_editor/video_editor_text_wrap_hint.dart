// ABOUTME: Toolbar chip that lets a text run past the video edges instead of
// ABOUTME: wrapping there, shown only while the edges wrap it or it runs past.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_layer_mapping.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar_chip.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Offers to switch the text layer [TextWrapHintCubit] names between
/// wrapping at the video edges and running past them.
///
/// Text layers wrap where they would reach past the edges of the video. A
/// user who wants a word larger than the video is wide can turn that off for
/// the layer, and the export then cuts the word off at the edges. The chip
/// only appears while that choice makes a difference: while the edges wrap
/// the layer, or while the layer already runs past them. Otherwise it shows
/// [fallback], the widget the toolbar's centre slot holds without it.
///
/// It must sit in a `Flex`, such as the toolbar's row, since it ellipsizes
/// its label instead of pushing the toolbar buttons apart.
class VideoEditorTextWrapHint extends StatelessWidget {
  /// Creates the hint.
  const VideoEditorTextWrapHint({this.fallback, super.key});

  /// Shown while the hint is not.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final layerId = context.select(
      (TextWrapHintCubit cubit) => cubit.state.layerId,
    );
    // Rebuilt on every layer change, which can wrap or unwrap the layer.
    context.select((TextWrapHintCubit cubit) => cubit.state.revision);

    final editor = VideoEditorScope.of(context).editor;
    final layer = layerId == null
        ? null
        : editor?.activeLayers
              .whereType<TextLayer>()
              .where(
                (layer) => layer.id == layerId,
              )
              .firstOrNull;
    // A burned-in caption takes its look from the caption track.
    if (editor == null || layer == null || captionCueIdOf(layer) != null) {
      return fallback ?? const SizedBox.shrink();
    }

    final runsPastEdges = !layer.wrapAtLayerBounds;
    if (!runsPastEdges && !editor.textLayerWrapsAtBounds(layer)) {
      return fallback ?? const SizedBox.shrink();
    }

    return Flexible(
      child: VideoEditorToolbarChip(
        icon: runsPastEdges ? .arrowBendDownLeft : .arrowRight,
        label: runsPastEdges
            ? context.l10n.videoEditorTextWrapAtEdges
            : context.l10n.videoEditorTextDontWrap,
        onTap: () {
          editor.replaceLayer(
            index: editor.activeLayers.indexOf(layer),
            layer: layer.copyWith(wrapAtLayerBounds: runsPastEdges),
          );
          context.read<TextWrapHintCubit>().wrapToggled();
        },
      ),
    );
  }
}
