// ABOUTME: Tests for DraftLocalAudioPaths.localAudioFilePaths extraction
// ABOUTME: Validates imported audio + voice-over paths are collected for cleanup

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent, VoiceEffect;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/draft_local_audio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _testPubkey =
    'abc123def456789012345678901234567890123456789012345678901234abcd';

DivineVideoClip _createTestClip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({
  Map<String, dynamic> editorStateHistory = const {},
  Map<String, dynamic> editorEditingParameters = const {},
  AudioEvent? selectedSound,
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: [_createTestClip()],
  title: '',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  editorStateHistory: editorStateHistory,
  editorEditingParameters: editorEditingParameters,
  selectedSound: selectedSound,
);

AudioEvent _localImport(String id, String path) => AudioEvent.fromLocalImport(
  id: id,
  filePath: path,
  createdAt: 1700000000,
  title: 'Imported',
  mimeType: 'audio/mp4',
);

Map<String, dynamic> _historyWithAudio(List<AudioEvent> tracks) => {
  'position': 0,
  'history': [
    {
      'meta': {
        VideoEditorConstants.audioStateHistoryKey: tracks
            .map((t) => t.toJson())
            .toList(),
      },
    },
  ],
};

void main() {
  group('DraftLocalAudioPaths', () {
    test('returns empty when no audio metadata exists', () {
      expect(_draft().localAudioFilePaths, isEmpty);
    });

    test('collects imported-audio path from editor history', () {
      const path = '/docs/draft_audio_imports/draft_1/imported.m4a';
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          _localImport('local_import_1', path),
        ]),
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('collects voice-over recording path from editor history', () {
      const path = '/docs/voice_over_recordings/voice_over_1.m4a';
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          _localImport('local_import_voice_over_1', path),
        ]),
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('collects both files of a voice-over with an effect', () {
      const original = '/docs/voice_over_recordings/voice_over_1.m4a';
      const processed = '/docs/voice_over_recordings/voice_over_1_robot.wav';
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          _localImport('local_import_voice_over_1', processed).copyWith(
            originalUrl: original,
            voiceEffect: const VoiceEffect(robot: 100),
          ),
        ]),
      );

      expect(draft.localAudioFilePaths, {processed, original});
    });

    test('collects local audio held in legacy selectedSound', () {
      const path = '/docs/draft_audio_imports/draft_1/selected.m4a';
      final draft = _draft(selectedSound: _localImport('local_import_2', path));

      expect(draft.localAudioFilePaths, {path});
    });

    test('collects local audio held only in completed-editor parameters', () {
      const path = '/docs/draft_audio_imports/draft_1/completed.m4a';
      final draft = _draft(
        editorEditingParameters: {
          'meta': {
            VideoEditorConstants.audioStateHistoryKey: [
              _localImport('local_import_completed', path).toJson(),
            ],
          },
        },
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('deduplicates completed-editor audio against history', () {
      const path = '/docs/draft_audio_imports/draft_1/shared.m4a';
      final track = _localImport('local_import_shared', path);
      final draft = _draft(
        editorStateHistory: _historyWithAudio([track]),
        editorEditingParameters: {
          'meta': {
            VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
          },
        },
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('ignores malformed completed-editor parameter shapes', () {
      final draft = _draft(
        editorEditingParameters: const {
          'meta': {
            VideoEditorConstants.audioStateHistoryKey: [
              'not-a-map',
              <String, dynamic>{},
            ],
          },
        },
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });

    test(
      'keeps history paths when completed-editor parameters are malformed',
      () {
        const path = '/docs/voice_over_recordings/history.m4a';
        final draft = _draft(
          editorStateHistory: _historyWithAudio([
            _localImport('local_import_history', path),
          ]),
          editorEditingParameters: const {'meta': 'not-a-map'},
        );

        expect(draft.localAudioFilePaths, {path});
      },
    );

    test('ignores non-local audio (bundled, network, original sound)', () {
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          AudioEvent(
            id: 'bundled_chime',
            pubkey: AudioEvent.bundledMarker,
            createdAt: 0,
            url: 'asset://sounds/chime.mp3',
          ),
          AudioEvent(
            id: 'remote-sound-id',
            pubkey: _testPubkey,
            createdAt: 1700000000,
            url: 'https://cdn.example.com/audio.mp3',
          ),
        ]),
        selectedSound: AudioEvent(
          id: 'video_remote',
          pubkey: _testPubkey,
          createdAt: 1700000000,
          url: 'https://cdn.example.com/original.mp4',
        ),
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });

    test('deduplicates a path repeated across history entries', () {
      const path = '/docs/voice_over_recordings/voice_over_1.m4a';
      final track = _localImport('local_import_voice_over_1', path);
      final draft = _draft(
        editorStateHistory: {
          'position': 1,
          'history': [
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
              },
            },
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
              },
            },
          ],
        },
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('does not throw on malformed history shapes', () {
      final draft = _draft(
        editorStateHistory: const {
          'history': [
            'not-a-map',
            {'meta': 'not-a-map'},
            {
              'meta': {VideoEditorConstants.audioStateHistoryKey: 'not-a-list'},
            },
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: ['not-a-map'],
              },
            },
          ],
        },
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });

    test('skips audio entries that parse as a map but throw in fromJson', () {
      // These clear the `raw is! Map` guard and reach AudioEvent.fromJson,
      // where the non-nullable id/pubkey/createdAt casts throw — exercising
      // the try/catch "cleanup must never throw" branch.
      final draft = _draft(
        editorStateHistory: const {
          'history': [
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [
                  <String, dynamic>{},
                  {'id': 123},
                ],
              },
            },
          ],
        },
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });
  });
}
