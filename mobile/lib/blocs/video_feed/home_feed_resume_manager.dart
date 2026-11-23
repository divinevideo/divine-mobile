// ABOUTME: Owns the cross-restart home-feed resume window for VideoFeedBloc —
// ABOUTME: reading the serveable cached window, splicing fresh results after
// ABOUTME: the active video, and persisting (debounced) the forward window.

import 'dart:async';

import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:videos_repository/videos_repository.dart';

/// How far past the active video the cross-restart cache resumes.
///
/// The forward window persisted on serve / load / swipe starts at the active
/// index plus this offset, so the next cold start opens on the first video the
/// user has not seen. An offset of `1` drops only the active (seen) video — the
/// user cannot scroll back to it, but no unseen video is skipped, and a
/// no-interaction reopen advances by a single video instead of burning through
/// the window two at a time.
const _resumeOffset = 1;

/// Leading videos kept ahead of the active one when splicing fresh results in.
///
/// Keeping the active video plus its lookahead lets `InfiniteVideoFeed`'s
/// common-prefix handling preserve the active controller, so the playing video
/// does not restart when fresh content lands.
const _spliceLookahead = 2;

/// Debounce window for persisting the resume position on rapid swipes.
///
/// The resume point need not be frame-accurate, so per-swipe disk writes are
/// coalesced — avoiding a JSON-encode + Drift write on every page change while
/// the user scrolls quickly through the feed.
const _persistDebounce = Duration(milliseconds: 600);

/// Coordinates the persisted forward window that lets `VideoFeedBloc` serve the
/// Home feed from disk on cold start and resume past already-seen videos.
class HomeFeedResumeManager {
  HomeFeedResumeManager({
    required HomeFeedCache cache,
    required VideosRepository videosRepository,
  }) : _cache = cache,
       _videosRepository = videosRepository;

  final HomeFeedCache _cache;
  final VideosRepository _videosRepository;

  Timer? _persistTimer;
  ({String? pubkey, String mode, List<VideoEvent> videos, int activeIndex})?
  _pending;

  /// Serialises same-key cache writes so they complete in submission order.
  ///
  /// Persists fire from multiple paths against the same key (serve, then the
  /// fresh-spliced load, plus debounced swipes). Without ordering, an earlier
  /// disk write that finishes late could overwrite the newer window. Chaining
  /// each write after the previous one guarantees the freshest window — always
  /// the latest submitted — is written last and wins.
  Future<void> _writeChain = Future<void>.value();

  /// Reads the cached window for [mode] and applies the current content and
  /// seen-video filters, waiting for history to load when filtering is enabled.
  ///
  /// The persisted window starts after the last active index, so the caller
  /// serves the surviving videos at index 0.
  Future<List<VideoEvent>> readServeableWindow({
    required String? pubkey,
    required String mode,
  }) async {
    final cached = await _cache.readVideos(pubkey: pubkey, mode: mode);
    if (cached == null || cached.isEmpty) return const [];
    final filtered = await _videosRepository.applyHomeFeedPreferences(cached);
    return filtered.where((v) => v.videoUrl != null).toList();
  }

  /// Keeps the active video plus one lookahead from [existing] and appends the
  /// [fresh] results (deduped) after them, so fresh content appears right after
  /// the current video instead of behind the whole cached window. The kept
  /// prefix leaves the active video's controller untouched, so it does not
  /// restart when fresh lands.
  ///
  /// Dedup uses [VideoEvent.feedDedupKey] (the addressable coordinate when
  /// present, else the event id) to match the pagination merge in
  /// [VideoFeedBloc]. A cached addressable video republished with a fresh event
  /// id shares its coordinate with the fresh copy, so keying on the raw id
  /// would let both through as a visible duplicate.
  List<VideoEvent> splice({
    required List<VideoEvent> existing,
    required List<VideoEvent> fresh,
    required int currentIndex,
  }) {
    if (existing.isEmpty) return fresh;
    if (fresh.isEmpty) return existing;

    final keepCount = (currentIndex + _spliceLookahead).clamp(
      0,
      existing.length,
    );
    final head = existing.sublist(0, keepCount);
    final headKeys = head.map((v) => v.feedDedupKey).toSet();
    final tail = fresh.where((v) => !headKeys.contains(v.feedDedupKey));
    return [...head, ...tail];
  }

  /// Persists the forward window immediately (used on serve and load).
  void persistNow({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
    required int activeIndex,
  }) {
    _persistTimer?.cancel();
    _pending = null;
    _write(
      pubkey: pubkey,
      mode: mode,
      videos: videos,
      activeIndex: activeIndex,
    );
  }

  /// Trailing-debounces a resume-window persist for the swipe hot path, so
  /// rapid swipes coalesce into a single disk write.
  void schedulePersist({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
    required int activeIndex,
  }) {
    _pending = (
      pubkey: pubkey,
      mode: mode,
      videos: videos,
      activeIndex: activeIndex,
    );
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _flush);
  }

  void _flush() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _write(
      pubkey: pending.pubkey,
      mode: pending.mode,
      videos: pending.videos,
      activeIndex: pending.activeIndex,
    );
  }

  /// Writes the videos from [activeIndex] + [_resumeOffset] onward, so the next
  /// cold start opens on the next unseen video. Already-watched videos before
  /// the offset are dropped, so the user cannot scroll back to them on resume.
  ///
  /// When nothing remains past the offset (the user reached the end of the
  /// window) the key is **cleared** rather than left untouched — otherwise the
  /// previous entry would re-serve already-seen videos on the next cold start.
  void _write({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
    required int activeIndex,
  }) {
    final start = (activeIndex + _resumeOffset).clamp(0, videos.length);
    final shouldClear = start >= videos.length;
    final window = shouldClear ? const <VideoEvent>[] : videos.sublist(start);

    // Append to the serialised chain so this write runs only after the
    // previous one completes — the latest submitted window always wins.
    _writeChain = _writeChain
        .then(
          (_) => shouldClear
              ? _cache.clearVideos(pubkey: pubkey, mode: mode)
              : _cache.writeVideos(pubkey: pubkey, mode: mode, videos: window),
        )
        .catchError((Object _) {});
  }

  /// Flushes any pending swipe persist and cancels the debounce timer.
  void dispose() {
    _flush();
    _persistTimer?.cancel();
    _persistTimer = null;
  }
}
