// ABOUTME: Cubit for managing Divine authentication flow
// ABOUTME: Handles sign in, sign up, and email verification states

import 'package:analytics/analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/utils/invite_error_utils.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:openvine/utils/validators.dart';
import 'package:unified_logger/unified_logger.dart';

part 'divine_auth_state.dart';

/// Cubit for managing Divine authentication flow.
///
/// Handles:
/// - Switching between sign in and sign up modes
/// - Form field updates and validation
/// - Submitting login/register requests
/// - Email verification flow
class DivineAuthCubit extends Cubit<DivineAuthState>
    with CloseGuardedEmit<DivineAuthState> {
  DivineAuthCubit({
    required KeycastOAuth oauthClient,
    required AuthService authService,
    required PendingVerificationService pendingVerificationService,
    required AuthValidationMessages validationMessages,
    InviteApiClient? inviteApiClient,
    String? inviteCode,
    String? inviteSourceSlug,
    bool requirePasswordConfirmation = false,
    AnalyticsEventSink analytics = const NoOpAnalyticsEventSink(),
  }) : _oauthClient = oauthClient,
       _authService = authService,
       _pendingVerificationService = pendingVerificationService,
       _inviteApiClient = inviteApiClient,
       _inviteCode = inviteCode == null
           ? null
           : InviteApiClient.normalizeCode(inviteCode),
       _inviteSourceSlug = inviteSourceSlug,
       _validationMessages = validationMessages,
       _requirePasswordConfirmation = requirePasswordConfirmation,
       _analytics = analytics,
       super(const DivineAuthInitial());

  final KeycastOAuth _oauthClient;
  final AuthService _authService;
  final PendingVerificationService _pendingVerificationService;
  final InviteApiClient? _inviteApiClient;
  final String? _inviteCode;
  final String? _inviteSourceSlug;
  final AuthValidationMessages _validationMessages;
  final bool _requirePasswordConfirmation;
  final AnalyticsEventSink _analytics;

  /// Initialize form with default state (sign up mode)
  void initialize({
    bool isSignIn = false,
    String? initialEmail,
    String? initialGeneralError,
  }) {
    emit(
      DivineAuthFormState(
        isSignIn: isSignIn,
        email: initialEmail ?? '',
        generalError: initialGeneralError,
        requiresPasswordConfirmation: _requirePasswordConfirmation && !isSignIn,
      ),
    );
  }

  /// Update email field
  void updateEmail(String email) {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(
      current.copyWith(
        email: email,
        clearEmailError: true,
        clearGeneralError: true,
        clearSignInFailureReason: true,
        clearInviteGateRecovery: true,
      ),
    );
  }

  /// Update password field
  void updatePassword(String password) {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(
      current.copyWith(
        password: password,
        clearPasswordError: true,
        clearConfirmPasswordError: true,
        clearGeneralError: true,
        clearSignInFailureReason: true,
        clearInviteGateRecovery: true,
      ),
    );
  }

  /// Update confirm password field
  void updateConfirmPassword(String confirmPassword) {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(
      current.copyWith(
        confirmPassword: confirmPassword,
        clearConfirmPasswordError: true,
        clearGeneralError: true,
        clearSignInFailureReason: true,
        clearInviteGateRecovery: true,
      ),
    );
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(current.copyWith(obscurePassword: !current.obscurePassword));
  }

  /// Set whether the user opted in to marketing communications at sign-up.
  void updateMarketingConsent(bool value) {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(current.copyWith(marketingConsent: value));
  }

  /// Validate and submit the form
  Future<void> submit() async {
    final current = state;
    if (current is! DivineAuthFormState) return;
    if (current.isSubmitting || current.isSkipping) return;

    // Validate fields
    final emailError = Validators.validateEmail(
      current.email,
      messages: _validationMessages,
    );
    final passwordError = Validators.validatePassword(
      current.password,
      messages: _validationMessages,
    );
    final confirmPasswordError =
        current.requiresPasswordConfirmation && !current.isSignIn
        ? Validators.validateConfirmPassword(
            current.confirmPassword,
            password: current.password,
            messages: _validationMessages,
          )
        : null;

    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      emit(
        current.copyWith(
          emailError: emailError,
          passwordError: passwordError,
          confirmPasswordError: confirmPasswordError,
          clearEmailError: emailError == null,
          clearPasswordError: passwordError == null,
          clearConfirmPasswordError: confirmPasswordError == null,
        ),
      );
      return;
    }

    // Start submission
    emit(
      current.copyWith(
        isSubmitting: true,
        clearGeneralError: true,
        clearSignInFailureReason: true,
        clearInviteGateRecovery: true,
      ),
    );

    try {
      final email = Validators.normalizeAuthEmail(current.email);
      if (current.isSignIn) {
        await _handleSignIn(email, current.password);
      } else {
        await _handleSignUp(
          email,
          current.password,
          marketingConsent: current.marketingConsent,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Auth submission error: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
      // Auth submission failures dominate (OAuth/Invite/network) —
      // matrix-NO. YES-narrowing deferred per #4592 (analogous to
      // #4597's `_onMessageSent` deferral).
      addError(e, stackTrace);

      final currentState = state;
      if (currentState is DivineAuthFormState) {
        emitIfOpen(
          currentState.copyWith(
            isSubmitting: false,
            generalError: 'An unexpected error occurred. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _handleSignIn(String email, String password) async {
    Log.info(
      'Attempting sign in using email and password',
      name: 'DivineAuthCubit',
      category: LogCategory.auth,
    );

    final (result, verifier) = await _oauthClient.headlessLogin(
      email: email,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success || result.code == null) {
      final reason = _signInFailureReasonFrom(result.failure);
      Log.warning(
        'Sign in failed: code=${result.errorCode}, reason=$reason, '
        'description=${result.errorDescription}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final current = state;
      if (current is DivineAuthFormState) {
        emitIfOpen(
          current.copyWith(isSubmitting: false, signInFailureReason: reason),
        );
      }
      return;
    }

    // Exchange code for tokens
    await _exchangeCodeAndLogin(result.code!, verifier);
  }

  /// Translates the client-layer [KeycastLoginFailure] into the UI-facing
  /// [SignInFailureReason]. Keeps the client taxonomy out of the state layer.
  SignInFailureReason _signInFailureReasonFrom(KeycastLoginFailure failure) {
    switch (failure) {
      case KeycastLoginFailure.invalidCredentials:
        return SignInFailureReason.invalidCredentials;
      case KeycastLoginFailure.emailNotVerified:
        return SignInFailureReason.emailNotVerified;
      case KeycastLoginFailure.invalidEmail:
        return SignInFailureReason.invalidEmail;
      case KeycastLoginFailure.network:
        return SignInFailureReason.network;
      case KeycastLoginFailure.unknown:
        return SignInFailureReason.unknown;
    }
  }

  Future<void> _handleSignUp(
    String email,
    String password, {
    required bool marketingConsent,
  }) async {
    Log.info(
      'Attempting sign up using email and password',
      name: 'DivineAuthCubit',
      category: LogCategory.auth,
    );

    final (result, verifier) = await _oauthClient.headlessRegister(
      email: email,
      password: password,
      scope: 'policy:full',
      marketingConsent: marketingConsent,
    );

    if (!result.success) {
      // Log the error code and description for debugging/monitoring
      Log.warning(
        'Sign up failed: errorCode=${result.errorCode}, '
        'errorDescription=${result.errorDescription}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      // Convert server error codes to localized messages
      final errorMsg = _getLocalizedRegistrationError(
        result.errorCode,
        result.errorDescription,
      );

      final current = state;
      if (current is DivineAuthFormState) {
        emitIfOpen(
          current.copyWith(
            isSubmitting: false,
            generalError: errorMsg,
            showLoginOptionsRecovery: result.errorCode == 'CONFLICT',
          ),
        );
      }
      return;
    }

    if (result.verificationRequired && result.deviceCode != null) {
      Log.info(
        'Email verification required for ${redactEmailForLogs(email)}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      // Persist verification data for cold-start deep link scenario
      await _pendingVerificationService.save(
        deviceCode: result.deviceCode!,
        verifier: verifier,
        email: email,
        inviteCode: _inviteCode,
      );

      // Emit email verification state
      emitIfOpen(
        DivineAuthEmailVerification(
          email: email,
          deviceCode: result.deviceCode!,
          verifier: verifier,
        ),
      );
    } else {
      final current = state;
      if (current is DivineAuthFormState) {
        emitIfOpen(
          current.copyWith(
            isSubmitting: false,
            generalError: 'Registration complete. Please check your email.',
          ),
        );
      }
    }
  }

  Future<void> _exchangeCodeAndLogin(String code, String verifier) async {
    try {
      Log.info(
        'Exchanging code for tokens',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final tokenResponse = await _oauthClient.exchangeCode(
        code: code,
        verifier: verifier,
      );

      final session = KeycastSession.fromTokenResponse(tokenResponse);
      await _consumeInviteWithSessionIfNeeded(session);

      // Get the session and sign in
      await _authService.signInWithDivineOAuth(session);

      Log.info(
        'Successfully signed in',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      // Same close-mid-flight race as skipWithAnonymousAccount: the sign-in
      // above flips AuthService to `authenticated` before returning, which
      // can reroute off the auth screen and close this cubit.
      emitIfOpen(const DivineAuthSuccess());
    } on InviteApiException catch (e, stackTrace) {
      await _authService.clearPendingDivineOAuthSession();
      Log.error(
        'Invite activation failed: '
        '${InviteErrorUtils.activationFailureLogDetails(e)}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
      // Invite API rejection — matrix-NO (API/domain row).
      addError(e, stackTrace);

      final current = state;
      if (current is DivineAuthFormState) {
        emitIfOpen(
          current.copyWith(
            isSubmitting: false,
            generalError: InviteErrorUtils.activationFailureMessage(e),
            showInviteGateRecovery: true,
            inviteRecoveryCode: _inviteCode,
            inviteRecoverySourceSlug: _inviteSourceSlug,
          ),
        );
      }
    } on OAuthException catch (e, stackTrace) {
      Log.error(
        'OAuth exchange failed: ${e.message}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
      // OAuth token exchange — matrix-NO (Auth/session + API/domain).
      addError(e, stackTrace);

      final current = state;
      if (current is DivineAuthFormState) {
        emitIfOpen(
          current.copyWith(isSubmitting: false, generalError: e.message),
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error exchanging code: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
      // Anything not Invite/OAuth — storage, signing, identity, network.
      // Matrix-NO; YES-narrowing deferred per #4592.
      addError(e, stackTrace);

      final current = state;
      if (current is DivineAuthFormState) {
        emitIfOpen(
          current.copyWith(
            isSubmitting: false,
            generalError: 'Failed to complete authentication',
          ),
        );
      }
    }
  }

  /// Sends a password reset request and returns whether it was accepted.
  Future<bool> sendPasswordResetEmail(String email) async {
    final normalizedEmail = Validators.normalizeAuthEmail(email);
    Log.info(
      'Sending password reset email to ${redactEmailForLogs(normalizedEmail)}',
      name: 'DivineAuthCubit',
      category: LogCategory.auth,
    );

    try {
      final result = await _oauthClient.sendPasswordResetEmail(normalizedEmail);

      if (!result.success) {
        Log.warning(
          'Password reset failed: ${result.error}',
          name: 'DivineAuthCubit',
          category: LogCategory.auth,
        );
      }
      return result.success;
    } catch (e, stackTrace) {
      Log.error(
        'Password reset error: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
        stackTrace: stackTrace,
      );
      // OAuth client network failure — matrix-NO (Network/IO).
      addError(e, stackTrace);
      return false;
    }
  }

  /// Create an anonymous account (skip email/password registration).
  ///
  /// Throws if identity creation fails.
  Future<void> skipWithAnonymousAccount() async {
    final current = state;
    if (current is! DivineAuthFormState) return;
    if (current.isSubmitting || current.isSkipping) return;

    emit(
      current.copyWith(
        isSkipping: true,
        clearGeneralError: true,
        clearInviteGateRecovery: true,
      ),
    );

    try {
      final inviteCode = _inviteCode;
      final inviteApiClient = _inviteApiClient;
      if (inviteCode != null && inviteApiClient != null) {
        final pendingKey = await SecureKeyContainer.generate();
        try {
          await inviteApiClient.consumeInviteWithKeyContainer(
            code: inviteCode,
            keyContainer: pendingKey,
          );
          await _setInviteCodeProperty(inviteCode);
          await _authService.createAnonymousAccountFromKeyContainer(pendingKey);
        } finally {
          pendingKey.dispose();
        }
      } else {
        await _authService.createAnonymousAccount();
      }

      Log.info(
        'Anonymous account created successfully',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      // Account creation flips AuthService to `authenticated` before it
      // returns, which reroutes off the create-account screen and closes
      // this cubit. Nothing is lost: the redirect runs off auth state, and
      // no listener acts on DivineAuthSuccess here.
      emitIfOpen(const DivineAuthSuccess());
    } on InviteApiException catch (e, stackTrace) {
      Log.error(
        'Anonymous account invite activation failed: '
        '${InviteErrorUtils.activationFailureLogDetails(e)}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
      // Invite API rejection — matrix-NO (API/domain row).
      addError(e, stackTrace);

      final currentState = state;
      if (currentState is DivineAuthFormState) {
        emitIfOpen(
          currentState.copyWith(
            isSkipping: false,
            generalError: InviteErrorUtils.activationFailureMessage(e),
            showInviteGateRecovery: true,
            inviteRecoveryCode: _inviteCode,
            inviteRecoverySourceSlug: _inviteSourceSlug,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Anonymous account creation failed: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
      // Key generation, storage, identity creation — matrix-NO
      // (Network/IO + signer). YES-narrowing deferred per #4592.
      addError(e, stackTrace);

      final currentState = state;
      if (currentState is DivineAuthFormState) {
        emitIfOpen(
          currentState.copyWith(
            isSkipping: false,
            generalError: 'Failed to create account. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _consumeInviteWithSessionIfNeeded(KeycastSession session) async {
    final inviteCode = _inviteCode;
    final inviteApiClient = _inviteApiClient;
    if (inviteCode == null || inviteApiClient == null) {
      return;
    }

    await inviteApiClient.consumeInviteWithSession(
      code: inviteCode,
      oauthConfig: _oauthClient.config,
      session: session,
    );
    await _setInviteCodeProperty(inviteCode);
  }

  Future<void> _setInviteCodeProperty(String inviteCode) async {
    try {
      await _analytics.setUserProperty(
        name: AnalyticsUserProperty.inviteCode,
        value: inviteCode,
      );
    } catch (error) {
      Log.warning(
        'Failed to set invite attribution: $error',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
    }
  }

  /// Return to form from email verification state
  void returnToForm() {
    final current = state;
    if (current is DivineAuthEmailVerification) {
      emit(
        DivineAuthFormState(
          email: current.email,
          requiresPasswordConfirmation: _requirePasswordConfirmation,
        ),
      );
    } else {
      emit(
        DivineAuthFormState(
          requiresPasswordConfirmation: _requirePasswordConfirmation,
        ),
      );
    }
  }

  /// Convert server error codes to localized messages for registration errors.
  ///
  /// Known error codes from the server:
  /// - 'email_exists': Email is already registered
  /// - 'invalid_email': Email format is invalid
  /// - 'weak_password': Password doesn't meet requirements
  /// - 'registration_failed': Generic registration failure
  String _getLocalizedRegistrationError(
    String? errorCode,
    String? serverDescription,
  ) {
    switch (errorCode) {
      case 'CONFLICT':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid_email':
        return 'Please enter a valid email address.';
      case 'weak_password':
        return 'Password is too weak. Please use a stronger password.';
      case 'rate_limited':
        return 'Too many attempts. Please try again later.';
      case 'server_error':
        return 'Server error. Please try again later.';
      case 'connection_error':
      case 'network_error':
        return 'Cannot connect to server. Please check your internet connection.';
      default:
        // For unknown error codes, log it so we can add handling later
        if (errorCode != null && errorCode != 'registration_failed') {
          Log.info(
            'Unhandled registration error code: $errorCode',
            name: 'DivineAuthCubit',
            category: LogCategory.auth,
          );
        }
        // Fall back to server description or generic message
        return serverDescription ?? 'Registration failed. Please try again.';
    }
  }
}
