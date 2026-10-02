// ABOUTME: Bloc behind the voice-effect sheet of a voice-over track: loops an
// ABOUTME: audition of every setting and bakes the kept one into the take.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent, VoiceEffect;
import 'package:openvine/blocs/video_editor/voice_over_effect/voice_over_effect_preset.dart';
import 'package:openvine/services/video_editor/voice_over_effect_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'voice_over_effect_event.dart';
part 'voice_over_effect_state.dart';

/// Lets the creator hear and pick a voice effect and noise reduction for one
/// voice-over [VoiceOverEffectState.track], and bakes the pick into the take
/// once they confirm.
///
/// Every setting is looped over the stretch of the take the track plays on
/// the timeline, so it is heard before it is kept. Any setting but the take as
/// recorded and the one the track already plays is rendered first, and a
/// newer setting cancels the rendering of an older one.
///
/// The baked track lands in [VoiceOverEffectState.result] under a new id:
/// timeline waveforms and the preview's audio are keyed by track id, and
/// [AudioEvent] equality ignores the file, so a track whose file changed in
/// place would keep showing and playing the old one.
class VoiceOverEffectBloc
    extends Bloc<VoiceOverEffectEvent, VoiceOverEffectState> {
  /// Creates the bloc for [track], starting from its current setting.
  ///
  /// [service] and [player] default to real instances so the UI can construct
  /// the bloc without importing the service layer; tests inject fakes. The
  /// bloc owns [player] and disposes it on close. [clock] stamps the baked
  /// track's id.
  VoiceOverEffectBloc({
    required AudioEvent track,
    VoiceOverEffectService? service,
    AudioClipPlayer? player,
    DateTime Function()? clock,
  }) : _service = service ?? VoiceOverEffectService(),
       _player = player ?? AudioClipPlayer(),
       _clock = clock ?? DateTime.now,
       super(
         VoiceOverEffectState(
           track: track,
           effect: track.voiceEffect,
           noiseReduction: track.noiseReduction,
         ),
       ) {
    on<VoiceOverEffectSettingsChanged>(
      _onSettingsChanged,
      transformer: restartable(),
    );
    on<VoiceOverEffectApplyRequested>(
      _onApplyRequested,
      transformer: droppable(),
    );
    // The clipped source loops by hand: ClippingAudioSource with
    // LoopMode.one is unreliable (see AudioTimingCubit).
    _loopSubscription = _player.completionStream.listen(
      (_) => runDetached(
        _restartAudition(),
        'restart voice-effect audition',
        logName: _logName,
        category: LogCategory.video,
      ),
    );
  }

  final VoiceOverEffectService _service;
  final AudioClipPlayer _player;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _loopSubscription;

  static const _logName = 'VoiceOverEffectBloc';

  /// Matches the suffix an earlier pick left on a track id, so repeated
  /// changes replace it instead of growing the id each time.
  static final _effectIdSuffix = RegExp(r'_fx\d+$');

  Future<void> _onSettingsChanged(
    VoiceOverEffectSettingsChanged event,
    Emitter<VoiceOverEffectState> emit,
  ) async {
    if (_isFinishing) return;
    final effect = event.effect ?? state.effect;
    final noiseReduction = event.noiseReduction ?? state.noiseReduction;
    emit(
      state.copyWith(
        effect: effect,
        noiseReduction: noiseReduction,
        status: VoiceOverEffectStatus.editing,
      ),
    );
    final track = state.track;
    final takePath = track.originalLocalFilePath;
    if (!event.audition || takePath == null) return;

    try {
      // The file the track already plays, and the take as recorded, need no
      // rendering.
      final String audition;
      var rendered = false;
      if (effect == track.voiceEffect &&
          noiseReduction == track.noiseReduction) {
        audition = track.localFilePath!;
      } else if (effect.isNone && !noiseReduction) {
        audition = takePath;
      } else {
        audition = await _service.renderAudition(
          takePath: takePath,
          effect: effect,
          noiseReduction: noiseReduction,
        );
        rendered = true;
      }
      // A newer setting, the creator confirming, or the sheet closing has
      // overtaken this one while it rendered.
      if (emit.isDone || _isFinishing) {
        if (rendered) await _service.discardAudition(audition);
        return;
      }
      await _loop(audition);
      final previous = state.auditionPath;
      emit(state.copyWith(auditionPath: audition));
      if (previous != null && previous != audition) {
        await _service.discardAudition(previous);
      }
    } on VoiceOverEffectException catch (e, stackTrace) {
      // Expected failure (decode / file IO), so not reportable.
      addError(e, stackTrace);
      emit(state.copyWith(status: VoiceOverEffectStatus.failure));
    } on Exception catch (e, stackTrace) {
      // The player could not open the audition; the setting can still be
      // kept, it just cannot be heard here.
      Log.warning(
        'Failed to play voice-effect audition: $e',
        name: _logName,
        category: LogCategory.video,
      );
      addError(e, stackTrace);
    }
  }

  Future<void> _onApplyRequested(
    VoiceOverEffectApplyRequested event,
    Emitter<VoiceOverEffectState> emit,
  ) async {
    if (_isFinishing) return;
    final track = state.track;
    final takePath = track.originalLocalFilePath;
    // The status changes before the audition stops, so one that finishes
    // rendering meanwhile sees it and discards itself instead of playing on.
    if (!state.hasChanges || takePath == null) {
      emit(state.copyWith(status: VoiceOverEffectStatus.done));
      await _stopAudition();
      return;
    }

    emit(state.copyWith(status: VoiceOverEffectStatus.applying));
    await _stopAudition();
    try {
      final processed = await _service.process(
        takePath: takePath,
        effect: state.effect,
        noiseReduction: state.noiseReduction,
      );
      final isTake = processed.path == takePath;
      final baseId = track.id.replaceFirst(_effectIdSuffix, '');
      emit(
        state.copyWith(
          status: VoiceOverEffectStatus.done,
          result: track.copyWith(
            id: '${baseId}_fx${_clock().microsecondsSinceEpoch}',
            url: processed.path,
            mimeType: processed.mimeType,
            voiceEffect: state.effect,
            noiseReduction: state.noiseReduction,
            originalUrl: isTake ? null : takePath,
            clearOriginalUrl: isTake,
          ),
        ),
      );
    } on VoiceOverEffectException catch (e, stackTrace) {
      // Expected failure (decode / file IO), so not reportable: the sheet
      // stays open on a failure status and the creator can try again.
      addError(e, stackTrace);
      emit(state.copyWith(status: VoiceOverEffectStatus.failure));
    }
  }

  /// Loops [path] over the stretch of the take the track plays.
  Future<void> _loop(String path) async {
    final track = state.track;
    final end = track.endTime;
    final length = end == null || end <= track.startTime
        ? null
        : end - track.startTime;
    await _player.setClip(
      AudioSourceConfig.file(
        path,
        start: track.startOffset,
        end: length == null ? null : track.startOffset + length,
      ),
    );
    await _player.play();
  }

  /// Whether the creator confirmed, after which no setting is taken or heard.
  bool get _isFinishing =>
      state.isApplying || state.status == VoiceOverEffectStatus.done;

  Future<void> _restartAudition() async {
    if (isClosed || _isFinishing) return;
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _stopAudition() async {
    try {
      await _player.stop();
    } on Exception catch (e) {
      Log.warning(
        'Failed to stop voice-effect audition: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  @override
  Future<void> close() async {
    await _loopSubscription.cancel();
    // Closed first, so an audition still rendering finds its handler done and
    // discards itself, instead of playing on the released player or landing
    // after the auditions were cleared.
    await super.close();
    await _player.dispose();
    await _service.clearAuditions();
  }
}
