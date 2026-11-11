// ABOUTME: Persists the user's Nostr relay signature verification policy.
// ABOUTME: Maps app settings onto the nostr_sdk relay-pool verification modes.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NostrSignatureVerificationPreferenceService {
  NostrSignatureVerificationPreferenceService(
    this._prefs, {
    bool isWeb = kIsWeb,
  }) : _isWeb = isWeb;

  static const prefsKey = 'nostr_signature_verification_policy';

  final SharedPreferences _prefs;
  final bool _isWeb;

  /// The policy used until the user picks one in settings.
  ///
  /// Native builds verify every relay. The web build trusts Divine's own
  /// relays, which check signatures when they accept an event, because every
  /// check there runs on the page's only thread; other relays are still
  /// verified.
  NostrSignatureVerificationPolicy get defaultPolicy => _isWeb
      ? NostrSignatureVerificationPolicy.nonDivineRelays
      : NostrSignatureVerificationPolicy.all;

  NostrSignatureVerificationPolicy get currentPolicy =>
      NostrSignatureVerificationPolicy.fromStorage(
        _prefs.getString(prefsKey),
        fallback: defaultPolicy,
      );

  Future<void> setPolicy(NostrSignatureVerificationPolicy policy) async {
    await _prefs.setString(prefsKey, policy.storageValue);
  }
}
