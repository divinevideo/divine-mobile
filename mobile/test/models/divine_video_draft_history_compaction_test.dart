// ABOUTME: Regression tests for a saved draft no longer storing its clip
// ABOUTME: list once per history entry, and restoring the full history on load

import 'dart:convert';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/utils/editor_state_history_compaction.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _deepEquals = DeepCollectionEquality();
const _oldDocs = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents';
const _newDocs = '/var/mobile/Containers/Data/Application/NEW-UUID/Documents';
const _voiceOverPath = '$_oldDocs/voice_over_recordings/take_1.m4a';

final String _manifest = jsonEncode({
  'hash': 'a' * 64,
  'deviceAttestation': 'A' * 10000,
});

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('$_oldDocs/clip.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
  proofManifestJson: _manifest,
);

AudioEvent _voiceOver() => AudioEvent.fromLocalImport(
  id: 'local_import_take',
  filePath: _voiceOverPath,
  createdAt: 1700000000,
  title: 'Take 1',
  mimeType: 'audio/mp4',
  duration: 2,
);

/// The meta the editor deep-copies into every entry it adds on top of a clip
/// change: the same clip list and audio track, moved text layer or not.
Map<String, dynamic> _meta() => {
  'clips': [_clip().toJson()],
  'audio': [_voiceOver().toJson()],
};

DivineVideoDraft _draft({required int entries}) => DivineVideoDraft(
  id: 'draft_1',
  clips: [_clip()],
  title: 'Test Draft',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  editorStateHistory: {
    'version': '1.0.0',
    'position': entries - 1,
    'history': [
      for (var i = 0; i < entries; i++)
        {
          'layers': [
            {'id': 'text_1', 'x': i * 10},
          ],
          'meta': _meta(),
        },
    ],
  },
);

List<Map<String, dynamic>> _storedEntries(Map<String, dynamic> json) =>
    ((json['editorStateHistory'] as Map)['history'] as List)
        .cast<Map<String, dynamic>>();

void main() {
  group(DivineVideoDraft, () {
    test('stores the clip list once for a run of layer-only edits', () {
      final json = _draft(entries: 20).toJson();

      final entries = _storedEntries(json);
      expect(entries.first.containsKey('meta'), isTrue);
      expect(
        entries.skip(1).map((e) => e[historyMetaRefKey]),
        everyElement(0),
      );
      expect(entries.skip(1).any((e) => e.containsKey('meta')), isFalse);
      expect(
        (json['editorStateHistory'] as Map)[proofManifestsKey],
        [_manifest],
      );
    });

    test('grows by the layer delta per edit instead of the clip list', () {
      final twoEdits = jsonEncode(_draft(entries: 2).toJson()).length;
      final twentyEdits = jsonEncode(_draft(entries: 20).toJson()).length;

      expect(twentyEdits - twoEdits, lessThan(2000));
    });

    test('restores the full history on load', () {
      final draft = _draft(entries: 5);
      final stored = jsonDecode(jsonEncode(draft.toJson()));

      final restored = DivineVideoDraft.fromJson(
        stored as Map<String, dynamic>,
        _oldDocs,
      );

      expect(
        _deepEquals.equals(
          restored.editorStateHistory,
          draft.editorStateHistory,
        ),
        isTrue,
      );
    });

    // The portable-path rewrite and the compaction share one boundary; a
    // referenced meta has to come back with its audio path resolved against
    // the new container just like the entry it was copied from.
    test('resolves draft-local audio in every restored entry', () {
      final stored = jsonDecode(jsonEncode(_draft(entries: 3).toJson()));

      final restored = DivineVideoDraft.fromJson(
        stored as Map<String, dynamic>,
        _newDocs,
      );

      final urls = (restored.editorStateHistory['history'] as List).map((e) {
        final audio = ((e as Map)['meta'] as Map)['audio'] as List;
        return (audio.single as Map)['url'];
      });
      expect(urls, everyElement('$_newDocs/voice_over_recordings/take_1.m4a'));
    });

    test('loads a draft saved before compaction unchanged', () {
      final draft = _draft(entries: 3);
      final legacy = draft.toJson()
        ..['editorStateHistory'] = jsonDecode(
          jsonEncode(draft.editorStateHistory),
        );

      final restored = DivineVideoDraft.fromJson(legacy, _oldDocs);

      expect(
        _deepEquals.equals(
          restored.editorStateHistory,
          draft.editorStateHistory,
        ),
        isTrue,
      );
    });
  });
}
