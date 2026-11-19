/// SharedPreferences key under which the current session's
/// [AuthenticationSource] `code` is persisted, so the correct sign-in method
/// can be restored at startup.
const kAuthenticationSourceKey = 'authentication_source';

/// Source of authentication used to restore session at startup
enum AuthenticationSource {
  none('none'),
  divineOAuth('divineOAuth'),
  importedKeys('imported_keys'),
  automatic('automatic'),
  bunker('bunker'),
  amber('amber'),
  nip07('nip07'),
  ;

  const AuthenticationSource(this.code);

  final String code;

  static AuthenticationSource fromCode(String? code) {
    return AuthenticationSource.values
            .where((s) => s.code == code)
            .firstOrNull ??
        AuthenticationSource.none;
  }
}

/// Whether an account signed in through [source] signs without asking the
/// person each time.
///
/// An external signer (Amber, a NIP-46 bunker, a browser extension) can
/// prompt for every signature, so work that signs on its own, unasked, is
/// limited to the sources that never prompt.
bool signsWithoutPrompting(AuthenticationSource source) => switch (source) {
  AuthenticationSource.divineOAuth ||
  AuthenticationSource.importedKeys ||
  AuthenticationSource.automatic => true,
  AuthenticationSource.none ||
  AuthenticationSource.bunker ||
  AuthenticationSource.amber ||
  AuthenticationSource.nip07 => false,
};
