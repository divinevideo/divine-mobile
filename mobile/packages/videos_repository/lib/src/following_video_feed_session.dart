// ABOUTME: Owns Following's badge/direct source selection and live pager.

import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

/// Resolves subscribed authors and falls back only to proven direct follows.
///
/// Author callbacks keep badge/follow repository dependencies outside this
/// package. Each successful first page installs one fixed author snapshot.
class FollowingVideoFeedSession {
  /// Creates a feed session using the existing video repository's readers.
  FollowingVideoFeedSession({
    required VideosRepository videosRepository,
    required List<String> Function() directAuthors,
    Future<Iterable<String>> Function()? badgeAuthors,
    Future<void> Function()? waitForDirectAuthors,
    bool Function()? directAuthorsKnown,
    Future<bool> Function()? confirmDirectAuthors,
    Duration directAuthorsTimeout = const Duration(seconds: 10),
    String? userPubkey,
  }) : _videosRepository = videosRepository,
       _directAuthors = directAuthors,
       _badgeAuthors = badgeAuthors,
       _waitForDirectAuthors = waitForDirectAuthors,
       _directAuthorsKnown = directAuthorsKnown,
       _confirmDirectAuthors = confirmDirectAuthors,
       _directAuthorsTimeout = directAuthorsTimeout,
       _userPubkey = userPubkey;

  final VideosRepository _videosRepository;
  final List<String> Function() _directAuthors;
  final Future<Iterable<String>> Function()? _badgeAuthors;
  final Future<void> Function()? _waitForDirectAuthors;
  final bool Function()? _directAuthorsKnown;
  final Future<bool> Function()? _confirmDirectAuthors;
  final Duration _directAuthorsTimeout;
  final String? _userPubkey;
  BadgeVideoPager? _pager;

  bool get _authorsKnown => _directAuthorsKnown?.call() ?? true;

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
    Future<HomeFeedResult> loadDirect() => _videosRepository.getHomeFeedVideos(
      authors: List<String>.of(_directAuthors()),
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
        throw const FollowingReadSuperseded();
      }
      return HomeFeedResult(
        videos: videos,
        hasMore: pager.hasMore,
        paginationCursor: pager.hasMore ? 'badge-following' : null,
      );
    }
    if (cursor != null || _badgeAuthors == null) return loadDirect();
    // Observe both outcomes immediately; badge paging may supersede this read.
    final directPage = _directAuthors().isNotEmpty
        ? Future<HomeFeedResult>.sync(
            loadDirect,
          ).then<({HomeFeedResult? value, Object? error, StackTrace? stack})>(
            (value) => (value: value, error: null, stack: null),
            onError: (Object error, StackTrace stack) =>
                (value: null, error: error, stack: stack),
          )
        : null;
    try {
      final badgeAuthors = await _badgeAuthors();
      if (!ownsRequest()) throw const FollowingReadSuperseded();
      if (badgeAuthors.isNotEmpty) {
        // An empty initial list is not proof that this account follows nobody.
        if (!_authorsKnown && _directAuthors().isEmpty) {
          // Initialization can remain pending when keys are unavailable or
          // local storage fails. Timing out leaves the follow list unknown.
          await _waitForDirectAuthors?.call().timeout(
            _directAuthorsTimeout,
            onTimeout: () {},
          );
        }
        if (!ownsRequest()) throw const FollowingReadSuperseded();
        if (!_authorsKnown && _directAuthors().isEmpty) {
          // No kind 3 is valid for a new account, but only a settled relay
          // answer can distinguish that from an unavailable follow list.
          final settled =
              await _confirmDirectAuthors?.call().timeout(
                _directAuthorsTimeout,
                onTimeout: () => false,
              ) ??
              false;
          if (!ownsRequest()) throw const FollowingReadSuperseded();
          if (!settled && !_authorsKnown && _directAuthors().isEmpty) {
            throw const FollowingAuthorsUnavailable();
          }
        }
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
          paginationCursor: pager.hasMore ? 'badge-following' : null,
        );
      }
    } catch (error, stackTrace) {
      if (!ownsRequest()) throw const FollowingReadSuperseded();
      if (_directAuthors().isEmpty) {
        // The user-feed endpoint selects only the server's kind-3 follows.
        // Accept its positive proof only while the local list is unknown;
        // never override a confirmed empty list or infer proof from no rows.
        if (!_authorsKnown && _userPubkey != null) {
          final result = await loadDirect();
          if (!ownsRequest()) throw const FollowingReadSuperseded();
          if (result.videos.isNotEmpty &&
              (!_authorsKnown || _directAuthors().isNotEmpty)) {
            _pager = null;
            return result;
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      Log.warning(
        'FollowingVideoFeedSession: badges unavailable, showing follows',
        name: 'FollowingVideoFeedSession',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
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
}

/// A Following read lost ownership before it could return a page.
class FollowingReadSuperseded implements Exception {
  /// Creates a superseded-read signal, distinct from an empty terminal page.
  const FollowingReadSuperseded();
}

/// The direct-follow snapshot is still unknown after initialization completed.
class FollowingAuthorsUnavailable implements Exception {
  /// Allows retry rather than installing a misleading holder-only feed.
  const FollowingAuthorsUnavailable();
}
