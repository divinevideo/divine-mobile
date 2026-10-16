// ABOUTME: Drives linking one platform — OAuth login or proof post — and
// ABOUTME: publishes the confirmed claim to the identity event.

import 'dart:async';
import 'dart:math';

import 'package:analytics/analytics.dart';
import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/verify/verify_proof_input.dart';
import 'package:openvine/blocs/verify/verify_rejection.dart';
import 'package:openvine/utils/async_utils.dart';
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
class VerifyConnectCubit extends Cubit<VerifyConnectState>
    with CloseGuardedEmit<VerifyConnectState> {
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
       _wait = wait,
       super(VerifyConnectState(platform: platform));

  final IdentityClaimsRepository _repository;
  final String _pubkey;
  final VerifyOAuthLauncher _launchOAuth;
  final AnalyticsEventSink _analytics;
  final String _oauthReturnUrl;
  final Random _random;
  // Tests pass their own; otherwise the wait is [_async]'s, so closing the
  // cubit ends it.
  final Future<void> Function(Duration)? _wait;
  final _async = AsyncScope(debugName: 'VerifyConnectCubit');

  // The sign-in waiting for approval. Kept out of state: its code and secret
  // never go into state, logs or analytics.
  _PendingSignIn? _pending;

  // About ten seconds of waiting for a sign-in the verifier hasn't seen yet,
  // however long each answer takes.
  static const _confirmAttempts = 5;
  static const _confirmRetryDelay = Duration(seconds: 2);
  static const _confirmWindow = Duration(seconds: 10);

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
    // A signed sign-in carries the links as they were when it was signed, so
    // publishing it after this would drop the link made here.
    if (_pending?.signed != null) return;

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

    if (!result.verified && result.code == verifierUnavailableCode) {
      // The verifier could not check the proof right now: the platform did not
      // answer, or a check limit was hit. That is no verdict on the proof, so
      // it is logged and counted apart from a rejection: a dashboard that
      // ignores `reason` would otherwise read an outage as a spike in rejected
      // proofs. Analytics gets only the platform key, so nothing that
      // identifies anyone, and the person is told to try again.
      Log.warning(
        'Verifier could not check ${claim.platform}:${claim.identity}: '
        '${result.error ?? 'no reason given'}',
        name: 'VerifyConnectCubit',
      );
      unawaited(
        _analytics.logEvent(
          name: 'verify_proof_unavailable',
          parameters: {'platform': claim.platform},
        ),
      );
      return _fail(verifyErrorForCode(result.code));
    }

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
    final linked = canonical.isServerValid ? canonical : claim;
    // A tag saved earlier under the form sent is the same account, so it is
    // replaced too rather than left beside the new one.
    await _publish(
      linked,
      replacingIdentity: linked.identity == claim.identity
          ? null
          : claim.identity,
    );
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

  /// Links the account the sign-in returned: signs the identity event with
  /// the value tied to this sign-in, has the verifier confirm it, then
  /// publishes that same event.
  Future<void> approveSignIn() async {
    final pending = _pending;
    if (pending == null || state.isBusy) return;
    emit(
      state.copyWith(status: VerifyConnectStatus.publishing, clearError: true),
    );
    try {
      final signed = pending.signed ??= await _repository.signClaim(
        pending.claim,
        confirmBinding: SignInSecrets.confirmBindingFor(
          pending.code,
          pending.startCheck,
        ),
      );
      if (_superseded(pending)) return;
      if (!pending.confirmed) {
        final confirmation = await _confirm(pending, signed);
        if (confirmation == null || _superseded(pending)) return;
        // Counted only when the verifier names the account this sign-in is
        // for, as on the verifier's own page. A resend would get the same
        // answer, so the sign-in ends.
        final claim = pending.claim;
        if (confirmation.platform != claim.platform ||
            confirmation.identity.toLowerCase() !=
                claim.identity.toLowerCase()) {
          Log.warning(
            'Verifier confirmed another account for the ${claim.platform} '
            'sign-in',
            name: 'VerifyConnectCubit',
          );
          return _fail(VerifyConnectError.signInNotConfirmed);
        }
        pending.confirmed = true;
      }
      await _repository.publishSignedClaim(signed);
    } on IdentityClaimNotSignedException {
      // _failKeepingSignIn already stops once the page has closed.
      _logNotSigned(pending.claim.platform);
      return _failKeepingSignIn(VerifyConnectError.notSigned);
    } on SignInConfirmException catch (error) {
      if (_superseded(pending)) return;
      Log.warning(
        'Verifier did not confirm the ${pending.claim.platform} sign-in '
        '(${error.refusal.name})',
        name: 'VerifyConnectCubit',
      );
      // Too many requests says nothing about the sign-in, so it stays to
      // approve again, as on the verifier's own page.
      if (error.statusCode == 429) {
        return _failKeepingSignIn(VerifyConnectError.verifierUnreachable);
      }
      return _fail(VerifyConnectError.signInNotConfirmed);
    } on VerifierClientException catch (error, stackTrace) {
      if (_superseded(pending)) return;
      addError(error, stackTrace);
      return _failKeepingSignIn(VerifyConnectError.verifierUnreachable);
    } on IdentityClaimReadException catch (error, stackTrace) {
      if (_superseded(pending)) return;
      addError(error, stackTrace);
      return _failKeepingSignIn(VerifyConnectError.linksUnreadable);
    } on Object catch (error, stackTrace) {
      if (_superseded(pending)) return;
      addError(error, stackTrace);
      return _failKeepingSignIn(VerifyConnectError.publishFailed);
    }
    // Defence in depth: nothing replaces _pending while approve holds isBusy.
    // Closing the page while publishing is left to emitIfOpen.
    if (!identical(_pending, pending)) return;
    _pending = null;
    emitIfOpen(
      state.copyWith(
        status: VerifyConnectStatus.linked,
        identity: pending.claim.identity,
        linkedClaim: pending.claim,
        clearSignedInAccount: true,
      ),
    );
  }

  /// Forgets the sign-in waiting for approval. Ignored while approving: by
  /// then the link may already be counted.
  void cancelSignIn() {
    if (state.isBusy) return;
    _pending = null;
    emit(
      state.copyWith(
        status: VerifyConnectStatus.editing,
        clearError: true,
        clearSignedInAccount: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _async.dispose();
    return super.close();
  }

  // Sends the same signed event every time: the verifier answers a repeat of
  // the event it confirmed the same way, and refuses a re-signed one as used.
  // Null when the approve was superseded while waiting to try again.
  Future<SignInConfirmation?> _confirm(
    _PendingSignIn pending,
    SignedIdentityClaim signed,
  ) async {
    final deadline = clock.now().add(_confirmWindow);
    for (var attempt = 1; ; attempt++) {
      try {
        return await _repository.confirmSignIn(
          code: pending.code,
          startSecret: pending.startSecret,
          signed: signed,
        );
      } on VerifierClientException catch (error) {
        final outOfTime = clock.now().add(_confirmRetryDelay).isAfter(deadline);
        if (!_worthRetrying(error) ||
            attempt >= _confirmAttempts ||
            outOfTime) {
          rethrow;
        }
        // Closing cancels this wait by throwing AsyncCancelledException,
        // which approveSignIn's catch drops once it sees the cubit closed.
        await (_wait ?? _async.delay)(_confirmRetryDelay);
        if (_superseded(pending)) return null;
      }
    }
  }

  // A sign-in the verifier hasn't seen yet, or a request that got no usable
  // answer. Every other answer is final for this attempt.
  static bool _worthRetrying(VerifierClientException error) => switch (error) {
    SignInConfirmException(:final refusal) => refusal == SignInRefusal.notFound,
    VerifierApiException(:final statusCode) => statusCode >= 500,
    VerifierTimeoutException() || VerifierNetworkException() => true,
  };

  // The cubit closed, or [pending] is no longer the sign-in waiting, so an
  // approve still running for it must not publish or emit.
  bool _superseded(_PendingSignIn pending) =>
      isClosed || !identical(_pending, pending);

  String _randomHex(int bytes) => [
    for (var i = 0; i < bytes; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  static String _bareHandle(String typed) =>
      typed.trim().replaceFirst(RegExp('^@'), '').trim();

  Future<void> _publish(
    IdentityClaim claim, {
    String? replacingIdentity,
  }) async {
    emit(state.copyWith(status: VerifyConnectStatus.publishing));
    try {
      await _repository.publishClaim(
        claim,
        replacingIdentity: replacingIdentity,
      );
      if (isClosed) return;
      // Linked now, so no sign-in is left waiting to approve.
      _pending = null;
      emit(
        state.copyWith(
          status: VerifyConnectStatus.linked,
          identity: claim.identity,
          linkedClaim: claim,
          clearSignedInAccount: true,
        ),
      );
    } on IdentityClaimNotSignedException {
      _logNotSigned(claim.platform);
      _fail(VerifyConnectError.notSigned);
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

  // The signer declined or failed. It reports its own faults, so this is
  // logged rather than filed again (#9340).
  static void _logNotSigned(String platform) => Log.warning(
    'The $platform link was not signed',
    name: 'VerifyConnectCubit',
  );

  // Back to editing, so any sign-in waiting for approval goes too.
  void _fail(VerifyConnectError error) {
    if (isClosed) return;
    _pending = null;
    emit(
      state.copyWith(
        status: VerifyConnectStatus.editing,
        error: error,
        errorAttempt: state.errorAttempt + 1,
        clearSignedInAccount: true,
      ),
    );
  }

  void _failKeepingSignIn(VerifyConnectError error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: VerifyConnectStatus.awaitingApproval,
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
