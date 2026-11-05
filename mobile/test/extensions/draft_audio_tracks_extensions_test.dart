// ABOUTME: Tests for DraftAudioTracks.editorAudioTracks, which the publish
// ABOUTME: flow credits even when a track never became the selected sound.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/draft_audio_tracks_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoDraft _draft(Map<String, dynamic> editorEditingParameters) =>
    DivineVideoDraft(
      id: 'draft_1',
      clips: [
        DivineVideoClip(
          id: 'clip_1',
          video: EditorVideo.file('/tmp/test.mp4'),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime(2025),
          originalAspectRatio: 9 / 16,
          targetAspectRatio: .vertical,
        ),
      ],
      title: '',
      description: '',
      hashtags: const {},
      selectedApproach: 'video',
      createdAt: DateTime(2025),
      lastModified: DateTime(2025),
      publishStatus: PublishStatus.draft,
      publishAttempts: 0,
      editorEditingParameters: editorEditingParameters,
    );

final _shipped = AudioEvent(
  id: 'bundled_freesound_yay',
  pubkey: AudioEvent.bundledMarker,
  createdAt: 0,
  title: 'YAY!',
  licenseName: 'CC BY 4.0',
  licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
);

void main() {
  group('DraftAudioTracks', () {
    group('editorAudioTracks', () {
      test('reads the tracks of the finished edit in timeline order', () {
        final second = _shipped.copyWith(id: 'bundled_freesound_elevator');
        final draft = _draft({
          'meta': {
            VideoEditorConstants.audioStateHistoryKey: [
              _shipped.toJson(),
              second.toJson(),
            ],
          },
        });

        expect(
          draft.editorAudioTracks.map((track) => track.id),
          equals(['bundled_freesound_yay', 'bundled_freesound_elevator']),
        );
        expect(
          draft.editorAudioTracks.first.licenseUrl,
          equals('https://creativecommons.org/licenses/by/4.0/'),
        );
      });

      test('is empty for a draft that was never edited', () {
        expect(_draft(const {}).editorAudioTracks, isEmpty);
      });

      test('is empty when the edit has no audio tracks', () {
        expect(
          _draft(const {'meta': <String, dynamic>{}}).editorAudioTracks,
          isEmpty,
        );
      });

      test('skips a malformed track and keeps the rest', () {
        final draft = _draft({
          'meta': {
            VideoEditorConstants.audioStateHistoryKey: [
              'not a track',
              {'id': 42},
              _shipped.toJson(),
            ],
          },
        });

        expect(
          draft.editorAudioTracks.map((track) => track.id),
          equals(['bundled_freesound_yay']),
        );
      });
    });
  });
}
