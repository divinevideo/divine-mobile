// ABOUTME: Regression tests for draft-local audio surviving iOS container moves
// ABOUTME: Covers state history, editing parameters and the selected sound

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/draft_local_audio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _oldDocs = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents';
const _newDocs = '/var/mobile/Containers/Data/Application/NEW-UUID/Documents';

const _importedPath = '$_oldDocs/draft_audio_imports/draft_1/song.m4a';
const _voiceOverPath = '$_oldDocs/voice_over_recordings/take_1.m4a';
const _extractedPath = '$_oldDocs/extracted_clip_audio/extracted_audio_1.wav';

AudioEvent _localAudio(String id, String path) => AudioEvent.fromLocalImport(
  id: id,
  filePath: path,
  createdAt: 1700000000,
  title: 'Local audio',
  mimeType: 'audio/mp4',
  duration: 4,
);

/// Audio the editor pulled off one of the draft's own clips. Not a local
/// import: the id marker differs, which is what keeps it out of the reuse and
/// attribution paths.
AudioEvent _extractedAudio() => AudioEvent(
  id: 'local_extracted_1',
  pubkey: '',
  createdAt: 1700000000,
  url: _extractedPath,
  mimeType: 'audio/wav',
  duration: 4,
);

DivineVideoDraft _draft() => DivineVideoDraft(
  id: 'draft_1',
  clips: [
    DivineVideoClip(
      id: 'clip_1',
      video: EditorVideo.file('$_oldDocs/clip.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2025),
      originalAspectRatio: 9 / 16,
      targetAspectRatio: .vertical,
    ),
  ],
  title: 'Test Draft',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  selectedSound: _localAudio('local_import_selected', _importedPath),
  editorStateHistory: {
    'version': '1.0.0',
    'history': [
      {
        'meta': {
          'audio': [
            _localAudio('local_import_1', _importedPath).toJson(),
            _localAudio('local_import_2', _voiceOverPath).toJson(),
            _extractedAudio().toJson(),
          ],
        },
      },
    ],
  },
  editorEditingParameters: {
    'meta': {
      'audio': [_localAudio('local_import_1', _importedPath).toJson()],
    },
  },
);

List<String> _historyAudioUrls(DivineVideoDraft draft) {
  final entry = (draft.editorStateHistory['history']! as List).first as Map;
  final audio = (entry['meta']! as Map)['audio']! as List;
  return audio.map((e) => (e as Map)['url'] as String).toList();
}

String _parametersAudioUrl(DivineVideoDraft draft) {
  final audio =
      (draft.editorEditingParameters['meta']! as Map)['audio']! as List;
  return (audio.first as Map)['url'] as String;
}

void main() {
  group(DivineVideoDraft, () {
    test('persists draft-local audio relative to the documents directory', () {
      final json = _draft().toJson();

      final entry =
          (json['editorStateHistory']! as Map<String, dynamic>)['history']!
              as List;
      final audio = ((entry.first as Map)['meta']! as Map)['audio']! as List;
      expect(
        audio.map((e) => (e as Map)['url']),
        [
          'draft_audio_imports/draft_1/song.m4a',
          'voice_over_recordings/take_1.m4a',
          'extracted_clip_audio/extracted_audio_1.wav',
        ],
      );
      expect(
        (json['selectedSound']! as Map<String, dynamic>)['url'],
        'draft_audio_imports/draft_1/song.m4a',
      );
    });

    test('rebases draft-local audio onto the current container on load', () {
      final restored = DivineVideoDraft.fromJson(_draft().toJson(), _newDocs);

      expect(_historyAudioUrls(restored), [
        '$_newDocs/draft_audio_imports/draft_1/song.m4a',
        '$_newDocs/voice_over_recordings/take_1.m4a',
        '$_newDocs/extracted_clip_audio/extracted_audio_1.wav',
      ]);
      expect(
        _parametersAudioUrl(restored),
        '$_newDocs/draft_audio_imports/draft_1/song.m4a',
      );
      expect(
        restored.selectedSound?.localFilePath,
        '$_newDocs/draft_audio_imports/draft_1/song.m4a',
      );
    });

    test('heals a draft saved with a previous container path', () {
      // Drafts written before audio paths became portable stored the absolute
      // path of the container they were created in.
      final legacyJson = _draft().toJson()
        ..['editorStateHistory'] = {
          'version': '1.0.0',
          'history': [
            {
              'meta': {
                'audio': [
                  _localAudio('local_import_1', _importedPath).toJson(),
                ],
              },
            },
          ],
        };

      final restored = DivineVideoDraft.fromJson(legacyJson, _newDocs);

      expect(_historyAudioUrls(restored), [
        '$_newDocs/draft_audio_imports/draft_1/song.m4a',
      ]);
    });

    test('leaves audio in portable form when useOriginalPath is set', () {
      final restored = DivineVideoDraft.fromJson(
        _draft().toJson(),
        _newDocs,
        useOriginalPath: true,
      );

      expect(_historyAudioUrls(restored), [
        'draft_audio_imports/draft_1/song.m4a',
        'voice_over_recordings/take_1.m4a',
        'extracted_clip_audio/extracted_audio_1.wav',
      ]);
      expect(
        _parametersAudioUrl(restored),
        'draft_audio_imports/draft_1/song.m4a',
      );
      expect(
        restored.selectedSound?.url,
        'draft_audio_imports/draft_1/song.m4a',
      );
    });

    test('reports rebased paths for draft-delete cleanup', () {
      final restored = DivineVideoDraft.fromJson(_draft().toJson(), _newDocs);

      expect(restored.localAudioFilePaths, {
        '$_newDocs/draft_audio_imports/draft_1/song.m4a',
        '$_newDocs/voice_over_recordings/take_1.m4a',
        '$_newDocs/extracted_clip_audio/extracted_audio_1.wav',
      });
    });

    test('leaves published sounds untouched', () {
      final draft = _draft().copyWith(
        selectedSound: AudioEvent(
          id: 'sound-id-1234567890123456789012345678901234567890123456789012',
          pubkey: 'abc123def456789012345678901234567890123456789012345678901234abcd',
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
        ),
        skipUpdateLastModified: true,
      );

      final restored = DivineVideoDraft.fromJson(draft.toJson(), _newDocs);

      expect(restored.selectedSound?.url, 'https://blossom.example/audio.aac');
    });
  });
}
