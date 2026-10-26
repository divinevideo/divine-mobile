import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group('VideoEditorProviderState.offersVideoReuse', () {
    AudioEvent sound({bool allowsDerivatives = true}) => AudioEvent(
      id: 'external_provider_sound',
      pubkey: AudioEvent.externalProviderMarker,
      createdAt: 1700000000,
      externalSource: AudioExternalSource(
        provider: 'sound-library',
        providerSoundId: '42',
        providerName: 'Sound library',
        sourceUrl: 'https://example.com/sounds/42',
        previewUrl: 'https://example.com/sounds/42.mp3',
        license: AudioLicenseMetadata(
          type: allowsDerivatives ? 'cc-by' : 'cc-by-nd',
          name: allowsDerivatives ? 'CC BY 4.0' : 'CC BY-ND 4.0',
          url:
              'https://creativecommons.org/licenses/'
              '${allowsDerivatives ? 'by' : 'by-nd'}/4.0/',
          allowsCommercialUse: true,
          allowsDerivatives: allowsDerivatives,
          requiresAttribution: true,
        ),
      ),
    );

    CompleteParameters parameters(List<AudioEvent> tracks) =>
        CompleteParameters.fromMap(<String, dynamic>{}).copyWith(
          meta: {
            VideoEditorConstants.audioStateHistoryKey: tracks
                .map((track) => track.toJson())
                .toList(),
          },
        );

    test('does not offer reuse unless the creator opts in', () {
      final state = VideoEditorProviderState(selectedSound: sound());

      expect(state.offersVideoReuse, isFalse);
    });

    test('offers reuse when all selected and timeline sounds allow it', () {
      final state = VideoEditorProviderState(
        allowVideoReuse: true,
        selectedSound: sound(),
        editorEditingParameters: parameters([sound(), sound()]),
      );

      expect(state.soundForbidsDerivatives, isFalse);
      expect(state.offersVideoReuse, isTrue);
    });

    test('locks reuse when the selected sound forbids derivatives', () {
      final state = VideoEditorProviderState(
        allowVideoReuse: true,
        selectedSound: sound(allowsDerivatives: false),
        editorEditingParameters: parameters([sound()]),
      );

      expect(state.soundForbidsDerivatives, isTrue);
      expect(state.offersVideoReuse, isFalse);
    });

    test('locks reuse when a later timeline sound forbids derivatives', () {
      final state = VideoEditorProviderState(
        allowVideoReuse: true,
        editorEditingParameters: parameters([
          sound(),
          sound(allowsDerivatives: false),
        ]),
      );

      expect(state.soundForbidsDerivatives, isTrue);
      expect(state.offersVideoReuse, isFalse);
    });

    test('a selected sound cannot hide a restricted timeline sound', () {
      final state = VideoEditorProviderState(
        allowVideoReuse: true,
        selectedSound: sound(),
        editorEditingParameters: parameters([
          sound(allowsDerivatives: false),
        ]),
      );

      expect(state.soundForbidsDerivatives, isTrue);
      expect(state.offersVideoReuse, isFalse);
    });

    test('removing the restricted track restores the creator choice', () {
      final state = VideoEditorProviderState(
        allowVideoReuse: true,
        editorEditingParameters: parameters([
          sound(allowsDerivatives: false),
        ]),
      );
      expect(state.offersVideoReuse, isFalse);

      final updated = state.copyWith(
        editorEditingParameters: parameters([]),
      );

      expect(updated.offersVideoReuse, isTrue);
    });
  });
}
