import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/ideas_transcript.dart';

void main() {
  group('toJson and fromJson', () {
    test(
      'private corrected transcript survives draft JSON without a caption track',
      () {
        const transcript = IdeasTranscript(
          revision: 'synthetic-edit-1',
          language: 'fr',
          text: 'Bonjour',
        );
        final draft = DivineVideoDraft.create(
          clips: [],
          title: '',
          description: '',
          hashtags: {},
          selectedApproach: 'capture',
          ideasTranscript: transcript,
        );
        final json = draft.toJson();
        final restored = DivineVideoDraft.fromJson(json, '/documents');
        expect(restored.ideasTranscript!.toJson(), transcript.toJson());
        expect(restored.editorEditingParameters, isEmpty);
        expect(
          restored.copyWith(title: 'Edited').ideasTranscript!.text,
          'Bonjour',
        );
        expect(IdeasTranscript.fromJson(null), isNull);
        expect(IdeasTranscript.fromJson({'text': 1}), isNull);
      },
    );
  });
}
