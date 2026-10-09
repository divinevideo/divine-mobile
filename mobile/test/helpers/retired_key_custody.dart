// ABOUTME: Test helper that sets the recorded custody of the shipped retired
// ABOUTME: moderation key, so a widget test can drive every custody state.

import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/official_accounts_providers.dart';

/// The shipped retired moderation key every DM surface test already uses.
String get shippedRetiredKey => kLegacyModerationPubkeys.first;

/// Overrides the register so [shippedRetiredKey] has [custody].
///
/// Official branding follows recorded custody (#9963), so the same pubkey is
/// presented as Divine or as a neutral former moderation account depending only
/// on this value.
Override retiredKeyCustody(RetiredKeyCustody custody) =>
    retiredModerationKeysProvider.overrideWithValue([
      RetiredModerationKey(pubkeyHex: shippedRetiredKey, custody: custody),
    ]);

/// Custodies that keep Divine's official name and wordmark.
const List<RetiredKeyCustody> keptCustodies = [
  RetiredKeyCustody.unrecovered,
  RetiredKeyCustody.destroyed,
];

/// Custodies that withdraw it, because someone could still sign as the key.
const List<RetiredKeyCustody> withdrawnCustodies = [
  RetiredKeyCustody.archived,
  RetiredKeyCustody.compromised,
];
