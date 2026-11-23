// ABOUTME: Turns a Google or Apple ID token into a Keycast session: Keycast
// ABOUTME: verifies the token, then the code is exchanged like a password login.

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/social_identity_service.dart';

/// Thrown when Keycast refused the provider's token or the code exchange
/// failed.
class SocialSignInException implements Exception {
  const SocialSignInException(this.failure, [this.cause]);

  final SocialLoginFailure failure;
  final Object? cause;

  @override
  String toString() =>
      'SocialSignInException(${failure.name}'
      '${cause == null ? '' : ', $cause'})';
}

/// Signs in to a Keycast account with Google or Apple.
class SocialSignInRepository {
  SocialSignInRepository({
    required SocialIdentityService identityService,
    required KeycastOAuth oauthClient,
  }) : _identityService = identityService,
       _oauthClient = oauthClient;

  final SocialIdentityService _identityService;
  final KeycastOAuth _oauthClient;

  /// Whether a sign-in button for [provider] belongs on this device.
  bool isAvailable(SocialProvider provider) =>
      _identityService.isAvailable(provider);

  /// Gets a token from [provider] and returns the Keycast session for the
  /// account it unlocks — signed in, linked by email, or newly created.
  ///
  /// Throws:
  /// * [SocialIdentityException] when the provider produced no token,
  ///   including when the person cancelled.
  /// * [SocialSignInException] when Keycast refused the token or the code
  ///   could not be exchanged.
  Future<KeycastSession> signIn(SocialProvider provider) async {
    final token = await _identityService.obtainToken(provider);
    final (result, verifier) = await _oauthClient.headlessSocialLogin(
      provider: provider,
      idToken: token.idToken,
      rawNonce: token.rawNonce,
      authorizationCode: token.authorizationCode,
    );
    final code = result.code;
    if (!result.success || code == null) {
      throw SocialSignInException(result.failure, result.errorDescription);
    }

    try {
      final tokens = await _oauthClient.exchangeCode(
        code: code,
        verifier: verifier,
      );
      return KeycastSession.fromTokenResponse(tokens);
    } on OAuthException catch (e) {
      throw SocialSignInException(SocialLoginFailure.unknown, e);
    } on Exception catch (e) {
      // exchangeCode lets transport failures through.
      throw SocialSignInException(SocialLoginFailure.network, e);
    }
  }
}
