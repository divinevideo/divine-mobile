// ABOUTME: Fetches a received encrypted video DM and decrypts it for playback.
// ABOUTME: Bounded Blossom download, hash check, AES-GCM decrypt to a temp file.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

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

/// Turns a received encrypted video DM into a locally playable file.
///
/// The ciphertext is a public Blossom blob, so the download carries no viewer
/// auth header. The decryption key and nonce come from the gift-wrapped
/// kind 15 tags and are never logged or persisted by this service. The
/// decrypted plaintext is written only to a message-scoped file under
/// [playbackDirName] in the platform temp directory — never into the media
/// cache — and callers delete it with [deleteClip] when they are done.
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

  /// Temp subdirectory that holds decrypted clips.
  static const String playbackDirName = 'dm_video_playback';

  final Dio _dio;
  final FileEncryption _encryption;
  int _clipSequence = 0;

  /// Temp file name for [message]'s decrypted clip number [sequence].
  ///
  /// Keyed on the full message id plus a per-decrypt [sequence], so the play
  /// page and a concurrent save of the same message never share a path and
  /// one cannot delete the clip the other is still reading. The extension is
  /// taken from the wire MIME type so the native decoder sees a recognisable
  /// container.
  static String clipFileNameFor(DmMessage message, {int sequence = 0}) {
    final fileType = message.fileMetadata?.fileType ?? '';
    final slash = fileType.indexOf('/');
    final raw = slash == -1 ? '' : fileType.substring(slash + 1);
    final extension = raw.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final safeId = message.id.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    return 'dm_video_${safeId}_$sequence.'
        '${extension.isEmpty ? 'mp4' : extension}';
  }

  /// Downloads, verifies, and decrypts [message]'s video, returning the path
  /// of the decrypted temp file.
  ///
  /// Throws a [DmVideoUnavailableException] when the message is not a video,
  /// the ciphertext exceeds [dmVideoMaxCiphertextBytes], or its SHA-256 does
  /// not match the sender's `x` tag; an [ArgumentError] for a non-HTTPS URL;
  /// a [DioException] if the download fails or times out; and whatever
  /// [FileEncryption.decrypt] throws when the ciphertext does not
  /// authenticate. No plaintext file is left behind on any failure.
  @useResult
  Future<String> decryptToFile(DmMessage message) async {
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

    final plaintext = await _encryption.decrypt(
      ciphertext: ciphertext,
      hexKey: metadata.decryptionKey,
      hexNonce: metadata.decryptionNonce,
    );

    final path = await _clipPathFor(
      clipFileNameFor(message, sequence: _clipSequence++),
    );
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(plaintext, flush: true);
    } catch (_) {
      deleteClip(path);
      rethrow;
    }
    return path;
  }

  /// Best-effort synchronous delete of a decrypted clip at [path].
  ///
  /// Never throws: a leftover temp file must not mask the caller's outcome.
  void deleteClip(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (error, stackTrace) {
      Log.warning(
        'Could not delete decrypted video temp file',
        name: 'DmVideoDecryptor',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<String> _clipPathFor(String fileName) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$playbackDirName/$fileName';
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
