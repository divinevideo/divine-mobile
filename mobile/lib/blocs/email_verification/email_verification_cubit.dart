// ABOUTME: Cubit for email verification polling that survives navigation
// ABOUTME: Manages polling lifecycle, timeout, and auth completion

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

part 'email_verification_state.dart';

enum EmailTokenVerificationStatus { success, terminalFailure, transientFailure }

final class EmailTokenVerificationResult extends Equatable {
  const EmailTokenVerificationResult._(this.status, {this.errorCode});

  const EmailTokenVerificationResult.success()
    : this._(EmailTokenVerificationStatus.success);

  const EmailTokenVerificationResult.terminalFailure(
    EmailVerificationError errorCode,
  ) : this._(
        EmailTokenVerificationStatus.terminalFailure,
        errorCode: errorCode,
      );

  const EmailTokenVerificationResult.transientFailure()
    : this._(EmailTokenVerificationStatus.transientFailure);

  final EmailTokenVerificationStatus status;
  final EmailVerificationError? errorCode;

  bool get isSuccess => status == EmailTokenVerificationStatus.success;

  @override
  List<Object?> get props => [status, errorCode];
}

/// Cubit for managing email verification polling independently of widget
/// lifecycle.
///
/// Handles:
/// - Starting/stopping polling for email verification
/// - Periodic polling every 3 seconds
/// - Timeout after 15 minutes
/// - Code exchange and authentication on success
/// - Transient network error handling (continues polling)
/// - Auth errors (stops polling with error state)
class EmailVerificationCubit extends Cubit<EmailVerificationState> {
  EmailVerificationCubit({
    required KeycastOAuth oauthClient,
    required AuthService authService,
  }) : _oauthClient = oauthClient,
       _authService = authService,
       super(const EmailVerificationState());

  final KeycastOAuth _oauthClient;
  final AuthService _authService;

  /// Tracks the device code that was already successfully exchanged.
  ///
  /// Static so it persists across cubit instances within the same Dart isolate
  /// (which survives Flutter engine restarts on Android). When one cubit
  /// completes exchange for a device code, zombie cubits polling with the same
  /// device code will see the match and stop. Safe for re-registration because
  /// new registrations receive a different device code.
  static String? _completedDeviceCode;

  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _resendTimer;
  String? _pendingDeviceCode;
  String? _pendingVerifier;
  String? _pendingVerificationToken;
  bool _isVerifyingEmailToken = false;
  int _verificationGeneration = 0;

  /// True once a terminal completion has been claimed for the current
  /// verification. Set synchronously at the top of [_exchangeCodeAndLogin]
  /// before the first await, so a racing poll completion and a racing PIN
  /// submit cannot both reach token exchange. Reset
  /// only by [startPolling] when a fresh verification begins.
  bool _completionClaimed = false;

  /// Whether a terminal completion has already been claimed for the current
  /// verification — either by an in-flight/finished exchange on this instance
  /// ([_completionClaimed]) or by another cubit instance that already
  /// exchanged the same device code (the static [_completedDeviceCode]).
  bool get _isCompletionClaimed =>
      _completionClaimed ||
      (_completedDeviceCode != null &&
          _completedDeviceCode == _pendingDeviceCode);

  bool _matchesActiveVerification({
    required int generation,
    required String deviceCode,
    required String verifier,
    required String? email,
  }) {
    return !isClosed &&
        generation == _verificationGeneration &&
        _pendingDeviceCode == deviceCode &&
        _pendingVerifier == verifier &&
        state.pendingEmail == email;
  }

  /// Client-side cooldown between resend requests, matching keycast's 5-minute
  /// server-side rate limit. The server always returns success (anti-
  /// enumeration), so the client owns surfacing the cooldown to the user.
  static const resendCooldown = Duration(minutes: 5);

  /// Cubit-internal backoff counter for [_schedulePoll]. Lives outside
  /// state because the UI never reads it — analogous to [_pollTimer] and
  /// [_pendingDeviceCode]. See `rules/state_management.md` "No Mutable
  /// Instance Variables in BLoC" for the exception this falls under.
  int _pollTickIndex = 0;

