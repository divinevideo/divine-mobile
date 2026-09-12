// ABOUTME: Green-screen action for a clip detached onto the canvas
// ABOUTME: Opens the chroma-key screen and writes the live key onto its layer

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/screens/video_editor/video_clip_chroma_key_screen.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer, WidgetLayer;

/// Opens the green-screen editor for the detached clip on [layer] and writes
/// the result onto that layer.
///
/// The same screen a timeline clip gets, with one difference in what happens
/// on confirm: nothing is rendered. A timeline clip bakes its key into a new
/// file because a single H.264 track has nothing underneath for a transparent
/// key to reveal. A detached clip is composited over the finished track at
/// export, so its key stays a *setting* on the layer — applied live by the
/// canvas shader and by the export composition — and the removed area is
/// genuinely see-through, which is what detaching a green-screen clip is for.
///
/// The write-back is one editor-history entry, so undo restores the previous
/// key (or the absence of one) together with everything else on the layer.
Future<void> editDetachedClipChromaKey(
  BuildContext context,
  Layer layer,
) async {
  final meta = DetachedClipLayerData.metaOf(layer);
  if (meta == null) return;

  // Captured before the await: the scope is an inherited widget, and reading
  // it through a context that may have unmounted while the screen was up is
  // what the mounted check below cannot save.
  final scope = VideoEditorScope.of(context);
  final documentsPath = await getDocumentsPath();
  if (!context.mounted) return;

  final data = DetachedClipLayerData.fromMeta(meta, documentsPath);
  final clip = data?.clip;
  if (clip == null || clip.video?.file?.path == null) return;

  final result = await Navigator.of(context).push<DetachedClipChromaKeyResult>(
    PageRouteBuilder<DetachedClipChromaKeyResult>(
      settings: const RouteSettings(name: 'detached_clip_chroma_key'),
      opaque: false,
      barrierColor: VineTheme.backgroundCamera,
      pageBuilder: (_, _, _) => VideoClipChromaKeyScreen.detached(
        clip: clip,
        chromaKey: data!.chromaKey,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  if (result == null) return;

  final editor = scope.editor;
  if (editor == null) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;
  final current = editor.activeLayers[index];
  if (current is! WidgetLayer) return;

  final ClipChromaKey? chromaKey = switch (result) {
    DetachedClipChromaKeyApplied(:final chromaKey) => chromaKey,
    DetachedClipChromaKeyRemoved() => null,
  };
  // Edited from the layer's *current* meta rather than the one captured
  // above, so a crop that landed while the screen was open is kept.
  final updated = DetachedClipLayerData.withChromaKey(
    DetachedClipLayerData.metaOf(current),
    chromaKey,
  );
  if (updated == null) return;

  editor.replaceLayer(
    index: index,
    layer: current.copyWith(
      widget: DetachedClipLayerView(meta: updated),
      meta: updated,
      exportConfigs: current.exportConfigs.copyWith(meta: updated),
    ),
  );
}
