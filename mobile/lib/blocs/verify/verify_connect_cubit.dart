// ABOUTME: Drives linking one platform — OAuth login or proof post — and
// ABOUTME: publishes the confirmed claim to the identity event.

import 'dart:async';
import 'dart:math';

import 'package:analytics/analytics.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/verify/verify_proof_input.dart';
import 'package:openvine/blocs/verify/verify_rejection.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'verify_connect_state.dart';

/// Opens an OAuth authorization URL and returns its HTTPS callback.
///
/// A `null` callback means the user closed or cancelled the browser session.
typedef VerifyOAuthLauncher = Future<Uri?> Function(Uri authorizationUrl);

/// Links a single platform to the signed-in identity.
///
/// Both routes end the same way: the verifier confirms the account, and only
/// then is the `i` tag published. The web flow leaves publishing as a second
/// button, which is how people end up verified with no checkmark (#6154).
class VerifyConnectCubit extends Cubit<VerifyConnectState> {
  /// Creates a [VerifyConnectCubit] for [platform].
  VerifyConnectCubit({
    required IdentityClaimsRepository repository,
    required String pubkey,
    required VerifierPlatform platform,
    required VerifyOAuthLauncher launchOAuth,
    required String oauthReturnUrl,
    required AnalyticsEventSink analytics,
    Random? random,
    Future<void> Function(Duration)? wait,
  }) : _repository = repository,
       _analytics = analytics,
       _pubkey = pubkey,
       _launchOAuth = launchOAuth,
       _oauthReturnUrl = oauthReturnUrl,
       _random = random ?? Random.secure(),
       _wait = wait ?? Future<void>.delayed,
       super(VerifyConnectState(platform: platform));

  final IdentityClaimsRepository _repository;
  final String _pubkey;
  final VerifyOAuthLauncher _launchOAuth;
  final AnalyticsEventSink _analytics;
  final String _oauthReturnUrl;
  final Random _random;
  // TODO(#10119): approving a sign-in waits with this between confirm
  // retries; drop the ignore when it lands.
  // ignore: unused_field
  final Future<void> Function(Duration) _wait;

  // The sign-in waiting for approval. Kept out of state: its code and secret
  // never go into state, logs or analytics.
  // TODO(#10119): approving a sign-in reads this; drop the ignore when it
  // lands.
  // ignore: unused_field
  _PendingSignIn? _pending;

  /// Records the account handle the user is claiming.
  void identityChanged(String identity) {
    emit(state.copyWith(identity: identity.trim(), clearError: true));
  }

  /// Records the proof URL or id backing the claim.
  void proofChanged(String proof) {
    emit(state.copyWith(proof: proof.trim(), clearError: true));
  }

  /// Asks the verifier to check the proof post, then publishes the claim.
  Future<void> submitProof() async {
    if (state.isBusy || !state.canSubmitProof) return;

    // A pasted post link has to be taken apart before it is sent: most
    // verifiers rebuild the URL from the handle and a bare id, so a link in
    // the proof field looks up a URL that cannot exist.
    final input = state.normalizedInput;
    if (input.problem != null) {
      return _fail(switch (input.problem!) {
        VerifyProofProblem.telegramNotPublic =>
          VerifyConnectError.telegramNotPublic,
      });
    }
    final claim = IdentityClaim(
      pubkey: _pubkey,
      platform: state.platform.key,
      identity: input.identity,
      proof: input.proof,
    );

    emit(
      state.copyWith(status: VerifyConnectStatus.verifying, clearError: true),
    );
    final VerificationResult result;
    try {
      result = await _repository.verifyClaim(claim);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      return _fail(VerifyConnectError.verifierUnreachable);
    }
    if (isClosed) return;

    if (!result.verified) {
      // `error` stays free-form English and is only fit for triage, so the log
      // keeps it. `code` is the stable half, and is what decides which of the
      // reasons the user is shown — telling someone their npub is missing when
      // the real problem was their username is what sends them round the loop
      // of re-posting a message that was already correct.
      Log.warning(
        'Verifier rejected ${claim.platform}:${claim.identity} '
        '(code: ${result.code ?? 'none'}): '
        '${result.error ?? 'no reason given'}',
        name: 'VerifyConnectCubit',
      );
      // Nothing else counts these. The rejection is an expected domain
      // outcome, so it is deliberately not a Crashlytics report — see the
      // reportable-error matrix in .claude/rules/error_handling.md — but with
      // no signal at all we cannot tell one stuck person from everybody.
      // `reason` is a fixed vocabulary and `platform` is a platform key, so
      // neither carries the npub, the handle, the link or the message.
      unawaited(
        _analytics.logEvent(
          name: 'verify_proof_rejected',
          parameters: {
            'platform': claim.platform,
            'reason': result.code ?? 'none',
          },
        ),
      );
      return _fail(verifyErrorForCode(result.code));
    }
    await _publish(claim);
  }

