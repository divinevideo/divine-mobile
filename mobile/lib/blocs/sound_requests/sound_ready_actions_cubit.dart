// ABOUTME: Verifies current audio permission before requester use/save effects.
// ABOUTME: Stops actions when the signed-in account changes during resolution.
import 'package:bloc/bloc.dart';
import 'package:models/models.dart';

enum SoundReadyActionStatus { idle, working, done, failed }

class SoundReadyActionsCubit extends Cubit<SoundReadyActionStatus> {
  SoundReadyActionsCubit({
    required Future<AudioEvent?> Function() resolveSound,
    required bool Function() isCurrentAccount,
  }) : _resolveSound = resolveSound,
       _isCurrentAccount = isCurrentAccount,
       super(SoundReadyActionStatus.idle);
  final Future<AudioEvent?> Function() _resolveSound;
  final bool Function() _isCurrentAccount;
  Future<void> use(Future<void> Function(AudioEvent) openRecorder) =>
      _perform(openRecorder);
  Future<void> save(Future<void> Function(AudioEvent) saveToLibrary) =>
      _perform(saveToLibrary);
  Future<void> _perform(Future<void> Function(AudioEvent) effect) async {
    if (isClosed ||
        state == SoundReadyActionStatus.working ||
        !_isCurrentAccount()) {
      return;
    }
    emit(SoundReadyActionStatus.working);
    try {
      final sound = await _resolveSound();
      if (isClosed || !_isCurrentAccount()) return;
      if (sound == null) {
        emit(SoundReadyActionStatus.failed);
        return;
      }
      await effect(sound);
      if (!isClosed && _isCurrentAccount()) emit(SoundReadyActionStatus.done);
    } on Object catch (error, stack) {
      if (!isClosed && _isCurrentAccount()) {
        addError(error, stack);
        emit(SoundReadyActionStatus.failed);
      }
    }
  }
}
