// ABOUTME: Tests for StyleClipboardCubit: a copied clip style and a copied
// ABOUTME: layer style are kept side by side.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/blocs/video_editor/style_clipboard/style_clipboard_cubit.dart';
import 'package:openvine/models/video_editor/clip_style.dart';
import 'package:openvine/models/video_editor/layer_style.dart';

void main() {
  group(StyleClipboardCubit, () {
    const clipStyle = ClipStyle(
      volume: 0.5,
      equalizer: EqualizerSettings.none,
      playbackSpeed: 2,
    );
    const layerStyle = LayerStyle(opacity: 0.4);

    blocTest<StyleClipboardCubit, StyleClipboardState>(
      'copying a layer style keeps the copied clip style',
      build: StyleClipboardCubit.new,
      act: (cubit) => cubit
        ..copyClipStyle(clipStyle)
        ..copyLayerStyle(layerStyle),
      expect: () => const [
        StyleClipboardState(clipStyle: clipStyle),
        StyleClipboardState(clipStyle: clipStyle, layerStyle: layerStyle),
      ],
    );
  });
}
