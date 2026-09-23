// ABOUTME: Regression test for a draft saved while detached clips could not
// ABOUTME: rotate coming back from storage with the rotation lock lifted

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _docs = '/docs';

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('$_docs/clip.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

/// A draft whose detached clip was saved with `enableRotate: false`, stored
/// the way the editor exports it: the layer's full map once under
/// `references`, with history entries naming it by id.
DivineVideoDraft _lockedDraft() => DivineVideoDraft(
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
    'position': 0,
    'references': {
      'layer-1': {
        'id': 'layer-1',
        'type': 'widget',
        'interaction': {'enableRotate': false, 'enableScale': true},
        'meta': DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta(),
      },
    },
    'history': [
      {
        'layers': [
          {'id': 'layer-1'},
        ],
      },
    ],
  },
);

void main() {
  group(DivineVideoDraft, () {
    group('fromJson', () {
      test('lifts the rotation lock a detached clip was saved with', () {
        final stored = jsonDecode(jsonEncode(_lockedDraft().toJson()));

        final restored = DivineVideoDraft.fromJson(
          stored as Map<String, dynamic>,
          _docs,
        );

        final references =
            restored.editorStateHistory['references']! as Map<String, dynamic>;
        final layer = references['layer-1']! as Map<String, dynamic>;
        expect(layer['interaction'], {
          'enableRotate': true,
          'enableScale': true,
        });
      });
    });
  });
}
