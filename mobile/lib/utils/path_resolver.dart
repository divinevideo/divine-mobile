// ABOUTME: Utility for resolving file paths for iOS compatibility
// ABOUTME: iOS changes container paths on app updates, so we store basenames
//
// Draft-local audio is the exception: it lives in per-draft subdirectories
// and keeps its whole documents-relative subpath. See
// `utils/draft_audio_path_resolver.dart`.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

/// Returns the application documents directory path.
///
/// On web, path_provider has no documents directory; returns `''` so callers
/// can join basenames without calling the plugin (avoids MissingPluginException).
///
/// The web branch is covered by `test/utils/path_resolver_test.dart` when run
/// locally as `flutter test test/utils/path_resolver_test.dart --platform chrome`
/// (not run in CI).
Future<String> getDocumentsPath() async {
  if (kIsWeb) {
    return '';
  }
  final dir = await path_provider.getApplicationDocumentsDirectory();
  return _cachedDocumentsPath = dir.path;
}

String? _cachedDocumentsPath;

/// The documents path if [getDocumentsPath] has already resolved it, else
/// `null`.
///
/// The directory does not move while the app is running, so once the plugin
/// has answered the value is good for the session. Exists for the first frame
/// of a widget that would otherwise render nothing until an await completes —
/// a layer remounted by an undo, say, where a blank frame reads as the layer
/// having been lost. Callers must still fall back to [getDocumentsPath]: the
/// cache is empty until something asks the plugin once.
String? get cachedDocumentsPath => kIsWeb ? '' : _cachedDocumentsPath;

/// Clears the cached documents path so a test can pin the miss path.
@visibleForTesting
void resetCachedDocumentsPath() => _cachedDocumentsPath = null;

/// Resolves a file path for storage/retrieval.
///
/// When [useOriginalPath] is true, returns the raw path unchanged (for migration checks).
/// Otherwise, joins [documentsPath] with only the basename of [rawPath].
///
/// This ensures iOS compatibility since the container path changes on app updates.
String? resolvePath(
  String? rawPath,
  String documentsPath, {
  bool useOriginalPath = false,
}) {
  if (rawPath == null) return null;
  return useOriginalPath ? rawPath : p.join(documentsPath, p.basename(rawPath));
}
