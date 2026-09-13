// ABOUTME: Response models for headless authentication API
// ABOUTME: Supports native login/register flows without browser redirects

/// Typed classification of a failed `POST /api/headless/register`.
enum KeycastRegisterFailure {
  emailAlreadyRegistered,
  invalidEmail,
  rateLimited,
  server,
  network,
  unknown,
}

/// Result from POST /api/headless/register
class HeadlessRegisterResult {
  HeadlessRegisterResult({
    required this.success,
    required this.pubkey,
    required this.verificationRequired,
    this.deviceCode,
    this.email,
    this.errorCode,
    this.errorDescription,
  });

  factory HeadlessRegisterResult.fromJson(Map<String, dynamic> json) {
    return HeadlessRegisterResult(
      success: json['success'] as bool? ?? false,
      pubkey: json['pubkey'] as String? ?? '',
      verificationRequired: json['verification_required'] as bool? ?? true,
      deviceCode: json['device_code'] as String?,
      email: json['email'] as String?,
      errorCode: json['error'] as String?,
      errorDescription:
          json['error_description'] as String? ?? json['message'] as String?,
    );
  }

  factory HeadlessRegisterResult.error(String message, {String? code}) {
    return HeadlessRegisterResult(
      success: false,
      pubkey: '',
      verificationRequired: false,
      errorCode: code ?? 'client_error',
      errorDescription: message,
    );
  }
  final bool success;
  final String pubkey;
  final bool verificationRequired;
  final String? deviceCode;
  final String? email;

  /// Machine-readable server or client-generated failure code.
  final String? errorCode;

  /// Human-readable error description from server
  final String? errorDescription;

  /// Typed classification of the failure, for handling outside the client.
  KeycastRegisterFailure get failure {
    switch (errorCode) {
      case 'CONFLICT':
      case 'EMAIL_ALREADY_EXISTS':
        return KeycastRegisterFailure.emailAlreadyRegistered;
      case 'INVALID_EMAIL':
        return KeycastRegisterFailure.invalidEmail;
      case 'rate_limited':
        return KeycastRegisterFailure.rateLimited;
      case 'server_error':
        return KeycastRegisterFailure.server;
      case 'connection_error':
      case 'network_error':
        return KeycastRegisterFailure.network;
      default:
        return KeycastRegisterFailure.unknown;
    }
  }
}

/// Typed classification of a failed `POST /api/headless/login`.
///
/// Maps the server's machine-readable `code` (and the client-synthesized
/// transport codes) to a small set the UI can localize. Deliberately login-
/// specific; [KeycastAuthFailure] models the register/poll taxonomy instead.
enum KeycastLoginFailure {
  /// Wrong email/password OR no such account — the server returns an identical
  /// 401 for both, so this value must never imply the account exists.
  invalidCredentials,

  /// Account exists but its email has not been verified (HTTP 403).
  emailNotVerified,

  /// The submitted email was malformed (HTTP 400).
  invalidEmail,

  /// Too many sign-in attempts have been made for now (HTTP 429).
  rateLimited,

  /// Transport failure (timeout / no connection) before a server verdict.
  network,

  /// Any other server or client error.
  unknown,
}

/// Result from POST /api/headless/login
class HeadlessLoginResult {
  HeadlessLoginResult({
    required this.success,
    this.code,
    this.pubkey,
    this.state,
    this.errorCode,
    this.errorDescription,
  });

  factory HeadlessLoginResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    // `json['code']` is the OAuth authorization code on success and the
    // machine failure code on error — disambiguate on `success`.
    final rawCode = json['code'] as String?;
    return HeadlessLoginResult(
      success: success,
      code: success ? rawCode : null,
      pubkey: json['pubkey'] as String?,
      state: json['state'] as String?,
      errorCode: success ? null : rawCode,
      errorDescription:
          json['error'] as String? ?? json['error_description'] as String?,
    );
  }

  factory HeadlessLoginResult.error(String message, {String? code}) {
    return HeadlessLoginResult(
      success: false,
      errorCode: code ?? 'client_error',
      errorDescription: message,
    );
  }
  final bool success;

  /// OAuth authorization code — present only on success (`json['code']`).
  final String? code;
  final String? pubkey;
  final String? state;

  /// Machine-readable failure code (e.g. `INVALID_CREDENTIALS`), failure only.
  ///
  /// Keycast sends this in `json['code']` on the error path and the human
  /// message in `json['error']` — the two must not be conflated.
  final String? errorCode;

  /// Human-readable error message from the server (`json['error']`).
  final String? errorDescription;

  /// Typed classification of the failure, for localization in the UI layer.
  KeycastLoginFailure get failure {
    switch (errorCode) {
      case 'INVALID_CREDENTIALS':
        return KeycastLoginFailure.invalidCredentials;
      case 'EMAIL_NOT_VERIFIED':
        return KeycastLoginFailure.emailNotVerified;
      case 'INVALID_EMAIL':
        return KeycastLoginFailure.invalidEmail;
      case 'TOO_MANY_ATTEMPTS':
        return KeycastLoginFailure.rateLimited;
      case 'timeout':
      case 'connection_error':
      case 'network_error':
        return KeycastLoginFailure.network;
      default:
        return KeycastLoginFailure.unknown;
    }
  }
}

