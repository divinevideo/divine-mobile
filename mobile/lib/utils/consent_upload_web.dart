// ABOUTME: Web boundary for consent recording, which requires a native camera.
import 'package:http/http.dart' as http;

/// Consent recording and its file upload are available on native platforms.
abstract class ConsentUpload {
  http.BaseRequest get request;
  String get payloadHash;

  static Future<ConsentUpload> prepare(http.MultipartRequest multipart) =>
      throw UnsupportedError('Consent recording requires a native platform');

  Future<void> dispose();
}