  /// Starts the platform's sign-in, and once it returns, asks the person to
  /// approve linking the account it named.
  Future<void> connectWithOAuth() async {
    if (state.isBusy) return;
    final platform = state.platform.key;
    final typedHandle = _bareHandle(state.identity);
    if (platform == 'bluesky' && typedHandle.isEmpty) {
      return _fail(VerifyConnectError.handleRequired);
    }
    _pending = null;
    emit(
      state.copyWith(
        status: VerifyConnectStatus.authorizing,
        clearError: true,
        clearSignedInAccount: true,
      ),
    );

    // The id ties the return to this screen; the secret, which only goes to
    // the verifier when confirming, ties the sign-in to this app.
    final signInId = _randomHex(16);
    final startSecret = SignInSecrets.newSecret(_random);
    final startCheck = SignInSecrets.startCheckFor(startSecret);

    final Uri? authorizationUrl;
    try {
      authorizationUrl = await _repository.startSignIn(
        platform: platform,
        pubkey: _pubkey,
        returnUrl: '$_oauthReturnUrl?signin=$signInId',
        startCheck: startCheck,
        handle: platform == 'bluesky' ? typedHandle : null,
      );
    } on VerifierNetworkException catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      return _fail(VerifyConnectError.verifierUnreachable);
    } on VerifierTimeoutException catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      return _fail(VerifyConnectError.verifierUnreachable);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      return _fail(VerifyConnectError.oauthFailed);
    }
    if (isClosed) return;
    if (authorizationUrl == null) {
      return _fail(VerifyConnectError.oauthUnavailable);
    }

    final Uri? callback;
    try {
      callback = await _launchOAuth(authorizationUrl);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      return _fail(VerifyConnectError.oauthFailed);
    }
    if (isClosed) return;
    if (callback == null) {
      emit(state.copyWith(status: VerifyConnectStatus.editing));
      return;
    }

    // The return address can carry a one-time code, so it's never logged.
    final params = callback.queryParameters;
    // The refusal's text came in on the return address, so only a fixed
    // reason name is logged.
    if (params.containsKey('oauth_error')) {
      Log.warning(
        'Verifier sign-in for $platform did not complete: refused',
        name: 'VerifyConnectCubit',
      );
      return _fail(VerifyConnectError.oauthFailed);
    }
    final identity = params['identity'] ?? '';
    final matches =
        params['signin'] == signInId &&
        params['platform'] == platform &&
        identity.isNotEmpty &&
        (platform != 'bluesky' ||
            identity.toLowerCase() == typedHandle.toLowerCase());
    if (!matches) {
      Log.warning(
        'Verifier sign-in return did not match the $platform sign-in this '
        'screen started',
        name: 'VerifyConnectCubit',
      );
      return _fail(VerifyConnectError.oauthFailed);
    }
    final code = params['oauth_confirm'] ?? '';
    if (code.isEmpty) {
      Log.warning(
        'Verifier sign-in for $platform came back without a confirmation code',
        name: 'VerifyConnectCubit',
      );
      return _fail(VerifyConnectError.signInNotConfirmed);
    }

    _pending = _PendingSignIn(
      code: code,
      startSecret: startSecret,
      startCheck: startCheck,
      claim: IdentityClaim(
        pubkey: _pubkey,
        platform: platform,
        identity: identity,
        proof: IdentityClaim.oauthProof,
      ),
    );
    emit(
      state.copyWith(
        status: VerifyConnectStatus.awaitingApproval,
        signedInAccount: identity,
      ),
    );
  }

  String _randomHex(int bytes) => [
    for (var i = 0; i < bytes; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  static String _bareHandle(String typed) =>
      typed.trim().replaceFirst(RegExp('^@'), '').trim();

  Future<void> _publish(IdentityClaim claim) async {
    emit(state.copyWith(status: VerifyConnectStatus.publishing));
    try {
      await _repository.publishClaim(claim);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: VerifyConnectStatus.linked,
          identity: claim.identity,
          linkedClaim: claim,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      _fail(
        error is IdentityClaimReadException
            ? VerifyConnectError.linksUnreadable
            : VerifyConnectError.publishFailed,
      );
    }
  }

  void _fail(VerifyConnectError error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: VerifyConnectStatus.editing,
        error: error,
        errorAttempt: state.errorAttempt + 1,
      ),
    );
  }
}

class _PendingSignIn {
  _PendingSignIn({
    required this.code,
    required this.startSecret,
    required this.startCheck,
    required this.claim,
  });

  final String code;
  final String startSecret;
  final String startCheck;
  final IdentityClaim claim;

  // Signed once, and sent again unchanged on a retry.
  SignedIdentityClaim? signed;
  bool confirmed = false;
}
