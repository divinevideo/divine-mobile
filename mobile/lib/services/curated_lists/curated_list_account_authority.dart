// ABOUTME: Binds a list service to the account activation that created it.
// ABOUTME: Prevents pending or same-owner replacement sessions reviving old writers.

import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures an opaque live receipt rather than an owner string or phase flag.
/// A service born before commitment must be replaced after actual settlement.
class CuratedListAccountAuthority {
  CuratedListAccountAuthority({
    required AuthService authService,
    required SharedPreferences preferences,
  }) : _auth = authService,
       _preferences = preferences,
       _activations = AccountActivationCoordinator.forPreferences(preferences),
       _authenticated = authService.isAuthenticated,
       _receipt = authService.committedAccountActivationReceipt {
    unresolvedAtCreation =
        _activations.hasUnresolvedActivation ||
        (_authenticated && _receipt == null);
  }

  final AuthService _auth;
  final SharedPreferences _preferences;
  final AccountActivationCoordinator _activations;
  final bool _authenticated;
  final AccountActivationReceipt? _receipt;
  late final bool unresolvedAtCreation;

  bool get hasPendingCleanup =>
      PendingAccountCleanup.readbackUnknown(_preferences) ||
      _preferences.containsKey(PendingAccountCleanup.storageKey);

  bool get isCurrent =>
      !_activations.hasUnresolvedActivation &&
      (_authenticated
          ? _auth.isAuthenticated &&
                _receipt?.isCurrent == true &&
                _receipt?.ownerPubkey == _auth.currentPublicKeyHex
          : !_auth.isAuthenticated);
}

/// A fresh list session cannot prove cache absence across unfinished setup.
class CuratedListAccountBoundaryException implements Exception {
  const CuratedListAccountBoundaryException();

  @override
  String toString() =>
      'Account cleanup must finish before lists can initialize';
}
