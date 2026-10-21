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

/// Thrown when a received encrypted video cannot be kept or played: it is too
/// large, its hash does not match the sender's `x` tag, or the message
/// carries no video metadata; or, with [mayPass], the network or the storage
/// failed.
class DmVideoUnavailableException implements Exception {
  /// Creates a [DmVideoUnavailableException] with a diagnostic [message].
  const DmVideoUnavailableException(this.message, {this.mayPass = false});

  /// Diagnostic text. Never contains the decryption key or nonce.
  final String message;

  /// Whether trying again later may work: the network or the storage
  /// failed, not the video itself.
  final bool mayPass;

  @override
  String toString() => 'DmVideoUnavailableException: $message';
}

/// Thrown when a download stopped at a size or time limit its caller set,
/// which a download without that limit may not reach.
class DmVideoLimitException extends DmVideoUnavailableException {
  /// Creates a [DmVideoLimitException] with a diagnostic [message].
  const DmVideoLimitException(super.message, {super.mayPass});
}

/// Thrown when a download stopped because its caller no longer wanted it,
/// which says nothing about the video.
class DmVideoWithdrawnException extends DmVideoUnavailableException {
  /// Creates a [DmVideoWithdrawnException].
  const DmVideoWithdrawnException()
    : super('the download was no longer wanted', mayPass: true);
}

/// Thrown when a video's message was retracted by its sender or removed with
/// its conversation: its video is neither fetched nor handed out.
class DmVideoGoneException extends DmVideoUnavailableException {
  /// Creates a [DmVideoGoneException].
  const DmVideoGoneException() : super('the message was retracted or removed');

  @override
  String toString() => 'DmVideoGoneException: $message';
}

/// Thrown when a kept video or frame could not be written to the device.
/// Trying again later may work, once there is room; downloading the video
/// again at once would only fail the same way.
class DmVideoStorageException extends DmVideoUnavailableException {
  /// Creates a [DmVideoStorageException] with a diagnostic [message].
  const DmVideoStorageException(super.message) : super(mayPass: true);
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
  DmVideoDecryptor({
    Dio? dio,
    FileEncryption? encryption,
    Duration wantedCheckInterval = const Duration(seconds: 1),
  }) : _dio = dio ?? Dio(),
       _encryption = encryption ?? FileEncryption(),
       _wantedCheckInterval = wantedCheckInterval {
    _dio.options
      ..connectTimeout ??= connectTimeout
      ..receiveTimeout ??= receiveTimeout;
  }

  /// Maximum time to establish a connection to the sender's Blossom host.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Maximum idle time between chunks while downloading the ciphertext.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Redirects followed to reach the ciphertext, each checked for HTTPS.
  static const int maxRedirects = 5;

  static const Set<int> _redirectStatuses = {301, 302, 303, 307, 308};

  static final RegExp _hexKey = RegExp(r'^[0-9a-fA-F]{64}$');
  static final RegExp _hexNonce = RegExp(r'^[0-9a-fA-F]{24}$');

  final Dio _dio;
  final FileEncryption _encryption;

  /// How often a download whose caller may stop wanting it asks again, so a
  /// stalled one, which reports no progress, still stops.
  final Duration _wantedCheckInterval;

