// ABOUTME: Keeps draft-local audio paths valid across iOS container changes
// ABOUTME: by persisting them relative to the app documents directory

import 'package:models/models.dart' show AudioEvent;
import 'package:path/path.dart' as p;

/// Documents-relative directory that *used* to hold imported audio files.
///
/// Imports landed under `draft_audio_imports/<draftId>/` — the draft that
/// happened to be open when the user picked the file. A track saved to My
/// Sounds is a library entry that outlives that draft, so the draft was never
/// its owner; only the directory said otherwise. New imports go to
/// [libraryAudioImportsDirName] and existing trees are moved there by
/// `migrateDraftOwnedAudioImports`.
///
/// The name stays a known audio root so paths persisted before the move can be
/// recognized and rebased onto library storage.
const String draftAudioImportsDirName = 'draft_audio_imports';

/// Documents-relative directory holding audio files the user imported.
///
/// Owned by the sound library rather than by any draft: its lifetime is the
/// user's, and nothing about deleting a draft implies deleting a track the
/// user imported while that draft happened to be open (#8024).
const String libraryAudioImportsDirName = 'library_audio_imports';

/// Documents-relative directory holding committed voice-over recordings.
const String voiceOverRecordingsDirName = 'voice_over_recordings';

/// Documents-relative directory holding audio extracted from a draft's clips.
///
/// Extraction writes to the temporary directory for one-shot consumers such as
/// caption generation, but a track the user drops on the timeline is persisted
/// into the draft — and the temporary directory is both container-scoped and
/// purgeable by iOS at any moment, so that copy has to live here instead.
const String extractedClipAudioDirName = 'extracted_clip_audio';

const Set<String> _audioRootDirNames = {
  draftAudioImportsDirName,
  libraryAudioImportsDirName,
  voiceOverRecordingsDirName,
  extractedClipAudioDirName,
};

/// Id prefixes of audio backed by a file this device wrote for a draft.
const Set<String> _draftLocalMarkers = {
  AudioEvent.localImportMarker,
  AudioEvent.localExtractedMarker,
};

/// Documents-relative form of an absolute draft-local audio [path].
///
/// iOS rewrites the app container path on every app update, so an absolute
/// audio path baked into a saved draft dangles from then on: the video still
/// plays — clip paths are persisted as basenames and rejoined on load — while
/// every sound goes silent. Audio paths keep their whole subpath below the
/// documents directory rather than only the basename because some audio roots
/// contain nested directories. Paths outside a known audio directory are
/// returned unchanged.
String toPortableAudioPath(String path) => _belowAudioRoot(path) ?? path;

/// Whether [path] names a file inside one of the four directories this app
/// writes draft-local audio into.
///
/// Bounds what an audio-reclaim path is allowed to delete. Every producer —
/// `LocalAudioImportService`, the voice-over cubit, clip audio extraction —
/// writes below one of those roots, so a stored `localFilePath` pointing
/// anywhere else did not come from this app's own audio storage and must not
/// be deleted on its behalf.
///
/// A `..` segment below the root is rejected: the root name matches, but the
/// path escapes upward out of app audio storage, and reclaim deletes the raw
/// path. Nothing writes such a path today, so this only keeps the delete
/// bound honest if one ever reaches the stored `localFilePath`.
bool isDraftLocalAudioPath(String path) {
  final relative = _belowAudioRoot(path);
  return relative != null && !p.split(relative).contains('..');
}

/// Absolute path for a persisted audio [path], rooted at [documentsPath].
///
/// Accepts the portable form as well as an absolute path from a previous
/// container, so drafts written before the portable form existed heal the
/// first time they are loaded. A path still naming the retired
/// [draftAudioImportsDirName] root is rebased onto
/// [libraryAudioImportsDirName], which is where
/// `migrateDraftOwnedAudioImports` put the file — the tail below the root is
/// preserved exactly, so basenames (which is what audio reclaim matches on)
/// do not change.
String resolveAudioPath(String path, String documentsPath) {
  final relative = _belowAudioRoot(path);
  if (relative == null) return path;
  return p.join(documentsPath, _relocateRetiredImportRoot(relative));
}

