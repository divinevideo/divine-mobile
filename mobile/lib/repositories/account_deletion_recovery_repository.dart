// ABOUTME: NIP-98 client for durable immediate-account-deletion attempts.
// ABOUTME: Prepares, submits, resumes, and cancels cross-service deletion work.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/services/nip98_auth_service.dart';

enum AccountDeletionRecoveryStage {
  coordinatorAttempt,
  usernamePreparation,
  coordinatorUsernameConfirmation,
}

class AccountDeletionRecoveryException implements Exception {
  const AccountDeletionRecoveryException(
    this.message, {
    this.code,
    this.stage,
    this.statusCode,
    this.isTransportFailure = false,
    this.indicatesMissingCoordinatorRoute = false,
    this.attempt,
  });

  final String message;
  final String? code;
  final AccountDeletionRecoveryStage? stage;
  final int? statusCode;
  final bool isTransportFailure;
  final bool indicatesMissingCoordinatorRoute;
  final AccountDeletionAttempt? attempt;

  /// Whether only the username release is unsupported by this deployment.
  ///
  /// The coordinator answers `503 username_recovery_unavailable` when an
  /// attempt carries a username and no Name Server is configured. A
  /// username-free deletion succeeds against that same coordinator, so this
  /// failure is user-actionable — unlike every other unavailable answer.
  bool get indicatesUsernameRecoveryUnsupported =>
      code == 'username_recovery_unavailable';

  @override
  String toString() =>
      'AccountDeletionRecoveryException($message, code: $code, '
      'stage: $stage, statusCode: $statusCode, '
      'isTransportFailure: $isTransportFailure, '
      'indicatesMissingCoordinatorRoute: '
      '$indicatesMissingCoordinatorRoute)';
}

