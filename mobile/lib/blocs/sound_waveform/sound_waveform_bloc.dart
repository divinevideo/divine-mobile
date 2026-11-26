// ABOUTME: BLoC for extracting audio waveform data from sounds.
// ABOUTME: Uses ProVideoEditor to extract amplitude samples for visualization.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent, AudioSourceKind;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'sound_waveform_event.dart';
part 'sound_waveform_state.dart';

/// BLoC for managing sound waveform extraction.
///
/// Handles:
/// - Extracting waveform data from audio URLs
/// - Providing both left and right channel data for stereo visualization
/// - Showing a long sound's waveform as it is read, from its start
/// - Caching results until cleared
class SoundWaveformBloc extends Bloc<SoundWaveformEvent, SoundWaveformState> {
  /// Creates the bloc. A network sound is read from the file
  /// [remoteAudioCache] keeps for it, downloaded there unless an earlier
  /// screen already did. On the web, which has no such cache, the editor
  /// reads the URL itself.
  SoundWaveformBloc({RemoteAudioCache? remoteAudioCache})
    : _remoteAudioCache =
          remoteAudioCache ?? (kIsWeb ? null : RemoteAudioCache()),
      super(const SoundWaveformInitial()) {
    on<SoundWaveformExtract>(_onExtract, transformer: restartable());
    on<SoundWaveformClear>(_onClear);
  }

  final RemoteAudioCache? _remoteAudioCache;

  /// Emits the waveform as the editor reads it, from the start of the sound
  /// on, so a long song shows its opening seconds at once instead of after
  /// the whole file is read.
  Future<void> _onExtract(
    SoundWaveformExtract event,
    Emitter<SoundWaveformState> emit,
  ) async {
    emit(const SoundWaveformLoading());

    try {
      final video = await _videoFor(event);
      final waveform = _ProgressiveWaveform();
      await for (final chunk in ProVideoEditor.instance.getWaveformStream(
        WaveformConfigs(video: video),
      )) {
        waveform.add(chunk);
        if (chunk.isComplete) break;
        emit(waveform.toState(isComplete: false));
      }
      final loaded = waveform.toState(isComplete: true);
      emit(loaded);

      Log.debug(
        'Waveform extracted: ${loaded.leftChannel.length} samples',
        name: 'SoundWaveformBloc',
        category: LogCategory.video,
      );
    } catch (e, s) {
      Log.error(
        'Failed to extract waveform: $e',
        name: 'SoundWaveformBloc',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
      addError(e, s);
      emit(const SoundWaveformError());
    }
  }

  Future<EditorVideo> _videoFor(SoundWaveformExtract event) async {
    switch (event.kind) {
      case AudioSourceKind.asset:
        return EditorVideo.asset(event.path);
      case AudioSourceKind.file:
        return EditorVideo.file(File(event.path));
      case AudioSourceKind.network:
        final cache = _remoteAudioCache;
        if (cache == null) return EditorVideo.network(event.path);
        // The editor would download a URL again on every read; the cache
        // keeps the file a preview or an earlier screen already fetched.
        return EditorVideo.file(await cache.fileFor(Uri.parse(event.path)));
    }
  }

  void _onClear(SoundWaveformClear event, Emitter<SoundWaveformState> emit) {
    emit(const SoundWaveformInitial());
  }
}

/// The samples of a waveform stream received so far, in place.
///
/// Sized for the whole sound from the first piece on, so a waveform drawn
/// from it puts each sample where it belongs in time; samples not read yet
/// are zero, drawn as silence.
class _ProgressiveWaveform {
  Float32List _left = Float32List(0);
  Float32List? _right;

  /// Where the samples received so far end.
  int _received = 0;
  Duration _duration = Duration.zero;

  /// Puts [chunk]'s samples in place.
  void add(WaveformChunk chunk) {
    _duration = chunk.totalDuration;
    // The sample count the editor allocates for the sound's duration.
    final expected =
        chunk.totalDuration.inMicroseconds *
        chunk.samplesPerSecond ~/
        Duration.microsecondsPerSecond;
    final length = math.max(expected, chunk.endIndex);
    _left = _sized(_left, length)
      ..setRange(chunk.startIndex, chunk.endIndex, chunk.leftChannel);
    final right = chunk.rightChannel;
    if (right != null || _right != null) {
      _right = _sized(_right ?? Float32List(0), length);
      if (right != null) {
        _right!.setRange(chunk.startIndex, chunk.endIndex, right);
      }
    }
    _received = math.max(_received, chunk.endIndex);
  }

  static Float32List _sized(Float32List samples, int length) {
    if (samples.length >= length) return samples;
    return Float32List(length)..setAll(0, samples);
  }

  /// A copy of the waveform: all of it while it is still being read, or
  /// only the samples read once [isComplete], as the editor ends a waveform
  /// where the decoded audio ends.
  SoundWaveformLoaded toState({required bool isComplete}) {
    final length = isComplete ? _received : _left.length;
    final right = _right;
    return SoundWaveformLoaded(
      leftChannel: _left.sublist(0, length),
      rightChannel: right?.sublist(0, length),
      duration: _duration,
      isComplete: isComplete,
    );
  }
}
