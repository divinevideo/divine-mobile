// ABOUTME: Regression tests for a saved draft no longer storing its clip
// ABOUTME: list once per history entry, and restoring the full history on load

import 'dart:convert';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
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

/// What the editor hands back on Done: `CompleteParameters` is built with
/// `meta: stateManager.activeMeta`, so the editing parameters carry their own
/// full copy of every clip's manifest.
Map<String, dynamic> _editingParameters() => {
  'meta': _meta(),
  'layers': <Object?>[],
  'image': <Object?>[],
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

/// A draft whose history is shaped the way the editor actually exports one.
///
/// The fixture above declares version `1.0.0` and no `references`, which is
/// the pre-3.0 shape the app stopped writing: `ExportStateHistory` writes
/// `ExportImportVersion.latest` and parks a detached clip layer's whole map —
/// including its ~10 KB attestation — in the top-level `references` table
/// rather than under `history[].meta`. So the transforms that cross at both
/// boundaries, compaction and the portable-path rewrite, were never exercised
/// on the branch of the tree where the app's own manifests live.
DivineVideoDraft _realisticDraft({required int entries}) => DivineVideoDraft(
  id: 'draft_2',
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
    'version': '6.5.0',
    'position': entries - 1,
    'history': [
      for (var i = 0; i < entries; i++)
        {
          'layers': [
            {'id': 'text_1', 'x': i * 10, 'type': 'text'},
          ],
          'meta': _meta(),
        },
    ],
    'references': {
      '0': {
        'type': 'widget',
        'exportConfigs': {
          'id': 'detached_1',
          'meta': {detachedClipLayerClipKey: _clip().toJson()},
        },
      },
    },
    'imgSize': {'width': 1080.0, 'height': 1920.0},
    'lastRenderedImgSize': {'width': 1080.0, 'height': 1920.0},
  },
);

Map<String, dynamic> _storedReferenceClip(Map<String, dynamic> json) =>
    ((((json['editorStateHistory'] as Map)['references'] as Map)['0']
                as Map)['exportConfigs']
            as Map)['meta']
        as Map<String, dynamic>;

List<Map<String, dynamic>> _storedEntries(Map<String, dynamic> json) =>
    ((json['editorStateHistory'] as Map)['history'] as List)
        .cast<Map<String, dynamic>>();

void main() {
  group(DivineVideoDraft, () {
    test('stores the clip list once for a run of layer-only edits', () {
      final json = _draft(entries: 20).toJson();

      final entries = _storedEntries(json);
      expect(entries.first.containsKey('meta'), isTrue);
      // The last entry is the one the editor is on and stays whole.
      final repeats = entries.sublist(1, entries.length - 1);
      expect(repeats.map((e) => e[historyMetaRefKey]), everyElement(0));
      expect(repeats.any((e) => e.containsKey('meta')), isFalse);
      expect(entries.last, isNot(contains(historyMetaRefKey)));
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

    group('on the shape the editor actually exports', () {
      test(
        'interns the manifest a detached clip layer parks in references',
        () {
          final json = _realisticDraft(entries: 4).toJson();

          expect(
            (json['editorStateHistory'] as Map)[proofManifestsKey],
            [_manifest],
            reason: 'the clip list and the reference share one stored manifest',
          );
          final referenceClip =
              _storedReferenceClip(json)[detachedClipLayerClipKey]! as Map;
          expect(referenceClip[proofManifestRefKey], 0);
          expect(referenceClip, isNot(contains('proofManifestJson')));
        },
      );

      test(
        'restores it whole, with audio resolved against the new container',
        () {
          final draft = _realisticDraft(entries: 4);
          final stored = jsonDecode(jsonEncode(draft.toJson()));

          final restored = DivineVideoDraft.fromJson(
            stored as Map<String, dynamic>,
            _newDocs,
          );

          final referenceClip =
              ((((restored.editorStateHistory['references'] as Map)['0']
                              as Map)['exportConfigs']
                          as Map)['meta']
                      as Map)[detachedClipLayerClipKey]
                  as Map;
          expect(referenceClip['proofManifestJson'], _manifest);

          final urls = (restored.editorStateHistory['history']! as List).map((
            e,
          ) {
            final audio = ((e as Map)['meta'] as Map)['audio'] as List;
            return (audio.single as Map)['url'];
          });
          expect(
            urls,
            everyElement('$_newDocs/voice_over_recordings/take_1.m4a'),
          );
        },
      );

      test('round-trips losslessly', () {
        final draft = _realisticDraft(entries: 6);
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

      test('still stores the clip list once across the run', () {
        final six = jsonEncode(_realisticDraft(entries: 6).toJson()).length;
        final twenty = jsonEncode(_realisticDraft(entries: 20).toJson()).length;

        expect(twenty - six, lessThan(2000));
      });
    });

    group('editorEditingParameters', () {
      // Sticky once the user taps Done: it stays in provider state and is
      // rewritten on every later autosave, so an uninterned copy of every
      // attestation was re-encoded on each one.
      test('interns its manifests against the same table', () {
        final draft = DivineVideoDraft(
          id: 'draft_3',
          clips: [_clip()],
          title: 'Test Draft',
          description: '',
          hashtags: const {},
          selectedApproach: 'camera',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
          editorEditingParameters: _editingParameters(),
        );

        final json = draft.toJson();
        final stored = json['editorEditingParameters']! as Map<String, dynamic>;
        final clip = ((stored['meta']! as Map)['clips']! as List).single as Map;

        expect(clip[proofManifestRefKey], 0);
        expect(clip, isNot(contains('proofManifestJson')));
        expect(stored[proofManifestsKey], [_manifest]);

        final restored = DivineVideoDraft.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
          _oldDocs,
        );

        expect(
          _deepEquals.equals(
            restored.editorEditingParameters,
            draft.editorEditingParameters,
          ),
          isTrue,
        );
      });

      test('stores one manifest for a clip it shares with the history', () {
        final draft = DivineVideoDraft(
          id: 'draft_4',
          clips: [_clip()],
          title: 'Test Draft',
          description: '',
          hashtags: const {},
          selectedApproach: 'camera',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
          editorStateHistory: _draft(entries: 4).editorStateHistory,
          editorEditingParameters: _editingParameters(),
        );

        final json = draft.toJson();

        // The manifest is JSON-escaped once nested, so count the attestation
        // payload, which survives escaping unchanged. Four history entries
        // and the editing parameters all name the same clip; each field
        // should store the attestation once.
        expect(
          ('A' * 10000)
              .allMatches(jsonEncode(json['editorStateHistory']))
              .length,
          1,
        );
        expect(
          ('A' * 10000)
              .allMatches(jsonEncode(json['editorEditingParameters']))
              .length,
          1,
        );
      });
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
