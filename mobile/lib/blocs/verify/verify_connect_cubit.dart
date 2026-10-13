// ABOUTME: Drives linking one platform — OAuth login or proof post — and
// ABOUTME: publishes the confirmed claim to the identity event.

import 'dart:async';

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
  }) : _repository = repository,
       _analytics = analytics,
       _pubkey = pubkey,
       _launchOAuth = launchOAuth,
       _oauthReturnUrl = oauthReturnUrl,
       super(VerifyConnectState(platform: platform));

  final IdentityClaimsRepository _repository;
  final String _pubkey;
  final VerifyOAuthLauncher _launchOAuth;
  final AnalyticsEventSink _analytics;
  final String _oauthReturnUrl;

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
    // A verified answer can carry the form of the claim to publish: a TikTok
    // share link reduced to its post number, a Mastodon `@user@server`
    // rewritten as `server/@user`, or a Mastodon account found on the
    // server's web domain rather than the domain typed. That form is what
    // other readers of the claim can check, so it is what gets published.
    // A value that breaks the server's text rules would be dropped every time
    // the event is read, leaving a tag nobody sees, so the claim as sent is
    // published instead.
    final canonical = IdentityClaim(
      pubkey: claim.pubkey,
      platform: claim.platform,
      identity: result.canonicalIdentity ?? claim.identity,
      proof: result.canonicalProof ?? claim.proof,
    );
    await _publish(canonical.isServerValid ? canonical : claim);
  }

  /// Runs the platform's OAuth login, then publishes the claim it confirms.
  Future<void> connectWithOAuth() async {
    if (state.isBusy) return;
    if (state.platform.key == 'bluesky' && state.identity.isEmpty) {
      return _fail(VerifyConnectError.handleRequired);
    }

    emit(
      state.copyWith(status: VerifyConnectStatus.authorizing, clearError: true),
    );

    // Twitter and YouTube ship an OAuth route the deployment has no
    // credentials for; the start endpoint answers 503 rather than redirecting,
    // and a browser session opened on that page never comes back. Resolving
    // the redirect here catches that without asking the verifier to start the
    // flow twice.
    final Uri? authorizationUrl;
    try {
      authorizationUrl = await _repository.resolveOAuthLaunchUri(
        platform: state.platform.key,
        pubkey: _pubkey,
        returnUrl: _oauthReturnUrl,
        handle: state.identity.isEmpty ? null : state.identity,
      );
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

    final params = callback.queryParameters;
    final identity = params['identity'] ?? '';
    // A success the provider could not name would publish a claim nothing can
    // ever verify, so it is treated as a refusal rather than a link.
    if (params['oauth_verified'] != 'true' || identity.isEmpty) {
      // The verifier's reason is free-form and not fit to show, but without it
      // in the log a provider-side refusal is undiagnosable.
      Log.warning(
        'Verifier OAuth refused ${state.platform.key}: '
        '${params['oauth_error'] ?? 'no reason given'}',
        name: 'VerifyConnectCubit',
      );
      return _fail(VerifyConnectError.oauthFailed);
    }

    await _publish(
      IdentityClaim(
        pubkey: _pubkey,
        platform: state.platform.key,
        identity: identity,
        proof: IdentityClaim.oauthProof,
      ),
    );
  }

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
