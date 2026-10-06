/// Private, draft-only transcript. Never converted into a subtitle track.
class IdeasTranscript {
  const IdeasTranscript({
    required this.revision,
    required this.language,
    required this.text,
  });
  final String revision;
  final String language;
  final String text;

  static IdeasTranscript? fromJson(Object? value) {
    if (value is! Map) return null;
    final revision = value['revision'];
    final language = value['language'];
    final text = value['text'];
    if (revision is! String || language is! String || text is! String) {
      return null;
    }
    return IdeasTranscript(revision: revision, language: language, text: text);
  }

  Map<String, String> toJson() => {
    'revision': revision,
    'language': language,
    'text': text,
  };
}
