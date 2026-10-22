// ABOUTME: Fetches the authenticated account's enforcement state from Funnelcake
// ABOUTME: and maps positive restriction signals without claiming all-clear.

import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/services/account_status_api_client.dart';

class AccountEnforcementRepository {
  AccountEnforcementRepository({required AccountStatusApiClient apiClient})
    : _apiClient = apiClient;

  final AccountStatusApiClient _apiClient;

  Future<AccountEnforcementStatus> fetchCurrentStatus({
    required String pubkey,
  }) async {
    try {
      final status = await _apiClient.fetchStatus(expectedPubkey: pubkey);
      return AccountEnforcementStatus.fromFunnelcake(status);
    } on AccountStatusApiException {
      throw const AccountStatusUnavailable();
    }
  }
}

/// Thrown when the account status could not be read at all.
///
/// This means the lookup itself failed and the previous answer, if any, is
/// still the best one available.
class AccountStatusUnavailable implements Exception {
  const AccountStatusUnavailable();

  @override
  String toString() => 'AccountStatusUnavailable';
}

/// Thrown when the account cannot sign the status request yet, as while a
/// remote signer is still connecting. No request was sent, so nothing failed
/// beyond waiting.
class AccountStatusSignerNotReady extends AccountStatusUnavailable {
  const AccountStatusSignerNotReady();

  @override
  String toString() => 'AccountStatusSignerNotReady';
}
