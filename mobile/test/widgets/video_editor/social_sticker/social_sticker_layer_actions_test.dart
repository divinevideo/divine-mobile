// ABOUTME: Tests the layer a social sticker is placed as: a poll, quiz or
// ABOUTME: slider stays upright and as large as placed, other stickers do not.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_layer_actions.dart';

void main() {
  group('socialStickerWidgetLayer', () {
    test('places a poll that moves but neither turns nor resizes', () {
      final layer = socialStickerWidgetLayer(
        const SocialStickerData(
          kind: SocialStickerKind.poll,
          pollQuestion: 'Which one?',
          pollOptions: ['Red', 'Blue'],
        ),
        width: 240,
      );

      expect(layer.interaction.enableMove, isTrue);
      expect(layer.interaction.enableRotate, isFalse);
      expect(layer.interaction.enableScale, isFalse);
    });

    test('leaves any other sticker free to turn and resize', () {
      final layer = socialStickerWidgetLayer(
        const SocialStickerData(
          kind: SocialStickerKind.hashtag,
          hashtag: 'summer',
        ),
        width: 240,
      );

      expect(layer.interaction.enableRotate, isTrue);
      expect(layer.interaction.enableScale, isTrue);
    });
  });
}
