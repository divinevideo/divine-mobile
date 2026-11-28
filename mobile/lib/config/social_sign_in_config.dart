// ABOUTME: Google OAuth client IDs for native sign-in. Client IDs are public
// ABOUTME: identifiers; Keycast checks each token against the same values.

/// Google OAuth clients the app signs in with.
///
/// While a value is empty, Google sign-in is reported unavailable on that
/// platform instead of failing inside the plugin.
abstract final class SocialSignInConfig {
  /// The web client ID. Google issues every ID token for this audience, on
  /// iOS and Android alike, and Keycast accepts it as the token's `aud`.
  static const googleServerClientId =
      '972941478875-rgd0b5c9fs0s5nlf1fm5f9qe9ag7aslo.apps.googleusercontent.com';

  /// iOS client IDs by bundle ID: each Xcode configuration ships its own
  /// bundle, while the backend environment can change at runtime. Each one
  /// needs its reversed form as a URL scheme in `ios/Runner/Info.plist`.
  ///
  /// The staging bundle has no iOS client, so Debug builds show no Google
  /// button.
  static const googleIosClientIds = <String, String>{
    'co.openvine.app': '972941478875-ola2pqhk40lo1gbo4jdlir5nrftnriha.apps.googleusercontent.com',
  };
}