/// Result from GET /api/oauth/poll
enum KeycastAuthFailure {
  emailAlreadyRegistered,
  expiredVerification,
  temporary,
  network,
  unknown,
}

class PollResult {
  PollResult({
    required this.status,
    this.code,
    this.error,
    this.errorCode,
    this.statusCode,
    this.failure,
  });

  factory PollResult.pending() => PollResult(status: PollStatus.pending);

  factory PollResult.complete(String code) =>
      PollResult(status: PollStatus.complete, code: code);

  factory PollResult.error(
    String message, {
    String? errorCode,
    int? statusCode,
    KeycastAuthFailure failure = KeycastAuthFailure.unknown,
  }) => PollResult(
    status: PollStatus.error,
    error: message,
    errorCode: errorCode,
    statusCode: statusCode,
    failure: failure,
  );
  final PollStatus status;
  final String? code;
  final String? error;
  final String? errorCode;
  final int? statusCode;
  final KeycastAuthFailure? failure;

  bool get isTransientFailure =>
      failure == KeycastAuthFailure.network ||
      failure == KeycastAuthFailure.temporary;
}

enum PollStatus {
  pending, // Still waiting for email verification
  complete, // User verified, code available
  error, // Something went wrong
}

/// Reason a [VerifyPinResult] failed.
///
/// keycast intentionally returns uniform anti-enumeration errors, so the
/// server may collapse several of these into one generic failure. Callers
/// should treat distinct cases as advisory and fall back to generic copy.
enum VerifyPinError {
  /// The submitted PIN was incorrect.
  invalid,

  /// The PIN (or its 24h verification window) has expired.
  expired,

  /// Too many failed attempts — the PIN is locked until a new one is sent.
  locked,

  /// Transient network error or timeout.
  network,

  /// Server returned a 5xx or otherwise unexpected/malformed response.
  server,

  /// The verify-pin endpoint is absent (404) or returned an unclassified 4xx.
  /// The PIN path isn't usable here; the UI should steer the user back to the
  /// email link / resend rather than claiming the PIN was incorrect.
  unavailable,

  /// Finalizing verification found the email already attached to an account.
  emailAlreadyRegistered,
}

/// Result from POST /api/headless/verify-pin
class VerifyPinResult {
  VerifyPinResult({
    required this.success,
    this.alreadyCompleted = false,
    this.code,
    this.errorCode,
    this.errorDescription,
  });

  factory VerifyPinResult.success(String code) =>
      VerifyPinResult(success: true, code: code);

  factory VerifyPinResult.alreadyCompleted() =>
      VerifyPinResult(success: true, alreadyCompleted: true);

  factory VerifyPinResult.failure(
    VerifyPinError errorCode, {
    String? description,
  }) => VerifyPinResult(
    success: false,
    errorCode: errorCode,
    errorDescription: description,
  );

  final bool success;

  /// True when keycast reports this registration was already finalized.
  final bool alreadyCompleted;

  /// OAuth authorization code, returned synchronously on success.
  final String? code;

  /// Reason code on failure (null on success).
  final VerifyPinError? errorCode;

  /// Human-readable description from the server, for logs only — never shown
  /// to the user (the UI localizes [errorCode]).
  final String? errorDescription;
}

/// Why a resend request did not send a new verification email.
enum ResendVerificationError {
  /// The resend endpoint is absent (404). This server build cannot resend at
  /// all, so retrying is pointless until it is redeployed — the UI should
  /// steer the user to the PIN from the email they already have.
  unavailable,

  /// The request reached the server and it declined to send (4xx other than
  /// 404). Retrying may work.
  declined,

  /// The pending registration has expired. Retrying resend cannot recover it;
  /// the user must start signup again.
  expired,

  /// Server returned a 5xx.
  server,

  /// Transient network error or timeout — the request may not have arrived.
  network,
}

/// Result from POST /api/auth/resend-verification
class ResendVerificationResult {
  ResendVerificationResult({
    required this.success,
    this.message,
    this.errorCode,
  });

