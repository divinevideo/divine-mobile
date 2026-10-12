// ABOUTME: Regression test for a draft whose detached clip was keyed after it
// ABOUTME: was placed coming back from storage with its green screen intact

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
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

void main() {
  group(DivineVideoDraft, () {
    group('fromJson', () {
      test('restores the export meta of a detached clip keyed after it was '
          'placed', () {
        final placedMeta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();
        final keyedMeta = DetachedClipLayerData.withChromaKey(
          placedMeta,
          const ClipChromaKey(key: ChromaKey.blueScreen()),
        );
        // Stored the way pro_image_editor before 14.11.1 exported it: the
        // keying entry's diff carries `meta` but no `exportConfigs`.
        final draft = DivineVideoDraft(
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
            'version': '6.5.0',
            'position': 1,
            'references': {
              'layer-1': {
                'id': 'layer-1',
                'type': 'widget',
                'meta': placedMeta,
                'exportConfigs': {'id': 'layer-1', 'meta': placedMeta},
              },
            },
            'history': [
              {
                'layers': [
                  {'id': 'layer-1'},
                ],
              },
              {
                'layers': [
                  {'id': 'layer-1', 'meta': keyedMeta},
                ],
              },
            ],
          },
        );
        final stored = jsonDecode(jsonEncode(draft.toJson()));

        final restored = DivineVideoDraft.fromJson(
          stored as Map<String, dynamic>,
          _docs,
        );

        final entries = restored.editorStateHistory['history']! as List;
        final keyedLayer = ((entries.last as Map)['layers'] as List).single;
        final exportConfigs = (keyedLayer as Map)['exportConfigs'] as Map;
        expect(
          DetachedClipLayerData.hasChromaKey(
            Map<String, dynamic>.from(exportConfigs['meta'] as Map),
          ),
          isTrue,
        );
      });
    });
  });
}
