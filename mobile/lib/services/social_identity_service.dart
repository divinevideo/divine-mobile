// ABOUTME: Gets an ID token from Google or Apple through the native sign-in
// ABOUTME: sheet, bound to a nonce Keycast checks when it verifies the token.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show SocialProvider;
import 'package:openvine/config/social_sign_in_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// An ID token from Google or Apple, with what Keycast needs to verify it.
class SocialIdentityToken {
  const SocialIdentityToken({
    required this.provider,
    required this.idToken,
    required this.rawNonce,
    this.authorizationCode,
  });

  final SocialProvider provider;
  final String idToken;

  /// The token's `nonce` claim is the SHA-256 of this value.
  final String rawNonce;

  /// Apple's one-time authorization code. Keycast exchanges it for the grant
  /// it revokes when the account is deleted.
  final String? authorizationCode;
}

/// Why a provider produced no ID token.
enum SocialIdentityFailure {
  /// The person closed the provider's sheet.
  cancelled,

  /// The provider cannot sign in on this device or build: not configured, or
  /// the system service it relies on is missing.
  unavailable,

  /// Anything else.
  failed,
}

/// Thrown when Google or Apple produced no ID token.
class SocialIdentityException implements Exception {
  const SocialIdentityException(this.provider, this.failure, [this.cause]);

  final SocialProvider provider;
  final SocialIdentityFailure failure;
  final Object? cause;

  @override
  String toString() =>
      'SocialIdentityException(${provider.name}, ${failure.name}'
      '${cause == null ? '' : ', $cause'})';
}

/// The Google sign-in calls this service needs.
abstract interface class GoogleIdTokenSource {
  /// Must run once per process before [authenticate].
  Future<void> initialize({
    required String? clientId,
    required String serverClientId,
    required String nonce,
  });

  /// Shows the account picker and returns the ID token.
  Future<String?> authenticate();

  Future<void> signOut();
}

/// The Apple sign-in call this service needs.
abstract interface class AppleIdTokenSource {
  /// Shows the Apple sheet and returns the identity token and one-time code.
  Future<({String? identityToken, String authorizationCode})> authenticate({
    required String nonce,
  });
}

/// Gets ID tokens from Google (iOS and Android) and Apple (iOS).
///
/// Google's plugin takes its nonce once, at initialization, so every Google
/// token in a process carries the same one; Keycast's replay guard keys on
/// the token rather than the nonce for that reason. Apple gets a fresh nonce
/// per attempt. One instance must live for the whole process, because the
/// Google plugin may only be initialized once.
class SocialIdentityService {
  SocialIdentityService({
    GoogleIdTokenSource? google,
    AppleIdTokenSource? apple,
    Future<String> Function()? readBundleId,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
    String Function()? generateRawNonce,
    String googleServerClientId = SocialSignInConfig.googleServerClientId,
    Map<String, String> googleIosClientIds =
        SocialSignInConfig.googleIosClientIds,
  }) : _google = google ?? const _PluginGoogleIdTokenSource(),
       _apple = apple ?? const _PluginAppleIdTokenSource(),
       _readBundleId = readBundleId ?? _readPlatformBundleId,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb,
       _generateRawNonce = generateRawNonce ?? _secureRawNonce,
       _googleServerClientId = googleServerClientId,
       _googleIosClientIds = googleIosClientIds;

  final GoogleIdTokenSource _google;
  final AppleIdTokenSource _apple;
  final Future<String> Function() _readBundleId;
  final TargetPlatform _platform;
  final bool _isWeb;
  final String Function() _generateRawNonce;
  final String _googleServerClientId;
  final Map<String, String> _googleIosClientIds;

  /// Resolves to the raw nonce bound into every Google token.
  Future<String>? _googleInitialization;

  bool get _isIOS => !_isWeb && _platform == TargetPlatform.iOS;
  bool get _isAndroid => !_isWeb && _platform == TargetPlatform.android;

  /// Whether a sign-in button for [provider] belongs on this device.
  bool isAvailable(SocialProvider provider) => switch (provider) {
    SocialProvider.apple => _isIOS,
    SocialProvider.google =>
      _googleServerClientId.isNotEmpty &&
          (_isAndroid ||
              (_isIOS &&
                  _googleIosClientIds.values.any((id) => id.isNotEmpty))),
  };

  /// Shows the provider's native sheet and returns its ID token.
  ///
  /// Throws a [SocialIdentityException] when no token comes back, including
  /// when the person cancels.
  Future<SocialIdentityToken> obtainToken(SocialProvider provider) {
    if (!isAvailable(provider)) {
      throw SocialIdentityException(
        provider,
        SocialIdentityFailure.unavailable,
      );
    }
    return switch (provider) {
      SocialProvider.google => _obtainGoogleToken(),
      SocialProvider.apple => _obtainAppleToken(),
    };
  }

