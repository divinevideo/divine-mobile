import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/features/publishing_ideas/publishing_ideas_revision.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/ideas_transcript.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('fromEditor', () {
    test('uses saved text only for the current composition', () {
      final revision = publishingIdeasRevision({}, []);
      final editor = VideoEditorProviderState(
        ideasTranscript: IdeasTranscript(
          revision: revision,
          language: 'en',
          text: 'Saved text',
        ),
      );
      expect(
        PublishingIdeasSource.fromEditor(editor, [], 'en').transcript,
        'Saved text',
      );
      final obsolete = editor.copyWith(
        ideasTranscript: const IdeasTranscript(
          revision: 'obsolete',
          language: 'en',
          text: 'Old text',
        ),
      );
      expect(
        PublishingIdeasSource.fromEditor(obsolete, [], 'en').transcript,
        isEmpty,
      );
    });

    test('subtitles take precedence and cues follow their start times', () {
      const track = CaptionTrack(
        presetId: 'classic',
        languageTag: 'fr',
        cues: [
          CaptionCue(
            id: 'later',
            text: 'Second',
            start: Duration(seconds: 2),
            end: Duration(seconds: 3),
          ),
          CaptionCue(
            id: 'earlier',
            text: 'First',
            start: Duration.zero,
            end: Duration(seconds: 1),
          ),
        ],
      );
      final parameters = CompleteParameters(
        meta: {'captions': track.toJson()},
        blur: 0,
        originalImageSize: const Size(1080, 1920),
        temporaryDecodedImageSize: const Size(1080, 1920),
        bodySize: const Size(400, 800),
        editorSize: const Size(400, 800),
        matrixFilterList: const [],
        matrixTuneAdjustmentsList: const [],
        startTime: null,
        endTime: null,
        cropWidth: null,
        cropHeight: null,
        rotateTurns: 0,
        cropX: null,
        cropY: null,
        flipX: false,
        flipY: false,
        image: Uint8List(0),
        isTransformed: false,
        layers: const [],
      );
      final revision = publishingIdeasRevision(parameters.toMap(), []);
      final editor = VideoEditorProviderState(
        editorEditingParameters: parameters,
        ideasTranscript: IdeasTranscript(
          revision: revision,
          language: 'en',
          text: 'Saved text',
        ),
      );
      final source = PublishingIdeasSource.fromEditor(editor, [], 'en');
      expect(source.transcript, 'First Second');
      expect(source.language, 'fr');
      expect(source.hasCaptions, isTrue);
      expect(source.canTranscribe, isFalse);
    });

    test('render readiness changes identity but not composition revision', () {
      final clip = DivineVideoClip(
        id: 'rendered',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: models.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
        video: EditorVideo.file('/documents/rendered.mp4'),
      );
      final editor = VideoEditorProviderState(finalRenderedClip: clip);
      final ready = PublishingIdeasSource.fromEditor(editor, [], 'en');
      final processing = PublishingIdeasSource.fromEditor(
        editor.copyWith(isProcessing: true),
        [],
        'en',
      );
      expect(ready.canTranscribe, isTrue);
      expect(processing.canTranscribe, isFalse);
      expect(processing.identity, isNot(ready.identity));
      expect(processing.revision, ready.revision);
    });
  });
}
