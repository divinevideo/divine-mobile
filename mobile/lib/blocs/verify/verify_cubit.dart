// ABOUTME: Drives the verify dashboard — the links on the identity event,
// ABOUTME: the verifier's verdict on each, and unlinking.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:verifier_client/verifier_client.dart' show SigninRequirement;

part 'verify_state.dart';

/// Loads and mutates the current user's NIP-39 identity claims.
class VerifyCubit extends Cubit<VerifyState> {
  /// Creates a [VerifyCubit] for [pubkey].
  VerifyCubit({
    required IdentityClaimsRepository repository,
    required String pubkey,
    required bool confirmationSignIn,
    required ConfirmationAccessReader readConfirmationAccess,
  }) : _repository = repository,
       _pubkey = pubkey,
       _confirmationSignIn = confirmationSignIn,
       _readConfirmationAccess = readConfirmationAccess,
       super(VerifyState());

  final IdentityClaimsRepository _repository;
  final String _pubkey;
  final bool _confirmationSignIn;

  /// The reader of the account this cubit was made for. The page keys the
  /// cubit on the repository and pubkey, so an account change makes a new
  /// cubit with the new account's reader rather than reusing this one's.
  final ConfirmationAccessReader _readConfirmationAccess;

  /// Reads the links and their verdicts, plus the platforms on offer.
  ///
  /// The platform list is loaded first and kept even if the claim read fails,
  /// so "add a link" still works when relays are unreachable.
  ///
  /// With the `confirmationSignIn` flag on and a platform whose sign-in needs
  /// Divine Confirmation, also reads whether the user holds it, so the list
  /// can say which platforms that gates. [refreshAccess] skips the remembered
  /// answer.
  ///
  /// A call while a load is already in flight is dropped, [refreshAccess]
  /// included. That is safe today: the only caller that asks for a refresh is
  /// [refreshQuietly], which falls back to this only when no list is showing,
  /// and the dashboard's own loads (open, retry) are never started from a
  /// state that shows a renew action.
  Future<void> load({bool refreshAccess = false}) async {
    if (state.status == VerifyStatus.loading) return;
    emit(state.copyWith(status: VerifyStatus.loading, clearError: true));

    List<VerifierPlatform> platforms;
    try {
      platforms = await _repository.supportedPlatforms();
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      platforms = state.platforms;
    }
    if (isClosed) return;

    try {
      final claims = await _repository.claimsWithVerdicts(_pubkey);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: VerifyStatus.ready,
          claims: claims.claims,
          verifiedKeys: claims.verifiedKeys,
          verifierReachable: claims.verifierReachable,
          signInCodes: claims.signInCodes,
          platforms: platforms,
        ),
      );
      // After the list is on screen: the answer can take a network trip, and
      // until it lands the badge reads as it does for a user who has it.
      await _loadConfirmationAccess(platforms, refresh: refreshAccess);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: VerifyStatus.failure,
          platforms: platforms,
          error: VerifyError.load,
          errorAttempt: state.errorAttempt + 1,
        ),
      );
    }
  }

  bool _refreshingQuietly = false;

  /// Bumped whenever the list is changed locally ([claimLinked], an unlink),
  /// so a quiet refresh that began before the change can tell its read is
  /// older than the list and must not replace it.
  int _listGeneration = 0;

  /// Re-reads the verdicts and Divine Confirmation access without leaving the
  /// list, for the return from the Confirmation screen.
  ///
  /// Deliberately not a [load]: that swaps the list for the loading spinner,
  /// resets the scroll, and can drop to the full failure screen over a
  /// transient error. Here the list stays, access is asked afresh, and a
  /// failed read leaves the list as it was and reports through
  /// [VerifyState.errorAttempt] (a snackbar), as an unlink that fails does.
  /// With no list showing yet it is a full [load].
  Future<void> refreshQuietly() async {
    if (state.status != VerifyStatus.ready) {
      return load(refreshAccess: true);
    }
    if (_refreshingQuietly) return;
    _refreshingQuietly = true;
    final generation = _listGeneration;
    try {
      final claims = await _repository.claimsWithVerdicts(_pubkey);
      if (isClosed) return;
      // A link or unlink landed while the read was out. The read may predate
      // it, or come from a relay that hasn't caught up, and would put back a
      // row the user just removed. The next load reconciles.
      if (generation == _listGeneration) {
        emit(
          state.copyWith(
            claims: claims.claims,
            verifiedKeys: claims.verifiedKeys,
            verifierReachable: claims.verifierReachable,
            signInCodes: claims.signInCodes,
          ),
        );
      }
      await _loadConfirmationAccess(state.platforms, refresh: true);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          error: VerifyError.load,
          errorAttempt: state.errorAttempt + 1,
        ),
      );
    } finally {
      _refreshingQuietly = false;
    }
  }

  Future<void> _loadConfirmationAccess(
    List<VerifierPlatform> platforms, {
    required bool refresh,
  }) async {
    final gated = platforms.any(
      (platform) =>
          platform.supportsOAuth &&
          platform.signinRequires == SigninRequirement.confirmation,
    );
    if (!_confirmationSignIn || !gated) return;
    ConfirmationAccess access;
    try {
      access = await _readConfirmationAccess(refresh: refresh);
    } on Object catch (error) {
      // Only the type: a signer's message can name the account. A read that
      // throws counts as unknown, which behaves like "has".
      Log.warning(
        'Confirmation access read failed: ${error.runtimeType}',
        name: 'VerifyCubit',
      );
      access = ConfirmationAccess.unknown;
    }
    if (isClosed) return;
    emit(state.copyWith(confirmationAccess: access));
  }

  /// Adds a claim the connect flow just published to the rendered list.
  ///
  /// Deliberately not a reload: the relay that accepted the event a second ago
  /// does not have to serve it back yet, and re-reading would leave the user
  /// staring at a list that does not contain what they just linked. It is
  /// shown as verified because the connect flow only publishes claims the
  /// verifier had already confirmed. The next [load] reconciles.
  ///
  /// [replacing] is the sign-in link a renewal under another handle took the
  /// place of: the connect flow published the new claim instead of it, so its
  /// row goes too. Both keys lose any reason the verifier gave for a lapsed
  /// sign-in.
  void claimLinked(IdentityClaim claim, {IdentityClaim? replacing}) {
    final key = VerifyState.keyOf(claim);
    final dropped = {key, if (replacing != null) VerifyState.keyOf(replacing)};
    _listGeneration++;
    emit(
      state.copyWith(
        status: VerifyStatus.ready,
        claims: [
          for (final existing in state.claims)
            if (!dropped.contains(VerifyState.keyOf(existing))) existing,
          claim,
        ],
        verifiedKeys: {...state.verifiedKeys, key},
        signInCodes: {...state.signInCodes}
          ..removeWhere((lapsedKey, _) => dropped.contains(lapsedKey)),
        clearError: true,
      ),
    );
  }

  /// Unlinks [claim] and drops it from the rendered list.
  ///
  /// The list is updated locally after the publish confirms rather than from a
  /// fresh relay read, so the row disappears immediately even if relays lag.
  Future<void> removeClaim(IdentityClaim claim) async {
    final key = VerifyState.keyOf(claim);
    if (state.removingKey != null) return;
    emit(state.copyWith(removingKey: key, clearError: true));

    try {
      await _repository.removeClaim(claim);
      if (isClosed) return;
      _listGeneration++;
      emit(
        state.copyWith(
          claims: [
            for (final existing in state.claims)
              if (VerifyState.keyOf(existing) != key) existing,
          ],
          verifiedKeys: {...state.verifiedKeys}..remove(key),
          signInCodes: {...state.signInCodes}..remove(key),
          clearRemoving: true,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          clearRemoving: true,
          error: error is IdentityClaimReadException
              ? VerifyError.linksUnreadable
              : VerifyError.remove,
          errorAttempt: state.errorAttempt + 1,
        ),
      );
    }
  }
}