  Future<SocialIdentityToken> _obtainGoogleToken() async {
    final rawNonce = await (_googleInitialization ??= _initializeGoogle());
    final String? idToken;
    try {
      idToken = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      throw SocialIdentityException(
        SocialProvider.google,
        googleFailureFor(e.code),
        e,
      );
    } finally {
      await _forgetGoogleAccount();
    }
    if (idToken == null || idToken.isEmpty) {
      throw const SocialIdentityException(
        SocialProvider.google,
        SocialIdentityFailure.failed,
      );
    }
    return SocialIdentityToken(
      provider: SocialProvider.google,
      idToken: idToken,
      rawNonce: rawNonce,
    );
  }

  Future<String> _initializeGoogle() async {
    String? clientId;
    if (_isIOS) {
      clientId = _googleIosClientIds[await _readBundleId()];
      if (clientId == null || clientId.isEmpty) {
        throw const SocialIdentityException(
          SocialProvider.google,
          SocialIdentityFailure.unavailable,
        );
      }
    }
    final rawNonce = _generateRawNonce();
    await _google.initialize(
      clientId: clientId,
      serverClientId: _googleServerClientId,
      nonce: hashNonce(rawNonce),
    );
    return rawNonce;
  }

  /// Keycast holds the account, so Google's session is never used again.
  /// Dropping it lets the next sign-in pick a different Google account.
  Future<void> _forgetGoogleAccount() async {
    try {
      await _google.signOut();
    } on Exception {
      // Intentional no-op: the token is already in hand, and a session left
      // behind only preselects the same account next time.
    }
  }

  Future<SocialIdentityToken> _obtainAppleToken() async {
    final rawNonce = _generateRawNonce();
    try {
      final credential = await _apple.authenticate(nonce: hashNonce(rawNonce));
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const SocialIdentityException(
          SocialProvider.apple,
          SocialIdentityFailure.failed,
        );
      }
      return SocialIdentityToken(
        provider: SocialProvider.apple,
        idToken: identityToken,
        rawNonce: rawNonce,
        authorizationCode: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      throw SocialIdentityException(
        SocialProvider.apple,
        appleFailureFor(e.code),
        e,
      );
    }
  }

  /// The nonce sent to the provider: lowercase hex SHA-256 of [rawNonce].
  /// Keycast recomputes it from the raw nonce the app sends alongside.
  static String hashNonce(String rawNonce) =>
      sha256.convert(utf8.encode(rawNonce)).toString();

  /// How a Google plugin error reads to the person signing in.
  @visibleForTesting
  static SocialIdentityFailure googleFailureFor(
    GoogleSignInExceptionCode code,
  ) => switch (code) {
    GoogleSignInExceptionCode.canceled ||
    GoogleSignInExceptionCode.interrupted => SocialIdentityFailure.cancelled,
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError ||
    GoogleSignInExceptionCode.uiUnavailable =>
      SocialIdentityFailure.unavailable,
    _ => SocialIdentityFailure.failed,
  };

  /// How an Apple plugin error reads to the person signing in.
  @visibleForTesting
  static SocialIdentityFailure appleFailureFor(AuthorizationErrorCode code) =>
      switch (code) {
        AuthorizationErrorCode.canceled => SocialIdentityFailure.cancelled,
        AuthorizationErrorCode.notHandled => SocialIdentityFailure.unavailable,
        _ => SocialIdentityFailure.failed,
      };

  static String _secureRawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<String> _readPlatformBundleId() async =>
      (await PackageInfo.fromPlatform()).packageName;
}

class _PluginGoogleIdTokenSource implements GoogleIdTokenSource {
  const _PluginGoogleIdTokenSource();

  @override
  Future<void> initialize({
    required String? clientId,
    required String serverClientId,
    required String nonce,
  }) => GoogleSignIn.instance.initialize(
    clientId: clientId,
    serverClientId: serverClientId,
    nonce: nonce,
  );

  @override
  Future<String?> authenticate() async =>
      (await GoogleSignIn.instance.authenticate()).authentication.idToken;

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();
}

class _PluginAppleIdTokenSource implements AppleIdTokenSource {
  const _PluginAppleIdTokenSource();

  @override
  Future<({String? identityToken, String authorizationCode})> authenticate({
    required String nonce,
  }) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
      nonce: nonce,
    );
    return (
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
    );
  }
}
