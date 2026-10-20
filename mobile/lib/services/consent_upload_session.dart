// ABOUTME: Owns a frozen consent submission across retries and releases it when
// ABOUTME: its screen closes, after any outstanding transport has finished.
import 'package:http/http.dart' as http;
import 'package:openvine/services/consent_upload.dart';

/// Expected lifecycle or retry-input rejection, rather than an app invariant.
class ConsentUploadInvalidatedException implements Exception {
  const ConsentUploadInvalidatedException();
}

/// One form's upload lifetime. A timed-out attempt keeps its transport and body.
class ConsentUploadSession {
  ConsentUpload? _upload;
  Future<http.Response>? _pending;
  bool _disposed = false;
  ({Uri url, String email, String videoPath, String? pubkey})? _binding;

  /// Prevents a retained body being sent to another case or account.
  Future<void> bind({
    required Uri url,
    required String email,
    required String videoPath,
    required String? pubkey,
  }) async {
    if (_disposed) throw const ConsentUploadInvalidatedException();
    final binding = (
      url: url,
      email: email,
      videoPath: videoPath,
      pubkey: pubkey,
    );
    if (_binding != null && _binding != binding) {
      if (_binding!.pubkey != pubkey) await dispose();
      throw const ConsentUploadInvalidatedException();
    }
    _binding = binding;
  }

  /// Case resolved by the repository on the first attempt, retained for retries.
  String? caseId;

  /// Reuses an outstanding transport, or signs and sends the retained snapshot.
  Future<http.Response> send({
    required Future<ConsentUpload> Function() prepare,
    required Future<http.Response> Function(ConsentUpload) transmit,
  }) {
    if (_disposed) throw StateError('Consent submission is closed');
    return _pending ??= _send(prepare, transmit);
  }

  Future<http.Response> _send(
    Future<ConsentUpload> Function() prepare,
    Future<http.Response> Function(ConsentUpload) transmit,
  ) async {
    try {
      final upload = _upload ??= await prepare();
      if (_disposed) throw const ConsentUploadInvalidatedException();
      return await transmit(upload);
    } finally {
      _pending = null;
      if (_disposed) await _discard();
    }
  }

  /// Prevents new attempts; an active transport finishes before its file goes.
  Future<void> dispose() async {
    _disposed = true;
    _binding = null;
    caseId = null;
    if (_pending == null) await _discard();
  }

  Future<void> _discard() async {
    final upload = _upload;
    _upload = null;
    if (upload != null) await upload.dispose();
  }
}
