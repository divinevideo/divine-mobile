// ABOUTME: Cubit for managing Bluesky crosspost toggle state
// ABOUTME: Loads status from keycast API and handles optimistic toggle updates

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/repositories/bluesky_crosspost_repository.dart';
import 'package:openvine/services/crosspost_api_client.dart';

part 'crosspost_settings_state.dart';

/// Manages Bluesky crosspost settings for the current user.
///
/// Fetches the current crosspost state from keycast on creation
/// and provides optimistic toggle with rollback on failure.
class CrosspostSettingsCubit extends Cubit<CrosspostSettingsState> {
  CrosspostSettingsCubit({
    required BlueskyCrosspostRepository repository,
    required String pubkey,
    Duration provisioningPollInterval = _defaultProvisioningPollInterval,
    int maxProvisioningPollAttempts = _defaultMaxProvisioningPollAttempts,
  }) : _repository = repository,
       _pubkey = pubkey,
       _provisioningPollInterval = provisioningPollInterval,
       _maxProvisioningPollAttempts = maxProvisioningPollAttempts,
       super(const CrosspostSettingsState()) {
    unawaited(loadStatus());
  }

  static const _defaultProvisioningPollInterval = Duration(seconds: 5);
  static const _defaultMaxProvisioningPollAttempts = 24;

  final BlueskyCrosspostRepository _repository;
  final String _pubkey;
  final Duration _provisioningPollInterval;
  final int _maxProvisioningPollAttempts;
  Timer? _provisioningPollTimer;

  /// Load the current crosspost status from keycast.
  Future<void> loadStatus() => _loadStatus(kind: _StatusLoadKind.user);

