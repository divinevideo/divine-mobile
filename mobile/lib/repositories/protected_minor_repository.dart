// ABOUTME: Fetches the protected-minor state from Keycast (verified_minor) and
// ABOUTME: maps it to ProtectedMinorStatus, preserving fetch failures as unknown.

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reads the durable approved-minor flag from Keycast's `GET /api/user/account`
/// (via [KeycastOAuth.getAccountStatus]) and maps it to [ProtectedMinorStatus].
///
/// [readAccessToken] supplies the current Keycast bearer token; a null/empty
/// token (e.g. a non-OAuth signer session, or a transient refresh miss) yields
/// unknown, NOT not-protected — a missing token is an absent signal, and
/// #175/#176 must not lift protection (or overwrite the sticky verdict) on it.
/// Keycast fetch failure likewise yields unknown, so #175/#176 fall back to
/// their last-known fail-safe posture and lift only on a positive not-a-minor
/// signal from Keycast.
class ProtectedMinorRepository {
  ProtectedMinorRepository({
    required KeycastOAuth oauthClient,
    required Future<String?> Function() readAccessToken,
  }) : _oauthClient = oauthClient,
       _readAccessToken = readAccessToken;

  final KeycastOAuth _oauthClient;
  final Future<String?> Function() _readAccessToken;

  Future<ProtectedMinorStatus> fetchCurrentStatus() async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) {
        // A missing token carries NO signal about minor status (a non-OAuth
        // signer session, or a transient refresh miss). It must map to unknown,
        // NOT a positive notProtected: through isProtectedMinorProvider a
        // trusted notProtected both lifts the DM/content gates AND overwrites
        // the sticky `protected`, re-opening a confirmed minor on an absent
        // signal. unknown falls back to the last-known sticky value instead.
        // Protection lifts only on a positive not-a-minor signal from Keycast.
        return ProtectedMinorStatus.unknown();
      }
      final status = await _oauthClient.getAccountStatus(token);
      return ProtectedMinorStatus.fromKeycast(status);
    } on Object catch (error) {
      // The type alone: the failure can carry account details, and unknown
      // keeps every protection on its fail-safe path either way.
      Log.warning(
        'Keycast account status check failed (${error.runtimeType}); '
        'treating protected-minor status as unknown',
        name: 'ProtectedMinorRepository',
        category: LogCategory.auth,
      );
      return ProtectedMinorStatus.unknown();
    }
  }
}
