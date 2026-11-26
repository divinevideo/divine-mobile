part of 'sound_waveform_bloc.dart';

/// State for sound waveform bloc.
sealed class SoundWaveformState extends Equatable {
  const SoundWaveformState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no waveform loaded.
class SoundWaveformInitial extends SoundWaveformState {
  const SoundWaveformInitial();
}

/// Waveform extraction in progress.
class SoundWaveformLoading extends SoundWaveformState {
  const SoundWaveformLoading();
}

/// Waveform data loaded successfully.
///
/// Overrides [operator ==] and [hashCode] directly instead of
/// relying on [Equatable]'s props because [Float32List] uses identity
/// for its own `==`. While Equatable 2.0.8's `objectsEquals`
/// recognises typed lists as [Iterable] and compares element-wise,
/// that is an implementation detail. Explicit overrides make the
/// value-equality contract obvious and version-proof.
class SoundWaveformLoaded extends SoundWaveformState {
  const SoundWaveformLoaded({
    required this.leftChannel,
    required this.duration,
    this.rightChannel,
    this.isComplete = true,
    this.readFraction = 1,
  });

  /// Left channel amplitude samples.
  final Float32List leftChannel;

  /// Right channel amplitude samples (null for mono).
  final Float32List? rightChannel;

  /// Duration of the audio.
  final Duration duration;

  /// Whether the whole sound has been read. Until then the channels span the
  /// whole [duration], and the samples not read yet are zero.
  final bool isComplete;

  /// How much of the sound has been read, from 0 to 1: the channels hold
  /// real samples up to this share of their length.
  final double readFraction;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SoundWaveformLoaded) return false;
    return _float32ListEquals(leftChannel, other.leftChannel) &&
        _float32ListEquals(rightChannel, other.rightChannel) &&
        duration == other.duration &&
        isComplete == other.isComplete &&
        readFraction == other.readFraction;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(leftChannel),
    rightChannel == null ? null : Object.hashAll(rightChannel!),
    duration,
    isComplete,
    readFraction,
  );

  /// Props is empty because equality is handled by the overrides
  /// above. Kept to satisfy the [Equatable] contract.
  @override
  List<Object?> get props => [];
}

/// Waveform extraction failed.
///
/// Carries no message: nothing renders one (the audio progress bar collapses
/// this and [SoundWaveformLoading] onto the same placeholder), and
/// `state_management.md` forbids error strings in state. The underlying
/// exception reaches diagnostics through `addError` in the bloc.
class SoundWaveformError extends SoundWaveformState {
  const SoundWaveformError();
}

/// Element-wise equality for nullable [Float32List] values.
bool _float32ListEquals(Float32List? a, Float32List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
