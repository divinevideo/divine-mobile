import 'package:flutter_test/flutter_test.dart';
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
  });
}