  /// Downloads, verifies, and decrypts [message]'s video, returning the
  /// plaintext.
  ///
  /// The download is cut off past [maxBytes] of ciphertext, which defaults to
  /// [dmVideoMaxCiphertextBytes], and, when [timeLimit] is given, once it has
  /// run that long; a host can otherwise trickle bytes forever. Once
  /// [limitsApply] says no, as when someone taps play on the video, the
  /// download carries on as if neither limit was given. When [stillWanted] is
  /// given it is asked as the download progresses, and the download stops
  /// once it says no.
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
    bool Function()? limitsApply,
    bool Function()? stillWanted,
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
      limitsApply: limitsApply,
      stillWanted: stillWanted,
    );
    if (stillWanted != null && !stillWanted()) {
      throw const DmVideoWithdrawnException();
    }

    return compute(_verifyAndDecrypt, (
      ciphertext: ciphertext,
      expectedHash: metadata.fileHash.toLowerCase(),
      hexKey: metadata.decryptionKey,
      hexNonce: metadata.decryptionNonce,
      encryption: _encryption,
    ));
  }

  /// Fetches the ciphertext at [url], refusing anything but `https`, on the
  /// first request and on every redirect, and aborting as soon as the body
  /// exceeds [maxBytes] or the download outlasts [timeLimit], while
  /// [limitsApply] says those apply.
  Future<Uint8List> _download(
    String url, {
    required int maxBytes,
    Duration? timeLimit,
    bool Function()? limitsApply,
    bool Function()? stillWanted,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isHttps(uri)) {
      throw const DmVideoUnavailableException('the video is not on HTTPS');
    }

    bool limited() => limitsApply?.call() ?? true;
    int sizeLimit() => limited() ? maxBytes : dmVideoMaxCiphertextBytes;
    final cancelToken = CancelToken();
    // The size the download had reached, or announced, past its limit.
    int? oversizedAt;
    var outlasted = false;
    var unwanted = false;
    final deadline = timeLimit == null
        ? null
        : Timer(timeLimit, () {
            if (!limited()) return;
            outlasted = true;
            cancelToken.cancel('encrypted video download took too long');
          });
    final wantedCheck = stillWanted == null
        ? null
        : Timer.periodic(_wantedCheckInterval, (_) {
            if (stillWanted()) return;
            unwanted = true;
            cancelToken.cancel('encrypted video no longer wanted');
          });
    late final Response<List<int>> response;
    // Redirect bodies count too, so a chain of redirects cannot multiply it.
    var consumed = 0;
    try {
      var target = url;
      for (var redirects = 0; ; redirects++) {
        final hop = await _dio.get<List<int>>(
          target,
          options: Options(
            responseType: ResponseType.bytes,
            // The client would follow a redirect to plain HTTP unchecked, so
            // each hop is followed, and checked, here.
            followRedirects: false,
            validateStatus: (status) => status != null && status < 400,
          ),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            final limit = sizeLimit();
            if (consumed + received > limit || consumed + total > limit) {
              oversizedAt = consumed + (total > received ? total : received);
              cancelToken.cancel('encrypted video exceeds size limit');
            } else if (stillWanted != null && !stillWanted()) {
              unwanted = true;
              cancelToken.cancel('encrypted video no longer wanted');
            }
          },
        );
        if (!_redirectStatuses.contains(hop.statusCode)) {
          response = hop;
          break;
        }
        consumed += hop.data?.length ?? 0;
        if (redirects == maxRedirects) {
          throw const DmVideoUnavailableException(
            'the video redirected too many times',
          );
        }
        final location = Uri.tryParse(hop.headers.value('location') ?? '');
        final resolved = location == null
            ? null
            : Uri.parse(target).resolveUri(location);
        if (resolved == null || !_isHttps(resolved)) {
          throw const DmVideoUnavailableException(
            'the video redirected away from HTTPS',
          );
        }
        target = resolved.toString();
      }
    } on DioException catch (error) {
      final reached = oversizedAt;
      if (reached != null && CancelToken.isCancel(error)) {
        throw _tooLarge(reached);
      }
      if (unwanted && CancelToken.isCancel(error)) {
        throw const DmVideoWithdrawnException();
      }
      if (outlasted && CancelToken.isCancel(error)) {
        throw const DmVideoLimitException(
          'the download outlasted its time limit',
          mayPass: true,
        );
      }
      // Dio's text carries the nested error, which can quote the URL or its
      // host: keep the kind of failure and the status only.
      final status = error.response?.statusCode;
      // A blob that is missing or refused stays so; a timeout, a busy server
      // or a dropped connection may pass.
      final lasting =
          status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429;
      throw DmVideoUnavailableException(
        'the download failed: ${error.type.name}'
        '${status == null ? '' : ', HTTP $status'}',
        mayPass: !lasting,
      );
    } finally {
      deadline?.cancel();
      wantedCheck?.cancel();
    }

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const DmVideoUnavailableException('empty ciphertext body');
    }
    if (consumed + data.length > sizeLimit()) {
      throw _tooLarge(consumed + data.length);
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  static bool _isHttps(Uri uri) => uri.scheme == 'https' && uri.host.isNotEmpty;

  /// The failure for a download stopped past its size limit at [bytes]: one
  /// that still fits the largest a video can be passed only its caller's.
  static DmVideoUnavailableException _tooLarge(int bytes) =>
      bytes <= dmVideoMaxCiphertextBytes
      ? const DmVideoLimitException('ciphertext exceeds the size limit')
      : const DmVideoUnavailableException('ciphertext exceeds the size limit');
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
