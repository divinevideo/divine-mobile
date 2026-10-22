// ABOUTME: The blend modes the editor offers a layer, and the mode the export
// ABOUTME: draws a layer with so it matches what the canvas shows.

import 'dart:ui' show BlendMode;

import 'package:pro_image_editor/pro_image_editor.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show LayerBlendMode;

/// The blend modes a layer can take in the editor, in the order they are
/// offered: normal first, then the modes that darken, the ones that lighten,
/// the ones that add contrast, and difference.
const List<LayerBlendMode> editorBlendModes = [
  LayerBlendMode.normal,
  LayerBlendMode.multiply,
  LayerBlendMode.darken,
  LayerBlendMode.screen,
  LayerBlendMode.lighten,
  LayerBlendMode.add,
  LayerBlendMode.overlay,
  LayerBlendMode.softLight,
  LayerBlendMode.difference,
];

/// How the export draws a layer onto the video beneath it.
extension LayerBlendModeExport on Layer {
  /// The mode that renders [Layer.blendMode] as the canvas paints it.
  ///
  /// Every mode the editor offers has one; [LayerBlendMode.normal] stands in
  /// for any other [BlendMode], which the export cannot draw.
  LayerBlendMode get exportBlendMode =>
      LayerBlendMode.fromBlendMode(blendMode) ?? LayerBlendMode.normal;
}
