import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/draft_content_warning_extensions.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('DraftContentWarnings', () {
    DivineVideoDraft draft({
      List<VideoEffect> effects = const [],
      String? contentWarning,
    }) => DivineVideoDraft.create(
      clips: const [],
      title: '',
      description: '',
      hashtags: const {},
      selectedApproach: 'native',
      contentWarning: contentWarning,
      editorEditingParameters: {
        'meta': {
          VideoEditorConstants.effectsStateHistoryKey: [
            for (final effect in effects) effect.toMap(),
          ],
        },
      },
    );

    test('adds flashing lights to the picks of a draft with a flashing '
        'effect', () {
      final flashing = draft(
        effects: const [VideoEffect.strobe()],
        contentWarning: 'nudity',
      );

      expect(flashing.requiredContentWarnings, {ContentLabel.flashingLights});
      expect(flashing.effectiveContentWarnings, {
        ContentLabel.nudity,
        ContentLabel.flashingLights,
      });
    });

    test('publishes only the picks without a flashing effect', () {
      final calm = draft(
        effects: const [VideoEffect.vignette()],
        contentWarning: 'nudity',
      );

      expect(calm.requiredContentWarnings, isEmpty);
      expect(calm.effectiveContentWarnings, {ContentLabel.nudity});
    });

    test('requires nothing for a draft without editor parameters', () {
      final plain = DivineVideoDraft.create(
        clips: const [],
        title: '',
        description: '',
        hashtags: const {},
        selectedApproach: 'native',
      );

      expect(plain.requiredContentWarnings, isEmpty);
    });
  });
}
