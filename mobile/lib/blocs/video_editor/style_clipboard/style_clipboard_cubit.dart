// ABOUTME: Holds the clip style and the layer style the user last copied in
// ABOUTME: the open editor, for Paste style to write onto other items (#10258).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/video_editor/clip_style.dart';
import 'package:openvine/models/video_editor/layer_style.dart';

part 'style_clipboard_state.dart';

/// The editor's style clipboard.
///
/// Lives as long as the editor screen, so a copied style stays within the
/// project it was copied in. A clip style and a layer style are kept apart:
/// neither can be pasted where the other goes, so copying one never throws
/// the other away.
class StyleClipboardCubit extends Cubit<StyleClipboardState> {
  /// Creates an empty clipboard.
  StyleClipboardCubit() : super(const StyleClipboardState());

  /// Keeps [style] for pasting onto clips.
  void copyClipStyle(ClipStyle style) => emit(state.copyWith(clipStyle: style));

  /// Keeps [style] for pasting onto layers.
  void copyLayerStyle(LayerStyle style) =>
      emit(state.copyWith(layerStyle: style));
}
