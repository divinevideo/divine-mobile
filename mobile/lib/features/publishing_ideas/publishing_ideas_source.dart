import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_revision.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';

/// The composition and language identity used by optional publishing ideas.
class PublishingIdeasSource {
  const PublishingIdeasSource({
    required this.identity,
    required this.revision,
    required this.language,
    required this.transcript,
    required this.hasCaptions,
    required this.canTranscribe,
  });

  factory PublishingIdeasSource.fromEditor(
    VideoEditorProviderState editor,
    List<DivineVideoClip> clips,
    String uiLanguage,
  ) {
    final editing = editor.editorEditingParameters;
    final captions = editing?.captionTrackFromMeta;
    final language = captions?.languageTag ?? uiLanguage;
    final revision = publishingIdeasRevision(
      editing?.toMap() ?? {},
      clips.map((clip) => clip.toJson()).toList(),
      selectedSound: (editing?.audioTracksFromMeta ?? []).isEmpty
          ? editor.selectedSound?.toJson()
          : null,
    );
    final subtitleText = captions == null
        ? null
        : ([...captions.cues]..sort((a, b) => a.start.compareTo(b.start)))
              .map((cue) => cue.text)
              .join(' ');
    final saved = editor.ideasTranscript;
    return PublishingIdeasSource(
      identity:
          '$revision|$language|$uiLanguage|${subtitleText ?? ''}|'
          '${editor.finalRenderedClip?.id}|${editor.isProcessing}',
      revision: revision,
      language: language,
      transcript:
          subtitleText ?? (saved?.revision == revision ? saved!.text : ''),
      hasCaptions: captions != null,
      canTranscribe:
          captions == null &&
          editor.finalRenderedClip != null &&
          !editor.isProcessing,
    );
  }

  final String identity;
  final String revision;
  final String language;
  final String transcript;
  final bool hasCaptions;
  final bool canTranscribe;
}
