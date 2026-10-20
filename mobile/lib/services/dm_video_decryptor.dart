// ABOUTME: Fetches a received encrypted video DM and decrypts it.
// ABOUTME: Bounded Blossom download, hash check, AES-GCM decrypt to bytes.

import 'dart:async';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
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

  static final RegExp _hexKey = RegExp(r'^[0-9a-fA-F]{64}$');
  static final RegExp _hexNonce = RegExp(r'^[0-9a-fA-F]{24}$');

  final Dio _dio;
  final FileEncryption _encryption;

  /// Downloads, verifies, and decrypts [message]'s video, returning the
  /// plaintext.
  ///
  /// The download is cut off past [maxBytes] of ciphertext, which defaults to
  /// [dmVideoMaxCiphertextBytes], and, when [timeLimit] is given, once it has
  /// run that long; a host can otherwise trickle bytes forever.
  ///
  /// Throws a [DmVideoUnavailableException] when the message is not a video
  /// or carries a malformed key or nonce (checked before any download, and
  /// never quoted), the ciphertext exceeds [maxBytes], the download outlasts
  /// [timeLimit], or
  /// the ciphertext's SHA-256 does not match the sender's `x` tag; also when
  /// the URL is not HTTPS or the download fails or stalls, naming the kind of
  /// failure and any HTTP status but never the address, which links the
  /// sender's upload to this recipient. Throws whatever
  /// [FileEncryption.decrypt] throws when the ciphertext does not
  /// authenticate.
  @useResult
  Future<Uint8List> decrypt(
    DmMessage message, {
    int? maxBytes,
    Duration? timeLimit,
  }) async {
    final metadata = message.fileMetadata;
    if (metadata == null || !metadata.isVideo) {
      throw const DmVideoUnavailableException('message is not a video');
    }
    if (!_hexKey.hasMatch(metadata.decryptionKey) ||
        !_hexNonce.hasMatch(metadata.decryptionNonce)) {
      throw const DmVideoUnavailableException(
        'the message carries a malformed key or nonce',
      );
    }

    final ciphertext = await _download(
      message.content,
      maxBytes: maxBytes ?? dmVideoMaxCiphertextBytes,
      timeLimit: timeLimit,
    );

    return compute(_verifyAndDecrypt, (
      ciphertext: ciphertext,
      expectedHash: metadata.fileHash.toLowerCase(),
      hexKey: metadata.decryptionKey,
      hexNonce: metadata.decryptionNonce,
      encryption: _encryption,
    ));
  }

  /// Fetches the ciphertext at [url], refusing anything but `https` and
  /// aborting as soon as the body exceeds [maxBytes] or the download outlasts
  /// [timeLimit].
  Future<Uint8List> _download(
    String url, {
    required int maxBytes,
    Duration? timeLimit,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const DmVideoUnavailableException('the video is not on HTTPS');
    }

    final cancelToken = CancelToken();
    var oversized = false;
    var outlasted = false;
    final deadline = timeLimit == null
        ? null
        : Timer(timeLimit, () {
            outlasted = true;
            cancelToken.cancel('encrypted video download took too long');
          });
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (received > maxBytes || total > maxBytes) {
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
      if (outlasted && CancelToken.isCancel(error)) {
        throw const DmVideoUnavailableException(
          'the download outlasted its time limit',
        );
      }
      // Dio's text carries the nested error, which can quote the URL or its
      // host: keep the kind of failure and the status only.
      final status = error.response?.statusCode;
      throw DmVideoUnavailableException(
        'the download failed: ${error.type.name}'
        '${status == null ? '' : ', HTTP $status'}',
      );
    } finally {
      deadline?.cancel();
    }

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const DmVideoUnavailableException('empty ciphertext body');
    }
    if (data.length > maxBytes) {
      throw const DmVideoUnavailableException(
        'ciphertext exceeds the size limit',
      );
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}

/// What [_verifyAndDecrypt] needs, sent to the isolate it runs in.
typedef _DecryptJob = ({
  Uint8List ciphertext,
  String expectedHash,
  String hexKey,
  String hexNonce,
  FileEncryption encryption,
});

/// Checks [job]'s ciphertext against the sender's hash and decrypts it. Run
/// off the UI isolate: both are pure Dart, about a second for 20 MB even on a
/// laptop, and a card can now start one without a tap.
Future<Uint8List> _verifyAndDecrypt(_DecryptJob job) async {
  if (job.expectedHash.isNotEmpty &&
      HashUtil.sha256Hash(job.ciphertext) != job.expectedHash) {
    throw const DmVideoUnavailableException(
      'ciphertext hash does not match the x tag',
    );
  }
  return job.encryption.decrypt(
    ciphertext: job.ciphertext,
    hexKey: job.hexKey,
    hexNonce: job.hexNonce,
  );
}
