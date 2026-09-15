// ABOUTME: Confirms Divine-controlled media cleanup after a creator kind-5.
// ABOUTME: Owns sync/poll fallback classification for moderation-service.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/nip98_auth_service.dart';

enum CreatorDeleteEnforcementStatus { confirmed, delayed, failed, unavailable }

class CreatorDeleteEnforcementResult {
  const CreatorDeleteEnforcementResult._({required this.status});

  const CreatorDeleteEnforcementResult.confirmed()
    : this._(status: CreatorDeleteEnforcementStatus.confirmed);

  const CreatorDeleteEnforcementResult.delayed()
    : this._(status: CreatorDeleteEnforcementStatus.delayed);

  const CreatorDeleteEnforcementResult.failed()
    : this._(status: CreatorDeleteEnforcementStatus.failed);

  const CreatorDeleteEnforcementResult.unavailable()
    : this._(status: CreatorDeleteEnforcementStatus.unavailable);

  final CreatorDeleteEnforcementStatus status;
}

class CreatorDeleteEnforcementRepository {
  CreatorDeleteEnforcementRepository({
    required String baseUrl,
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    bool enabled = true,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration pollTimeout = const Duration(seconds: 30),
    bool Function()? shouldBoundSigning,
    Future<void> Function(Duration) delay = Future<void>.delayed,
    void Function(Object, StackTrace)? reportError,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient,
       _nip98AuthService = nip98AuthService,
       _enabled = enabled,
       _requestTimeout = requestTimeout,
       _pollTimeout = pollTimeout,
       _shouldBoundSigning = shouldBoundSigning ?? _alwaysBoundSigning,
       _delay = delay,
       _reportError = reportError;

  static const _initialBackoff = Duration(milliseconds: 500);
  static const _maximumBackoff = Duration(seconds: 5);

  final String _baseUrl;
  final http.Client _httpClient;
  final Nip98AuthService _nip98AuthService;
  final bool _enabled;
  final Duration _requestTimeout;
  final Duration _pollTimeout;
  final bool Function() _shouldBoundSigning;
  final Future<void> Function(Duration) _delay;
  final void Function(Object, StackTrace)? _reportError;

  /// Asks moderation-service to clean up the media a published kind-5 covers.
  ///
  /// [deletionEvent] is that signed event as JSON, with `id` equal to
  /// [kind5Id]. Supplying it lets the service validate the event directly
  /// instead of looking it up on the relay, which can lag publication.
  Future<CreatorDeleteEnforcementResult> enforce(
    String kind5Id, {
    Event? deletionEvent,
  }) async {
    if (!_enabled) return const CreatorDeleteEnforcementResult.unavailable();
    try {
      // Encode once so NIP-98 binds exactly the bytes sent to the service.
      final body = deletionEvent == null
          ? null
          : jsonEncode({'event': deletionEvent.toJson()});
      return await _enforce(kind5Id, body: body);
    } on Object catch (error, stackTrace) {
      _reportError?.call(error, stackTrace);
      return const CreatorDeleteEnforcementResult.delayed();
    }
  }

  Future<CreatorDeleteEnforcementResult> _enforce(
    String kind5Id, {
    String? body,
  }) async {
    final postUri = _uri('/api/delete', kind5Id);
    final firstResponse = await _request(postUri, HttpMethod.post, body: body);
    if (firstResponse?.statusCode == 202) return _poll(kind5Id);
    final result = _terminalPostResult(firstResponse);
    if (result != null) return result;
    return const CreatorDeleteEnforcementResult.delayed();
  }

  CreatorDeleteEnforcementResult? _terminalPostResult(http.Response? response) {
    if (response == null ||
        {401, 404, 429}.contains(response.statusCode) ||
        response.statusCode >= 500) {
      return const CreatorDeleteEnforcementResult.delayed();
    }
    if ({400, 403, 413}.contains(response.statusCode)) {
      _reportContractFailure('POST rejected with ${response.statusCode}');
      return const CreatorDeleteEnforcementResult.failed();
    }
    if (response.statusCode != 200) return null;
    return _decodePostBody(response.body);
  }

  CreatorDeleteEnforcementResult _decodePostBody(String body) {
    final json = _decodeObject(body);
    if (json?['status'] == 'success') {
      return const CreatorDeleteEnforcementResult.confirmed();
    }
    if (json?['status'] == 'failed') {
      return const CreatorDeleteEnforcementResult.failed();
    }
    _reportContractFailure('POST returned an invalid terminal response');
    return const CreatorDeleteEnforcementResult.failed();
  }

  Future<CreatorDeleteEnforcementResult> _poll(String kind5Id) async {
    final uri = _uri('/api/delete-status', kind5Id);
    final stopwatch = Stopwatch()..start();
    var scheduledElapsed = Duration.zero;
    var backoff = _initialBackoff;
    while (_effectiveElapsed(stopwatch, scheduledElapsed) < _pollTimeout) {
      final remaining =
          _pollTimeout - _effectiveElapsed(stopwatch, scheduledElapsed);
      final wait = backoff < remaining ? backoff : remaining;
      await _delay(wait);
      scheduledElapsed += wait;
      final requestBudget =
          _pollTimeout - _effectiveElapsed(stopwatch, scheduledElapsed);
      if (requestBudget <= Duration.zero) break;
      final response = await _request(
        uri,
        HttpMethod.get,
        timeout: requestBudget < _requestTimeout
            ? requestBudget
            : _requestTimeout,
      );
      final result = _pollResult(response);
      if (result != null) return result;
      backoff = Duration(
        milliseconds: (backoff.inMilliseconds * 2).clamp(
          _initialBackoff.inMilliseconds,
          _maximumBackoff.inMilliseconds,
        ),
      );
    }
    return const CreatorDeleteEnforcementResult.delayed();
  }

  Duration _effectiveElapsed(Stopwatch stopwatch, Duration scheduled) =>
      stopwatch.elapsed > scheduled ? stopwatch.elapsed : scheduled;

  CreatorDeleteEnforcementResult? _pollResult(http.Response? response) {
    if (response == null || response.statusCode == 404) return null;
    if (response.statusCode == 401) {
      return const CreatorDeleteEnforcementResult.delayed();
    }
    if ({400, 403}.contains(response.statusCode)) {
      _reportContractFailure('GET rejected with ${response.statusCode}');
      return const CreatorDeleteEnforcementResult.failed();
    }
    if (response.statusCode != 200) return null;
    final json = _decodeObject(response.body);
    final targets = json?['targets'];
    if (targets is! List<Object?> || targets.isEmpty) {
      _reportContractFailure('GET returned no target states');
      return const CreatorDeleteEnforcementResult.failed();
    }
    final statuses = targets
        .whereType<Map<String, dynamic>>()
        .map((target) => target['status'])
        .whereType<String>()
        .toList();
    if (statuses.length != targets.length) {
      _reportContractFailure('GET returned malformed target states');
      return const CreatorDeleteEnforcementResult.failed();
    }
    if (statuses.any((status) => status.startsWith('failed:permanent:'))) {
      return const CreatorDeleteEnforcementResult.failed();
    }
    if (statuses.every((status) => status == 'success')) {
      return const CreatorDeleteEnforcementResult.confirmed();
    }
    return null;
  }

  Future<http.Response?> _request(
    Uri uri,
    HttpMethod method, {
    Duration? timeout,
    String? body,
  }) async {
    final requestBudget = timeout ?? _requestTimeout;
    final stopwatch = Stopwatch()..start();
    try {
      final tokenFuture = _nip98AuthService.createAuthToken(
        url: uri.toString(),
        method: method,
        payload: method == HttpMethod.post ? body ?? '' : null,
      );
      // Keycast signing is an unattended network request and must share the
      // request budget. Human-approved signers remain unbounded so the user
      // can read and approve their prompt without an arbitrary deadline.
      final token = _shouldBoundSigning()
          ? await tokenFuture.timeout(requestBudget)
          : await tokenFuture;
      if (token == null) {
        return http.Response('', 401);
      }
      final remaining = requestBudget - stopwatch.elapsed;
      if (remaining <= Duration.zero) return null;
      final headers = {
        'Authorization': token.authorizationHeader,
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      };
      return await switch (method) {
        HttpMethod.get =>
          _httpClient.get(uri, headers: headers).timeout(remaining),
        HttpMethod.post =>
          _httpClient
              .post(uri, headers: headers, body: body)
              .timeout(remaining),
        _ => throw ArgumentError.value(method, 'method'),
      };
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  Uri _uri(String path, String kind5Id) =>
      Uri.parse('$_baseUrl$path/${Uri.encodeComponent(kind5Id)}');

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  void _reportContractFailure(String message) {
    _reportError?.call(StateError(message), StackTrace.current);
  }

  static bool _alwaysBoundSigning() => true;
}