class AccountDeletionRecoveryRepository {
  AccountDeletionRecoveryRepository({
    required String baseUrl,
    required String nameServerBaseUrl,
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    required String? Function() currentPubkey,
    Duration timeout = const Duration(seconds: 15),
    Duration retryBaseDelay = const Duration(milliseconds: 500),
    Future<void> Function(Duration) delay = Future<void>.delayed,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient,
       _nameServerBaseUrl = nameServerBaseUrl.endsWith('/')
           ? nameServerBaseUrl.substring(0, nameServerBaseUrl.length - 1)
           : nameServerBaseUrl,
       _nip98AuthService = nip98AuthService,
       _currentPubkey = currentPubkey,
       _timeout = timeout,
       _retryBaseDelay = retryBaseDelay,
       _delay = delay;

  static const _attemptsPath = '/api/account-deletion/attempts';

  final String _baseUrl;
  final http.Client _httpClient;
  final String _nameServerBaseUrl;
  final Nip98AuthService _nip98AuthService;
  final String? Function() _currentPubkey;
  final Duration _timeout;
  final Duration _retryBaseDelay;
  final Future<void> Function(Duration) _delay;

  static const _maxAttempts = 3;
  static const _pollInterval = Duration(seconds: 2);
  static const _cancellationTimeout = Duration(minutes: 2);

  Uri get _attemptsUri => Uri.parse('$_baseUrl$_attemptsPath');
  Uri get _currentAttemptUri => Uri.parse('$_baseUrl$_attemptsPath/current');
  Uri _submitUri(String id) =>
      Uri.parse('$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/submit');
  Uri _statusUri(String id) =>
      Uri.parse('$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/status');
  Uri _cancelUri(String id) =>
      Uri.parse('$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/cancel');
  Uri _usernamePreparedUri(String id) => Uri.parse(
    '$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/username-prepared',
  );
  Uri get _namePrepareUri =>
      Uri.parse('$_nameServerBaseUrl/api/username/release/prepare');

  Future<AccountDeletionAttempt> prepare({String? username}) async {
    final attempt = await _post(
      uri: _attemptsUri,
      body: jsonEncode({'username': ?username}),
      acceptedStatusCodes: const {200, 201},
      stage: AccountDeletionRecoveryStage.coordinatorAttempt,
    );
    if (username == null) return attempt;
    return resumePreparation(attempt);
  }

  /// Completes the username handshake for an existing preparing attempt.
  ///
  /// Recovery must preserve the coordinator's attempt id. Creating another
  /// attempt here would rely on an undocumented POST idempotency contract and
  /// could orphan the attempt returned by `fetchCurrent`.
  Future<AccountDeletionAttempt> resumePreparation(
    AccountDeletionAttempt attempt,
  ) async {
    final username = attempt.username;
    if (username == null) {
      throw AccountDeletionRecoveryException(
        'Preparing username attempt did not include a username',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
        attempt: attempt,
      );
    }
    if (attempt.status == AccountDeletionAttemptStatus.recoverable) {
      return attempt;
    }
    if (attempt.isCancellationInFlight) {
      throw const AccountDeletionRecoveryException(
        'Username preparation cannot resume during cancellation',
        code: 'illegal_transition',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
      );
    }
    if (attempt.status != AccountDeletionAttemptStatus.preparing) {
      throw AccountDeletionRecoveryException(
        'Coordinator prepare returned ${attempt.status.name}',
        stage: AccountDeletionRecoveryStage.coordinatorAttempt,
      );
    }

    final nameBody = jsonEncode({'name': username, 'attempt_id': attempt.id});
    final nameHeaders = await _authHeaders(
      uri: _namePrepareUri,
      method: HttpMethod.post,
      payload: nameBody,
      stage: AccountDeletionRecoveryStage.usernamePreparation,
    );
    final http.Response nameResponse;
    try {
      nameResponse = await _sendWithRetry(
        () => _httpClient
            .post(_namePrepareUri, headers: nameHeaders, body: nameBody)
            .timeout(_timeout),
      );
    } on TimeoutException {
      throw const AccountDeletionRecoveryException(
        'Username preparation timed out',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
        isTransportFailure: true,
      );
    } on http.ClientException {
      throw const AccountDeletionRecoveryException(
        'Username preparation request failed',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
        isTransportFailure: true,
      );
    } on IOException {
      throw const AccountDeletionRecoveryException(
        'Username preparation request failed',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
        isTransportFailure: true,
      );
    }
    if (nameResponse.statusCode != 200) {
      throw _exceptionFromResponse(
        nameResponse,
        'Username preparation failed',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
      );
    }
    final Map<String, dynamic> nameJson;
    try {
      nameJson = jsonDecode(nameResponse.body) as Map<String, dynamic>;
    } on Object {
      throw const AccountDeletionRecoveryException(
        'Username preparation returned an invalid response',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
      );
    }
    final expiresAt = (nameJson['expires_at'] as num?)?.toInt();
    final returnedAttemptId = nameJson['attempt_id'] as String?;
    if (expiresAt == null || returnedAttemptId != attempt.id) {
      throw const AccountDeletionRecoveryException(
        'Username preparation returned an invalid response',
        stage: AccountDeletionRecoveryStage.usernamePreparation,
      );
    }
    return _post(
      uri: _usernamePreparedUri(attempt.id),
      body: jsonEncode({
        'attempt_id': attempt.id,
        'username': username,
        'expires_at': expiresAt,
      }),
      acceptedStatusCodes: const {200},
      stage: AccountDeletionRecoveryStage.coordinatorUsernameConfirmation,
    );
  }

  Future<AccountDeletionAttempt?> fetchCurrent() async {
    final uri = _currentAttemptUri;
    final headers = await _authHeaders(uri: uri, method: HttpMethod.get);
    try {
      final response = await _sendWithRetry(
        () => _httpClient.get(uri, headers: headers).timeout(_timeout),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw _exceptionFromResponse(response, 'Status lookup failed');
      }
      return _decodeAttempt(response.body);
    } on TimeoutException {
      throw const AccountDeletionRecoveryException(
        'Status lookup timed out',
        isTransportFailure: true,
      );
    } on http.ClientException {
      throw const AccountDeletionRecoveryException(
        'Status lookup request failed',
        isTransportFailure: true,
      );
    } on IOException {
      throw const AccountDeletionRecoveryException(
        'Status lookup request failed',
        isTransportFailure: true,
      );
    }
  }

  /// Reads a submitted attempt after its signer has been removed.
  Future<AccountDeletionAttempt> fetchStatus({
    required String attemptId,
    required String pubkeyHex,
  }) async {
    final uri = _statusUri(attemptId);
    try {
      final response = await _sendWithRetry(
        () => _httpClient
            .get(
              uri,
              headers: {
                'Accept': 'application/json',
                'X-Account-Deletion-Pubkey': pubkeyHex,
              },
            )
            .timeout(_timeout),
      );
      if (response.statusCode != 200) {
        throw _exceptionFromResponse(response, 'Deletion status lookup failed');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AccountDeletionAttempt.fromJson({...json, 'operation': 'none'});
    } on TimeoutException {
      throw const AccountDeletionRecoveryException(
        'Deletion status lookup timed out',
        isTransportFailure: true,
      );
    } on http.ClientException {
      throw const AccountDeletionRecoveryException(
        'Deletion status lookup failed',
        isTransportFailure: true,
      );
    } on IOException {
      throw const AccountDeletionRecoveryException(
        'Deletion status lookup failed',
        isTransportFailure: true,
      );
    }
  }

  Future<AccountDeletionAttempt> submit({
    required String attemptId,
    required String vanishEventId,
  }) async {
    return _post(
      uri: _submitUri(attemptId),
      body: jsonEncode({'vanish_event_id': vanishEventId}),
      acceptedStatusCodes: const {200, 202},
    );
  }

  Future<AccountDeletionAttempt> cancel({required String attemptId}) async {
    return _post(
      uri: _cancelUri(attemptId),
      body: '{}',
      acceptedStatusCodes: const {200, 202},
    );
  }

  /// Cancels [attemptId] and waits for the coordinator's terminal answer.
  ///
  /// The coordinator answers `202` while another request is still rolling the
  /// username back, so the cancellation is only known once the attempt reports
  /// `cancelled`. The wait is bounded: an attempt the coordinator never moves
  /// out of `cancelling` sits there until its own 24-hour deadline, and an
  /// unbounded wait would keep the caller polling — and the caller's spinner
  /// spinning — for that entire day.
  Future<AccountDeletionAttempt> cancelAndWait({
    required String attemptId,
    Duration timeout = _cancellationTimeout,
  }) async {
    var attempt = await cancel(attemptId: attemptId);
    var waited = Duration.zero;
    while (true) {
      if (attempt.status == AccountDeletionAttemptStatus.cancelled) {
        return attempt;
      }
      if (!attempt.isCancellationInFlight) {
        throw const AccountDeletionRecoveryException(
          'Account deletion cancellation ended in an invalid state',
        );
      }
      if (waited >= timeout) {
        throw const AccountDeletionRecoveryException(
          'Account deletion cancellation did not finish in time',
        );
      }
      await _delay(_pollInterval);
      waited += _pollInterval;
      final current = await fetchCurrent();
      if (current == null || current.id != attemptId) {
        throw const AccountDeletionRecoveryException(
          'Cancellation status did not match the account deletion attempt',
        );
      }
      attempt = current;
    }
  }

  Future<AccountDeletionAttempt> _post({
    required Uri uri,
    required String body,
    required Set<int> acceptedStatusCodes,
    AccountDeletionRecoveryStage? stage,
  }) async {
    final headers = await _authHeaders(
      uri: uri,
      method: HttpMethod.post,
      payload: body,
      stage: stage,
    );
    try {
      final response = await _sendWithRetry(
        () => _httpClient
            .post(uri, headers: headers, body: body)
            .timeout(_timeout),
      );
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        throw _exceptionFromResponse(
          response,
          'Deletion attempt request failed',
          stage: stage,
        );
      }
      return _decodeAttempt(response.body);
    } on TimeoutException {
      throw AccountDeletionRecoveryException(
        'Deletion attempt request timed out',
        stage: stage,
        isTransportFailure: true,
      );
    } on http.ClientException {
      throw AccountDeletionRecoveryException(
        'Deletion attempt request failed',
        stage: stage,
        isTransportFailure: true,
      );
    } on IOException {
      throw AccountDeletionRecoveryException(
        'Deletion attempt request failed',
        stage: stage,
        isTransportFailure: true,
      );
    }
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final response = await send();
      if (!_isRetryable(response.statusCode) || attempt == _maxAttempts) {
        return response;
      }
      await _delay(_retryBaseDelay * (1 << (attempt - 1)));
    }
    throw StateError('Retry loop completed without a response');
  }

  bool _isRetryable(int statusCode) =>
      statusCode == 429 || (statusCode >= 500 && statusCode <= 599);

  AccountDeletionRecoveryException _exceptionFromResponse(
    http.Response response,
    String fallback, {
    AccountDeletionRecoveryStage? stage,
  }) {
    String? code;
    var hasParseableResponseBody = false;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      hasParseableResponseBody = true;
      code = (json['failure_code'] ?? json['code']) as String?;
    } on Object {
      // The status code and localized client fallback remain authoritative.
    }
    return AccountDeletionRecoveryException(
      '$fallback (${response.statusCode})',
      code: code,
      stage: stage,
      statusCode: response.statusCode,
      indicatesMissingCoordinatorRoute:
          response.statusCode == 404 && !hasParseableResponseBody,
    );
  }

  Future<Map<String, String>> _authHeaders({
    required Uri uri,
    required HttpMethod method,
    String? payload,
    AccountDeletionRecoveryStage? stage,
  }) async {
    final token = await _nip98AuthService.createAuthToken(
      url: uri.toString(),
      method: method,
      payload: payload,
    );
    if (token == null) {
      throw AccountDeletionRecoveryException(
        'Could not authorize deletion attempt request',
        stage: stage,
      );
    }
    final currentPubkey = _currentPubkey();
    if (currentPubkey == null || token.signedEvent.pubkey != currentPubkey) {
      throw AccountDeletionRecoveryException(
        'Deletion attempt authorization targeted the wrong account',
        stage: stage,
      );
    }
    return {
      'Accept': 'application/json',
      'Authorization': token.authorizationHeader,
      if (payload != null) 'Content-Type': 'application/json',
    };
  }

  AccountDeletionAttempt _decodeAttempt(String body) {
    try {
      return AccountDeletionAttempt.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw AccountDeletionRecoveryException(
        'Invalid deletion attempt response: $error',
      );
    }
  }
}
