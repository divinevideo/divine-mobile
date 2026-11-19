// ABOUTME: Tests for CaptionPreviewCues: a style preview shows the video's
// ABOUTME: first two captions whole, and the tagline until there are two.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/caption_preview_cues.dart';
import 'package:openvine/models/video_editor/caption_track.dart';

void main() {
  CaptionCue cue(String text) => CaptionCue(
    id: text,
    text: text,
    start: Duration.zero,
    end: const Duration(seconds: 1),
  );

  group(CaptionPreviewCues, () {
    group('fromCues', () {
      test('previews the first two captions whole', () {
        expect(
          CaptionPreviewCues.fromCues([
            cue('Welcome back to my kitchen'),
            cue('Today we bake bread'),
            cue('Let us start'),
          ]),
          equals(
            const CaptionPreviewCues(
              'Welcome back to my kitchen',
              'Today we bake bread',
            ),
          ),
        );
      });

      test('skips captions whose text was cleared', () {
        expect(
          CaptionPreviewCues.fromCues([cue('  '), cue('Hi'), cue('There')]),
          equals(const CaptionPreviewCues('Hi', 'There')),
        );
      });

      test('falls back to the tagline until there are two captions', () {
        expect(
          CaptionPreviewCues.fromCues(const []),
          equals(CaptionPreviewCues.fallback),
        );
        expect(
          CaptionPreviewCues.fromCues([cue('This is so cool'), cue(' ')]),
          equals(CaptionPreviewCues.fallback),
        );
      });
    });
  });
}