/// [relative] with a leading [draftAudioImportsDirName] segment replaced by
/// [libraryAudioImportsDirName].
String _relocateRetiredImportRoot(String relative) {
  final segments = p.split(relative);
  if (segments.first != draftAudioImportsDirName) return relative;
  return p.joinAll([libraryAudioImportsDirName, ...segments.skip(1)]);
}

/// [json] with every draft-local audio path rewritten to its portable form.
Map<String, dynamic> toPortableAudioPaths(Map<String, dynamic> json) =>
    _rewriteAudioUrls(json, toPortableAudioPath)! as Map<String, dynamic>;

/// [json] with every draft-local audio path resolved against [documentsPath].
///
/// When [useOriginalPath] is true the stored paths are returned unchanged,
/// mirroring `resolvePath`.
Map<String, dynamic> resolveAudioPaths(
  Map<String, dynamic> json,
  String documentsPath, {
  bool useOriginalPath = false,
}) {
  if (useOriginalPath) return json;
  return _rewriteAudioUrls(
        json,
        (path) => resolveAudioPath(path, documentsPath),
      )!
      as Map<String, dynamic>;
}

/// The `<audio-root>/…` tail of [path], or `null` when it has no audio root.
///
/// Matches on the segment name alone, not on whether [path] sits under the
/// documents directory, so a file placed in a `voice_over_recordings/` folder
/// anywhere else would also be rebased onto documents on load. Nothing writes
/// any of the three names outside the documents directory today.
String? _belowAudioRoot(String path) {
  if (path.isEmpty) return null;
  final segments = p.split(path);
  // Stop at the second-to-last segment: a match needs a file below the root.
  for (var i = segments.length - 2; i >= 0; i--) {
    if (_audioRootDirNames.contains(segments[i])) {
      return p.joinAll(segments.sublist(i));
    }
  }
  return null;
}

/// Applies [transform] to the `url` of every draft-local [AudioEvent] map
/// nested anywhere inside [node], returning [node] itself when nothing moved.
///
/// The editor persists audio in three unrelated shapes — the selected sound,
/// `editorStateHistory.history[].meta.audio[]`, and
/// `editorEditingParameters.meta.audio[]` — so this walks the whole tree
/// instead of hardcoding those routes.
Object? _rewriteAudioUrls(
  Object? node,
  String Function(String path) transform,
) {
  if (node is List) {
    List<Object?>? copy;
    for (var i = 0; i < node.length; i++) {
      final rewritten = _rewriteAudioUrls(node[i], transform);
      if (identical(rewritten, node[i])) continue;
      (copy ??= List<Object?>.of(node))[i] = rewritten;
    }
    return copy ?? node;
  }
  if (node is! Map) return node;

  final url = _draftLocalAudioUrl(node);
  if (url != null) {
    final rewritten = transform(url);
    if (rewritten == url) return node;
    return <String, dynamic>{
      ...Map<String, dynamic>.from(node),
      'url': rewritten,
    };
  }

  Map<String, dynamic>? copy;
  for (final entry in node.entries) {
    final key = entry.key;
    if (key is! String) continue;
    final rewritten = _rewriteAudioUrls(entry.value, transform);
    if (identical(rewritten, entry.value)) continue;
    (copy ??= Map<String, dynamic>.from(node))[key] = rewritten;
  }
  return copy ?? node;
}

/// The on-disk url of [node] when it is a draft-local audio event, else `null`.
///
/// Mirrors [AudioEvent.isDraftLocalAudio] and [AudioEvent.localFilePath]
/// against a raw map: the persisted tree is walked without deserializing, so a
/// malformed audio entry is skipped rather than throwing. Keep the predicate in
/// step.
String? _draftLocalAudioUrl(Map<Object?, Object?> node) {
  final id = node['id'];
  if (id is! String || !_draftLocalMarkers.any((m) => id.startsWith('${m}_'))) {
    return null;
  }
  final url = node['url'];
  return url is String && url.isNotEmpty ? url : null;
}
