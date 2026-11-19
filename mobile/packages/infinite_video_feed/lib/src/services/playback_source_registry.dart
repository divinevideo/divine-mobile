import 'package:flutter/foundation.dart';

/// In-memory registry of playback source URLs and the currently active
/// source per video index.
///
/// Tracks which URL each video is currently trying to play and supports
/// failover to the next URL in the list. Pure data — no I/O, no Flutter,
/// no async work.
class PlaybackSourceRegistry {
  final _sources = <int, List<String>>{};
  final _activeIndices = <int, int>{};

  /// Records the resolved [sources] and the [activeIndex] currently in use
  /// for video [index].
  void register(int index, List<String> sources, int activeIndex) {
    _sources[index] = sources;
    _activeIndices[index] = activeIndex;
  }

  /// Records [sources] as runtime fallbacks for a video whose first frame
  /// is being loaded from a local cache file (i.e. no network source is
  /// "active" yet). A subsequent [advance] call will return `sources[0]`.
  ///
  /// Use this so that a runtime `parseError` on a corrupt cache file can
  /// still fail over to the network sources.
  void registerPrestart(int index, List<String> sources) {
    _sources[index] = sources;
    _activeIndices[index] = -1; // advance() returns sources[0] on first call
  }

  /// Returns the active source URL for [index], or `null` if none recorded.
  ///
  /// Returns `null` for prestart entries (active index `-1`) — no network
  /// source is in use yet, the first frame is coming from a local cache.
  String? activeSourceFor(int index) {
    final list = _sources[index];
    if (list == null) return null;
    final i = _activeIndices[index] ?? 0;
    return (i >= 0 && i < list.length) ? list[i] : null;
  }

  /// Whether this index has any sources registered.
  bool hasSources(int index) =>
      _sources[index] != null && _sources[index]!.isNotEmpty;

  /// Whether there is at least one more source to try for [index].
  bool canAdvance(int index) => nextSourceFor(index) != null;

  /// Returns the next source for [index] without changing the active source.
  String? nextSourceFor(int index) {
    final list = _sources[index];
    // _activeIndices[index] == -1 means prestart (cache); next = 0 is valid.
    final next = (_activeIndices[index] ?? 0) + 1;
    return list != null && next < list.length ? list[next] : null;
  }

  /// Advances [index] to the next source and returns it, or `null` when the
  /// source list is exhausted.
  String? advance(int index) {
    final source = nextSourceFor(index);
    if (source != null) {
      _activeIndices[index] = (_activeIndices[index] ?? 0) + 1;
    }
    return source;
  }

  /// The current attempt index for [index] (0-based).
  @visibleForTesting
  int attemptFor(int index) => _activeIndices[index] ?? 0;

  /// Forgets all entries for [index].
  void remove(int index) {
    _sources.remove(index);
    _activeIndices.remove(index);
  }

  /// Forgets all entries.
  void clear() {
    _sources.clear();
    _activeIndices.clear();
  }
}
