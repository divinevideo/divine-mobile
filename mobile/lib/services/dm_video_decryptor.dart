// ABOUTME: Fetches a received encrypted video DM and decrypts it for playback.
// ABOUTME: Downloads Blossom ciphertext, AES-GCM decrypts, writes a player clip.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:meta/meta.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';

/// Turns a received encrypted video DM into a locally playable [VideoClip].
///
/// The ciphertext is a public Blossom blob, so the download carries no viewer
/// auth header. The decryption key and nonce come from the gift-wrapped
/// kind 15 tags and are never logged or persisted by this service; the
/// decrypted plaintext is written only to the player's own temp path via
/// [VideoClip.memory], never into the media cache or gallery.
class DmVideoDecryptor {
  /// Creates a [DmVideoDecryptor].
  ///
  /// [dio] defaults to a plain client and [encryption] to a real
  /// [FileEncryption]; both exist so tests can inject fakes.
  ///
  /// The receive path fetches a URL chosen by the sender, so the client is
  /// given finite timeouts. A caller-injected client that already set a
  /// timeout keeps it.
  DmVideoDecryptor({Dio? dio, FileEncryption? encryption})
    : _dio = dio ?? Dio(),
      _encryption = encryption ?? FileEncryption() {
    _dio.options
      ..connectTimeout ??= connectTimeout
      ..receiveTimeout ??= receiveTimeout;
  }

  /// Maximum time to establish a connection to the sender's Blossom host.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Maximum idle time between chunks while downloading the ciphertext.
  static const Duration receiveTimeout = Duration(seconds: 30);

  final Dio _dio;
  final FileEncryption _encryption;

  /// Downloads the ciphertext at [url], decrypts it with [key]/[nonce], and
  /// returns a [VideoClip] over the decrypted bytes named [fileName].
  ///
  /// [key] and [nonce] are the hex strings from the sender's kind 15
  /// `decryption-key` / `decryption-nonce` tags.
  ///
  /// [url] comes from the sender's message, so only an `https` URL is fetched;
  /// anything else (including `http`, `file`, or a bare string) is rejected
  /// before any request is made.
  ///
  /// Throws an [ArgumentError] for a non-HTTPS [url], a [DioException] if the
  /// download fails or times out, and whatever [FileEncryption.decrypt] throws
  /// when the ciphertext does not authenticate, so the caller can surface a
  /// received-video failure.
  @useResult
  Future<VideoClip> materialize({
    required String url,
    required String key,
    required String nonce,
    required String fileName,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(url, 'url', 'must be an https URL');
    }

    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Empty response body for encrypted video at $url');
    }

    final plaintext = await _encryption.decrypt(
      ciphertext: data is Uint8List ? data : Uint8List.fromList(data),
      hexKey: key,
      hexNonce: nonce,
    );

    return VideoClip.memory(plaintext, fileName: fileName);
  }
}
