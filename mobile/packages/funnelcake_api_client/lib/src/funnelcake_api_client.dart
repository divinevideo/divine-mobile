// ABOUTME: HTTP client for the Funnelcake REST API (ClickHouse analytics).
// ABOUTME: Provides methods for fetching video data with engagement metrics.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:funnelcake_api_client/src/exceptions.dart';
import 'package:funnelcake_api_client/src/leaderboard_period.dart';
import 'package:funnelcake_api_client/src/models/models.dart';
import 'package:funnelcake_api_client/src/user_agent.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

/// Source split for the v2 popular feed.
enum PopularVideosVariant {
  /// New/native Divine videos, excluding imported Vine archive items.
  native,

  /// Imported classic Vine archive items only.
  classic,
}

/// HTTP client for the Funnelcake REST API.
///
/// Funnelcake provides a ClickHouse-backed analytics API that offers
/// faster queries than Nostr relays for video data and engagement metrics.
///
/// **Stateless:** This client has no in-memory caching — every call hits
/// the network. Callers that need request deduplication or stale-while-
/// revalidate behavior should manage that at a higher layer.
///
/// **Errors:** Unlike the legacy analytics service (which often returned
/// empty lists on HTTP failures), this client throws typed subclasses of
/// `FunnelcakeException` (for example `FunnelcakeApiException`,
/// `FunnelcakeTimeoutException`). Call sites should use `try`/`catch`.
///
/// Example usage:
/// ```dart
/// final client = FunnelcakeApiClient(
///   baseUrl: 'https://api.example.com',
/// );
///
/// final videos = await client.getVideosByAuthor(pubkey: 'abc123');
/// ```
class FunnelcakeApiClient {
  /// Creates a new [FunnelcakeApiClient] instance.
  ///
  /// [baseUrl] is the base URL for the Funnelcake API
  /// (e.g., 'https://api.example.com').
  /// [httpClient] is an optional HTTP client for making requests.
  /// [timeout] bounds a whole call, not a single attempt: a GET spends it
  /// across every retry and backoff wait, so retrying never multiplies a
  /// caller's worst case (defaults to 15 seconds).
  /// [retryBaseDelay] seeds the backoff between GET retries; pass
  /// [Duration.zero] in tests to keep suites fast.
  FunnelcakeApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
    Duration retryBaseDelay = const Duration(milliseconds: 300),
    String moderationProfile = defaultModerationProfile,
    String? appVersion,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _timeout = timeout,
       _retryBaseDelay = retryBaseDelay,
       _moderationProfile = moderationProfile,
       _appVersion = appVersion;

  final String? _appVersion;

  /// Total attempts an idempotent GET makes before giving up.
  ///
  /// Reads retry because a flaky last mile is far more likely than the API
  /// being down: the production host is CDN-replicated, so a GET that fails
  /// once usually succeeds moments later on the same connection.
  static const int maxGetAttempts = 3;

  /// Upper bound on a single backoff wait, before jitter.
  static const Duration _maxRetryDelay = Duration(seconds: 4);

  /// Default moderation profile sent with video-bearing Funnelcake requests.
  static const String defaultModerationProfile = 'default';

  /// Sort key for profile searches ordered by follower count.
  static const String profileSortFollowers = 'followers';

  /// Server-side cap on the engagement-list endpoints, used as the default
  /// page size for [getVideoLikers] because the list renders in one screen.
  ///
  /// Larger values are clamped to this by the API, so a video with more
  /// likers is truncated here rather than paginated.
  static const int maxVideoLikersLimit = 500;

  static const Set<String> _diagnosticStructuralKeys = {
    'categories',
    'data',
    'error',
    'followers',
    'following',
    'hashtags',
    'items',
    'message',
    'notifications',
    'pagination',
    'profiles',
    'results',
    'status',
    'success',
    'videos',
  };

  /// Sink used to surface warning-level diagnostics from static helpers such
  /// as [_unwrapListResponse].
  ///
  /// Defaults to routing through `unified_logger`'s [Log.warning] (the
  /// repo-wide logging contract). Tests override this to assert that envelope
  /// regressions are surfaced rather than silently swallowed; production code
  /// should leave it untouched.
  @visibleForTesting
  static void Function(String message) warningLogger = _defaultWarningLogger;

  static void _defaultWarningLogger(String message) {
    Log.warning(
      message,
      name: 'FunnelcakeApiClient',
      category: LogCategory.api,
    );
  }

  final String _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _timeout;
  final Duration _retryBaseDelay;
  final String _moderationProfile;
  final math.Random _retryJitter = math.Random();

  /// Whether the API is available (has a non-empty base URL).
  bool get isAvailable => _baseUrl.isNotEmpty;

  /// The base URL for the API.
  @visibleForTesting
  String get baseUrl => _baseUrl;

