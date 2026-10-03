// ABOUTME: Bloc behind the voice-effect sheet of a timeline sound: loops an
// ABOUTME: audition of every setting and bakes the kept one into its audio.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioSourceKind, VoiceEffect;
import 'package:openvine/blocs/video_editor/voice_effect/voice_effect_preset.dart';
import 'package:openvine/services/video_editor/voice_effect_service.dart';
import 'package:openvine/utils/audio_mime_type.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'voice_effect_event.dart';
part 'voice_effect_state.dart';

/// Lets the creator hear and pick a voice effect and noise reduction for one
/// timeline sound, [VoiceEffectState.track] — a voice-over, an imported or
/// extracted track, or a bundled, published or provider sound — and bakes the
/// pick into its audio once they confirm.
///
/// Every setting is looped over the stretch of the sound the track plays on
/// the timeline, so it is heard before it is kept. Any setting but the sound
/// as it came and the one the track already plays is rendered first, and a
/// newer setting cancels the rendering of an older one.
///
/// The baked track lands in [VoiceEffectState.result] under a new id:
/// timeline waveforms and the preview's audio are keyed by track id, and
/// [AudioEvent] equality ignores the file, so a track whose file changed in
/// place would keep showing and playing the old one.
class VoiceEffectBloc extends Bloc<VoiceEffectEvent, VoiceEffectState> {
  /// Creates the bloc for [track], starting from its current setting.
  ///
  /// The bloc owns [player] and disposes it on close. [clock] stamps the
  /// baked track's id.
  VoiceEffectBloc({
    required AudioEvent track,
    required VoiceEffectService service,
    required AudioClipPlayer player,
    DateTime Function()? clock,
  }) : _service = service,
       _player = player,
       _clock = clock ?? DateTime.now,
       super(
         VoiceEffectState(
           track: track,
           effect: track.voiceEffect,
           noiseReduction: track.noiseReduction,
         ),
       ) {
    on<VoiceEffectSettingsChanged>(
      _onSettingsChanged,
      transformer: restartable(),
    );
    on<VoiceEffectApplyRequested>(
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

  final VoiceEffectService _service;
  final AudioClipPlayer _player;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _loopSubscription;

  static const _logName = 'VoiceEffectBloc';

  /// Matches the suffix an earlier pick left on a track id, so repeated
  /// changes replace it instead of growing the id each time.
  static final _effectIdSuffix = RegExp(r'_fx\d+$');

  Future<void> _onSettingsChanged(
    VoiceEffectSettingsChanged event,
    Emitter<VoiceEffectState> emit,
  ) async {
    if (_isFinishing) return;
    final effect = event.effect ?? state.effect;
    final noiseReduction = event.noiseReduction ?? state.noiseReduction;
    emit(
      state.copyWith(
        effect: effect,
        noiseReduction: noiseReduction,
        status: VoiceEffectStatus.editing,
      ),
    );
    final track = state.track;
    final source = track.originalSource;
    if (!event.audition || source == null) return;

    try {
      // What the track already plays, and the sound as it came, need no
      // rendering; they loop over the stretch the track plays.
      final AudioSourceConfig audition;
      var rendered = false;
      if (effect == track.voiceEffect &&
          noiseReduction == track.noiseReduction) {
        audition = _stretchOf(track.resolvedSource ?? source);
      } else if (effect.isNone && !noiseReduction) {
        audition = _stretchOf(source);
      } else {
        // Rendered from that stretch only, so it loops whole.
        audition = AudioSourceConfig.file(
          await _service.renderAudition(
            source: source,
            effect: effect,
            noiseReduction: noiseReduction,
            start: track.startOffset,
            length: _stretchLength,
          ),
        );
        rendered = true;
      }
      // A newer setting, the creator confirming, or the sheet closing has
      // overtaken this one while it rendered.
      if (emit.isDone || _isFinishing) {
        if (rendered) await _service.discardAudition(audition.uri);
        return;
      }
      final started = await _loop(audition, isCancelled: () => emit.isDone);
      if (!started || emit.isDone || _isFinishing) {
        if (rendered) await _service.discardAudition(audition.uri);
        return;
      }
      final previous = state.auditionPath;
      emit(state.copyWith(auditionPath: audition.uri));
      if (previous != null && previous != audition.uri) {
        await _service.discardAudition(previous);
      }
    } on VoiceEffectException catch (e, stackTrace) {
      // Expected failure (decode / file IO), so not reportable.
      addError(e, stackTrace);
      emit(state.copyWith(status: VoiceEffectStatus.failure));
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
    VoiceEffectApplyRequested event,
    Emitter<VoiceEffectState> emit,
  ) async {
    if (_isFinishing) return;
    final track = state.track;
    final source = track.originalSource;
    // The status changes before the audition stops, so one that finishes
    // rendering meanwhile sees it and discards itself instead of playing on.
    if (!state.hasChanges || source == null) {
      emit(state.copyWith(status: VoiceEffectStatus.done));
      await _stopAudition();
      return;
    }

    emit(state.copyWith(status: VoiceEffectStatus.applying));
    await _stopAudition();
    try {
      final baseId = track.id.replaceFirst(_effectIdSuffix, '');
      final id = '${baseId}_fx${_clock().microsecondsSinceEpoch}';
      final AudioEvent result;
      if (state.effect.isNone && !state.noiseReduction) {
        result = _unprocessed(track, source).copyWith(id: id);
      } else {
        final processed = await _service.process(
          source: source,
          effect: state.effect,
          noiseReduction: state.noiseReduction,
        );
        result = track.copyWith(
          id: id,
          url: processed.path,
          mimeType: processed.mimeType,
          voiceEffect: state.effect,
          noiseReduction: state.noiseReduction,
          // A track already playing a copy keeps the sound it came from.
          originalUrl: track.playsProcessedCopy ? null : track.url,
          originalMimeType: track.playsProcessedCopy ? null : track.mimeType,
        );
      }
      emit(state.copyWith(status: VoiceEffectStatus.done, result: result));
    } on VoiceEffectException catch (e, stackTrace) {
      // Expected failure (decode / file IO), so not reportable: the sheet
      // stays open on a failure status and the creator can try again.
      addError(e, stackTrace);
      emit(state.copyWith(status: VoiceEffectStatus.failure));
      runDetached(
        _restartAudition(),
        'resume voice-effect audition after a failed save',
        logName: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// [track] playing the sound it was processed from, [source], again.
  static AudioEvent _unprocessed(AudioEvent track, VoiceEffectSource source) {
    // Copies made before the MIME type was kept were all of takes, whose
    // file name still tells it.
    final mimeType =
        track.originalMimeType ??
        (source.kind == AudioSourceKind.file
            ? audioMimeTypeForPath(source.path)
            : null);
    return track.copyWith(
      url: track.originalUrl,
      mimeType: mimeType,
      clearMimeType: mimeType == null,
      voiceEffect: VoiceEffect.none,
      noiseReduction: false,
      clearOriginalUrl: true,
      clearOriginalMimeType: true,
    );
  }

  /// How long the track plays its sound on the timeline, or `null` to the
  /// end of the sound.
  Duration? get _stretchLength {
    final track = state.track;
    final end = track.endTime;
    return end == null || end <= track.startTime ? null : end - track.startTime;
  }

  /// [source], clipped to the stretch of it the track plays.
  AudioSourceConfig _stretchOf(VoiceEffectSource source) {
    final start = state.track.startOffset;
    final length = _stretchLength;
    final end = length == null ? null : start + length;
    return switch (source.kind) {
      AudioSourceKind.asset => AudioSourceConfig.asset(
        source.path,
        start: start,
        end: end,
      ),
      AudioSourceKind.file => AudioSourceConfig.file(
        source.path,
        start: start,
        end: end,
      ),
      AudioSourceKind.network => AudioSourceConfig.network(
        source.path,
        start: start,
        end: end,
      ),
    };
  }

  /// Loops [audition].
  Future<bool> _loop(
    AudioSourceConfig audition, {
    required bool Function() isCancelled,
  }) async {
    await _player.setClip(audition);
    if (isCancelled() || isClosed || _isFinishing) return false;
    // play completes when playback stops, not when it starts. Keep the
    // audition in state immediately so switching settings can reclaim it.
    runDetached(
      _player.play(),
      'play voice-effect audition',
      logName: _logName,
      category: LogCategory.video,
    );
    return true;
  }

  /// Whether the creator confirmed, after which no setting is taken or heard.
  bool get _isFinishing =>
      state.isApplying || state.status == VoiceEffectStatus.done;

  Future<void> _restartAudition() async {
    if (isClosed || _isFinishing || state.auditionPath == null) return;
    await _player.seek(Duration.zero);
    if (isClosed || _isFinishing) return;
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
