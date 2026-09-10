// ABOUTME: Cubit driving manual crossposting of one video from the share flow
// ABOUTME: Loads connections, submits jobs, then polls until terminal states

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoCrosspostCubit extends Cubit<VideoCrosspostState> {
  VideoCrosspostCubit({
    required CrosspostingApiClient client,
    required String eventId,
    List<CrosspostingConnection>? initialConnections,
    Duration pollInterval = const Duration(seconds: 3),
    Duration pollTimeout = const Duration(minutes: 5),
  }) : _client = client,
       _eventId = eventId,
       _pollInterval = pollInterval,
       _pollTimeout = pollTimeout,
       super(
         initialConnections == null
             ? const VideoCrosspostState()
             : VideoCrosspostState(
                 status: VideoCrosspostStatus.ready,
                 connections: initialConnections,
                 selectedPlatforms: {
                   for (final connection in initialConnections)
                     if (connection.isConnected) connection.platform.wireName,
                 },
               ),
       );

  final CrosspostingApiClient _client;
  final String _eventId;
  final Duration _pollInterval;
  final Duration _pollTimeout;

  Timer? _pollTimer;

  Future<void> loadConnections() async {
    emit(state.copyWith(status: VideoCrosspostStatus.loadingConnections));
    try {
      final connections = await _client.getConnections();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: VideoCrosspostStatus.ready,
          connections: connections,
          selectedPlatforms: {
            for (final connection in connections)
              if (connection.isConnected) connection.platform.wireName,
          },
        ),
      );
    } on CrosspostingApiException catch (e, stackTrace) {
      Log.error(
        'Failed to load crossposter connections',
        name: 'VideoCrosspostCubit',
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(status: VideoCrosspostStatus.connectionsFailed));
    }
  }

  void togglePlatform(String platform) {
    if (state.status != VideoCrosspostStatus.ready) return;
    final selected = {...state.selectedPlatforms};
    if (!selected.remove(platform)) selected.add(platform);
    emit(state.copyWith(selectedPlatforms: selected));
  }

  /// Fire the crosspost request, then poll until every job reaches a
  /// terminal state. Safe to call again after a failure.
  Future<void> submit() async {
    final platforms = state.selectedPlatforms.toList();
    if (platforms.isEmpty) return;
    emit(state.copyWith(status: VideoCrosspostStatus.submitting));
    try {
      final jobs = await _client.createCrossposts(
        eventId: _eventId,
        platforms: platforms,
      );
      if (isClosed) return;
      _onJobsUpdated(jobs);
    } on CrosspostingApiException catch (e, stackTrace) {
      Log.error(
        'Crosspost submit failed',
        name: 'VideoCrosspostCubit',
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: VideoCrosspostStatus.submitFailed,
          submitError: _submitErrorFor(e),
        ),
      );
    }
  }

  void _onJobsUpdated(List<CrosspostJob> jobs) {
    final pending = jobs.any((j) => j.status.isPending);
    emit(
      state.copyWith(
        status: pending
            ? VideoCrosspostStatus.polling
            : VideoCrosspostStatus.finished,
        jobs: jobs,
      ),
    );
    if (pending) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    final maxTicks =
        _pollTimeout.inMilliseconds ~/
        (_pollInterval.inMilliseconds == 0 ? 1 : _pollInterval.inMilliseconds);
    var ticks = 0;
    // Timer-based polling: the crossposter has no push channel for job
    // progress, so the client refreshes on a fixed cadence.
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      ticks += 1;
      if (ticks > maxTicks) {
        _stopPolling();
        if (!isClosed && state.hasPendingJobs) {
          emit(
            state.copyWith(
              status: VideoCrosspostStatus.finished,
              pollTimedOut: true,
            ),
          );
        }
        return;
      }
      try {
        final jobs = await _client.getCrossposts(eventId: _eventId);
        if (isClosed || _pollTimer == null) return;
        final pending = jobs.any((j) => j.status.isPending);
        emit(
          state.copyWith(
            status: pending
                ? VideoCrosspostStatus.polling
                : VideoCrosspostStatus.finished,
            jobs: jobs,
          ),
        );
        if (!pending) _stopPolling();
      } on CrosspostingApiException catch (e, stackTrace) {
        // Transient poll failure — keep the timer running and retry on
        // the next tick.
        Log.warning(
          'Crosspost poll failed, will retry: $e',
          name: 'VideoCrosspostCubit',
        );
        addError(e, stackTrace);
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  VideoCrosspostSubmitError _submitErrorFor(CrosspostingApiException e) =>
      switch (e.code) {
        'not_owner' => VideoCrosspostSubmitError.notOwner,
        'not_eligible' => VideoCrosspostSubmitError.notEligible,
        'not_connected' => VideoCrosspostSubmitError.notConnected,
        'unauthorized' => VideoCrosspostSubmitError.unauthorized,
        _ => VideoCrosspostSubmitError.network,
      };

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
