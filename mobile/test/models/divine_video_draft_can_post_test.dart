// ABOUTME: Tests for DivineVideoDraft.canPost getter
// ABOUTME: Validates library draft post eligibility mirrors publish behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createTestClip([String id = 'clip_1']) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({
  List<DivineVideoClip>? clips,
  DivineVideoClip? finalRenderedClip,
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: clips ?? [_createTestClip()],
  title: '',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  finalRenderedClip: finalRenderedClip,
);

void main() {
  group(DivineVideoDraft, () {
    group('canPost', () {
      test(
        'successful-video recovery is never offered as another video post',
        () {
          expect(
            _draft().copyWith(publishStatus: PublishStatus.published).canPost,
            isFalse,
          );
        },
      );
      // #5203 hid Post for these drafts because the publish path shipped the
      // raw recording, dropping every editor layer. Publish now renders them
      // with their layers restored, so gating on a cached render would only
      // hide a working action.
      test('allows posting a single-clip draft with no final render', () {
        expect(_draft().canPost, isTrue);
      });

      test('allows posting a multi-clip draft with no final render', () {
        expect(
          _draft(
            clips: [_createTestClip(), _createTestClip('clip_2')],
          ).canPost,
          isTrue,
        );
      });

      test('refuses a draft with nothing to publish', () {
        expect(_draft(clips: const []).canPost, isFalse);
      });
    });
  });
}
