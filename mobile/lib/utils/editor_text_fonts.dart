// ABOUTME: Registers the editor's Google Fonts before restored text renders
// ABOUTME: Shared by the editor screen and the headless draft rasterizer

import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Published Google Fonts family names keyed by the font's static tear-off.
///
/// Built from [VideoEditorConstants.textFontCatalogue], which carries the name
/// beside each tear-off, rather than by reversing `GoogleFonts.asMap()`. That
/// map is const over the package's whole catalogue, so referencing it retains
/// every one of its ~1700 font descriptors — see [EditorTextFont].
final Map<TextFont, String> _googleFontFamilyNames = {
  for (final entry in VideoEditorConstants.textFontCatalogue)
    entry.font: entry.familyName,
};

/// The published Google Fonts family name of [font] ("Bebas Neue"), or `null`
/// when [font] is not one of the editor's catalogue fonts.
String? googleFontFamilyName(TextFont font) => _googleFontFamilyNames[font];

/// The `TextStyle.fontFamily` google_fonts assigns to the regular face of the
/// font published as [familyName]: the name with its spaces removed and the
/// variant appended (`'Bebas Neue'` → `'BebasNeue_regular'`). That identifier
/// is what a serialized text layer carries, so it is how a restored layer is
/// matched back to the font that registers it.
String _regularFontFamilyIdentifier(String familyName) =>
    '${familyName.replaceAll(' ', '')}_regular';

/// The editor fonts a text layer carrying one of [fontFamilies] renders with.
///
/// Identifiers that name no editor font are ignored: nothing here could
/// register them, and the layer falls back exactly as it did before.
@visibleForTesting
List<TextFont> editorTextFontsFor(Iterable<String> fontFamilies) {
  final wanted = fontFamilies.toSet();
  return [
    for (final font in VideoEditorConstants.textFonts)
      if (googleFontFamilyName(font) case final name?
          when wanted.contains(_regularFontFamilyIdentifier(name)))
        font,
  ];
}

/// The index in [VideoEditorConstants.textFonts] of the editor font a
/// serialized text layer carrying [fontFamily] names, or `-1` when no editor
/// font does.
///
/// Maps a restored layer back to its catalogue entry without calling any font:
/// calling one registers a load, which is the fetch a restore is trying to
/// avoid.
int editorTextFontIndexFor(String? fontFamily) {
  if (fontFamily == null) return -1;
  final fonts = editorTextFontsFor([fontFamily]);
  if (fonts.isEmpty) return -1;
  return VideoEditorConstants.textFonts.indexOf(fonts.first);
}

/// The `fontFamily` identifiers of every text layer in a serialized editor
/// state history, as `exportStateHistory` writes it with `enableMinify: false`.
///
/// Walks the whole map rather than a fixed path because a text layer's style
/// lands both in the `references` table and, when it changed, in a history
/// entry's delta.
Set<String> textFontFamiliesInHistory(Map<String, dynamic> history) {
  final families = <String>{};
  void visit(Object? node) {
    switch (node) {
      case Map<dynamic, dynamic>():
        for (final entry in node.entries) {
          if (entry.key == 'fontFamily' && entry.value is String) {
            families.add(entry.value as String);
          } else {
            visit(entry.value);
          }
        }
      case List<dynamic>():
        node.forEach(visit);
    }
  }

  visit(history);
  return families;
}

/// Registers the text-overlay fonts so a restored [TextLayer] paints in the
/// typeface the user picked.
///
/// A persisted text layer carries only the serialized font family name, and
/// Google Fonts register lazily per process. Anything that renders imported
/// overlays — the editor canvas importing a state history, or the headless
/// rasterizer baking them for a publish — has to register them first, or the
/// text falls back to the platform default: wrong typeface, and wrong metrics,
/// which also moves the layer (#5181).
///
/// [fontFamilies] are the identifiers the layers about to render carry (see
/// [textFontFamiliesInHistory]); only the editor fonts they name are
/// registered, so a draft with two text layers fetches two fonts rather than
/// the whole catalogue.
///
/// Already-cached fonts resolve instantly; the timeout only bounds the first,
/// uncached load. Timing out is not an error, and neither is a load that fails:
/// in both cases the render proceeds with whatever resolved.
Future<void> preloadEditorTextFonts({
  required Iterable<String> fontFamilies,
}) async {
  final fonts = editorTextFontsFor(fontFamilies);
  if (fonts.isEmpty) return;
  for (final font in fonts) {
    font();
  }
  await GoogleFonts.pendingFonts()
      .timeout(
        VideoEditorConstants.textFontLoadTimeout,
        onTimeout: () => const [],
      )
      // A failed load stays in google_fonts' pending set, which makes every
      // later pendingFonts() call throw instead of time out.
      .catchError((_) => const <void>[]);
}
