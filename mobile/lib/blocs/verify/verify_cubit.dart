// ABOUTME: Drives the verify dashboard — the links on the identity event,
// ABOUTME: the verifier's verdict on each, and unlinking.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:profile_repository/profile_repository.dart';

part 'verify_state.dart';

/// Loads and mutates the current user's NIP-39 identity claims.
class VerifyCubit extends Cubit<VerifyState> {
  /// Creates a [VerifyCubit] for [pubkey].
  VerifyCubit({
    required IdentityClaimsRepository repository,
    required String pubkey,
  }) : _repository = repository,
       _pubkey = pubkey,
       super(VerifyState());

  final IdentityClaimsRepository _repository;
  final String _pubkey;

  /// Reads the links and their verdicts, plus the platforms on offer.
  ///
  /// The platform list is loaded first and kept even if the claim read fails,
  /// so "add a link" still works when relays are unreachable.
  Future<void> load() async {
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
          platforms: platforms,
        ),
      );
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

  /// Adds a claim the connect flow just published to the rendered list.
  ///
  /// Deliberately not a reload: the relay that accepted the event a second ago
  /// does not have to serve it back yet, and re-reading would leave the user
  /// staring at a list that does not contain what they just linked. It is
  /// shown as verified because the connect flow only publishes claims the
  /// verifier had already confirmed. The next [load] reconciles.
  ///
  /// [replacing] is the link a sign-in again renewed: the connect flow
  /// published the new claim in its place, so its row goes too.
  void claimLinked(IdentityClaim claim, {IdentityClaim? replacing}) {
    final key = VerifyState.keyOf(claim);
    final dropped = {key, if (replacing != null) VerifyState.keyOf(replacing)};
    emit(
      state.copyWith(
        status: VerifyStatus.ready,
        claims: [
          for (final existing in state.claims)
            if (!dropped.contains(VerifyState.keyOf(existing))) existing,
          claim,
        ],
        verifiedKeys: {...state.verifiedKeys, key},
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
      emit(
        state.copyWith(
          claims: [
            for (final existing in state.claims)
              if (VerifyState.keyOf(existing) != key) existing,
          ],
          verifiedKeys: {...state.verifiedKeys}..remove(key),
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