  factory ResendVerificationResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    final message = json['message'] as String?;
    return ResendVerificationResult(
      success: success,
      message: message,
      errorCode: success ? null : _errorCodeFromMessage(message),
    );
  }

  factory ResendVerificationResult.failure(ResendVerificationError errorCode) =>
      ResendVerificationResult(success: false, errorCode: errorCode);

  /// Classifies a 2xx body that reports `success: false`.
  ///
  /// An expired pending registration is the one such body keycast sends with a
  /// distinct meaning, and it arrives as **HTTP 200** with
  /// `{"success": false, "message": "This registration has expired. Please
  /// sign up again."}` — see `headless_resend_pin`, the `expires_at <=
  /// Utc::now()` branch in keycast `api/src/api/http/headless.rs`. The uniform
  /// anti-enumeration response on that route is `success: true`, so any other
  /// `success: false` is a genuine decline.
  ///
  /// Do not confuse this with the 410 `AuthError::RegistrationExpired` on the
  /// `/api/auth/*` users-table routes (which means an async password hash died)
  /// or with verify-pin's 410 `pin_expired`. Neither is reachable from
  /// `/api/headless/resend-pin`.
  ///
  /// Matching on prose is the weak point: if keycast rewords that sentence this
  /// silently degrades to [ResendVerificationError.declined], which costs the
  /// user the "start again" guidance but leaves resend retryable.
  // TODO(dcadenas): switch to the server's `code` once keycast emits one on
  // resend-pin, tracked in divinevideo/keycast#362; keep this match as the
  // old-server fallback until then. `verifyPin` already keys on codes this way.
  static ResendVerificationError _errorCodeFromMessage(String? message) {
    final normalized = message?.toLowerCase() ?? '';
    if (normalized.contains('registration') &&
        normalized.contains('expired') &&
        normalized.contains('sign up')) {
      return ResendVerificationError.expired;
    }
    return ResendVerificationError.declined;
  }

  final bool success;
  final String? message;

  /// Reason code on failure (null on success).
  final ResendVerificationError? errorCode;
}

/// Result from POST /api/auth/forgot-password
class ForgotPasswordResult {
  ForgotPasswordResult({required this.success, this.message, this.error});

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory ForgotPasswordResult.error(String message) {
    return ForgotPasswordResult(success: false, error: message);
  }
  final bool success;
  final String? message;
  final String? error;
}

class ResetPasswordResult {
  ResetPasswordResult({required this.success, this.message});

  factory ResetPasswordResult.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  factory ResetPasswordResult.error(String message) {
    return ResetPasswordResult(success: false, message: message);
  }
  final bool success;
  final String? message;
}

/// Result from DELETE /api/user/account
class DeleteAccountResult {
  DeleteAccountResult({
    required this.success,
    this.message,
    this.error,
    this.requiresReauthentication = false,
  });

  factory DeleteAccountResult.fromJson(Map<String, dynamic> json) {
    return DeleteAccountResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory DeleteAccountResult.error(
    String message, {
    bool requiresReauthentication = false,
  }) {
    return DeleteAccountResult(
      success: false,
      error: message,
      requiresReauthentication: requiresReauthentication,
    );
  }
  final bool success;
  final String? message;
  final String? error;

  /// True when the credential could not authorize the deletion and only a
  /// fresh sign-in can, rather than a retry.
  ///
  /// [error] carries the server's prose, which is written for humans and
  /// varies by deployment — callers must branch on this flag instead of
  /// matching that text.
  final bool requiresReauthentication;
}

/// Result from POST /api/auth/verify-email
class VerifyEmailResult {
  VerifyEmailResult({
    required this.success,
    this.message,
    this.error,
    this.errorCode,
    this.statusCode,
    this.failure,
  });

  factory VerifyEmailResult.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    return VerifyEmailResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
      errorCode: json['code'] as String?,
      statusCode: statusCode,
    );
  }

  factory VerifyEmailResult.error(
    String message, {
    String? errorCode,
    int? statusCode,
    KeycastAuthFailure failure = KeycastAuthFailure.unknown,
  }) => VerifyEmailResult(
    success: false,
    error: message,
    errorCode: errorCode,
    statusCode: statusCode,
    failure: failure,
  );
  final bool success;
  final String? message;
  final String? error;
  final String? errorCode;
  final int? statusCode;
  final KeycastAuthFailure? failure;

  bool get isTransientFailure =>
      failure == KeycastAuthFailure.network ||
      failure == KeycastAuthFailure.temporary;
}

/// Why a `POST /api/user/export-key` call did not return key material.
///
/// The server writes its refusals as human prose that varies by deployment and
/// is not stable enough to branch on, and each of its two refusal codes covers
/// two unrelated causes: 401 is a wrong account password or a stale bearer
/// token, 403 is an unverified email or a custody policy denial. Callers must
/// switch on this enum rather than on [ExportKeyResult.error] or the status
/// code.
enum ExportKeyFailure {
  /// The bearer token is valid but the submitted account password is not.
  /// Recoverable in place: re-prompt without sending the user elsewhere.
  wrongPassword,

