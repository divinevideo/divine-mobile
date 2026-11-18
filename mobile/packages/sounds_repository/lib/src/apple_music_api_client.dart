// ABOUTME: HTTP client for the Apple Music API catalog: the top songs chart
// ABOUTME: and song search. Needs a MusicKit developer token.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A song as the Apple Music catalog lists it.
@immutable
class AppleMusicSong {
  /// Creates an [AppleMusicSong].
  const AppleMusicSong({
    required this.id,
    required this.name,
    required this.artistName,
    required this.url,
    this.previewUrl,
    this.artworkUrlTemplate,
    this.genreNames = const [],
  });

  /// The catalog's id for the song.
  final String id;

  /// The song's title.
  final String name;

  /// The artist as the catalog credits them.
  final String artistName;

  /// The song's page on Apple Music.
  final String url;

  /// The audio preview the catalog offers, or `null` when it offers none.
  final String? previewUrl;

  /// The artwork URL, with `{w}` and `{h}` where the size goes.
  final String? artworkUrlTemplate;

  /// The song's genres, such as `Pop` and `Music`.
  final List<String> genreNames;

  /// The artwork [size] pixels wide and high, or `null` without artwork.
  String? artworkUrl(int size) =>
      artworkUrlTemplate?.replaceAll('{w}', '$size').replaceAll('{h}', '$size');
}

/// Thrown by [AppleMusicApiClient] when a request fails: no connection, a
/// timeout, a response that is not the JSON the API documents, or a status
/// outside 2xx.
class AppleMusicApiException implements Exception {
  /// Creates an [AppleMusicApiException].
  const AppleMusicApiException(this.message, {this.statusCode});

  /// What failed.
  final String message;

  /// The HTTP status the API answered with, or `null` when it did not answer.
  /// `401` means the developer token is missing, malformed or expired.
  final int? statusCode;

  @override
  String toString() =>
      'AppleMusicApiException: $message (${statusCode ?? 'no status'})';
}

/// Reads songs from the Apple Music catalog.
///
/// Catalog requests are authorized by the developer token alone, so nothing
/// here identifies the person searching.
class AppleMusicApiClient {
  /// Creates an [AppleMusicApiClient].
  ///
  /// [developerToken] is the signed MusicKit token. [httpClient] and
  /// [timeout] can be replaced in tests.
  AppleMusicApiClient({
    required String developerToken,
    http.Client? httpClient,
    Duration? timeout,
  }) : _developerToken = developerToken,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout ?? const Duration(seconds: 12);

  /// The most songs one chart request returns.
  static const maxChartLimit = 200;

  /// The most songs one search request returns.
  static const maxSearchLimit = 25;

  static const _host = 'api.music.apple.com';

  final String _developerToken;
  final http.Client _httpClient;
  final Duration _timeout;

  /// The most played songs in [storefront], a two-letter country code, most
  /// played first.
  ///
  /// Throws [AppleMusicApiException] when the request fails.
  Future<List<AppleMusicSong>> fetchTopSongs({
    required String storefront,
    int limit = 50,
  }) async {
    final decoded = await _get(
      storefront: storefront,
      resource: 'charts',
      queryParameters: {
        'types': 'songs',
        'limit': '${limit.clamp(1, maxChartLimit)}',
      },
    );
    // One entry per chart; without a `chart` parameter the API answers with
    // the most played.
    final charts = _results(decoded)['songs'];
    if (charts is! List) return const [];
    return _songs(
      charts.whereType<Map<String, dynamic>>().firstOrNull?['data'],
    );
  }

  /// The songs in [storefront] that match [term], a title, an artist or both,
  /// best match first.
  ///
  /// Throws [AppleMusicApiException] when [term] is blank or the request
  /// fails.
  Future<List<AppleMusicSong>> searchSongs({
    required String storefront,
    required String term,
    int limit = maxSearchLimit,
  }) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      throw const AppleMusicApiException('Search term is required');
    }
    final decoded = await _get(
      storefront: storefront,
      resource: 'search',
      queryParameters: {
        'term': trimmed,
        'types': 'songs',
        'limit': '${limit.clamp(1, maxSearchLimit)}',
      },
    );
    // A search nothing matches answers without a `songs` entry.
    final songs = _results(decoded)['songs'];
    return _songs(songs is Map<String, dynamic> ? songs['data'] : null);
  }

  /// Closes the underlying HTTP client.
  void close() => _httpClient.close();

  Future<Map<String, dynamic>> _get({
    required String storefront,
    required String resource,
    required Map<String, String> queryParameters,
  }) async {
    final uri = Uri(
      scheme: 'https',
      host: _host,
      pathSegments: ['v1', 'catalog', storefront, resource],
      queryParameters: queryParameters,
    );
    final http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_developerToken',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AppleMusicApiException('Apple Music request timed out');
    } on http.ClientException catch (error) {
      throw AppleMusicApiException('Apple Music network error: $error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleMusicApiException(
        'Apple Music request failed',
        statusCode: response.statusCode,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AppleMusicApiException(
        'Apple Music response was not valid JSON',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw AppleMusicApiException(
        'Apple Music response was invalid',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Map<String, dynamic> _results(Map<String, dynamic> decoded) {
    final results = decoded['results'];
    return results is Map<String, dynamic> ? results : const {};
  }

  /// The songs in [data], leaving out any row without the fields a song
  /// always has: the catalog is not ours, and one odd row should not cost the
  /// whole list.
  List<AppleMusicSong> _songs(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map<String, dynamic>>())
        ?_songFromJson(row),
    ];
  }

  AppleMusicSong? _songFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final attributes = json['attributes'];
    if (id is! String || attributes is! Map<String, dynamic>) return null;
    final name = attributes['name'];
    final artistName = attributes['artistName'];
    final url = attributes['url'];
    if (name is! String || artistName is! String || url is! String) {
      return null;
    }
    final artwork = attributes['artwork'];
    final artworkUrl = artwork is Map<String, dynamic> ? artwork['url'] : null;
    final previews = attributes['previews'];
    final previewUrl = previews is List
        ? previews
              .whereType<Map<String, dynamic>>()
              .map((preview) => preview['url'])
              .whereType<String>()
              .firstOrNull
        : null;
    final genreNames = attributes['genreNames'];
    return AppleMusicSong(
      id: id,
      name: name,
      artistName: artistName,
      url: url,
      previewUrl: previewUrl,
      artworkUrlTemplate: artworkUrl is String ? artworkUrl : null,
      genreNames: genreNames is List
          ? List.unmodifiable(genreNames.whereType<String>())
          : const [],
    );
  }
}
