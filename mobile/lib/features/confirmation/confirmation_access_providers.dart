// ABOUTME: Where the app reads Divine Confirmation access from, and the
// ABOUTME: developer override that forces an answer for testing.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:profile_repository/profile_repository.dart';

/// SharedPreferences key holding the developer override's
/// [ConfirmationAccess.name].
///
/// It forces an answer about the signed-in account, so it is swept with the
/// account's other settings (`UserDataCleanupService.userSpecificKeys`) and
/// must not carry onto the next account.
const confirmationAccessOverrideKey = 'confirmation_access_override';

/// Whether this is a debug build, where the override applies without
/// developer mode. A provider only so tests can run as a release build.
@visibleForTesting
final confirmationAccessDebugBuildProvider = Provider<bool>(
  (ref) => kDebugMode,
);

/// The Confirmation answer a developer chose in developer options, or null
/// for the verifier's real answer.
///
/// Stored even while it doesn't apply: [confirmationAccessReaderProvider]
/// honours it only in a debug build or with developer mode on, so turning
/// developer mode off restores the real answer without clearing anything.
final confirmationAccessOverrideProvider =
    NotifierProvider<ConfirmationAccessOverrideNotifier, ConfirmationAccess?>(
      ConfirmationAccessOverrideNotifier.new,
    );

/// Holds and persists the developer's Confirmation override.
class ConfirmationAccessOverrideNotifier extends Notifier<ConfirmationAccess?> {
  @override
  ConfirmationAccess? build() {
    // Re-read on every auth change. A sign-out keeps this container, so
    // without it the in-memory answer would outlive the key the sign-out
    // swept and carry onto the next account. The sweep runs before the auth
    // state flips, so the re-read finds the key gone.
    ref.watch(currentAuthStateProvider);
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(confirmationAccessOverrideKey);
    // A value this build doesn't recognise reads as no override.
    return ConfirmationAccess.values.asNameMap()[stored];
  }

  /// Forces [value], or restores the real answer when null.
  Future<void> set(ConfirmationAccess? value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    if (value == null) {
      await prefs.remove(confirmationAccessOverrideKey);
    } else {
      await prefs.setString(confirmationAccessOverrideKey, value.name);
    }
  }
}

/// Reads whether the signed-in user holds Divine Confirmation: the
/// developer override when it applies, otherwise the verifier's answer
/// through `IdentityClaimsRepository.confirmationAccess`.
///
/// The override applies in a debug build, or in any build with developer
/// mode on, so testers can reach every state on a release build.
final confirmationAccessReaderProvider = Provider<ConfirmationAccessReader>((
  ref,
) {
  final override = ref.watch(confirmationAccessOverrideProvider);
  final overrideApplies =
      ref.watch(confirmationAccessDebugBuildProvider) ||
      ref.watch(isDeveloperModeEnabledProvider);
  if (override != null && overrideApplies) {
    return ({bool refresh = false}) async => override;
  }
  return ref.watch(identityClaimsRepositoryProvider).confirmationAccess;
});

/// SharedPreferences key holding whether the developer setting that simulates
/// the verifier's Confirmation requirement is on.
///
/// Device-wide, unlike [confirmationAccessOverrideKey]: it stands in for the
/// verifier's answer, which is the same for every account, so it is not swept
/// on sign-out.
const confirmationRequirementSimulatedKey =
    'confirmation_requirement_simulated';

/// Whether a developer turned on "act as if the verifier requires Divine
/// Confirmation" in developer options.
///
/// Stored even while it doesn't apply: [simulateConfirmationRequirementProvider]
/// honours it only in a debug build or with developer mode on.
final confirmationRequirementSimulatedProvider =
    NotifierProvider<ConfirmationRequirementSimulatedNotifier, bool>(
      ConfirmationRequirementSimulatedNotifier.new,
    );

/// Holds and persists the developer setting that simulates the requirement.
class ConfirmationRequirementSimulatedNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getBool(confirmationRequirementSimulatedKey) ??
      false;

  /// Turns the simulation on or off. Off removes the stored key.
  Future<void> set({required bool on}) async {
    state = on;
    final prefs = ref.read(sharedPreferencesProvider);
    if (on) {
      await prefs.setBool(confirmationRequirementSimulatedKey, true);
    } else {
      await prefs.remove(confirmationRequirementSimulatedKey);
    }
  }
}

/// Whether the Verify screens treat every platform whose sign-in is on as
/// requiring Divine Confirmation, as the verifier reports while its
/// requirement is on (see `withSimulatedConfirmationRequirement`).
///
/// It applies, like the access override, in a debug build or in any build with
/// developer mode on, so a tester can see the Confirmation screens on a build
/// that talks to a verifier with the requirement off. It changes only what the
/// app shows: the verifier still approves sign-ins as before.
final simulateConfirmationRequirementProvider = Provider<bool>((ref) {
  final applies =
      ref.watch(confirmationAccessDebugBuildProvider) ||
      ref.watch(isDeveloperModeEnabledProvider);
  return applies && ref.watch(confirmationRequirementSimulatedProvider);
});
