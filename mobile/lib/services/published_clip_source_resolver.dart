// ABOUTME: Finds whether a received clip is a video already published on
// ABOUTME: Divine, so the person who published it is credited, not the sender.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

/// Lists videos [pubkey] published before the Unix time [before], newest
/// first, at most [limit].
typedef PublishedVideosByAuthor = Future<List<VideoEvent>> Function({
  required String pubkey,
  required int limit,
  int? before,
});

/// A Divine post whose exact file a received clip turned out to be.
class PublishedClipSource {
  /// Creates a [PublishedClipSource].
  const PublishedClipSource({required this.ownerPubkey, this.video});

  /// Hex pubkey of the account that uploaded the file to Divine's media
  /// server, which is the account that published it.
  final String ownerPubkey;

  /// The published video event, when it could be found. Without it the
  /// owner is still the right person to credit, just without a link to the
  /// post.
  final VideoEvent? video;
}

/// The lookup could not tell whether a file was published.
class PublishedClipSourceLookupException implements Exception {
  /// Creates a [PublishedClipSourceLookupException].
  const PublishedClipSourceLookupException(this.message);

  /// Why the lookup failed.
  final String message;

  @override
  String toString() => 'PublishedClipSourceLookupException: $message';
}

/// Looks a file's SHA-256 up on Divine's media server.
///
/// A published Divine video is signed at publish as a fresh camera capture,
/// so its C2PA credential cannot tell a post from a raw recording. A clip
/// forwarded from a post is the post's exact file, though, and the media
/// server keeps who uploaded every file it holds. Crediting that account
/// instead of the person who forwarded it keeps the credit with whoever
/// filmed it.
class PublishedClipSourceResolver {
  /// Creates a resolver against [mediaServer].
  PublishedClipSourceResolver({
    required Uri mediaServer,
    required PublishedVideosByAuthor videosByAuthor,
    http.Client Function()? httpClientFactory,
  }) : _mediaServer = mediaServer,
       _videosByAuthor = videosByAuthor,
       _httpClientFactory = httpClientFactory ?? http.Client.new;

  /// Upper bound on the provenance request.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// How long after the upload the post is looked for. A post goes out
  /// minutes after its file is uploaded.
  static const Duration publishWindow = Duration(days: 7);

  /// How many of the owner's videos are searched for the matching post.
  static const int searchLimit = 50;

  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  final Uri _mediaServer;
  final PublishedVideosByAuthor _videosByAuthor;
  final http.Client Function() _httpClientFactory;

  /// Returns who published the file with SHA-256 [sha256], or null when the
  /// media server has never held it.
  ///
  /// Throws a [PublishedClipSourceLookupException] when the media server
  /// cannot be asked or gives no usable answer, since crediting the sender
  /// then could credit the wrong person.
  Future<PublishedClipSource?> resolve(String sha256) async {
    final upload = await _fetchUpload(sha256.toLowerCase());
    if (upload == null) return null;
    return PublishedClipSource(
      ownerPubkey: upload.owner,
      video: await _findPost(sha256.toLowerCase(), upload),
    );
  }

  Future<({String owner, int uploadedAt})?> _fetchUpload(String sha256) async {
    final uri = _mediaServer.replace(path: '/$sha256/provenance');
    final client = _httpClientFactory();
    try {
      final response = await client.get(uri).timeout(requestTimeout);
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw PublishedClipSourceLookupException(
          'provenance request returned ${response.statusCode}',
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw const PublishedClipSourceLookupException(
          'provenance response is not an object',
        );
      }
      final owner = body['owner'];
      if (owner == null) return null;
      if (owner is! String || !_hexPubkey.hasMatch(owner)) {
        throw const PublishedClipSourceLookupException(
          'provenance response names no valid owner',
        );
      }
      final authEvent = body['upload_auth_event'];
      final uploadedAt = authEvent is Map ? authEvent['created_at'] : null;
      return (
        owner: owner,
        uploadedAt: uploadedAt is int
            ? uploadedAt
            : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    } on PublishedClipSourceLookupException {
      rethrow;
    } on Exception catch (error) {
      throw PublishedClipSourceLookupException('$error');
    } finally {
      client.close();
    }
  }

  Future<VideoEvent?> _findPost(
    String sha256,
    ({String owner, int uploadedAt}) upload,
  ) async {
    try {
      final videos = await _videosByAuthor(
        pubkey: upload.owner,
        limit: searchLimit,
        before: upload.uploadedAt + publishWindow.inSeconds,
      );
      for (final video in videos) {
        if (video.sha256?.toLowerCase() == sha256) return video;
      }
      return null;
    } on Exception catch (error, stackTrace) {
      // The owner is already known and is the right person to credit; the
      // post only adds a link to it.
      Log.warning(
        'Could not find the post for a published clip',
        name: 'PublishedClipSourceResolver',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
