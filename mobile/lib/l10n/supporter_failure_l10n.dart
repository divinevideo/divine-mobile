// ABOUTME: Maps SupporterFailure codes to localized strings.
// ABOUTME: Supporter state stores the failure; the UI layer localizes it.

import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/l10n/l10n.dart';

/// User-facing wording for a [SupporterFailure].
extension SupporterFailureMessage on SupporterFailure {
  String message(AppLocalizations l10n) => switch (this) {
    SupporterFailure.storeUnavailable => l10n.supporterErrorStoreUnavailable,
    SupporterFailure.purchaseFailed => l10n.supporterErrorPurchaseFailed,
    SupporterFailure.purchasePending => l10n.supporterErrorPurchasePending,
    SupporterFailure.restoreFailed => l10n.supporterErrorRestoreFailed,
    SupporterFailure.ownershipConflict => l10n.supporterErrorOwnershipConflict,
    SupporterFailure.verificationUnavailable =>
      l10n.supporterErrorVerificationUnavailable,
    SupporterFailure.unknown => l10n.supporterErrorUnknown,
  };
}
