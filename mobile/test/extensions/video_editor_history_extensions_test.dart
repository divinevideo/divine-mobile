import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _key = ClipChromaKey(key: ChromaKey.greenScreen());
const String _clipsKey = VideoEditorConstants.clipsStateHistoryKey;

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  thumbnailPath: '/documents/${id}_raw.jpg',
);

List<DivineVideoClip> _clipsIn(EditorStateHistory entry) => [
  for (final json
      in (entry.meta[_clipsKey] as List).cast<Map<String, dynamic>>())
    DivineVideoClip.fromJson(json, '/documents'),
];

void main() {
  group('VideoEditorHistoryExtensions', () {
    group('compositionAspectRatio', () {
      StateManager managerWith(Map<String, dynamic> meta) =>
          StateManager(onStateHistoryChange: null, activeBackgroundImage: null)
            ..stateHistory = [EditorStateHistory(meta: meta)];

      test("reads the first clip's shape in the current entry", () {
        final manager = managerWith({
          _clipsKey: [
            _clip('a').copyWith(targetAspectRatio: .square).toJson(),
            _clip('b').toJson(),
          ],
        });

        expect(manager.compositionAspectRatio, AspectRatio.square);
      });

      test('is null for an entry without clips', () {
        expect(managerWith(const {}).compositionAspectRatio, isNull);
        expect(
          managerWith(const {_clipsKey: <Object>[]}).compositionAspectRatio,
          isNull,
        );
      });
    });

    group('adoptCapturedChromaKeyBakes', () {
      test('keys the raw take in every entry without adding one', () {
        final take = _clip('take').copyWith(captureChromaKey: _key);
        final other = _clip('other');
        final keyed = take.copyWith(
          video: EditorVideo.file('/documents/take_keyed.mp4'),
          chromaKey: _key,
          chromaKeySourcePath: '/documents/take.mp4',
          clearCaptureChromaKey: true,
          thumbnailPath: '/documents/take_keyed.jpg',
        );
        final manager =
            StateManager(
                onStateHistoryChange: null,
                activeBackgroundImage: null,
              )
              ..stateHistory = [
                EditorStateHistory(
                  meta: {
                    _clipsKey: [take.toJson()],
                  },
                ),
                EditorStateHistory(
                  meta: {
                    _clipsKey: [
                      take
                          .copyWith(
                            trimStart: const Duration(milliseconds: 400),
                          )
                          .toJson(),
                      other.toJson(),
                    ],
                  },
                ),
              ]
              ..historyPointer = 1;

        final changed = manager.adoptCapturedChromaKeyBakes([
          keyed,
        ], '/documents');

        expect(changed, isTrue);
        expect(manager.stateHistory, hasLength(2));
        expect(manager.historyPointer, 1);
        for (final entry in manager.stateHistory) {
          final held = _clipsIn(entry).firstWhere((c) => c.id == 'take');
          // Undo can no longer reach the raw take.
          expect(held.video?.file?.path, '/documents/take_keyed.mp4');
          expect(held.chromaKey, _key);
          expect(held.hasPendingCaptureChromaKey, isFalse);
        }
        final latest = _clipsIn(manager.stateHistory.last);
        // The entry's own edits stay, and so do the other clips.
        expect(latest.first.trimStart, const Duration(milliseconds: 400));
        expect(latest.last.video?.file?.path, '/documents/other.mp4');
        expect(
          manager.clipSnapshots('/documents').first.chromaKey,
          _key,
          reason: 'the active entry is refreshed too',
        );
      });
    });

    group('adoptSecondaryCameraLayers', () {
      const placedKey =
          VideoEditorConstants.placedSecondaryCameraTakesStateHistoryKey;

      WidgetLayer pip(String id) =>
          WidgetLayer(id: id, widget: const SizedBox.shrink());

      StateManager managerWith(List<EditorStateHistory> entries) =>
          StateManager(onStateHistoryChange: null, activeBackgroundImage: null)
            ..stateHistory = entries
            ..historyPointer = entries.length - 1;

      test('puts the layers into every entry without adding one', () {
        final drawing = WidgetLayer(
          id: 'drawing',
          widget: const SizedBox.shrink(),
        );
        final manager = managerWith([
          EditorStateHistory(),
          EditorStateHistory(
            layers: [drawing],
            meta: {
              _clipsKey: [_clip('a').toJson()],
            },
          ),
        ]);

        manager.adoptSecondaryCameraLayers([pip('pip')], ['a_second']);

        expect(manager.stateHistory, hasLength(2));
        expect(manager.historyPointer, 1);
        // Undo can no longer take the second camera away.
        for (final entry in manager.stateHistory) {
          expect(entry.layers.map((layer) => layer.id), contains('pip'));
        }
        expect(manager.activeLayers.map((layer) => layer.id), [
          'drawing',
          'pip',
        ]);
        // The entry's own metadata stays.
        expect(_clipsIn(manager.stateHistory.last).single.id, 'a');
      });

      test('gives every entry a copy of its own', () {
        final manager = managerWith([
          EditorStateHistory(),
          EditorStateHistory(),
        ]);

        manager.adoptSecondaryCameraLayers([pip('pip')], ['a_second']);

        expect(
          identical(
            manager.stateHistory.first.layers.single,
            manager.stateHistory.last.layers.single,
          ),
          isFalse,
          reason: 'moving the active layer must not move it in older entries',
        );
      });

      test('records the takes as placed in every entry', () {
        final manager = managerWith([
          EditorStateHistory(),
          EditorStateHistory(
            meta: const {
              placedKey: ['a_second'],
            },
          ),
        ]);

        manager.adoptSecondaryCameraLayers([pip('pip')], ['b_second']);

        expect(manager.placedSecondaryCameraTakeIds, {'a_second', 'b_second'});
        expect(manager.stateHistory.first.meta[placedKey], ['b_second']);
        expect(
          manager.stateHistory.last.meta[placedKey],
          unorderedEquals(['a_second', 'b_second']),
        );
      });
    });

    group('placedSecondaryCameraTakeIds', () {
      test('is empty for a history without placed takes', () {
        final manager = StateManager(
          onStateHistoryChange: null,
          activeBackgroundImage: null,
        )..stateHistory = [EditorStateHistory()];

        expect(manager.placedSecondaryCameraTakeIds, isEmpty);
      });

      test('reads the record from any entry and skips values not ids', () {
        final manager =
            StateManager(
                onStateHistoryChange: null,
                activeBackgroundImage: null,
              )
              ..stateHistory = [
                EditorStateHistory(),
                EditorStateHistory(
                  meta: const {
                    VideoEditorConstants
                        .placedSecondaryCameraTakesStateHistoryKey: [
                      'a_second',
                      42,
                    ],
                  },
                ),
              ];

        expect(manager.placedSecondaryCameraTakeIds, {'a_second'});
      });
    });
  });
}