  /// The bearer token is missing, expired, or rejected. Only a fresh sign-in
  /// clears it.
  needsSignIn,

  /// The account's email address is not verified yet, which Keycast requires
  /// before any raw-key egress.
  emailUnverified,

  /// Keycast refused the export by policy. Today this is the `verified_minor`
  /// custody refusal, which is deliberately indistinguishable from any other
  /// policy denial so it leaks no account state.
  denied,

  /// No exportable key is on record for this account.
  noKey,

  /// Too many export attempts have been made for now. Unlike every other
  /// refusal here, waiting is the remedy — an immediate retry will not clear
  /// it.
  rateLimited,

  /// Transport failure, timeout, or a malformed response.
  network,

  /// Keycast reported an internal fault (5xx).
  server,

  /// Anything not covered above.
  unknown,
}

/// Result from POST /api/user/export-key.
///
/// [key] is present only on success and holds raw key material — never log it,
/// never persist it, and drop the reference as soon as it reaches the
/// clipboard.
class ExportKeyResult {
  ExportKeyResult({required this.success, this.key, this.error, this.failure});

  factory ExportKeyResult.success(String key) =>
      ExportKeyResult(success: true, key: key);

  factory ExportKeyResult.failure(
    ExportKeyFailure failure, {
    String? message,
  }) => ExportKeyResult(success: false, error: message, failure: failure);

  final bool success;
  final String? key;
  final String? error;
  final ExportKeyFailure? failure;
}

/// Why a `POST /api/user/change-password` call did not change the password.
///
/// Like the export refusals, 401 covers two unrelated causes — a wrong current
/// password or a bearer token the server no longer accepts — and the response
/// body discriminates neither, so callers must switch on this enum rather than
/// on the status code or on [ChangePasswordResult.error], which carries server
/// prose that is never translated.
enum ChangePasswordFailure {
  /// The bearer token is valid but the submitted current password is not.
  /// Recoverable in place: re-prompt without sending the user elsewhere.
  wrongPassword,

  /// The bearer token is missing, expired, or rejected. Only a fresh sign-in
  /// clears it.
  needsSignIn,

  /// The server rejected the new password (it enforces its own minimum length).
  weakPassword,

  /// Too many attempts for now — waiting is the remedy, not a retry.
  rateLimited,

  /// Transport failure, timeout, or a malformed response.
  network,

  /// Keycast reported an internal fault (5xx).
  server,

  /// Anything not covered above.
  unknown,
}

/// Result from POST /api/user/change-password.
class ChangePasswordResult {
  ChangePasswordResult({required this.success, this.error, this.failure});

  factory ChangePasswordResult.success() => ChangePasswordResult(success: true);

  factory ChangePasswordResult.failure(
    ChangePasswordFailure failure, {
    String? message,
  }) => ChangePasswordResult(success: false, error: message, failure: failure);

  final bool success;

  /// Server prose. Written for Keycast's own web UI, never translated — for
  /// logs and debugging only, never for display.
  final String? error;

  final ChangePasswordFailure? failure;
}

/// Why a `POST /api/user/change-email` call did not start an email change.
///
/// Note what is deliberately absent: there is no "already taken" value. Keycast
/// answers 200 for an address that is already registered so the endpoint cannot
/// be used to probe for accounts, so a caller can never tell that case apart
/// from an accepted change — and must not try to.
enum ChangeEmailFailure {
  /// The bearer token is valid but the submitted account password is not.
  wrongPassword,

  /// The bearer token is missing, expired, or rejected. Only a fresh sign-in
  /// clears it.
  needsSignIn,

  /// The server rejected the address as malformed.
  invalidEmail,

  /// Too many attempts for now — waiting is the remedy, not a retry.
  rateLimited,

  /// Transport failure, timeout, or a malformed response.
  network,

  /// Keycast reported an internal fault (5xx).
  server,

  /// Anything not covered above.
  unknown,
}

/// Result from POST /api/user/change-email.
///
/// Success means only that Keycast accepted the request and sent confirmation
/// links; the address changes when both the old and the new inbox confirm.
class ChangeEmailResult {
  ChangeEmailResult({required this.success, this.error, this.failure});

  factory ChangeEmailResult.success() => ChangeEmailResult(success: true);

  factory ChangeEmailResult.failure(
    ChangeEmailFailure failure, {
    String? message,
  }) => ChangeEmailResult(success: false, error: message, failure: failure);

  final bool success;

  /// Server prose. Written for Keycast's own web UI, never translated — for
  /// logs and debugging only, never for display.
  final String? error;

  final ChangeEmailFailure? failure;
}
