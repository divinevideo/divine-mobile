// ABOUTME: Finds the stretch of a sound that can be heard, from its peak
// ABOUTME: levels, so silent edges can be cut and silent sounds left out.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// The peak level, in dBFS, below which a stretch of sound counts as silent.
///
/// It is ffmpeg's default `silencedetect` threshold. Digital silence, the
/// dither of a 16-bit file and what an AAC encoder leaves of silence all stay
/// near -90 dBFS, well below it, so a muted or soundless recording is always
/// caught. At an ordinary listening volume a -60 dBFS peak plays at about
/// the threshold of hearing, so nothing quieter is lost. It is compared with
/// peaks rather than an average, so a short sound in a quiet stretch still
/// counts as audible.
const double soundSilenceThresholdDbfs = -60;

/// The silence kept before the first and after the last audible moment when
/// a sound's silent edges are cut.
///
/// A soft consonant or the end of a fade can stay under
/// [soundSilenceThresholdDbfs] while still shaping how a sound starts and
/// ends, and a gap shorter than about 200 ms is heard as part of a sound's
/// start rather than as a pause before it.
const Duration soundEdgeMargin = Duration(milliseconds: 200);

/// The part of a sound worth keeping, as offsets into it.
class AudibleRange extends Equatable {
  const AudibleRange({required this.start, required this.end});

  /// Where the kept part starts.
  final Duration start;

  /// Where the kept part ends.
  final Duration end;

  /// How long the kept part is.
  Duration get duration => end - start;

  @override
  List<Object?> get props => [start, end];
}

/// The part of a sound of [duration] to keep, from [soundEdgeMargin] before
/// its first audible block to [soundEdgeMargin] after its last, within the
/// sound; `null` when no block of any channel reaches
/// [soundSilenceThresholdDbfs].
///
/// [channels] holds the peak of every block of each channel, from 0 (silent)
/// to 1 (full scale), [blocksPerSecond] blocks a second, as `getWaveform`
/// measures them. A channel counts on its own, so a sound heard on only one
/// side is not silent.
///
/// Throws an [ArgumentError] when [blocksPerSecond] or [duration] is not
/// positive.
AudibleRange? audibleRange({
  required List<Float32List> channels,
  required int blocksPerSecond,
  required Duration duration,
}) {
  if (blocksPerSecond <= 0) {
    throw ArgumentError.value(blocksPerSecond, 'blocksPerSecond');
  }
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration, 'duration');
  }
  final threshold = math.pow(10, soundSilenceThresholdDbfs / 20);
  final blocks = channels.fold(
    0,
    (most, peaks) => math.max(most, peaks.length),
  );

  bool audible(int block) => channels.any(
    (peaks) => block < peaks.length && peaks[block] >= threshold,
  );

  var first = 0;
  while (first < blocks && !audible(first)) {
    first++;
  }
  if (first == blocks) return null;
  var last = blocks - 1;
  while (!audible(last)) {
    last--;
  }

  Duration at(int block) => Duration(
    microseconds: block * Duration.microsecondsPerSecond ~/ blocksPerSecond,
  );
  Duration within(Duration offset) => offset < Duration.zero
      ? Duration.zero
      : offset > duration
      ? duration
      : offset;
  return AudibleRange(
    start: within(at(first) - soundEdgeMargin),
    end: within(at(last + 1) + soundEdgeMargin),
  );
}
