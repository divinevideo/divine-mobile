// ABOUTME: Name rules shared by every style a user saves from the video
// ABOUTME: editor (caption styles, title styles): trimming and a length cap.

import 'package:characters/characters.dart';

/// Longest name a saved style may carry. Keeps a row label readable next to
/// its preview and matches the clip-category limit.
const int savedStyleMaxNameLength = 40;

/// Trims [rawName] and returns it, or `null` when it holds no usable text.
///
/// Callers use `null` to reject the input instead of saving a style with a
/// blank or whitespace-only name. A longer name is cut to
/// [savedStyleMaxNameLength] graphemes, so an emoji never splits in half.
String? sanitizeSavedStyleName(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.characters.take(savedStyleMaxNameLength).toString();
}
