// ABOUTME: Supplies a real activation receipt to list-consumer test fixtures.
// ABOUTME: Does not emulate key creation or grant canonical-list creation rights.

import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The consumer's authenticated identity is supplied by its test fixture.
/// Native receipt writes, readback and lifetime fencing use the real coordinator.
/// Actual credential/session setup remains covered by AuthService tests.
Future<AccountActivationReceipt> stubCommittedListAccount({
  required AuthService auth,
  required SharedPreferences preferences,
  bool Function()? isCurrent,
  bool replaceLiveAccount = false,
}) async {
  final owner = auth.currentPublicKeyHex;
  if (!auth.isAuthenticated || owner == null) {
    throw StateError('A committed fixture requires an authenticated owner');
  }
  final coordinator = AccountActivationCoordinator.forPreferences(preferences);
  final existing = auth.committedAccountActivationReceipt;
  if (!replaceLiveAccount &&
      existing?.isCurrent == true &&
      existing?.ownerPubkey == owner &&
      coordinator.committedOwnerPubkey == owner) {
    return existing!;
  }
  bool current() =>
      auth.isAuthenticated &&
      auth.currentPublicKeyHex == owner &&
      (isCurrent?.call() ?? true);
  final ticket = await coordinator.begin(
    ownerPubkey: owner,
    isCurrent: current,
    replaceLiveAccount: replaceLiveAccount,
  );
  await coordinator.markIdentityReady(ticket);
  final receipt = await coordinator.commit(ticket);
  when(() => auth.committedAccountActivationReceipt).thenReturn(receipt);
  return receipt;
}
