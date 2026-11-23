// ABOUTME: Google OAuth client IDs for native sign-in. Client IDs are public
// ABOUTME: identifiers; Keycast checks each token against the same values.

/// Google OAuth clients the app signs in with.
///
/// While a value is empty, Google sign-in is reported unavailable on that
/// platform instead of failing inside the plugin.
abstract final class SocialSignInConfig {
  /// The web client ID. Google issues every ID token for this audience, on
  /// iOS and Android alike, and Keycast accepts it as the token's `aud`.
  // TODO(#11392): Fill in once the Google Cloud OAuth clients exist.
  static const googleServerClientId = '';

  /// iOS client IDs by bundle ID: each Xcode configuration ships its own
  /// bundle, while the backend environment can change at runtime.
  // TODO(#11392): Fill in together with the URL schemes in Info.plist.
  static const googleIosClientIds = <String, String>{
    'co.openvine.app': '',
    'co.openvine.app.staging': '',
  };
}
