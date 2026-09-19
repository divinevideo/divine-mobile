// ABOUTME: Tests for DivineVideoDraft.finalRenderVersion
// ABOUTME: A cached final render from an older renderer must not be reused

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({DivineVideoClip? finalRenderedClip}) =>
    DivineVideoDraft(
      id: 'draft_1',
      clips: [_clip('source')],
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

/// A draft as a build from before render versions were stamped stored it.
DivineVideoDraft _legacyDraft({DivineVideoClip? finalRenderedClip}) =>
    DivineVideoDraft.fromJson(
      _draft(finalRenderedClip: finalRenderedClip).toJson()
        ..remove('finalRenderVersion'),
      '/tmp',
    );

void main() {
  group(DivineVideoDraft, () {
    group('finalRenderVersion', () {
      test('keeps a final render saved by this build across a round trip', () {
        final restored = DivineVideoDraft.fromJson(
          _draft(finalRenderedClip: _clip('rendered')).toJson(),
          '/tmp',
        );

        expect(restored.finalRenderedClip?.id, 'rendered');
        expect(restored.hasStaleFinalRender, isFalse);
      });

      test('marks a render saved before versions were stamped as stale', () {
        final restored = _legacyDraft(finalRenderedClip: _clip('rendered'));

        // Still loaded, so file bookkeeping can find the render and delete it.
        expect(restored.finalRenderedClip?.id, 'rendered');
        expect(restored.hasStaleFinalRender, isTrue);
      });

      test('keeps a stale render stale when the draft is saved again', () {
        final stale = _legacyDraft(finalRenderedClip: _clip('rendered'));

        final resaved = DivineVideoDraft.fromJson(
          stale.copyWith(title: 'Renamed').toJson(),
          '/tmp',
        );

        expect(resaved.finalRenderedClip?.id, 'rendered');
        expect(resaved.hasStaleFinalRender, isTrue);
      });

      test('treats a render handed to copyWith as current', () {
        final stale = _legacyDraft(finalRenderedClip: _clip('rendered'));
        expect(stale.hasStaleFinalRender, isTrue);

        final rerendered = stale.copyWith(finalRenderedClip: _clip('fresh'));

        expect(rerendered.finalRenderedClip?.id, 'fresh');
        expect(rerendered.hasStaleFinalRender, isFalse);
      });

      test('keeps a stale render stale in a duplicate', () {
        final stale = _legacyDraft(finalRenderedClip: _clip('rendered'));

        final copy = stale.duplicate();

        expect(copy.finalRenderedClip?.id, 'rendered');
        expect(copy.hasStaleFinalRender, isTrue);
      });

      test('is not stale when the draft has no final render', () {
        expect(_legacyDraft().hasStaleFinalRender, isFalse);
      });
    });
  });
}