  Future<void> _loadStatus({required _StatusLoadKind kind}) async {
    if (isClosed) return;
    final generation = switch (kind) {
      _StatusLoadKind.user => _beginUserLoad(),
      _StatusLoadKind.poll => _beginPollLoad(),
    };
    if (generation == null) return;
    if (kind == _StatusLoadKind.user && !isClosed) {
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.loading,
          clearError: true,
        ),
      );
    }
    try {
      final result = switch (kind) {
        _StatusLoadKind.user => await _repository.loadStatus(pubkey: _pubkey),
        _StatusLoadKind.poll => _mergeKeycastStatus(
          await _repository.loadKeycastStatus(),
        ),
      };
      if (isClosed || generation != state.operationGeneration) return;
      _emitLoaded(result, fromPoll: kind == _StatusLoadKind.poll);
    } catch (e, stackTrace) {
      if (isClosed || generation != state.operationGeneration) return;
      if (kind == _StatusLoadKind.poll) {
        _emitQuietPollFailure();
        return;
      }
      addError(e, stackTrace);
      _emitLoadFailure(e);
    } finally {
      _endLoad(kind);
    }
  }

  int? _beginUserLoad() {
    if (state.userLoadInFlight) return null;
    final generation = state.operationGeneration + 1;
    emit(
      state.copyWith(
        userLoadInFlight: true,
        operationGeneration: generation,
        provisioningPollAttempts: 0,
        provisioningPollingTimedOut: false,
      ),
    );
    return generation;
  }

  int? _beginPollLoad() {
    if (state.pollLoadInFlight ||
        state.userLoadInFlight ||
        state.status == CrosspostSettingsStatus.toggling ||
        state.provisioningPollingTimedOut) {
      return null;
    }
    emit(state.copyWith(pollLoadInFlight: true));
    return state.operationGeneration;
  }

  void _endLoad(_StatusLoadKind kind) {
    if (isClosed) return;
    switch (kind) {
      case _StatusLoadKind.user:
        if (!state.userLoadInFlight) return;
        emit(state.copyWith(userLoadInFlight: false));
      case _StatusLoadKind.poll:
        if (!state.pollLoadInFlight) return;
        emit(state.copyWith(pollLoadInFlight: false));
    }
  }

  /// Toggle crossposting with optimistic update.
  ///
  /// Enabling requires a confirmed missing `.divine.video` username to
  /// short-circuit. Unknown claim status is allowed through so the API can
  /// report the current crosspost precondition instead of sending users into a
  /// claim flow after a transient lookup failure.
  ///
  /// A confirmed missing username short-circuits to a
  /// [CrosspostSettingsError.usernameNotClaimed] failure and let the UI route
  /// the user into the claim flow instead of optimistically flipping a toggle
  /// that will snap back.
  ///
  /// Otherwise emits the new value optimistically, calls the API, and reverts
  /// with a categorized [CrosspostSettingsError] on failure.
  Future<void> toggleCrosspost({required bool enabled}) async {
    if (isClosed) return;
    if (state.status == CrosspostSettingsStatus.toggling) return;
    if (enabled &&
        state.usernameClaimStatus == UsernameClaimStatus.notClaimed) {
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.failure,
          error: CrosspostSettingsError.usernameNotClaimed,
          attempt: state.attempt + 1,
        ),
      );
      return;
    }

    final previousState = state;
    final generation = state.operationGeneration + 1;
    emit(
      state.copyWith(
        status: CrosspostSettingsStatus.toggling,
        enabled: enabled,
        clearError: true,
        operationGeneration: generation,
        userLoadInFlight: false,
        pollLoadInFlight: false,
      ),
    );

    try {
      final result = await _repository.setCrosspost(
        pubkey: _pubkey,
        enabled: enabled,
      );
      if (isClosed || generation != state.operationGeneration) return;
      _emitLoaded(result);
    } catch (e, stackTrace) {
      if (isClosed || generation != state.operationGeneration) return;
      addError(e, stackTrace);
      // Revert to previous state on failure, tagging the reason.
      emit(
        previousState.copyWith(
          status: CrosspostSettingsStatus.failure,
          error: _errorFromException(e, previousState.usernameClaimStatus),
          attempt: previousState.attempt + 1,
          operationGeneration: generation,
          userLoadInFlight: false,
          pollLoadInFlight: false,
        ),
      );
    }
  }

  /// Retry provisioning after keycast reports a failed ATProto account setup.
  Future<void> retryProvisioning() => toggleCrosspost(enabled: true);

  /// Clear a surfaced error after the UI has acted on it, returning to a
  /// loaded state so the same error does not fire again.
  void acknowledgeError() {
    if (state.error == null) return;
    if (isClosed) return;
    emit(
      state.copyWith(status: CrosspostSettingsStatus.loaded, clearError: true),
    );
  }

  void _emitLoadFailure(Object error) {
    final claimFailure = error is BlueskyCrosspostStatusException
        ? error
        : null;
    emit(
      CrosspostSettingsState(
        status: CrosspostSettingsStatus.failure,
        enabled: state.enabled,
        username: claimFailure?.username ?? state.username,
        handle: claimFailure?.handle ?? state.handle,
        provisioningState: state.provisioningState,
        did: state.did,
        usernameClaimStatus:
            claimFailure?.usernameClaimStatus ?? state.usernameClaimStatus,
        error: CrosspostSettingsError.generic,
        attempt: state.attempt + 1,
        operationGeneration: state.operationGeneration,
        provisioningPollAttempts: state.provisioningPollAttempts,
        provisioningPollingTimedOut: state.provisioningPollingTimedOut,
      ),
    );
  }

  void _emitLoaded(
    BlueskyCrosspostAccountStatus result, {
    bool fromPoll = false,
  }) {
    if (isClosed) return;
    if (result.provisioningError case final error?
        when error.trim().isNotEmpty) {
      addError(CrosspostProvisioningException(error));
    }
    final pollAttempts =
        result.provisioningState == AtprotoProvisioningState.pending
        ? (fromPoll ? state.provisioningPollAttempts + 1 : 0)
        : 0;
    final pollingTimedOut =
        result.provisioningState == AtprotoProvisioningState.pending &&
        pollAttempts >= _maxProvisioningPollAttempts;
    emit(
      CrosspostSettingsState(
        status: CrosspostSettingsStatus.loaded,
        enabled: result.crosspostEnabled,
        username: result.username,
        handle: result.handle,
        provisioningState: result.provisioningState,
        did: result.did,
        usernameClaimStatus: result.usernameClaimStatus,
        attempt: state.attempt,
        operationGeneration: state.operationGeneration,
        provisioningPollAttempts: pollAttempts,
        provisioningPollingTimedOut: pollingTimedOut,
      ),
    );
    _syncProvisioningPoller(result.provisioningState, pollingTimedOut);
  }

  void _emitQuietPollFailure() {
    final pollAttempts = state.provisioningPollAttempts + 1;
    final pollingTimedOut = pollAttempts >= _maxProvisioningPollAttempts;
    emit(
      state.copyWith(
        pollLoadInFlight: false,
        provisioningPollAttempts: pollAttempts,
        provisioningPollingTimedOut: pollingTimedOut,
      ),
    );
    if (pollingTimedOut) {
      _stopProvisioningPoller();
    }
  }

  void _syncProvisioningPoller(
    AtprotoProvisioningState provisioningState,
    bool pollingTimedOut,
  ) {
    if (provisioningState == AtprotoProvisioningState.pending &&
        !pollingTimedOut) {
      _provisioningPollTimer ??= Timer.periodic(
        _provisioningPollInterval,
        (_) => unawaited(_loadStatus(kind: _StatusLoadKind.poll)),
      );
      return;
    }
    _stopProvisioningPoller();
  }

  BlueskyCrosspostAccountStatus _mergeKeycastStatus(CrosspostStatus status) {
    final username = status.username ?? state.username;
    return BlueskyCrosspostAccountStatus(
      crosspostEnabled: status.crosspostEnabled,
      provisioningState: status.provisioningState,
      usernameClaimStatus: state.usernameClaimStatus,
      username: username,
      handle: status.handle ?? state.handle ?? _handleFor(username),
      did: status.did,
      provisioningError: status.provisioningError,
    );
  }

  String? _handleFor(String? username) {
    if (username == null || username.isEmpty) return null;
    return '$username.divine.video';
  }

  void _stopProvisioningPoller() {
    _provisioningPollTimer?.cancel();
    _provisioningPollTimer = null;
  }

  CrosspostSettingsError _errorFromException(
    Object exception,
    UsernameClaimStatus claimStatus,
  ) {
    if (exception is CrosspostApiException) {
      switch (exception.kind) {
        case CrosspostApiErrorKind.usernameNotClaimed:
          return switch (claimStatus) {
            UsernameClaimStatus.claimed =>
              CrosspostSettingsError.usernameNotSynced,
            UsernameClaimStatus.notClaimed =>
              CrosspostSettingsError.usernameNotClaimed,
            UsernameClaimStatus.unknown => CrosspostSettingsError.unavailable,
          };
        case CrosspostApiErrorKind.unavailable:
          return CrosspostSettingsError.unavailable;
        case CrosspostApiErrorKind.generic:
          return CrosspostSettingsError.generic;
      }
    }
    return CrosspostSettingsError.generic;
  }

  @override
  Future<void> close() {
    _stopProvisioningPoller();
    return super.close();
  }
}

class CrosspostProvisioningException implements Exception {
  const CrosspostProvisioningException(this.message);

  final String message;

  @override
  String toString() => 'CrosspostProvisioningException: $message';
}

enum _StatusLoadKind { user, poll }
