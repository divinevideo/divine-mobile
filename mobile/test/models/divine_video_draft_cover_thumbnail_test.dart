// ABOUTME: Tests for DivineVideoDraft.coverThumbnailPath getter
// ABOUTME: Validates the selected cover is preferred over the source clip

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _clip({required String id, String? thumbnailPath}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/tmp/$id.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2025),
      originalAspectRatio: 9 / 16,
      targetAspectRatio: .vertical,
      thumbnailPath: thumbnailPath,
    );

DivineVideoDraft _draft({
  required List<DivineVideoClip> clips,
  DivineVideoClip? finalRenderedClip,
  String? customThumbnailPath,
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: clips,
  title: '',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  finalRenderedClip: finalRenderedClip,
  customThumbnailPath: customThumbnailPath,
);

void main() {
  group(DivineVideoDraft, () {
    group('coverThumbnailPath', () {
      test('prefers the custom cover over the rendered and source clips', () {
        final draft = _draft(
          clips: [_clip(id: 'source', thumbnailPath: '/docs/source.jpg')],
          finalRenderedClip: _clip(
            id: 'rendered',
            thumbnailPath: '/docs/rendered.jpg',
          ),
          customThumbnailPath: '/docs/custom.jpg',
        );

        expect(draft.coverThumbnailPath, '/docs/custom.jpg');
      });

      test('prefers the rendered clip cover over the source clip', () {
        final draft = _draft(
          clips: [_clip(id: 'source', thumbnailPath: '/docs/source.jpg')],
          finalRenderedClip: _clip(
            id: 'rendered',
            thumbnailPath: '/docs/cover.jpg',
          ),
        );

        expect(draft.coverThumbnailPath, '/docs/cover.jpg');
      });

      test('falls back to the first source clip when no rendered clip', () {
        final draft = _draft(
          clips: [_clip(id: 'source', thumbnailPath: '/docs/source.jpg')],
        );

        expect(draft.coverThumbnailPath, '/docs/source.jpg');
      });

      test("shows a dual-camera take's first clip with both cameras", () {
        final draft = _draft(
          clips: [
            _clip(id: 'source', thumbnailPath: '/docs/source.jpg').copyWith(
              secondaryCamera: SecondaryCameraTake(
                clip: _clip(id: 'source_second'),
                compositeThumbnailPath: '/docs/source_dual.jpg',
              ),
            ),
          ],
        );

        expect(draft.coverThumbnailPath, '/docs/source_dual.jpg');
      });

      test('returns null when there is no thumbnail anywhere', () {
        final draft = _draft(clips: [_clip(id: 'source')]);

        expect(draft.coverThumbnailPath, isNull);
      });

      test('returns null when there are no clips', () {
        final draft = _draft(clips: const []);

        expect(draft.coverThumbnailPath, isNull);
      });
    });

    group('customThumbnailPath serialization', () {
      test('round-trips as a basename resolved against the documents '
          'path', () {
        final draft = _draft(
          clips: [_clip(id: 'source')],
          customThumbnailPath: '/old/container/cover.jpg',
        );

        final json = draft.toJson();
        expect(
          json['customThumbnailPath'],
          'cover.jpg',
          reason: 'only the basename is persisted for iOS path stability',
        );

        final restored = DivineVideoDraft.fromJson(json, '/new/container');
        expect(restored.customThumbnailPath, '/new/container/cover.jpg');
      });

      test('omits the key when there is no custom cover', () {
        final draft = _draft(clips: [_clip(id: 'source')]);

        expect(draft.toJson().containsKey('customThumbnailPath'), isFalse);
      });
    });
  });
}
