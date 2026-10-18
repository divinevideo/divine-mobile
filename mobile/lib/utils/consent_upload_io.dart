// ABOUTME: Freezes multipart bytes on disk before signing and streams that same
// ABOUTME: snapshot on upload, keeping memory bounded for large consent videos.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// A single-use multipart snapshot owned until its HTTP operation finishes.
class ConsentUpload {
  ConsentUpload._(this.request, this.payloadHash, this._directory);

  /// The immutable body and its original multipart content type.
  final http.BaseRequest request;

  /// SHA-256 of the exact bytes [request] sends, including multipart framing.
  final String payloadHash;
  final Directory _directory;

  /// Spools once so a source-file change while signing cannot change the body.
  static Future<ConsentUpload> prepare(http.MultipartRequest multipart) async {
    final directory = await Directory.systemTemp.createTemp('consent-upload-');
    try {
      final file = File('${directory.path}/body');
      final sink = file.openWrite();
      try {
        await sink.addStream(multipart.finalize());
      } finally {
        await sink.close();
      }
      final digest = await sha256.bind(file.openRead()).first;
      final request = _FileRequest(multipart.method, multipart.url, file)
        ..headers.addAll(multipart.headers)
        ..contentLength = await file.length();
      return ConsentUpload._(request, digest.toString(), directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  /// Deletes only the snapshot; the accepted recording remains retryable.
  Future<void> dispose() => _directory.delete(recursive: true);
}

class _FileRequest extends http.BaseRequest {
  _FileRequest(super.method, super.url, this._file);

  final File _file;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_file.openRead());
  }
}
