// ABOUTME: Freezes multipart bytes on disk before signing and streams that same
// ABOUTME: snapshot on upload, keeping memory bounded for large consent videos.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// A multipart snapshot retained for the lifetime of one submission.
class ConsentUpload {
  ConsentUpload._(
    this._method,
    this._url,
    this._headers,
    this._file,
    this._length,
    this.payloadHash,
    this._directory,
  );

  /// The immutable body and its original multipart content type.
  http.BaseRequest get request => _FileRequest(_method, _url, _file)
    ..headers.addAll(_headers)
    ..contentLength = _length;

  final String _method;
  final Uri _url;
  final Map<String, String> _headers;
  final File _file;
  final int _length;

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
      return ConsentUpload._(
        multipart.method,
        multipart.url,
        Map.of(multipart.headers),
        file,
        await file.length(),
        digest.toString(),
        directory,
      );
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