  /// Performs an idempotent GET, retrying transient failures.
  ///
  /// Retries cover the two shapes a flaky connection produces: a thrown
  /// transport error (timeout, dropped socket) and a retryable status
  /// (429, 5xx). A definitive answer — including 404 — is returned on the
  /// first attempt, because absence is information and must not be
  /// confused with an unreachable server.
  ///
  /// [_timeout] bounds the whole call, not one attempt: every attempt and
  /// backoff wait draws from the same budget. A caller's worst case is
  /// therefore unchanged by retrying — which matters because callers await
  /// this inline (the login pre-fetch blocks the post-auth redirect on it),
  /// and a per-attempt bound would have multiplied that stall by
  /// [maxGetAttempts]. The trade is that a request which burns the entire
  /// budget in one attempt is not retried; the fast failures a flaky link
  /// actually produces — reset sockets, refused connections, 5xx — leave
  /// almost the whole budget intact and still get every attempt.
  Future<http.Response> _get(Uri uri) async {
    final elapsed = Stopwatch()..start();
    Duration remaining() => _timeout - elapsed.elapsed;

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _httpClient
            .get(
              uri,
              headers: {
                'Accept': 'application/json',
                ...buildDivineClientHeaders(appVersion: _appVersion),
              },
            )
            .timeout(remaining());

        if (_canRetry(attempt, remaining()) &&
            _isRetryableStatus(response.statusCode)) {
          await _awaitRetryDelay(attempt, remaining());
          continue;
        }
        return response;
      } on TimeoutException catch (e) {
        // Future.timeout sets duration; transport timeouts constructed by
        // the client stack usually do not. The former has spent this call's
        // whole budget and must not start another attempt.
        if (e.duration != null) rethrow;
        if (!_canRetry(attempt, remaining())) rethrow;
        await _awaitRetryDelay(attempt, remaining());
      } on Object {
        // Nothing above constructs a FunnelcakeException, so any throw here
        // is transport-level and worth another attempt.
        if (!_canRetry(attempt, remaining())) rethrow;
        await _awaitRetryDelay(attempt, remaining());
      }
    }
  }

  /// Whether another GET attempt is allowed after [attempt] failed, with
  /// [remaining] left of the call's timeout budget.
  bool _canRetry(int attempt, Duration remaining) =>
      attempt < maxGetAttempts && remaining > Duration.zero;

  /// Whether [statusCode] represents a failure the server may recover from.
  bool _isRetryableStatus(int statusCode) =>
      statusCode == 429 || (statusCode >= 500 && statusCode < 600);

  /// Waits out the backoff for [attempt], using full jitter so clients that
  /// lost the same flaky link do not retry in lockstep when it returns.
  ///
  /// Never waits longer than [remaining], so backoff cannot overrun the
  /// call's timeout budget on its own.
  Future<void> _awaitRetryDelay(int attempt, Duration remaining) async {
    if (_retryBaseDelay == Duration.zero) return;
    final exponential = _retryBaseDelay.inMilliseconds * (1 << (attempt - 1));
    final capped = math.min(
      math.min(exponential, _maxRetryDelay.inMilliseconds),
      remaining.inMilliseconds,
    );
    if (capped <= 0) return;
    await Future<void>.delayed(
      Duration(milliseconds: _retryJitter.nextInt(capped + 1)),
    );
  }

  Future<http.Response> _post(Uri uri, {required Object body}) {
    return _httpClient
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...buildDivineClientHeaders(appVersion: _appVersion),
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Map<String, String> _diagnosticHeaders(http.Response response) {
    const headerNames = <String>[
      'x-request-id',
      'x-correlation-id',
      'traceparent',
      'cf-ray',
      'x-amzn-trace-id',
      'server-timing',
    ];

    return {
      for (final name in headerNames)
        if (response.headers[name]?.isNotEmpty ?? false)
          name: response.headers[name]!,
    };
  }

  Map<String, String> _videoQueryParameters(Map<String, String> params) {
    return <String, String>{
      ...params,
      'nsfw': 'show',
      'moderation_profile': _moderationProfile,
    };
  }

  void _addViewerPreferenceQueryParameters(
    Map<String, String> queryParams, {
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) {
    final languages = preferredLanguages
        .map((language) => language.trim())
        .where((language) => language.isNotEmpty)
        .toList();
    if (languages.isNotEmpty) {
      queryParams['preferred_languages'] = languages.join(',');
    }

    final country = viewerCountry?.trim();
    if (country != null && country.isNotEmpty) {
      queryParams['viewer_country'] = country;
    }
  }

  /// Unwraps a funnelcake list response that may be either a raw JSON array
  /// (legacy / `legacy-array-response` flag on) or the post-#238 envelope
  /// shape `{"data": [...], "pagination": {"has_more": bool, "next_cursor":
  /// string|null, "next_offset": int|null}}`.
  ///
  /// Returns a record with:
  /// - `items`: the list of raw JSON objects.
  /// - `hasMore`: `true`/`false` from the envelope; `null` for raw arrays
  ///   (caller should apply its own heuristic, e.g. `items.length >= limit`).
  /// - `nextCursor`: opaque cursor string from the envelope, or `null` when
  ///   the raw-array shape is used (caller computes its own cursor).
  ///
  /// Mirrors the `unwrapListResponse<T>` helper in divine-web#277.
  static ({List<dynamic> items, bool? hasMore, String? nextCursor})
  _unwrapListResponse(Object? decoded) {
    if (decoded is List) {
      return (items: decoded, hasMore: null, nextCursor: null);
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        final pagination = decoded['pagination'];
        bool? hasMore;
        String? nextCursor;
        if (pagination is Map<String, dynamic>) {
          hasMore = pagination['has_more'] as bool?;
          final rawCursor = pagination['next_cursor'];
          final rawOffset = pagination['next_offset'];
          if (rawCursor != null) {
            nextCursor = rawCursor.toString();
          } else if (rawOffset != null) {
            nextCursor = rawOffset.toString();
          }
        }
        return (items: data, hasMore: hasMore, nextCursor: nextCursor);
      }
    }
    // Unrecognised shape — log so envelope regressions are visible, then
    // return empty so callers never throw.
    warningLogger(
      'Unrecognised funnelcake list response shape; returning empty list. '
      'shape=${_describeShape(decoded)}',
    );
    return (items: const <dynamic>[], hasMore: false, nextCursor: null);
  }

  /// Builds a short, non-sensitive description of an unrecognised decoded
  /// response for diagnostic logging.
  ///
  /// Avoids dumping full response bodies (which may be large or contain user
  /// data); reports the runtime type plus, for maps, key counts and a small
  /// allow-list of structural keys. Unknown keys are counted rather than
  /// emitted because malformed responses may carry user data in key position.
  static String _describeShape(Object? decoded) {
    if (decoded == null) {
      return 'null';
    }
    if (decoded is Map) {
      final keys = decoded.keys.map((key) => '$key').toSet();
      final structuralKeys =
          keys.where(_diagnosticStructuralKeys.contains).toList()..sort();
      final unknownKeyCount = keys.length - structuralKeys.length;
      return 'Map('
          'keyCount: ${keys.length}, '
          'structuralKeys: [${structuralKeys.join(', ')}], '
          'unknownKeyCount: $unknownKeyCount'
          ')';
    }
    return decoded.runtimeType.toString();
  }

  static int? _parseIntPageToken(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Builds the notifications endpoint URI for a user.
  ///
  /// The returned URI includes the same query parameters used by
  /// [getNotifications] so callers can sign the exact request URL.
  Uri notificationsUri({
    required String pubkey,
    int limit = 50,
    String? cursor,
    String? cursorId,
    List<String>? types,
  }) {
    // Server timestamps are Unix seconds, not milliseconds.
    final effectiveBefore =
        cursor ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final queryParams = <String, String>{
      'limit': '$limit',
      'before': effectiveBefore,
      'before_id': ?cursorId,
      if (types != null && types.isNotEmpty) 'types': types.join(','),
    };

    return Uri.parse(
      '$_baseUrl/api/users/$pubkey/notifications',
    ).replace(queryParameters: queryParams);
  }

  /// Returns the full mark-notifications-read URI for the given user.
  ///
  /// Callers building NIP-98 auth headers must sign the same URL that the
  /// HTTP request will use, including scheme + host. Use this helper to
  /// avoid signing a path-only URL while the request goes out to a full
  /// origin (the resulting `URL mismatch` 401 is the precise failure mode
  /// PR #4034's rollback semantics treat as a hard failure).
  Uri notificationsReadUri({required String pubkey}) =>
      Uri.parse('$_baseUrl/api/users/$pubkey/notifications/read');

  /// Builds the JSON body sent to [markNotificationsRead].
  ///
  /// Exposed so callers building NIP-98 auth headers can hash the exact
  /// bytes that will land in the POST body — otherwise the auth event's
  /// `payload` tag drifts from the request body and the server rejects
  /// with `payload hash mismatch`.
  ///
  /// Passing `null` (or omitting [notificationIds]) marks all of the
  /// user's unread notifications as read, per the funnelcake docs.
  static String buildMarkNotificationsReadBody({
    List<String>? notificationIds,
  }) => jsonEncode({'notification_ids': ?notificationIds});

  /// Fetches videos by a specific author.
  ///
  /// [pubkey] is the author's public key (hex format).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [offset] is an optional pagination offset.
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a [VideosByAuthorResponse] containing a list of [VideoStats]
  /// and an optional `totalCount` parsed from the `X-Total-Count` response
  /// header.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeNotFoundException] if the author is not found.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<VideosByAuthorResponse> getVideosByAuthor({
    required String pubkey,
    int limit = 50,
    int? offset,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = _videoQueryParameters({'limit': limit.toString()});
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, :hasMore, :nextCursor) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        final videos = items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // totalCount comes solely from the X-Total-Count response header.
        // It is null when the header is absent — the envelope pagination object
        // does not carry a total count. hasMore and nextOffset (via nextCursor)
        // do come from the envelope when the v2 shape is used.
        final totalCountHeader = response.headers['x-total-count'];
        final totalCount = totalCountHeader != null
            ? int.tryParse(totalCountHeader)
            : null;

        return VideosByAuthorResponse(
          videos: videos,
          totalCount: totalCount,
          nextOffset: _parseIntPageToken(nextCursor),
          hasMore: hasMore,
        );
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Author videos',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch author videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch author videos: $e', cause: e);
    }
  }

  /// Fetches trending videos sorted by engagement score.
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by trending score.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getTrendingVideos({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'sort': 'trending',
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch trending videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch trending videos: $e');
    }
  }

  /// Fetches recent videos sorted by original publication time (newest first).
  ///
  /// Funnelcake preserves `published_at` across addressable-event edits, so a
  /// thumbnail or metadata revision does not move an old video back to the
  /// head of the New feed.
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by publication recency.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getRecentVideos({
    int limit = 50,
    int? before,
  }) async {
    final response = await getRecentVideosPage(limit: limit, before: before);
    return response.videos;
  }

  /// Fetches recent videos sorted by original publication time, preserving how
  /// many rows the server actually returned.
  ///
  /// Prefer this over [getRecentVideos] when paginating: [getRecentVideos]
  /// drops malformed rows, so its length cannot distinguish "the source ran
  /// out" from "one row was unusable".
  ///
  /// Throws the same exceptions as [getRecentVideos].
  Future<RecentVideosResponse> getRecentVideosPage({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'sort': 'published',
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, :hasMore, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return RecentVideosResponse(
          videos: items
              .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
              .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
              .toList(),
          serverItemCount: items.length,
          hasMore: hasMore,
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch recent videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch recent videos: $e');
    }
  }

  /// Fetches videos sorted by 24-hour CDN view count with NO age decay.
  ///
  /// Surfaces what people are looking at right now — including classic
  /// Vines getting current attention. Backed by Funnelcake's
  /// `?sort=watching` mode (see funnelcake#305 + funnelcake#307).
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getWatchingVideos({
    int limit = 50,
    int? before,
  }) async {
    final response = await getWatchingVideosPage(limit: limit, before: before);
    return response.videos;
  }

  /// Fetches videos sorted by 24-hour CDN view count with NO age decay,
  /// returning pagination metadata when the v2 envelope is available.
  Future<WatchingVideosResponse> getWatchingVideosPage({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'sort': 'watching',
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, :hasMore, :nextCursor) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        final videos = items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        return WatchingVideosResponse(
          videos: videos,
          nextCursor: _parseIntPageToken(nextCursor),
          hasMore: hasMore,
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch watching videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch watching videos: $e');
    }
  }

  /// Fetches the v2 popular feed filtered to native Divine or classic Vine
  /// imports.
  ///
  /// Native mode maps to `sort=popular&period=now&exclude_platform=vine`;
  /// classic mode maps to `sort=popular&period=month&platform=vine`.
  /// Callers that need a strict platform-only page should continue paging on
  /// the raw response cursor and apply any client-side filtering themselves.
  Future<List<VideoStats>> getV2PopularVideos({
    required PopularVideosVariant variant,
    int limit = 50,
    int? before,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    final response = await getV2PopularVideosPage(
      variant: variant,
      limit: limit,
      before: before,
      preferredLanguages: preferredLanguages,
      viewerCountry: viewerCountry,
    );
    return response.videos;
  }

  /// Fetches the v2 popular feed filtered to native Divine or classic Vine
  /// imports, preserving the server's opaque pagination metadata.
  Future<V2PopularVideosResponse> getV2PopularVideosPage({
    required PopularVideosVariant variant,
    int limit = 50,
    String? cursor,
    int? before,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'sort': 'popular',
      'period': variant == PopularVideosVariant.classic ? 'month' : 'now',
      'limit': limit.toString(),
    });
    if (variant == PopularVideosVariant.classic) {
      queryParams['platform'] = 'vine';
    } else {
      queryParams['exclude_platform'] = 'vine';
    }
    if (cursor != null) {
      queryParams['cursor'] = cursor;
    } else if (before != null) {
      queryParams['before'] = before.toString();
    }
    _addViewerPreferenceQueryParameters(
      queryParams,
      preferredLanguages: preferredLanguages,
      viewerCountry: viewerCountry,
    );

    final uri = Uri.parse(
      '$_baseUrl/api/v2/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, :hasMore, :nextCursor) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        final videos = items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        return V2PopularVideosResponse(
          videos: videos,
          nextCursor: nextCursor,
          hasMore: hasMore,
        );
      }

      throw FunnelcakeApiException(
        message: 'Failed to fetch v2 popular videos',
        statusCode: response.statusCode,
        url: uri.toString(),
      );
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch v2 popular videos: $e');
    }
  }

  /// Fetches the currently renderable featured hashtag tabs.
  ///
  /// The response never carries the configured hashtag — each tab exposes
  /// only an opaque [FeaturedTabConfig.id] used for fetching and analytics.
  /// The server normally returns only enabled, in-window tabs that have
  /// content, but callers must still apply their own eligibility checks.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<FeaturedTabsResponse> getFeaturedTabs() async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final uri = Uri.parse('$_baseUrl/api/featured-tabs');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FunnelcakeException(
            'Unexpected featured tabs response shape',
          );
        }
        return FeaturedTabsResponse.fromJson(decoded);
      }

      throw FunnelcakeApiException(
        message: 'Failed to fetch featured tabs',
        statusCode: response.statusCode,
        url: uri.toString(),
      );
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch featured tabs: $e');
    }
  }

  /// Fetches one page of videos for the featured tab identified by [id].
  ///
  /// Results arrive curated-first then approved newest-first; the returned
  /// order is authoritative and callers must not re-sort or re-filter it.
  /// A well-formed id for a retired or out-of-window tab returns an empty
  /// page rather than a 404.
  ///
  /// [limit] is clamped by the server to 1-100 and defaults to 25.
  /// [cursor] is the opaque cursor from a previous page.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<FeaturedTabVideosResponse> getFeaturedTabVideos({
    required String id,
    int limit = 25,
    String? cursor,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({'limit': limit.toString()});
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/featured-tabs/${Uri.encodeComponent(id)}/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, :hasMore, :nextCursor) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        final videos = items
            .whereType<Map<String, dynamic>>()
            .map(VideoStats.fromJson)
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        return FeaturedTabVideosResponse(
          videos: videos,
          nextCursor: nextCursor,
          hasMore: hasMore,
        );
      }

      throw FunnelcakeApiException(
        message: 'Failed to fetch featured tab videos',
        statusCode: response.statusCode,
        url: uri.toString(),
      );
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch featured tab videos: $e');
    }
  }

  /// Fetches the top videos for a given leaderboard time window.
  ///
  /// Backed by funnelcake's `/api/leaderboard/videos?period=…` endpoint
  /// (see api.divine.video/docs/llm-guide → Leaderboards). Items are ranked
  /// server-side by views/loops within the window. Results are sorted by
  /// rank, not by `created_at` — the caller should not re-sort.
  ///
  /// Endpoint uses a `{period, entries}` envelope rather than the standard
  /// `{data, pagination}` shape, so `_unwrapListResponse` does not apply.
  ///
  /// [period] is the time window: day / week / month / alltime.
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [offset] is the optional offset for pagination (in items, not timestamps).
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getLeaderboardVideos({
    required LeaderboardPeriod period,
    int limit = 50,
    int? offset,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'period': period.wireValue,
      'limit': limit.toString(),
    };
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/leaderboard/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          return const [];
        }
        final entries = decoded['entries'];
        if (entries is! List) {
          return const [];
        }
        return entries
            .whereType<Map<String, dynamic>>()
            .map(VideoStats.fromJson)
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      }

      throw FunnelcakeApiException(
        message: 'Failed to fetch leaderboard videos',
        statusCode: response.statusCode,
        url: uri.toString(),
      );
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch leaderboard videos: $e');
    }
  }

  /// Fetches the home feed for a specific user.
  ///
  /// Returns videos from accounts the user follows, with cursor-based
  /// pagination.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [sort] is the sort order ('recent' or 'trending', defaults to 'recent').
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a [HomeFeedResponse] containing videos and pagination info.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeNotFoundException] if the user's feed is not found.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<HomeFeedResponse> getHomeFeed({
    required String pubkey,
    int limit = 50,
    String sort = 'recent',
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'sort': sort,
    };
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/feed',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body) as Map<String, dynamic>;

        // Tolerate both the legacy shape `{"videos": [...]}` and the
        // post-funnelcake#238 envelope `{"data": [...], "pagination": {...}}`.
        final videosData =
            (raw['videos'] as List<dynamic>?) ??
            (raw['data'] as List<dynamic>?) ??
            <dynamic>[];
        final videos = videosData
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // Pagination metadata may be at top level or under `pagination`.
        final pagination = raw['pagination'] as Map<String, dynamic>?;
        final rawCursor = raw['next_cursor'] ?? pagination?['next_cursor'];
        final nextCursor = switch (rawCursor) {
          final int value => value,
          final String value => int.tryParse(value),
          _ => null,
        };
        final hasMore =
            raw['has_more'] as bool? ??
            pagination?['has_more'] as bool? ??
            false;

        return HomeFeedResponse(
          videos: videos,
          nextCursor: nextCursor,
          hasMore: hasMore,
          rawBody: before == null ? response.body : null,
        );
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Home feed',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch home feed',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch home feed: $e');
    }
  }

  /// Searches for user profiles by query string.
  ///
  /// [query] is the search term to look for in profile names, display names,
  /// and NIP-05 identifiers.
  /// [limit] is the maximum number of profiles to return (defaults to 50).
  /// [offset] is the number of results to skip for pagination.
  /// [sortBy] optionally sorts results server-side (e.g., 'followers').
  /// [hasVideos] when true, filters to only users who have published videos.
  ///
  /// Returns a list of [ProfileSearchResult] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the query is empty.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<ProfileSearchResult>> searchProfiles({
    required String query,
    int limit = 50,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const FunnelcakeException('Search query cannot be empty');
    }

    final queryParams = <String, String>{
      'q': trimmedQuery,
      'limit': limit.toString(),
    };
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }
    if (sortBy != null) {
      queryParams['sort_by'] = sortBy;
    }
    if (hasVideos) {
      queryParams['has_videos'] = 'true';
    }

    final uri = Uri.parse(
      '$_baseUrl/api/search/profiles',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((p) => ProfileSearchResult.fromJson(p as Map<String, dynamic>))
            .where((p) => p.pubkey.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to search profiles',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to search profiles: $e');
    }
  }

  /// Fetches confirmed collaborator videos for a user.
  ///
  /// This endpoint is the canonical confirmed collaborator read path. It is not
  /// a raw Nostr p-tag mention search; pending/unconfirmed collaborator tags
  /// should not be surfaced as profile collabs by callers.
  ///
  /// [pubkey] is the confirmed collaborator's public key (hex format).
  /// [limit] is the maximum number of videos to return
  /// (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for
  /// pagination.
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is
  ///   not configured.
  /// - [FunnelcakeNotFoundException] if no collabs found.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] on timeout.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getCollabVideos({
    required String pubkey,
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = _videoQueryParameters({'limit': limit.toString()});
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/collabs',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Collab videos',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch collab videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch collab videos: $e');
    }
  }

  /// Searches for hashtags matching the query.
  ///
  /// [query] is the search term to match against hashtag names.
  /// When null or empty, returns popular hashtags without filtering.
  /// [limit] is the maximum number of hashtags to return (defaults to 20).
  ///
  /// Returns a list of hashtag name strings sorted by popularity/trending.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<String>> searchHashtags({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (offset > 0) 'offset': offset.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
    };

    final uri = Uri.parse(
      '$_baseUrl/api/hashtags/trending',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        // Both branches go through HashtagSearchResult so a bare-string item
        // gets the same UTF-16 normalization as a mapped one — these tags end
        // up as chip labels, and a lone surrogate throws out of Flutter's
        // paragraph builder.
        return items
            .map((item) {
              if (item is Map<String, dynamic>) {
                return HashtagSearchResult.fromJson(item).tag;
              }
              return HashtagSearchResult(tag: item.toString()).tag;
            })
            .where((tag) => tag.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to search hashtags',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to search hashtags: $e');
    }
  }

  /// Fetches videos sorted by loop count (highest first).
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by loop count.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByLoops({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'sort': 'loops',
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch videos by loops',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch videos by loops: $e');
    }
  }

  /// Fetches videos by hashtag, sorted by trending score.
  ///
  /// [hashtag] is the hashtag to filter by (without `#` prefix).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by trending score.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the hashtag is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByHashtag({
    required String hashtag,
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();
    if (normalizedTag.isEmpty) {
      throw const FunnelcakeException('Hashtag cannot be empty');
    }

    final queryParams = _videoQueryParameters({
      'tag': normalizedTag,
      'sort': 'trending',
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch videos by hashtag',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch videos by hashtag: $e');
    }
  }

  /// Fetches classic/all-time-popular videos for a hashtag.
  ///
  /// Uses `sort=loops` to surface classic vines and high-engagement
  /// content sorted by all-time loop count.
  ///
  /// [hashtag] is the hashtag to filter by (without `#` prefix).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  ///
  /// Returns a list of [VideoStats] objects sorted by loop count.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the hashtag is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getClassicVideosByHashtag({
    required String hashtag,
    int limit = 50,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();
    if (normalizedTag.isEmpty) {
      throw const FunnelcakeException('Hashtag cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos').replace(
      queryParameters: _videoQueryParameters({
        'tag': normalizedTag,
        'sort': 'loops',
        'limit': limit.toString(),
      }),
    );

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch classic videos by hashtag',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException(
        'Failed to fetch classic videos by hashtag: $e',
      );
    }
  }

  /// Searches videos by text query.
  ///
  /// [query] is the search term.
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [sort] is the API sort order: `'trending'`, `'loops'`,
  /// `'engagement'`, `'recent'`, or `'published'`.
  ///
  /// Returns a list of [VideoStats] matching the query.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the query is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int limit = 50,
    int offset = 0,
    String sort = 'trending',
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const FunnelcakeException('Search query cannot be empty');
    }

    final queryParams = _videoQueryParameters({
      'q': trimmedQuery,
      'limit': limit.toString(),
      'sort': sort,
      'type': 'video',
    });
    if (offset > 0) {
      queryParams['cursor'] = 'o:$offset';
    }

    final uri = Uri.parse(
      '$_baseUrl/api/v2/search',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, :hasMore, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        final videos = items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        final totalCount =
            int.tryParse(response.headers['x-total-count'] ?? '') ??
            offset + videos.length;

        return VideoSearchResponse(
          videos: videos,
          totalCount: totalCount,
          hasMore: hasMore ?? false,
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to search videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to search videos: $e');
    }
  }

  /// Fetches classic vines (imported Vine platform videos).
  ///
  /// [sort] is the sort order: `'loops'` (most viral),
  /// `'trending'`, or `'recent'` (defaults to `'loops'`).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [offset] is the pagination offset for rank-based sorting.
  /// [before] is a Unix timestamp cursor for time-based pagination.
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getClassicVines({
    String sort = 'loops',
    int limit = 50,
    int offset = 0,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'classic': 'true',
      'platform': 'vine',
      'sort': sort,
      'limit': limit.toString(),
    });
    if (sort == 'recent' && before != null) {
      queryParams['before'] = before.toString();
    } else if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        // Normalise the legacy `{"videos": [...]}` shape that was returned by
        // earlier funnelcake server builds before funnelcake#238.  All other
        // shapes (raw array, `{"data":[...], "pagination":{...}}` envelope) are
        // handled by _unwrapListResponse below.
        final raw = jsonDecode(response.body);
        final normalised =
            (raw is Map<String, dynamic> &&
                raw['videos'] is List &&
                raw['data'] == null)
            ? (raw['videos'] as List<dynamic>)
            : raw;

        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          normalised,
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch classic vines',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch classic vines: $e');
    }
  }

  /// Fetches trending hashtags.
  ///
  /// [limit] is the maximum number of hashtags to return
  /// (defaults to 20).
  ///
  /// Returns a list of [TrendingHashtag] objects sorted by
  /// popularity.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<TrendingHashtag>> fetchTrendingHashtags({int limit = 20}) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/hashtags',
    ).replace(queryParameters: {'limit': limit.toString()});

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((h) => TrendingHashtag.fromJson(h as Map<String, dynamic>))
            .where((h) => h.tag.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch trending hashtags',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch trending hashtags: $e');
    }
  }

  /// Fetches stats for a specific video.
  ///
  /// [eventId] is the Nostr event ID for the video.
  ///
  /// Returns a [VideoStats] if found, or `null` if not found.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the event ID is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<VideoStats?> getVideoStats(String eventId) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventId.isEmpty) {
      throw const FunnelcakeException('Event ID cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/$eventId/stats');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoStats.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video stats',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video stats: $e');
    }
  }

  /// Fetches the pubkeys that have liked a video, most recent first.
  ///
  /// [eventId] is the Nostr event ID (or d-tag) for the video.
  /// [addressableId] is the optional `kind:pubkey:d-tag` coordinate; the
  /// server resolves one itself when omitted, and an explicit value wins.
  /// [limit] is clamped server-side to [maxVideoLikersLimit].
  ///
  /// Resolves the whole NIP-33 coordinate, not just the id passed in: the
  /// `e`-tag arm expands across every sibling revision, so reactions left on
  /// a superseded id before an edit are still returned (funnelcake#799).
  /// Downvotes, same-author kind-5 retractions, and moderated accounts are
  /// filtered out server-side, and pubkeys are deduplicated — so the result
  /// is smaller than the headline reaction count, which counts every
  /// reaction event.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the event ID is empty.
  /// - [FunnelcakeNotFoundException] if the video is unknown to the API.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<PaginatedPubkeys> getVideoLikers(
    String eventId, {
    String? addressableId,
    int limit = maxVideoLikersLimit,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventId.isEmpty) {
      throw const FunnelcakeException('Event ID cannot be empty');
    }

    final queryParams = <String, String>{'limit': limit.toString()};
    if (addressableId != null && addressableId.isNotEmpty) {
      queryParams['a'] = addressableId;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos/$eventId/likers',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PaginatedPubkeys.fromJson(data);
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Video likers',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video likers',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video likers: $e');
    }
  }

  /// Fetches view count for a specific video.
  ///
  /// [eventId] is the Nostr event ID for the video.
  ///
  /// Returns the view count as an `int`. Returns `0` for 404
  /// responses (video has no views yet).
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the event ID is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<int> getVideoViews(String eventId) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventId.isEmpty) {
      throw const FunnelcakeException('Event ID cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/$eventId/views');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return _parseViewCount(data);
        }
        return 0;
      } else if (response.statusCode == 404) {
        return 0;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video views',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video views: $e');
    }
  }

  /// Fetches the full Nostr event for a specific video route ID.
  ///
  /// [videoId] accepts either a canonical event ID or a stable shared ID
  /// supported by the Funnelcake API.
  ///
  /// Returns the raw [Event] when found, or `null` for 404 responses.
  Future<Event?> getVideoEvent(String videoId) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (videoId.isEmpty) {
      throw const FunnelcakeException('Video ID cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/$videoId');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final eventJson = data['event'];
          if (eventJson is Map<String, dynamic>) {
            return Event.fromJson(eventJson);
          }
          // Some server builds may return the raw event object directly.
          if (data['id'] is String &&
              data['pubkey'] is String &&
              data['created_at'] != null &&
              data['kind'] != null) {
            return Event.fromJson(data);
          }
        }
        throw const FunnelcakeException('Malformed video event response');
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video event',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video event: $e');
    }
  }

  /// Fetches paginated comments for a specific video.
  ///
  /// [videoId] accepts either a video event ID or a d-tag supported by
  /// the FunnelCake API.
  ///
  /// Returns a [VideoCommentsResponse] on success, or `null` when the video
  /// is not found.
  Future<VideoCommentsResponse?> getVideoComments({
    required String videoId,
    String sort = 'newest',
    int limit = 25,
    int offset = 0,
    String? cacheBustToken,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (videoId.isEmpty) {
      throw const FunnelcakeException('Video ID cannot be empty');
    }

    // The comments response is edge-cached (surrogate-control max-age) and is
    // NOT purged when a new Kind 1111 comment/reply is ingested, so a same-URL
    // re-fetch can return a stale list for the cache TTL. When the caller
    // passes a [cacheBustToken] (e.g. after the local user just posted), it
    // becomes a query param so the edge serves a fresh response. The token is
    // stable within a post window, so it does not create unbounded cache keys.
    final uri = Uri.parse('$_baseUrl/api/v2/videos/$videoId/comments').replace(
      queryParameters: {
        'sort': sort,
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (cacheBustToken != null && cacheBustToken.isNotEmpty)
          '_cb': cacheBustToken,
      },
    );

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoCommentsResponse.fromJson(data, offset: offset);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video comments',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video comments: $e');
    }
  }

  /// Fetches user profile data.
  ///
  /// [pubkey] is the user's public key (hex format).
  ///
  /// Returns [UserProfileFound] if the user has published a Kind 0 profile,
  /// [UserProfileNotPublished] if the user exists in Funnelcake but has never
  /// published one, [UserProfileVanished] if the account asked to be erased and
  /// the server is serving no profile for it, or `null` if the user is not
  /// found at all (404).
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<UserProfileResult?> getUserProfile(String pubkey) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/users/$pubkey');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profileJson = data['profile'] as Map<String, dynamic>?;
        final socialJson = data['social'] as Map<String, dynamic>?;
        final statsJson = data['stats'] as Map<String, dynamic>?;
        final engagementJson = data['engagement'] as Map<String, dynamic>?;
        final hasVanishRequest = data['has_vanish_request'] == true;

        // `has_vanish_request` is historical, not a tombstone by itself. A
        // completed vanish can later publish post-boundary Kind 0 metadata and
        // the server serves that as live. Only a suppressed/missing profile with
        // the flag should render as a deleted account. Absent means the server
        // predates the field, preserving the previous not-published behaviour.
        if (hasVanishRequest && profileJson == null) {
          return UserProfileVanished(pubkey: pubkey);
        }

        final social = socialJson != null
            ? ProfileSocialData.fromJson(socialJson)
            : null;
        final stats = statsJson != null
            ? ProfileStatsData.fromJson(statsJson)
            : null;
        final engagement = engagementJson != null
            ? ProfileEngagementData.fromJson(engagementJson)
            : null;

        if (profileJson != null &&
            (profileJson['name'] != null ||
                profileJson['display_name'] != null)) {
          return UserProfileFound(
            profile: UserProfileData.fromJson(pubkey, profileJson),
            social: social,
            stats: stats,
            engagement: engagement,
          );
        }

        // User exists in Funnelcake but has never published a Kind 0 event.
        return UserProfileNotPublished(
          pubkey: pubkey,
          social: social,
          stats: stats,
          engagement: engagement,
        );
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch user profile',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch user profile: $e');
    }
  }

  /// Fetches social counts (follower/following) for a user.
  ///
  /// [pubkey] is the user's public key (hex format).
  ///
  /// Returns a [SocialCounts] if found, or `null` if not found.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<SocialCounts?> getSocialCounts(String pubkey) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/users/$pubkey/social');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SocialCounts.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch social counts',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch social counts: $e');
    }
  }

  /// Fetches a paginated list of followers for a user.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of results (defaults to 100).
  /// [offset] is the pagination offset (defaults to 0).
  ///
  /// Returns a [PaginatedPubkeys] with follower pubkeys.
  ///
  /// [query] narrows the page to profiles whose name, display name, or
  /// NIP-05 contains it. A blank query is omitted from the request, so the
  /// caller does not have to special-case an empty search field.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeNotFoundException] if not found.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<PaginatedPubkeys> getFollowers({
    required String pubkey,
    int limit = 100,
    int offset = 0,
    String? query,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{'limit': limit.toString()};
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }
    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      queryParams['q'] = trimmedQuery;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/followers',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PaginatedPubkeys.fromJson(data);
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Followers',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch followers',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch followers: $e');
    }
  }

  /// Fetches a paginated list of users that a user follows.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of results (defaults to 100).
  /// [offset] is the pagination offset (defaults to 0).
  ///
  /// Returns a [PaginatedPubkeys] with following pubkeys.
  ///
  /// [query] narrows the page to profiles whose name, display name, or
  /// NIP-05 contains it. A blank query is omitted from the request, so the
  /// caller does not have to special-case an empty search field.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeNotFoundException] if not found.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<PaginatedPubkeys> getFollowing({
    required String pubkey,
    int limit = 100,
    int offset = 0,
    String? query,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{'limit': limit.toString()};
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }
    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      queryParams['q'] = trimmedQuery;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/following',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PaginatedPubkeys.fromJson(data);
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Following',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch following',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch following: $e');
    }
  }

  /// Fetches personalized video recommendations for a user.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of videos (defaults to 20).
  /// [fallback] is the strategy when personalization is unavailable
  /// (`'popular'` or `'recent'`, defaults to `'popular'`).
  /// [category] is an optional hashtag/category filter.
  /// [cursor] is the opaque cursor returned by a previous response.
  /// [seed] is an optional opaque per-session value used by the backend
  /// to vary ordering while keeping cursor pagination coherent.
  ///
  /// Returns a [RecommendationsResponse] with videos and source.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeNotFoundException] if the endpoint is not
  ///   deployed.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<RecommendationsResponse> getRecommendations({
    required String pubkey,
    int limit = 20,
    String fallback = 'popular',
    String? category,
    String? cursor,
    String? seed,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'fallback': fallback,
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    if (seed != null && seed.isNotEmpty) {
      queryParams['seed'] = seed;
    }
    _addViewerPreferenceQueryParameters(
      queryParams,
      preferredLanguages: preferredLanguages,
      viewerCountry: viewerCountry,
    );

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/recommendations',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body) as Map<String, dynamic>;

        // Tolerate both the legacy shape `{"videos": [...], "source": ...}`
        // and the post-funnelcake#238 envelope
        // `{"data": [...], "pagination": {...}, "source": ...}`.
        // Mirrors divine-web#277 `fetchRecommendations` logic.
        final videosData =
            (raw['videos'] as List<dynamic>?) ??
            (raw['data'] as List<dynamic>?) ??
            <dynamic>[];

        final videos = videosData
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        final source = raw['source'] as String? ?? 'unknown';
        final pagination = raw['pagination'] as Map<String, dynamic>?;
        final rawHasMore = raw['has_more'] ?? pagination?['has_more'];
        final rawNextCursor = raw['next_cursor'] ?? pagination?['next_cursor'];
        final hasMore = rawHasMore is bool ? rawHasMore : videos.isNotEmpty;

        return RecommendationsResponse(
          videos: videos,
          source: source,
          hasMore: hasMore,
          nextCursor: rawNextCursor?.toString(),
          rawBody: response.body,
        );
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Recommendations',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch recommendations',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch recommendations: $e');
    }
  }

  /// Fetches multiple user profiles in bulk.
  ///
  /// [pubkeys] is the list of public keys to fetch.
  ///
  /// Returns a [BulkProfilesResponse] with a map of pubkey to
  /// [UserProfileResult]. Users that exist but have no Kind 0 profile are
  /// included as [UserProfileNotPublished] entries, and an account the server
  /// reports as erased as a [UserProfileVanished] one. A pubkey the server
  /// omits entirely — which includes an account with a vanish request still
  /// pending — is simply absent from the map.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if pubkeys list is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<BulkProfilesResponse> getBulkProfiles(List<String> pubkeys) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkeys.isEmpty) {
      throw const FunnelcakeException('Pubkeys list cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/users/bulk');

    try {
      final response = await _post(uri, body: {'pubkeys': pubkeys});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final usersData = data['users'] as List<dynamic>? ?? [];

        final result = <String, UserProfileResult>{};
        for (final user in usersData) {
          if (user is Map<String, dynamic>) {
            final pubkey = user['pubkey']?.toString();
            if (pubkey == null || pubkey.isEmpty) continue;

            final profileJson = user['profile'] as Map<String, dynamic>?;
            final socialJson = user['social'] as Map<String, dynamic>?;
            final statsJson = user['stats'] as Map<String, dynamic>?;
            final engagementJson = user['engagement'] as Map<String, dynamic>?;
            final hasVanishRequest = user['has_vanish_request'] == true;

            // Same contract as getUserProfile: the flag alone is historical,
            // while flag + null profile is the suppressed/deleted-account shape.
            if (hasVanishRequest && profileJson == null) {
              result[pubkey] = UserProfileVanished(pubkey: pubkey);
              continue;
            }

            final social = socialJson != null
                ? ProfileSocialData.fromJson(socialJson)
                : null;
            final stats = statsJson != null
                ? ProfileStatsData.fromJson(statsJson)
                : null;
            final engagement = engagementJson != null
                ? ProfileEngagementData.fromJson(engagementJson)
                : null;

            if (profileJson != null &&
                (profileJson['name'] != null ||
                    profileJson['display_name'] != null)) {
              result[pubkey] = UserProfileFound(
                profile: UserProfileData.fromJson(pubkey, profileJson),
                social: social,
                stats: stats,
                engagement: engagement,
              );
            } else {
              // User exists in Funnelcake but has no Kind 0 profile event.
              result[pubkey] = UserProfileNotPublished(
                pubkey: pubkey,
                social: social,
                stats: stats,
                engagement: engagement,
              );
            }
          }
        }

        return BulkProfilesResponse(profiles: result);
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch bulk profiles',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch bulk profiles: $e');
    }
  }

  /// Fetches video stats for multiple videos in bulk.
  ///
  /// [eventIds] is the list of Nostr event IDs to fetch stats for.
  ///
  /// Returns a [BulkVideoStatsResponse] with a map of event ID to
  /// stats.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if eventIds list is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<BulkVideoStatsResponse> getBulkVideoStats(
    List<String> eventIds,
  ) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventIds.isEmpty) {
      throw const FunnelcakeException('Event IDs list cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/stats/bulk');

    try {
      final response = await _post(uri, body: {'event_ids': eventIds});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = <String, BulkVideoStatsEntry>{};
        final statsData = data['stats'];

        if (statsData is List) {
          for (final stat in statsData) {
            if (stat is Map) {
              final statMap = Map<String, dynamic>.from(stat);
              final entry = BulkVideoStatsEntry.fromJson(statMap);
              if (entry.eventId.isNotEmpty) {
                result[entry.eventId] = entry;
              }
            }
          }
        } else if (statsData is Map) {
          for (final mapEntry in statsData.entries) {
            final eventId = mapEntry.key.toString();
            final value = mapEntry.value;
            if (value is Map) {
              final statMap = Map<String, dynamic>.from(value);
              final entry = BulkVideoStatsEntry.fromJson({
                'event_id': statMap['event_id'] ?? eventId,
                ...statMap,
              });
              if (entry.eventId.isNotEmpty) {
                result[entry.eventId] = entry;
              }
            }
          }
        }

        return BulkVideoStatsResponse(stats: result);
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch bulk video stats',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch bulk video stats: $e');
    }
  }

  /// Fetches content categories with video counts.
  ///
  /// [limit] is the maximum number of categories (defaults to 50).
  /// [offset] is the pagination offset (defaults to 0).
  /// [query] is an optional case-insensitive substring filter.
  ///
  /// Returns a list of [VideoCategory] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoCategory>> getCategories({
    int limit = 50,
    int offset = 0,
    String? query,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (query != null && query.isNotEmpty) {
      queryParams['q'] = query;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/categories',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );
        return items
            .map((item) => VideoCategory.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch categories',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch categories: $e');
    }
  }

  /// Fetches videos filtered by category.
  ///
  /// [category] is the category name (e.g., "music", "comedy").
  /// [limit] is the maximum number of videos (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  /// [sort] is the sort order (defaults to "trending").
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the category is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByCategory({
    required String category,
    int limit = 50,
    int? before,
    String sort = 'trending',
    String? platform,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (category.isEmpty) {
      throw const FunnelcakeException('Category cannot be empty');
    }

    final queryParams = _videoQueryParameters({
      'category': category.toLowerCase(),
      'sort': sort,
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }
    if (platform != null) {
      queryParams['platform'] = platform;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final (:items, hasMore: _, nextCursor: _) = _unwrapListResponse(
          jsonDecode(response.body),
        );

        return items
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch videos by category',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch videos by category: $e');
    }
  }

  /// Fetches notifications for a user from the relay REST API.
  ///
  /// Uses NIP-98 authentication. The [cursor] parameter enables pagination
  /// via the `before` query param and optional `before_id` tiebreaker.
  /// The [authHeaders] parameter allows the caller to provide pre-built
  /// NIP-98 auth headers.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<NotificationResponse> getNotifications({
    required String pubkey,
    int limit = 50,
    String? cursor,
    String? cursorId,
    List<String>? types,
    Uri? requestUri,
    Map<String, String>? authHeaders,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final url =
        requestUri ??
        notificationsUri(
          pubkey: pubkey,
          limit: limit,
          cursor: cursor,
          cursorId: cursorId,
          types: types,
        );

    try {
      final response = await _httpClient
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              ...buildDivineClientHeaders(appVersion: _appVersion),
              ...?authHeaders,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return NotificationResponse.fromJson(json);
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch notifications',
          statusCode: response.statusCode,
          url: url.toString(),
          responseBody: response.body,
          diagnosticHeaders: _diagnosticHeaders(response),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(url.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch notifications: $e');
    }
  }

  /// Marks notifications as read for a user.
  ///
  /// Pass [notificationIds] to mark specific notifications, or omit to
  /// mark all as read. The [authHeaders] parameter allows the caller to
  /// provide pre-built NIP-98 auth headers.
  ///
  /// A `200 OK` response with `success: false` is treated as an API
  /// failure and throws [FunnelcakeApiException] (with `statusCode: 200`
  /// and the server-provided `error` text in the message) so the
  /// repository rollback path fires consistently with the HTTP-error
  /// case.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success
  ///   status, or returns `200` with `success: false`.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<MarkReadResponse> markNotificationsRead({
    required String pubkey,
    List<String>? notificationIds,
    Map<String, String>? authHeaders,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final url = notificationsReadUri(pubkey: pubkey);

    final payload = buildMarkNotificationsReadBody(
      notificationIds: notificationIds,
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              ...buildDivineClientHeaders(appVersion: _appVersion),
              ...?authHeaders,
            },
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = MarkReadResponse.fromJson(json);
        if (!result.success) {
          final detail = result.error;
          throw FunnelcakeApiException(
            message: detail != null && detail.isNotEmpty
                ? 'Mark notifications read rejected by server: $detail'
                : 'Mark notifications read rejected by server',
            statusCode: 200,
            url: url.toString(),
          );
        }
        return result;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to mark notifications as read',
          statusCode: response.statusCode,
          url: url.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(url.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to mark notifications as read: $e');
    }
  }

  /// Disposes of the HTTP client if it was created internally.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

/// Parses a dynamic value to int for view count extraction.
int _parseViewCount(Map<String, dynamic> data) {
  final views =
      data['views'] ??
      data['view_count'] ??
      data['total_views'] ??
      data['unique_views'] ??
      data['unique_viewers'];
  if (views is int) return views;
  if (views is num) return views.toInt();
  if (views is String) return int.tryParse(views) ?? 0;
  return 0;
}
