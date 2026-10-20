// ABOUTME: Owns Following's badge/direct source selection and live pager.

import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

/// Resolves subscribed authors and falls back only to known direct follows.
///
/// Author callbacks keep badge/follow repository dependencies outside this
/// package. Each successful first page installs one fixed author snapshot.
class FollowingVideoFeedSession {
  /// Creates a feed session using the existing video repository's readers.
  FollowingVideoFeedSession({
    required VideosRepository videosRepository,
    required List<String> Function() directAuthors,
    Future<Iterable<String>> Function()? badgeAuthors,
    String? userPubkey,
  }) : _videosRepository = videosRepository,
       _directAuthors = directAuthors,
       _badgeAuthors = badgeAuthors,
       _userPubkey = userPubkey;

  final VideosRepository _videosRepository;
  final List<String> Function() _directAuthors;
  final Future<Iterable<String>> Function()? _badgeAuthors;
  final String? _userPubkey;
  BadgeVideoPager? _pager;

  /// Whether the committed Following snapshot includes badge holders.
  bool get hasBadgeAuthors => _pager != null;

  /// Reads a first page or continues the currently committed author snapshot.
  ///
  /// [ownsRequest] prevents an obsolete first page from replacing the pager.
  /// [isActive] prevents continuation after the consuming feed has closed.
  Future<HomeFeedResult> loadPage({
    required bool Function() ownsRequest,
    required bool Function() isActive,
    String? cursor,
  }) async {
    final directAuthors = List<String>.of(_directAuthors());
    Future<HomeFeedResult> loadDirect() => _videosRepository.getHomeFeedVideos(
      authors: directAuthors,
      userPubkey: _userPubkey,
      cursor: cursor,
    );
    if (cursor == 'badge-following') {
      final pager = _pager;
      if (pager == null) {
        return const HomeFeedResult(videos: [], hasMore: false);
      }
      final videos = await pager.loadMore();
      if (!identical(pager, _pager) || !isActive()) {
        return const HomeFeedResult(videos: [], hasMore: false);
      }
      return HomeFeedResult(
        videos: videos,
        hasMore: pager.hasMore,
        paginationCursor: pager.hasMore ? 'badge-following' : null,
      );
    }
    if (cursor != null || _badgeAuthors == null) return loadDirect();
    // Observe both outcomes immediately; badge paging may supersede this read.
    final directPage = directAuthors.isNotEmpty
        ? Future<HomeFeedResult>.sync(
            loadDirect,
          ).then<({HomeFeedResult? value, Object? error, StackTrace? stack})>(
            (value) => (value: value, error: null, stack: null),
            onError: (Object error, StackTrace stack) =>
                (value: null, error: error, stack: stack),
          )
        : null;
    final badgeAuthors = await _loadBadgeAuthors();
    if (!ownsRequest()) throw const FollowingReadSuperseded();
    if (badgeAuthors.isNotEmpty) {
      try {
        // Keep a first-page pager local until its page is ready and this load
        // still owns the feed. Stale loads may neither activate nor clear it.
        final pager = _videosRepository.createBadgeVideoPager([
          ..._directAuthors(),
          ...badgeAuthors,
        ], prioritizeUnseen: true);
        final videos = await pager.loadMore();
        if (!ownsRequest()) throw const FollowingReadSuperseded();
        _pager = pager;
        return HomeFeedResult(
          videos: videos,
          hasMore: pager.hasMore,
          // Resume the live pager's buffers and offsets with an opaque token.
          paginationCursor: pager.hasMore ? 'badge-following' : null,
        );
      } catch (error, stackTrace) {
        if (!ownsRequest()) throw const FollowingReadSuperseded();
        if (_directAuthors().isEmpty) rethrow;
        Log.warning(
          'FollowingVideoFeedSession: holder videos unavailable, '
          'showing follows',
          name: 'FollowingVideoFeedSession',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final HomeFeedResult result;
    if (directPage == null) {
      result = await loadDirect();
    } else {
      final page = await directPage;
      if (page.error case final error?) {
        Error.throwWithStackTrace(error, page.stack!);
      }
      result = page.value!;
    }
    if (!ownsRequest()) throw const FollowingReadSuperseded();
    _pager = null;
    return result;
  }

  /// Subscribed badge holders, falling back only when direct follows exist.
  /// Without direct follows, preserve failures so the feed offers a retry.
  Future<List<String>> _loadBadgeAuthors() async {
    try {
      return (await _badgeAuthors?.call())?.toList() ?? const <String>[];
    } catch (error, stackTrace) {
      if (_directAuthors().isEmpty) rethrow;
      Log.warning(
        'FollowingVideoFeedSession: subscriptions unavailable, showing follows',
        name: 'FollowingVideoFeedSession',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return const <String>[];
    }
  }
}

/// A Following read lost ownership before it could return a page.
class FollowingReadSuperseded implements Exception {
  /// Creates a superseded-read signal, distinct from an empty terminal page.
  const FollowingReadSuperseded();
}
