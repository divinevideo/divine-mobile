// ABOUTME: Presentation actions for the current account's sound requests.
// ABOUTME: Discards results from replaced account-scoped dependencies.
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_state.dart';

export 'sound_requests_state.dart';

class SoundRequestsCubit extends Cubit<SoundRequestsState> {
  SoundRequestsCubit() : super(const SoundRequestsState());
  SoundRequestsRepository? _repository;
  StreamSubscription<SoundRequestSnapshot>? _subscription;

  Future<void> connect(SoundRequestsRepository? repository) async {
    if (identical(_repository, repository)) return;
    _repository = repository;
    emit(SoundRequestsState(ownerPubkey: repository?.ownerPubkey ?? ''));
    await _subscription?.cancel();
    if (isClosed || !identical(_repository, repository) || repository == null) {
      return;
    }
    _subscription = repository.watchState().listen(
      (snapshot) {
        if (!isClosed && identical(_repository, repository)) {
          emit(state.copyWith(snapshot: snapshot));
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!isClosed && identical(_repository, repository)) {
          addError(error, stack);
          emit(state.copyWith(operation: SoundRequestOperation.failed));
        }
      },
    );
    try {
      await repository.start();
    } on Object catch (error, stack) {
      if (!isClosed && identical(_repository, repository)) {
        addError(error, stack);
        emit(state.copyWith(operation: SoundRequestOperation.failed));
      }
    }
  }

  Future<void> loadPreview(String address) async {
    final repository = _repository;
    if (repository == null || state.videos.containsKey(address)) return;
    try {
      final video = await repository.sourceVideo(address);
      if (!isClosed && identical(_repository, repository)) {
        emit(state.copyWith(videos: {...state.videos, address: video}));
      }
    } on Object catch (error, stack) {
      if (!isClosed && identical(_repository, repository)) {
        addError(error, stack);
      }
    }
  }

  Future<AudioEvent?> resolveReady(SoundRequestMessage message) async {
    final repository = _repository;
    if (repository == null) return null;
    final audio = await repository.resolveReady(message);
    return !isClosed && identical(_repository, repository) ? audio : null;
  }

  Future<void> checkEligibility(String address, {bool refresh = false}) async {
    final repository = _repository;
    if (repository == null ||
        (!refresh && state.eligibility.containsKey(address))) {
      return;
    }
    emit(
      state.copyWith(
        eligibility: {
          ...state.eligibility,
          address: SoundRequestEligibility.checking,
        },
      ),
    );
    try {
      final available = await repository.canRequest(address);
      if (!isClosed && identical(_repository, repository)) {
        emit(
          state.copyWith(
            eligibility: {
              ...state.eligibility,
              address: available
                  ? SoundRequestEligibility.available
                  : SoundRequestEligibility.unavailable,
            },
          ),
        );
      }
    } on Object catch (error, stack) {
      if (!isClosed && identical(_repository, repository)) {
        addError(error, stack);
        emit(
          state.copyWith(
            eligibility: {
              ...state.eligibility,
              address: SoundRequestEligibility.failed,
            },
          ),
        );
      }
    }
  }

  Future<bool> _act(
    String target,
    Future<void> Function(SoundRequestsRepository) action,
  ) async {
    final repository = _repository;
    if (repository == null) return false;
    emit(
      state.copyWith(target: target, operation: SoundRequestOperation.working),
    );
    try {
      await action(repository);
      if (isClosed || !identical(_repository, repository)) return false;
      emit(
        state.copyWith(target: target, operation: SoundRequestOperation.sent),
      );
      return true;
    } on Object catch (error, stack) {
      if (!isClosed && identical(_repository, repository)) {
        addError(error, stack);
        emit(
          state.copyWith(
            target: target,
            operation: SoundRequestOperation.failed,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> request(String address) => _act(address, (repository) async {
    await repository.request(address);
  });
  Future<bool> approve(String id) =>
      _act(id, (repository) => repository.approve(id));
  Future<bool> dismiss(String id) =>
      _act(id, (repository) => repository.dismiss(id));
  Future<bool> retry(String id) =>
      _act(id, (repository) => repository.retry(id));
  @override
  Future<void> close() async {
    _repository = null;
    await _subscription?.cancel();
    await super.close();
  }
}
