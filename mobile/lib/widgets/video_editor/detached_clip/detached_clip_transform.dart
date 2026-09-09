// ABOUTME: Crop / rotate / flip action for a clip detached onto the canvas
// ABOUTME: Opens the clip transform editor and writes the result onto its layer

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/screens/video_editor/video_clip_transform_screen.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_configs.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show ExportTransform;

/// Opens the crop editor for the detached clip on [layer] and asks
/// [ClipEditorBloc] to bake the result into a new file.
///
/// The same editor a timeline clip gets, with one difference: the crop is
/// unconstrained. A timeline clip has to keep the composition's output ratio,
/// but a detached clip is a free-floating object on the canvas, so whatever
/// shape it is cropped to is the shape it keeps — and the layer is
/// re-proportioned to match once the render lands.
///
/// The clip travels with the event because it is no longer in
/// [ClipEditorState.clips]; the rendered result comes back through
/// [ClipEditorState.lastDetachedClipTransformResult], which the scaffold
/// writes onto the layer.
Future<void> transformDetachedClip(BuildContext context, Layer layer) async {
  final meta = DetachedClipLayerData.metaOf(layer);
  if (meta == null) return;

  final bloc = context.read<ClipEditorBloc>();
  final documentsPath = await getDocumentsPath();
  if (!context.mounted) return;

  final clip = DetachedClipLayerData.fromMeta(meta, documentsPath)?.clip;
  if (clip == null || clip.video?.file?.path == null) return;

  final transform = await Navigator.of(context).push<ExportTransform>(
    PageRouteBuilder<ExportTransform>(
      settings: const RouteSettings(name: 'detached_clip_transform'),
      opaque: false,
      barrierColor: VineTheme.backgroundCamera,
      pageBuilder: (_, _, _) => VideoClipTransformScreen(
        clip: clip,
        initAspectRatio: freeCropAspectRatio,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  if (transform == null || transform.isEmpty) return;

  bloc.add(
    ClipEditorDetachedClipTransformRequested(
      layerId: layer.id,
      clip: clip,
      transform: transform,
    ),
  );
}
