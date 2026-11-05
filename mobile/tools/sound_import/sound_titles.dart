// ABOUTME: Turns sound pack file names into readable titles, such as
// ABOUTME: `impactPunch_heavy_000.ogg` into "Impact Punch Heavy 0".

const _smallWords = {'a', 'an', 'and', 'at', 'by', 'in', 'of', 'on', 'or'};

/// A readable title for the file [fileName], with [context] (such as the
/// pack's name) put in front when the name alone says nothing, as with
/// `1.ogg`.
String titleFromFileName(String fileName, {required String context}) {
  var stem = fileName;
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);

  // Recording dates some packs lead with, such as "2023-03-23 Haze".
  stem = stem.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}\s+'), '');
  stem = stem
      .replaceAll('_', ' ')
      // "impactPunch" to "impact Punch", "SAX15" to "SAX 15". A single
      // letter keeps its digit, so a note such as "C2" stays one word.
      .replaceAllMapped(
        RegExp('([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAllMapped(
        RegExp('([A-Za-z]{2})([0-9])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAllMapped(RegExp(r'\b0+(\d)'), (match) => match[1]!)
      .replaceAll(RegExp(r'\s*-\s*'), ' - ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final words = stem.split(' ');
  final title = [
    for (final (index, word) in words.indexed)
      if (index > 0 && _smallWords.contains(word.toLowerCase()))
        word.toLowerCase()
      else
        _capitalized(word),
  ].join(' ');

  final saysSomething = RegExp('[A-Za-z]{3,}').hasMatch(title);
  return saysSomething ? title : '$context $title'.trim();
}

String _capitalized(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
