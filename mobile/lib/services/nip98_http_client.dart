// ABOUTME: Learns server time and retries NIP-98 timestamp rejections once.
// ABOUTME: Preserves request bytes and signing identity across the retry.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// HTTP transport for an explicitly configured NIP-98 service origin.
///
/// Only HTTPS responses to authenticated requests can adjust the signing clock.
/// Redirects are not followed: the signature is bound to the original URL.
class Nip98HttpClient extends http.BaseClient {
  Nip98HttpClient({
    required http.Client inner,
    required Nip98AuthService authService,
    required Uri trustedOrigin,
    Duration retryBudget = const Duration(seconds: 15),
    Duration Function()? elapsed,
  }) : _inner = inner,
       _authService = authService,
       _trustedOrigin = trustedOrigin.origin,
       _retryBudget = retryBudget {
    final stopwatch = Stopwatch()..start();
    _elapsed = elapsed ?? () => stopwatch.elapsed;
  }

  final http.Client _inner;
  final Nip98AuthService _authService;
  final String _trustedOrigin;
  final Duration _retryBudget;
  late final Duration Function() _elapsed;
  bool _closed = false;
  // Avoid starting a mutation retry just before the caller's timeout. This
  // reserves room for transport work, without claiming to cancel sent requests.
  static const _minimumRetryTime = Duration(seconds: 2);

  void _logRecovery(String message) {
    Log.info(
      'NIP-98 recovery for $_trustedOrigin: $message',
      name: 'Nip98HttpClient',
      category: LogCategory.system,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final started = _elapsed();
    final authorization = request.headers['Authorization'];
    if (request is! http.Request ||
        request.url.scheme != 'https' ||
        request.url.origin != _trustedOrigin ||
        authorization == null ||
        !authorization.startsWith('Nostr ')) {
      return _inner.send(request);
    }

    // Snapshot before send finalizes the request. These are the exact bytes
    // whose hash the original signer authorized, including an empty body.
    final body = request.bodyBytes.toList();
    final headers = Map<String, String>.of(request.headers);
    request.followRedirects = false;
    final response = await _inner.send(request);
    final learnedTime = _learnTime(request.url, response);
    if (response.statusCode != 401) return response;
    if (!learnedTime) {
      _logRecovery('retry skipped: no usable server Date');
      return response;
    }

    final bytes = await response.stream.toBytes();
    final originalResponse = http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
    if (!_isTimestampRejection(utf8.decode(bytes, allowMalformed: true))) {
      _logRecovery('retry skipped: unrecognized authentication rejection');
      return originalResponse;
    }

    final owner = _signedOwner(authorization);
    final method = HttpMethod.parse(request.method);
    final blocked = _retryBlockedReason(owner, method, _elapsed() - started);
    if (blocked != null) {
      _logRecovery('retry skipped: $blocked');
      return originalResponse;
    }
    final String payload;
    try {
      payload = utf8.decode(body);
    } on FormatException {
      _logRecovery('retry skipped: request body is not UTF-8');
      return originalResponse;
    }
    final token = await _authService.createAuthToken(
      url: request.url.toString(),
      method: method!,
      payload: payload,
      reuseCached: false,
    );
    final blockedAfterSigning = _retryBlockedReason(
      owner,
      method,
      _elapsed() - started,
    );
    if (blockedAfterSigning != null ||
        token == null ||
        token.signedEvent.pubkey != owner) {
      _logRecovery(
        'retry skipped after signing: ${blockedAfterSigning ?? 'signature unavailable or owner mismatch'}',
      );
      return originalResponse;
    }

    _logRecovery('retrying timestamp rejection with corrected server time');
    final retry = http.Request(request.method, request.url)
      ..headers.addAll(headers)
      ..headers['Authorization'] = token.authorizationHeader
      ..bodyBytes = body
      ..followRedirects = false
      ..persistentConnection = request.persistentConnection;
    final retriedResponse = await _inner.send(retry);
    _learnTime(request.url, retriedResponse);
    return retriedResponse;
  }

  String? _retryBlockedReason(
    String? owner,
    HttpMethod? method,
    Duration elapsed,
  ) {
    if (_closed) return 'transport closed';
    if (owner == null) return 'signed owner unavailable';
    if (method == null) return 'unsupported HTTP method';
    if (!_authService.isCurrentOwner(owner)) {
      return 'account changed or signed out';
    }
    if (_retryBudget - elapsed < _minimumRetryTime) {
      return 'insufficient remaining retry budget';
    }
    return null;
  }

  bool _learnTime(Uri uri, http.StreamedResponse response) {
    final date = response.headers['date'];
    // A cached Date describes when a response was produced, not the server's
    // current clock. Never learn from a redirect or a stored response.
    if (date == null ||
        response.isRedirect ||
        (response.statusCode >= 300 && response.statusCode < 400) ||
        (response.headers.containsKey('age') &&
            response.headers['age'] != '0')) {
      return false;
    }
    try {
      _authService.updateServerTime(uri, parseHttpDate(date));
      return true;
    } on FormatException {
      return false;
    }
  }

  bool _isTimestampRejection(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return false;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        return error['code'] == 'unauthorized' &&
            error['message'] ==
                'nostr auth event is expired or from the future';
      }
      // Preserve the known timestamp contract even when an envelope also
      // carries a generic error code. An arbitrary 401 still cannot retry.
      return [error, decoded['message']].whereType<String>().any(
        (message) =>
            message == 'Auth failed: event timestamp is in the future' ||
            RegExp(r'^Auth failed: event expired \(older than \d+s\)$')
                .hasMatch(message),
      );
    } on FormatException {
      return false;
    }
  }

  String? _signedOwner(String authorization) {
    try {
      final event = jsonDecode(
        utf8.decode(base64Decode(authorization.substring(6))),
      );
      return event is Map<String, dynamic> && event['pubkey'] is String
          ? event['pubkey'] as String
          : null;
    } on FormatException {
      return null;
    }
  }

  @override
  void close() {
    _closed = true;
    _inner.close();
  }
}