  /// Reset the static completed device code tracking.
  /// Only for use in tests to ensure test isolation.
  @visibleForTesting
  static void resetCompletedDeviceCode() => _completedDeviceCode = null;

  /// Polling timeout duration (15 minutes)
  static const _pollingTimeout = Duration(minutes: 15);

  /// Bounded exponential backoff schedule for the verification poll.
  ///
  /// Reasons for the specific shape:
  /// - First two ticks at 3 s preserve snappy UX for users who click the
  ///   email link within a few seconds.
  /// - Subsequent ticks grow until they hit the 30 s cap, so a user who
  ///   never clicks costs roughly 33 polls over the 15-min window instead
  ///   of the 300 polls a fixed 3 s interval would issue.
  @visibleForTesting
  static const pollBackoffSchedule = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
    Duration(seconds: 21),
  ];

  @visibleForTesting
  static const pollBackoffCap = Duration(seconds: 30);

  static Duration _delayForTick(int tickIndex) {
    if (tickIndex < pollBackoffSchedule.length) {
      return pollBackoffSchedule[tickIndex];
    }
    return pollBackoffCap;
  }

  /// Start polling for email verification
  void startPolling({
    required String deviceCode,
    required String verifier,
    required String email,
  }) {
    Log.info(
      'startPolling called for ${redactEmailForLogs(email)} '
      '(cubit=$hashCode, authSvc=${_authService.hashCode}, '
      'hasExistingTimer=${_pollTimer != null})',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    _verificationGeneration++;
    _pendingDeviceCode = deviceCode;
    _pendingVerifier = verifier;

    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: email,
      ),
    );

    // Cancel any existing timers. The resend cooldown timer is nulled too
    // (it is not reassigned below, unlike the poll/timeout timers) so a re-init
    // can't leave an orphaned Timer.periodic ticking onto the reset state.
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _resendTimer?.cancel();
    _resendTimer = null;

    _pollTickIndex = 0;
    _completionClaimed = false;
    _schedulePoll();

    // Set timeout to stop polling after 15 minutes
    _timeoutTimer = Timer(_pollingTimeout, _onTimeout);
  }

  void _schedulePoll() {
    final scheduledGeneration = _verificationGeneration;
    final delay = _delayForTick(_pollTickIndex);
    _pollTimer = Timer(delay, () async {
      _pollTickIndex++;
      await _poll();
      // Continue only while we still have a pending verification. _cleanup()
      // (called on success, terminal failure, or close) nulls
      // _pendingDeviceCode, which stops the recursion cleanly. Using the
      // pending state — not _pollTimer — as the guard keeps intent explicit
      // and survives future cleanup paths that forget to clear the timer.
      //
      // Also bail once the poll window has elapsed: _onTimeout keeps the
      // pending device code (so PIN entry still works) but the poll loop must
      // stop. Without this, an in-flight _poll() resuming after the timeout
      // would re-arm the timer and poll forever. resumePollingAfterTimeout()
      // restarts cleanly via startPolling when a late link click warrants it.
      if (!isClosed &&
          scheduledGeneration == _verificationGeneration &&
          _pendingDeviceCode != null &&
          state.status != EmailVerificationStatus.pollingTimedOut) {
        _schedulePoll();
      }
    });
  }

  /// Emit a failure state from outside the cubit (e.g., token verification).
  ///
  /// Callers must pass a reason code — state never carries English strings;
  /// the UI layer is responsible for mapping the code to localized copy.
  void emitFailure(EmailVerificationError errorCode, {String? pendingEmail}) {
    _cleanup();
    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.failure,
        pendingEmail: pendingEmail,
        errorCode: errorCode,
      ),
    );
  }

  /// Stop polling (e.g., user cancelled)
  void stopPolling() {
    Log.info(
      'stopPolling called (cubit=$hashCode, hasTimer=${_pollTimer != null})',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    _cleanup();
    // Don't reset to initial state if verification already succeeded —
    // cleanup was already performed by the cubit and resetting would cause
    // a brief UI flash of the pre-verification content before navigation.
    if (state.status != EmailVerificationStatus.success) {
      emit(const EmailVerificationState());
    }
  }

  EmailVerificationError _errorForVerifyEmailResult(VerifyEmailResult result) {
    switch (result.failure) {
      case KeycastAuthFailure.emailAlreadyRegistered:
        return EmailVerificationError.emailAlreadyRegistered;
      case KeycastAuthFailure.network:
      case KeycastAuthFailure.temporary:
        return EmailVerificationError.verificationConnectionError;
      case KeycastAuthFailure.expiredVerification:
      case KeycastAuthFailure.unknown:
      case null:
        return EmailVerificationError.verificationLinkExpired;
    }
  }

  Future<EmailTokenVerificationResult> verifyEmailToken({
    required String token,
    String? pendingEmail,
    bool keepPollingOnTransient = false,
  }) async {
    if (keepPollingOnTransient) {
      _pendingVerificationToken = token;
    }

    return _verifyEmailTokenWithRetries(
      token: token,
      pendingEmail: pendingEmail,
      keepPollingOnTransient: keepPollingOnTransient,
    );
  }

  Future<EmailTokenVerificationResult> _verifyPendingTokenIfNeeded() async {
    final token = _pendingVerificationToken;
    if (token == null || _isVerifyingEmailToken) {
      return const EmailTokenVerificationResult.success();
    }

    return _verifyEmailTokenWithRetries(
      token: token,
      pendingEmail: state.pendingEmail,
      keepPollingOnTransient: true,
    );
  }

  Future<EmailTokenVerificationResult> _verifyEmailTokenWithRetries({
    required String token,
    required String? pendingEmail,
    required bool keepPollingOnTransient,
  }) async {
    _isVerifyingEmailToken = true;
    try {
      for (var attempt = 1; attempt <= _maxVerifyRetries; attempt++) {
        try {
          Log.info(
            'Verifying email token (attempt $attempt/$_maxVerifyRetries)',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          final result = await _oauthClient.verifyEmail(token: token);
          if (result.success) {
            if (_pendingVerificationToken == token) {
              _pendingVerificationToken = null;
            }
            return const EmailTokenVerificationResult.success();
          }

          if (result.isTransientFailure) {
            final transientResult = await _handleTransientVerifyFailure(
              attempt: attempt,
              error: result.error,
              pendingEmail: pendingEmail,
              keepPollingOnTransient: keepPollingOnTransient,
            );
            if (transientResult != null) {
              return transientResult;
            }
            continue;
          }

          return _emitVerifyEmailFailure(result, pendingEmail: pendingEmail);
        } catch (e) {
          final transientResult = await _handleTransientVerifyFailure(
            attempt: attempt,
            error: e,
            pendingEmail: pendingEmail,
            keepPollingOnTransient: keepPollingOnTransient,
          );
          if (transientResult != null) {
            return transientResult;
          }
        }
      }
    } finally {
      _isVerifyingEmailToken = false;
    }

    return const EmailTokenVerificationResult.transientFailure();
  }

  Future<EmailTokenVerificationResult?> _handleTransientVerifyFailure({
    required int attempt,
    required Object? error,
    required String? pendingEmail,
    required bool keepPollingOnTransient,
  }) async {
    final isLastAttempt = attempt == _maxVerifyRetries;
    Log.warning(
      'Transient email-token verification failure '
      '(attempt $attempt/$_maxVerifyRetries): $error',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    if (!isLastAttempt) {
      await Future<void>.delayed(_verifyRetryDelay);
      return null;
    }

    if (keepPollingOnTransient) {
      Log.warning(
        'Keeping verification poll active after transient token failure',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      return const EmailTokenVerificationResult.transientFailure();
    }

    emitFailure(
      EmailVerificationError.verificationConnectionError,
      pendingEmail: _pendingEmailForFailure(
        EmailVerificationError.verificationConnectionError,
        pendingEmail,
      ),
    );
    return const EmailTokenVerificationResult.terminalFailure(
      EmailVerificationError.verificationConnectionError,
    );
  }

  EmailTokenVerificationResult _emitVerifyEmailFailure(
    VerifyEmailResult result, {
    required String? pendingEmail,
  }) {
    final errorCode = _errorForVerifyEmailResult(result);
    Log.warning(
      'Email verification failed: status=${result.statusCode}, '
      'code=${result.errorCode}, failure=${result.failure}, '
      'mappedError=$errorCode, error=${result.error}',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    emitFailure(
      errorCode,
      pendingEmail: _pendingEmailForFailure(errorCode, pendingEmail),
    );
    return EmailTokenVerificationResult.terminalFailure(errorCode);
  }

  String? _pendingEmailForFailure(
    EmailVerificationError errorCode,
    String? pendingEmail,
  ) {
    if (errorCode != EmailVerificationError.emailAlreadyRegistered) {
      return null;
    }
    return pendingEmail ?? state.pendingEmail;
  }

  /// Reset to initial state unconditionally.
  ///
  /// Called when a new verification screen opens to clear stale state from
  /// a previous verification (e.g., User A verified, now User B's deep link
  /// arrives). Without this, the builder would render success UI from the
  /// previous verification instead of the new verification flow.
  void reset() {
    _cleanup();
    emit(const EmailVerificationState());
  }

  void _onTimeout() {
    // A poll/PIN completion already landing (or finished) owns the terminal
    // state — don't clobber its success with pollingTimedOut.
    if (_isCompletionClaimed) return;
    Log.warning(
      'Email verification polling timed out after '
      '${_pollingTimeout.inMinutes} minutes — keeping PIN entry available',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    // Stop the poll/timeout timers but KEEP the pending device code + verifier
    // so the user can still finish via the emailed PIN. Dropping to a terminal
    // failure here would force a re-registration (and trip the duplicate-email
    // edge); instead the screen stays usable for PIN entry / resend.
    _stopPollTimers();
    // Also tear down the resend cooldown timer so its periodic tick can't
    // revive resendCooldownSeconds onto the fresh timed-out state emitted
    // below (which resets resend fields to idle/0).
    _resendTimer?.cancel();
    _resendTimer = null;
    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.pollingTimedOut,
        pendingEmail: state.pendingEmail,
      ),
    );
  }

  EmailVerificationError _errorForPollFailure(PollResult result) {
    switch (result.failure) {
      case KeycastAuthFailure.emailAlreadyRegistered:
        return EmailVerificationError.emailAlreadyRegistered;
      case KeycastAuthFailure.expiredVerification:
        return EmailVerificationError.verificationLinkExpired;
      case KeycastAuthFailure.temporary:
      case KeycastAuthFailure.network:
      case KeycastAuthFailure.unknown:
      case null:
        return EmailVerificationError.pollFailed;
    }
  }

  /// Cancel the poll + timeout timers without clearing the pending
  /// verification context (unlike [_cleanup], which also nulls the device
  /// code / verifier and is used on terminal completion).
  void _stopPollTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Re-arm polling after a [EmailVerificationStatus.pollingTimedOut], reusing
  /// the device code / verifier the timeout retained.
  ///
  /// Used when a late email-link click marks the email verified on the server
  /// *after* the 15-minute poll window already elapsed: re-arming lets the next
  /// poll pick up the completion so the flow auto-finishes instead of waiting
  /// on manual PIN entry. No-ops unless we are timed out and still hold the
  /// pending context.
  void resumePollingAfterTimeout() {
    if (state.status != EmailVerificationStatus.pollingTimedOut) return;
    final deviceCode = _pendingDeviceCode;
    final verifier = _pendingVerifier;
    if (deviceCode == null || verifier == null) return;
    Log.info(
      'Re-arming polling after timeout following a late verifyEmail',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    startPolling(
      deviceCode: deviceCode,
      verifier: verifier,
      email: state.pendingEmail ?? '',
    );
  }

  /// Submit the 6-digit PIN the user read from the verification email.
  ///
  /// On success keycast returns the OAuth authorization code synchronously,
  /// which is fed into the same [_exchangeCodeAndLogin] path as the link/poll
  /// flow — no separate completion logic. Failures surface as a
  /// [PinSubmissionStatus.failure] with a [EmailVerificationError] code; the
  /// link/poll affordances stay intact.
  Future<void> submitPin(String pin) async {
    if (_isCompletionClaimed) {
      // A poll completion or an earlier PIN submit already claimed the
      // exchange. Submitting again would burn a server-side PIN attempt (and
      // could duplicate the exchange) or overwrite the landed success.
      Log.info(
        'submitPin ignored — completion already claimed',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      return;
    }

    final deviceCode = _pendingDeviceCode;
    final verifier = _pendingVerifier;
    final email = state.pendingEmail;
    final generation = _verificationGeneration;
    if (deviceCode == null || verifier == null) {
      // No pending context to exchange against (e.g. expired persistence).
      // Retrying the PIN can't help — surface a generic failure.
      Log.warning(
        'submitPin called without pending device code / verifier',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          pinStatus: PinSubmissionStatus.failure,
          pinErrorCode: EmailVerificationError.pinFailed,
        ),
      );
      return;
    }

    emit(state.copyWith(pinStatus: PinSubmissionStatus.submitting));

    try {
      final result = await _oauthClient.verifyPin(
        deviceCode: deviceCode,
        pin: pin,
      );

      if (!_matchesActiveVerification(
        generation: generation,
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
      )) {
        Log.info(
          'submitPin: active verification changed during verifyPin — abandoning',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        return;
      }

      if (result.alreadyCompleted) {
        Log.info(
          'PIN verification already completed; leaving polling/link recovery active',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        emit(
          state.copyWith(
            pinStatus: PinSubmissionStatus.idle,
            pinErrorCode: null,
          ),
        );
        return;
      }

      if (result.success && result.code != null) {
        if (_isCompletionClaimed) {
          // A poll completion won the race while verifyPin was in flight.
          // Don't re-exchange or stop timers it already owns.
          return;
        }
        Log.info(
          'PIN verification succeeded, exchanging code',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        _stopPollTimers();
        await _exchangeCodeAndLogin(result.code!, verifier);
        return;
      }

      Log.warning(
        'PIN verification failed: ${result.errorCode}',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      if (result.errorCode == VerifyPinError.emailAlreadyRegistered) {
        _stopPollTimers();
        emit(
          state.copyWith(
            status: EmailVerificationStatus.failure,
            errorCode: EmailVerificationError.emailAlreadyRegistered,
            pinStatus: PinSubmissionStatus.idle,
            pinErrorCode: null,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          pinStatus: PinSubmissionStatus.failure,
          pinErrorCode: _pinErrorFor(result.errorCode),
        ),
      );
    } catch (e, stackTrace) {
      if (!_matchesActiveVerification(
        generation: generation,
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
      )) {
        return;
      }
      Log.error(
        'PIN verification exception: $e',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      addError(e, stackTrace);
      emit(
        state.copyWith(
          pinStatus: PinSubmissionStatus.failure,
          pinErrorCode: EmailVerificationError.pinFailed,
        ),
      );
    }
  }

  static EmailVerificationError _pinErrorFor(VerifyPinError? error) {
    return switch (error) {
      VerifyPinError.invalid => EmailVerificationError.pinInvalid,
      VerifyPinError.expired => EmailVerificationError.pinExpired,
      VerifyPinError.locked => EmailVerificationError.pinLocked,
      VerifyPinError.unavailable => EmailVerificationError.pinUnavailable,
      VerifyPinError.emailAlreadyRegistered =>
        EmailVerificationError.emailAlreadyRegistered,
      VerifyPinError.network ||
      VerifyPinError.server ||
      null => EmailVerificationError.pinFailed,
    };
  }

  /// Request a fresh verification email (link + PIN) and start the 5-minute
  /// resend cooldown. No-ops while a resend is in flight or on cooldown.
  Future<void> resendVerification() async {
    final email = state.pendingEmail;
    final deviceCode = _pendingDeviceCode;
    final verifier = _pendingVerifier;
    final generation = _verificationGeneration;
    if (email == null || email.isEmpty) return;
    if (deviceCode == null || verifier == null) return;
    if (state.resendStatus == ResendStatus.sending ||
        state.resendStatus == ResendStatus.cooldown) {
      return;
    }

    emit(state.copyWith(resendStatus: ResendStatus.sending));
    try {
      final result = await _oauthClient.resendHeadlessVerification(deviceCode);
      if (!_matchesActiveVerification(
        generation: generation,
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
      )) {
        return;
      }
      if (result.success) {
        _startResendCooldown();
        return;
      }
      // Route-absent and expired-registration failures both need specific
      // recovery guidance. Every other decline stays retryable.
      final status = switch (result.errorCode) {
        ResendVerificationError.unavailable => ResendStatus.unavailable,
        ResendVerificationError.expired => ResendStatus.expired,
        _ => ResendStatus.failure,
      };
      Log.warning(
        'Resend verification failed (${result.errorCode}); status=$status',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      emit(state.copyWith(resendStatus: status));
    } catch (e, stackTrace) {
      if (!_matchesActiveVerification(
        generation: generation,
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
      )) {
        return;
      }
      // Transient network failure — leave resend available to retry.
      Log.warning(
        'Resend verification request failed: $e',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      addError(e, stackTrace);
      emit(state.copyWith(resendStatus: ResendStatus.failure));
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    var remaining = resendCooldown.inSeconds;
    emit(
      state.copyWith(
        resendStatus: ResendStatus.cooldown,
        resendCooldownSeconds: remaining,
      ),
    );
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        emit(
          state.copyWith(
            resendStatus: ResendStatus.idle,
            resendCooldownSeconds: 0,
          ),
        );
      } else {
        emit(state.copyWith(resendCooldownSeconds: remaining));
      }
    });
  }

  Future<void> _poll() async {
    // Guard: stop polling if another cubit already completed this device code.
    // Handles orphaned cubits from Flutter engine restarts where a different
    // cubit instance completed verification but this one's timer survived.
    // The static field crosses instance boundaries within the Dart isolate.
    if (_completedDeviceCode != null &&
        _completedDeviceCode == _pendingDeviceCode) {
      Log.info(
        'Device code already completed by another cubit, stopping zombie poll '
        '(cubit=$hashCode)',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      _cleanup();
      // Emit success so the screen's BlocConsumer navigates away instead of
      // staying stuck on "Waiting for verification..."
      emit(
        const EmailVerificationState(status: EmailVerificationStatus.success),
      );
      return;
    }

    // Guard: stop polling if user completed OAuth sign-in on this auth service.
    // Use isRegistered (not isAuthenticated) because anonymous users are
    // authenticated but still need polling to complete the secure-account flow.
    //
    // isAuthenticated is also required: isRegistered checks _authSource which
    // persists across sign-outs and remains divineOAuth even when authState is
    // unauthenticated. Without this gate, a new user registering on a device
    // that previously had a signed-out OAuth session would have polling killed
    // on the first tick — leaving them stuck on "Waiting for verification"
    // even after clicking the email link.
    if (_authService.isAuthenticated && _authService.isRegistered) {
      Log.info(
        'Auth already registered, stopping orphaned poll '
        '(cubit=$hashCode)',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      _cleanup();
      return;
    }

    if (_pendingDeviceCode == null) {
      Log.warning(
        'Poll called but _pendingDeviceCode is null, cleaning up',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      _cleanup();
      return;
    }

    try {
      Log.info(
        'Polling for email verification '
        '(cubit=$hashCode, authSvc=${_authService.hashCode}, '
        'isAuth=${_authService.isAuthenticated}, '
        'hasTimer=${_pollTimer != null})',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      final pollGeneration = _verificationGeneration;
      final deviceCode = _pendingDeviceCode;
      final verifier = _pendingVerifier;
      if (deviceCode == null) {
        Log.warning(
          'Poll called but pending device code was cleared, cleaning up',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        _cleanup();
        return;
      }

      final tokenResult = await _verifyPendingTokenIfNeeded();
      if (pollGeneration != _verificationGeneration ||
          _pendingDeviceCode != deviceCode ||
          _pendingVerifier != verifier) {
        Log.info(
          'Poll context changed during token verification — abandoning stale poll',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        return;
      }
      if (tokenResult.status == EmailTokenVerificationStatus.terminalFailure) {
        return;
      }

      final result = await _oauthClient.pollForCode(deviceCode);
      if (pollGeneration != _verificationGeneration ||
          _pendingDeviceCode != deviceCode ||
          _pendingVerifier != verifier) {
        Log.info(
          'Poll context changed during pollForCode — abandoning stale poll',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        return;
      }

      Log.info(
        'Poll result: status=${result.status}, hasCode=${result.code != null}, '
        'error=${result.error}',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );

      switch (result.status) {
        case PollStatus.complete:
          Log.info(
            'Email verification complete! code=${result.code != null}, '
            'verifier=${verifier != null}',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          _pollTimer?.cancel();
          if (_isCompletionClaimed) {
            // A PIN submit (or an earlier completion) already claimed the
            // exchange while this poll was in flight. Bail instead of emitting
            // a missingAuthCode failure over the success it is landing.
            Log.info(
              'Completion already claimed, ignoring in-flight poll result '
              '(cubit=$hashCode)',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            return;
          }
          if (result.code != null && verifier != null) {
            await _exchangeCodeAndLogin(result.code!, verifier);
          } else {
            // Edge case: completion detected but missing code or verifier.
            // Log presence only — BYOK verifiers embed the raw nsec and
            // captured logs are uploaded with bug reports.
            Log.error(
              'Verification complete but missing code or verifier! '
              'code=${result.code != null}, '
              'verifier=${verifier != null}',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            _cleanup();
            emit(
              const EmailVerificationState(
                status: EmailVerificationStatus.failure,
                errorCode: EmailVerificationError.missingAuthCode,
              ),
            );
          }

        case PollStatus.pending:
          // Keep polling - use info level so it's visible in logs
          Log.info(
            'Email verification still pending, will poll again in 3s',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );

        case PollStatus.error:
          final errorMsg = result.error ?? 'Verification failed';
          if (result.isTransientFailure) {
            // Network errors are transient - keep polling
            Log.warning(
              'Transient error during poll, will retry: '
              'status=${result.statusCode}, code=${result.errorCode}, '
              'failure=${result.failure}, error=$errorMsg',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            // Don't stop polling - it will retry in 3 seconds
          } else {
            final errorCode = _errorForPollFailure(result);

            // A completion was already claimed (an in-flight/finished exchange
            // on this instance, or another cubit finished this device code).
            // A late poll error is stale and must not clobber that success.
            if (_isCompletionClaimed) {
              Log.warning(
                'Ignoring post-completion poll error (cubit=$hashCode): '
                '$errorMsg',
                name: 'EmailVerificationCubit',
                category: LogCategory.auth,
              );
              return;
            }

            // After the poll window elapsed, _onTimeout deliberately retains
            // the pending device code / verifier so PIN entry still works. A
            // recoverable/unknown poll error that lands late must not tear that
            // down — only a genuinely expired / already-registered device code
            // is truly terminal.
            final isTerminalFailure =
                errorCode == EmailVerificationError.emailAlreadyRegistered ||
                errorCode == EmailVerificationError.verificationLinkExpired;
            if (!isTerminalFailure &&
                state.status == EmailVerificationStatus.pollingTimedOut) {
              Log.warning(
                'Recoverable poll error after timeout — keeping PIN entry '
                'available: $errorMsg',
                name: 'EmailVerificationCubit',
                category: LogCategory.auth,
              );
              return;
            }

            final pendingEmail = state.pendingEmail;
            Log.error(
              'Email verification polling error (stopping): '
              'status=${result.statusCode}, code=${result.errorCode}, '
              'failure=${result.failure}, mappedError=$errorCode, '
              'error=$errorMsg',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            _cleanup();
            emit(
              EmailVerificationState(
                status: EmailVerificationStatus.failure,
                pendingEmail:
                    errorCode == EmailVerificationError.emailAlreadyRegistered
                    ? pendingEmail
                    : null,
                errorCode: errorCode,
              ),
            );
          }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Email verification polling exception: $e\n$stackTrace',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      // Don't stop polling on transient errors, just log
    }
  }

  /// Maximum retries for token exchange on network errors
  static const _maxExchangeRetries = 3;

  /// Maximum retries for token verification on network errors
  static const _maxVerifyRetries = 3;

  /// Delay between exchange retries
  static const _exchangeRetryDelay = Duration(seconds: 2);

  /// Delay between token verification retries
  static const _verifyRetryDelay = Duration(seconds: 2);

  Future<void> _exchangeCodeAndLogin(String code, String verifier) async {
    // Atomically claim completion before the first await. A racing poll
    // completion or a second PIN submit that reaches here after the claim
    // returns immediately, preventing a duplicate token exchange. Snapshot then
    // null the pending device code / verifier
    // under the claim so a resuming in-flight _poll() reads the cleared context
    // and bails (see the PollStatus.complete guard) instead of landing a second
    // exchange or emitting missingAuthCode over this success.
    if (_isCompletionClaimed) {
      return;
    }
    _completionClaimed = true;
    final exchangeGeneration = _verificationGeneration;
    final claimedDeviceCode = _pendingDeviceCode;
    _pendingDeviceCode = null;
    _pendingVerifier = null;

    bool isStaleExchange() => exchangeGeneration != _verificationGeneration;

    for (var attempt = 1; attempt <= _maxExchangeRetries; attempt++) {
      try {
        Log.info(
          'Attempting token exchange (attempt $attempt/$_maxExchangeRetries)',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        final tokenResponse = await _oauthClient.exchangeCode(
          code: code,
          verifier: verifier,
        );
        if (isStaleExchange()) {
          return;
        }

        final session = KeycastSession.fromTokenResponse(tokenResponse);

        Log.info(
          'Token exchange successful, showing verification confirmation',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        // Mark this device code as completed so zombie cubits from engine
        // restarts (which hold different AuthService instances) will stop.
        // Uses the snapshot taken at claim time because _pendingDeviceCode was
        // nulled under the completion claim above.
        _completedDeviceCode = claimedDeviceCode;

        // Emit success BEFORE signing in, because signInWithDivineOAuth
        // triggers an auth state change that causes GoRouter to redirect
        // to the home screen immediately. By emitting first, the UI can
        // display "Email Verified!" before the redirect occurs.
        _cleanup();
        emit(
          const EmailVerificationState(status: EmailVerificationStatus.success),
        );

        // Brief pause so the user sees the success confirmation
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // Now sign in — this triggers GoRouter redirect to home
        await _authService.signInWithDivineOAuth(session);

        // Verify sign-in actually succeeded (signInWithDivineOAuth catches
        // errors internally and sets state to unauthenticated without throwing)
        if (_authService.isAnonymous) {
          Log.error(
            'Sign-in failed after email verification',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          emit(
            const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.signInFailed,
            ),
          );
        }

        return; // Success - exit the retry loop
      } on OAuthException catch (e) {
        if (isStaleExchange()) {
          return;
        }
        // OAuth errors are not retryable (e.g., invalid code, expired code)
        Log.error(
          'OAuth exchange failed: ${e.message}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        _cleanup();
        emit(
          const EmailVerificationState(
            status: EmailVerificationStatus.failure,
            errorCode: EmailVerificationError.oauthExchange,
          ),
        );
        return; // Don't retry OAuth errors
      } catch (e) {
        if (isStaleExchange()) {
          return;
        }
        // Network errors - retry if we have attempts left
        final isLastAttempt = attempt == _maxExchangeRetries;
        Log.warning(
          'Token exchange network error (attempt $attempt/$_maxExchangeRetries): $e',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        if (isLastAttempt) {
          Log.error(
            'Token exchange failed after $_maxExchangeRetries attempts',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          _cleanup();
          emit(
            const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              errorCode: EmailVerificationError.networkExchange,
            ),
          );
          return;
        }

        // Wait before retrying
        await Future<void>.delayed(_exchangeRetryDelay);
        if (isStaleExchange()) {
          return;
        }
      }
    }
  }

  void _cleanup() {
    _verificationGeneration++;
    Log.info(
      '_cleanup (cubit=$hashCode, hadPollTimer=${_pollTimer != null}, '
      'hadTimeoutTimer=${_timeoutTimer != null})',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    _pollTimer?.cancel();
    _pollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _resendTimer?.cancel();
    _resendTimer = null;
    _pollTickIndex = 0;
    _pendingDeviceCode = null;
    _pendingVerifier = null;
    _pendingVerificationToken = null;
  }

  @override
  Future<void> close() {
    _cleanup();
    return super.close();
  }
}
