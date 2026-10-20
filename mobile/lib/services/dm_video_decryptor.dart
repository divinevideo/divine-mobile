// ABOUTME: Fetches a received encrypted video DM and decrypts it.
// ABOUTME: Bounded Blossom download, hash check, AES-GCM decrypt to bytes.

import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:openvine/services/dm_video_encryption.dart';

/// Thrown when a received encrypted video cannot be turned into a clip for a
/// reason other than transport: it is too large, its hash does not match the
/// sender's `x` tag, or the message carries no video metadata.
class DmVideoUnavailableException implements Exception {
  /// Creates a [DmVideoUnavailableException] with a diagnostic [message].
  const DmVideoUnavailableException(this.message);

  /// Diagnostic text. Never contains the decryption key or nonce.
  final String message;

  @override
  String toString() => 'DmVideoUnavailableException: $message';
}

/// Downloads and decrypts a received encrypted video DM.
///
/// The ciphertext is a public Blossom blob, so the download carries no viewer
/// auth header. The decryption key and nonce come from the gift-wrapped
/// kind 15 tags and are never logged or persisted by this service; the
/// plaintext is returned to the caller, `DmVideoStore`, which keeps it in the
/// account's own folder, never in the media cache.
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

  /// Downloads, verifies, and decrypts [message]'s video, returning the
  /// plaintext.
  ///
  /// Throws a [DmVideoUnavailableException] when the message is not a video,
  /// the ciphertext exceeds [dmVideoMaxCiphertextBytes], or its SHA-256 does
  /// not match the sender's `x` tag; an [ArgumentError] for a non-HTTPS URL;
  /// a [DioException] if the download fails or times out; and whatever
  /// [FileEncryption.decrypt] throws when the ciphertext does not
  /// authenticate.
  @useResult
  Future<Uint8List> decrypt(DmMessage message) async {
    final metadata = message.fileMetadata;
    if (metadata == null || !metadata.isVideo) {
      throw const DmVideoUnavailableException('message is not a video');
    }

    final ciphertext = await _download(message.content);

    final expectedHash = metadata.fileHash.toLowerCase();
    if (expectedHash.isNotEmpty &&
        HashUtil.sha256Hash(ciphertext) != expectedHash) {
      throw const DmVideoUnavailableException(
        'ciphertext hash does not match the x tag',
      );
    }

    return _encryption.decrypt(
      ciphertext: ciphertext,
      hexKey: metadata.decryptionKey,
      hexNonce: metadata.decryptionNonce,
    );
  }

  /// Fetches the ciphertext at [url], refusing anything but `https` and
  /// aborting as soon as the body exceeds [dmVideoMaxCiphertextBytes].
  Future<Uint8List> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(url, 'url', 'must be an https URL');
    }

    final cancelToken = CancelToken();
    var oversized = false;
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (received > dmVideoMaxCiphertextBytes ||
              total > dmVideoMaxCiphertextBytes) {
            oversized = true;
            cancelToken.cancel('encrypted video exceeds size limit');
          }
        },
      );
    } on DioException catch (error) {
      if (oversized && CancelToken.isCancel(error)) {
        throw const DmVideoUnavailableException(
          'ciphertext exceeds the size limit',
        );
      }
      rethrow;
    }

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const DmVideoUnavailableException('empty ciphertext body');
    }
    if (data.length > dmVideoMaxCiphertextBytes) {
      throw const DmVideoUnavailableException(
        'ciphertext exceeds the size limit',
      );
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}
