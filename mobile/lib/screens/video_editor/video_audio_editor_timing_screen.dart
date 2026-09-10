// ABOUTME: Screen for adjusting audio timing/offset for video editor.
// ABOUTME: Displays video preview with audio segment selector overlay.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_editor/audio_timing/audio_timing_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:sound_service/sound_service.dart';

/// Result of the audio timing screen.
///
/// Returned via [Navigator.pop] to indicate whether the user confirmed
/// the timing selection or deleted the audio.
sealed class AudioTimingResult {
  const AudioTimingResult();
}

/// User confirmed the audio timing selection.
class AudioTimingConfirmed extends AudioTimingResult {
  /// Creates a confirmed result with the updated sound.
  const AudioTimingConfirmed(this.sound);

  /// The sound with updated [AudioEvent.startOffset].
  final AudioEvent sound;
}

/// User deleted the audio.
class AudioTimingDeleted extends AudioTimingResult {
  /// Creates a deleted result.
  const AudioTimingDeleted();
}

/// Screen for adjusting audio timing/offset in the video editor.
///
/// This screen is shown after selecting audio, allowing users to
/// set the start position of the audio track relative to the video.
///
/// Returns an [AudioTimingResult] via [Navigator.pop]:
/// - [AudioTimingConfirmed] with the updated sound when confirmed
/// - [AudioTimingDeleted] when the user deletes the audio
/// - `null` when cancelled (back navigation)
class VideoAudioEditorTimingScreen extends StatefulWidget {
  /// Creates the audio timing screen.
  const VideoAudioEditorTimingScreen({
    required this.sound,
    this.enableDeleteButton = true,
    @visibleForTesting this.clipPlayer,
    super.key,
  });

  /// The sound to edit timing for.
  final AudioEvent sound;

  /// Whether the delete button is shown in the toolbar.
  final bool enableDeleteButton;

  /// Optional audio clip player override for tests.
  @visibleForTesting
  final AudioClipPlayer? clipPlayer;

  /// Route name for navigation.
  static const routeName = 'video-audio-timing';

  /// Route path.
  static const path = '/video-audio-timing';

  @visibleForTesting
  static const videoDurationSegmentKey = Key(
    'video-audio-timing-video-duration-segment',
  );

  @visibleForTesting
  static const waveformSelectionKey = Key(
    'video-audio-timing-waveform-selection',
  );

  @override
  State<VideoAudioEditorTimingScreen> createState() =>
      _VideoAudioEditorTimingScreenState();
}

class _VideoAudioEditorTimingScreenState
    extends State<VideoAudioEditorTimingScreen>
    with SingleTickerProviderStateMixin {
  late final SoundWaveformBloc _waveformBloc;
  late final AnimationController _flingController;
  late final AudioTimingCubit _audioTimingCubit;

  /// Friction for momentum scrolling (higher = stops faster).
  static const double _friction = 0.015;

  @override
  void initState() {
    super.initState();
    _waveformBloc = SoundWaveformBloc();
    _flingController = AnimationController.unbounded(vsync: this);
    _flingController.addListener(_onFlingUpdate);
    _audioTimingCubit = AudioTimingCubit(
      sound: widget.sound,
      clipPlayer: widget.clipPlayer,
    );

    // Delay initialization until after first frame
    addPostFrameCallbackIfMounted(() {
      // Sync fling controller with initial offset after cubit initializes
      _audioTimingCubit.initialize().then((_) {
        if (mounted) {
          _flingController.value = _audioTimingCubit.state.startOffset;
        }
      });

      _extractWaveform();
    });
  }

  @override
  void dispose() {
    _flingController
      ..removeListener(_onFlingUpdate)
      ..dispose();
    _waveformBloc.close();
    _audioTimingCubit.close();
    super.dispose();
  }

  void _onFlingUpdate() {
    final offset = _flingController.value.clamp(0.0, 1.0);
    _audioTimingCubit.updateOffset(offset);
    // Resume audio at end of fling (when velocity approaches 0)
    if (_flingController.velocity.abs() < 0.001) {
      _audioTimingCubit.resumePlayback();
    }
  }

  void _handleFling(double velocity) {
    // If velocity is too low, just resume audio immediately
    if (velocity.abs() < 0.01) {
      _audioTimingCubit.resumePlayback();
      return;
    }

    // Convert velocity to offset units (normalized 0-1 range)
    // Positive velocity = moving right/forward in audio
    final simulation = FrictionSimulation(
      _friction,
      _audioTimingCubit.state.startOffset,
      velocity,
    );
    _flingController.animateWith(simulation);
  }

  void _handleOffsetChanged(double offset) {
    _flingController.stop();
    _audioTimingCubit.updateOffset(offset);
  }

  /// Pauses audio playback when dragging starts.
  void _handleDragStart() {
    _audioTimingCubit.pausePlayback();
  }

  /// Called from onDragEnd — audio resume is handled by _handleFling.
  void _handleDragEnd() {
    // Audio resume is handled by _handleFling / _onFlingUpdate
  }

  void _extractWaveform() {
    final event = SoundWaveformExtract.forSound(widget.sound);
    if (event != null) {
      _waveformBloc.add(event);
    }
  }

  Future<void> _deleteAudio() async {
    await _audioTimingCubit.stopPlayback();
    if (mounted) context.pop<AudioTimingResult>(const AudioTimingDeleted());
  }

  Future<void> _confirmSelection() async {
    await _audioTimingCubit.stopPlayback();
    final startOffset = _audioTimingCubit.calculateStartOffset();
    // Persist the resolved duration when the source AudioEvent did not
    // carry one (common for sounds coming from Nostr).
    final resolvedDuration =
        widget.sound.duration ?? _audioTimingCubit.state.audioDuration;
    final updatedSound = widget.sound.copyWith(
      startOffset: startOffset,
      duration: resolvedDuration,
    );
    if (mounted) {
      context.pop<AudioTimingResult>(AudioTimingConfirmed(updatedSound));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _waveformBloc),
        BlocProvider.value(value: _audioTimingCubit),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: VineTheme.transparent,
          systemNavigationBarColor: VineTheme.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: VineTheme.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: VineTheme.scrim65),

              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    VideoEditorToolbar(
                      closeIcon: widget.enableDeleteButton ? .trash : .x,
                      closeType: widget.enableDeleteButton
                          ? .error
                          : .ghostOverMedia,
                      closeSemanticLabel: widget.enableDeleteButton
                          ? context.l10n.videoEditorRemoveAudioSemanticLabel
                          : context.l10n
                                .videoEditorDiscardToolChangesSemanticLabel(
                                  context.l10n.videoEditorAudioLabel,
                                ),
                      doneSemanticLabel: context.l10n
                          .videoEditorApplyToolChangesSemanticLabel(
                            context.l10n.videoEditorAudioLabel,
                          ),
                      onClose: widget.enableDeleteButton
                          ? _deleteAudio
                          : context.pop,
                      onDone: _confirmSelection,
                      center: Flexible(
                        child: IgnorePointer(
                          child: VideoEditorAudioChip(
                            selectedSound: widget.sound,
                            onSoundChanged: (_) {},
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Bottom controls
                    BlocBuilder<AudioTimingCubit, AudioTimingState>(
                      builder: (context, timingState) {
                        return _BottomControls(
                          startOffset: timingState.startOffset,
                          audioDuration: timingState.audioDuration,
                          onOffsetChanged: _handleOffsetChanged,
                          onFling: _handleFling,
                          onDragStart: _handleDragStart,
                          onDragEnd: _handleDragEnd,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom controls with instruction text and timeline selector.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.startOffset,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Instruction text
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(
            context.l10n.videoEditorAudioSegmentInstruction,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: .center,
          ),
        ),

        const SizedBox(height: 28),

        // Video duration timeline (top bar with green segment)
        _VideoDurationTimeline(
          startOffset: startOffset,
          audioDuration: audioDuration,
          onOffsetChanged: onOffsetChanged,
          onFling: onFling,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        ),

        const SizedBox(height: 18),

        // Audio waveform with draggable selection
        _AudioWaveformSelector(
          startOffset: startOffset,
          audioDuration: audioDuration,
          onOffsetChanged: onOffsetChanged,
          onFling: onFling,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        ),
      ],
    );
  }
}

/// [VideoEditorConstants.maxDuration] expressed in seconds.
double get _maxDurationSecs =>
    VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;

/// Converts [seconds] of audio into a [Duration].
Duration _secondsToDuration(double seconds) =>
    Duration(milliseconds: (seconds * 1000).toInt());

/// Width of the marker representing [VideoEditorConstants.maxDuration] of audio
/// on a bar where [trackWidth] pixels span [audioDurationSecs] of audio.
///
/// [minWidth] floors the result — the two callers floor it for unrelated
/// reasons (visibility above, scrub resolution below), so the floor stays at
/// the call site rather than being baked in here.
double _maxDurationSegmentWidth({
  required double trackWidth,
  required double audioDurationSecs,
  required double minWidth,
}) {
  if (audioDurationSecs <= _maxDurationSecs) return trackWidth;
  return (trackWidth * _maxDurationSecs / audioDurationSecs).clamp(
    math.min(minWidth, trackWidth),
    trackWidth,
  );
}

/// Video duration timeline showing where the selected segment will play.
class _VideoDurationTimeline extends StatelessWidget {
  const _VideoDurationTimeline({
    required this.startOffset,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  /// Smallest the segment marker may be drawn.
  ///
  /// Keeps it visible on very long tracks, where its true share of the bar
  /// falls below a few pixels.
  static const double _minSegmentWidth = 12;

  final double startOffset;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;

  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width - 32;
    final audioDurationSecs = audioDuration ?? 0;

    // This bar spans the whole track, so the marker's share of it is the
    // segment's true share of the audio — the waveform below owns scrub
    // precision and sets its own zoom independently.
    final segmentWidth = _maxDurationSegmentWidth(
      trackWidth: screenWidth,
      audioDurationSecs: audioDurationSecs,
      minWidth: _minSegmentWidth,
    );

    // Scrollable distance lets the segment's left edge reach
    // `audioDuration - minRemainingAudio`, so users can pick a late start
    // even when the trailing audio is shorter than the video duration.
    // `screenWidth` represents `audioDurationSecs` worth of time, so the
    // minimum-remaining slice occupies this many pixels on screen.
    final double maxScrollableDistance;
    if (audioDurationSecs <= 0 ||
        audioDurationSecs <= AudioTimingCubit.minRemainingAudioSecs) {
      maxScrollableDistance = 0;
    } else {
      final minRemainingWidth =
          screenWidth *
          (AudioTimingCubit.minRemainingAudioSecs / audioDurationSecs);
      maxScrollableDistance = (screenWidth - minRemainingWidth).clamp(
        0.0,
        double.infinity,
      );
    }

    final segmentLeft = startOffset * maxScrollableDistance;
    // Shrink the segment when the remaining audio is shorter than the video's
    // max duration, mirroring how [AudioTimingCubit] clamps the playable clip
    // to the tail of the source.
    final effectiveSegmentWidth = segmentWidth.clamp(
      0.0,
      (screenWidth - segmentLeft).clamp(0.0, double.infinity),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (details) {
        // Don't allow scrolling if selection fills the timeline
        if (maxScrollableDistance < 1) return;

        final delta = details.delta.dx;
        // Dragging right increases offset (moves segment right)
        final newOffset = (startOffset + delta / maxScrollableDistance).clamp(
          0.0,
          1.0,
        );
        onOffsetChanged(newOffset);
      },
      onHorizontalDragEnd: (details) {
        onDragEnd();
        if (maxScrollableDistance < 1) {
          // No scrolling possible, but still resume audio
          onFling(0);
          return;
        }
        // Convert velocity from pixels to normalized offset units
        final velocityInOffset =
            (details.primaryVelocity ?? 0) / maxScrollableDistance / 1000;
        onFling(velocityInOffset);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: VineTheme.scrim65,
                borderRadius: .circular(4),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: segmentLeft,
                    child: Container(
                      key: VideoAudioEditorTimingScreen.videoDurationSegmentKey,
                      width: effectiveSegmentWidth,
                      height: 8,
                      decoration: BoxDecoration(
                        color: VineTheme.vineGreen,
                        borderRadius: BorderRadius.circular(4),
                        border: .all(
                          color: VineTheme.accentYellow,
                          width: 4,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Audio waveform with draggable green selection area.
class _AudioWaveformSelector extends StatelessWidget {
  const _AudioWaveformSelector({
    required this.startOffset,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width - 32;
    final audioDurationSecs = audioDuration ?? 0;

    // Zoom is chosen for scrub precision, not to mirror the overview bar above.
    // `selectionWidth` pixels always represent [VideoEditorConstants.maxDuration]
    // of audio, so one pixel of drag moves the in-point by
    // `maxDuration / selectionWidth` seconds. Flooring that width at one pixel
    // per frame keeps the in-point resolvable on the same grid the timeline
    // ruler labels; a purely proportional width collapses on long tracks, where
    // a single pixel used to jump roughly six frames.
    final selectionWidth = _maxDurationSegmentWidth(
      trackWidth: screenWidth,
      audioDurationSecs: audioDurationSecs,
      minWidth: _maxDurationSecs * VideoEditorConstants.editorFps,
    );
    // Selection is always centered
    final selectionLeft = (screenWidth - selectionWidth) / 2;

    // Every length below is derived from this one scale, so the bars, the
    // scrollable range and the shrinking tail cannot disagree about where a
    // second of audio sits.
    final pixelsPerSecond = selectionWidth / _maxDurationSecs;

    // The canvas spans whichever is longer, the track or the video window:
    // audio shorter than the video leaves the remainder to the painter's
    // placeholder bars.
    final waveformSpanSecs = math.max(audioDurationSecs, _maxDurationSecs);
    final fullWaveformWidth = waveformSpanSecs * pixelsPerSecond;

    // On-screen extent of the audio itself. Until the duration resolves there
    // is nothing to measure it against, so the placeholder canvas stands in.
    final trackWidth = audioDurationSecs > 0
        ? audioDurationSecs * pixelsPerSecond
        : fullWaveformWidth;

    // The in-point ranges from 0 to `audioDuration - minRemainingAudio`, so
    // the waveform scrolls by exactly that much audio — users can pick a late
    // start even when the trailing audio is shorter than the video.
    final maxScrollableDistance =
        ((audioDurationSecs - AudioTimingCubit.minRemainingAudioSecs) *
                pixelsPerSecond)
            .clamp(0.0, double.infinity);

    // Waveform position: at offset 0 the track starts at the selection's left
    // edge; at offset 1 only `minRemainingAudio` is left inside it.
    final waveformLeft = selectionLeft - startOffset * maxScrollableDistance;

    // Shrink the green selection to the audio still under it, so the box
    // matches the actual playable clip (mirrors
    // [AudioTimingCubit._setClippedAudioSource]'s end clamp).
    final remainingSelectionWidth = (waveformLeft + trackWidth - selectionLeft)
        .clamp(0.0, double.infinity);
    final effectiveSelectionWidth = math.min(
      selectionWidth,
      remainingSelectionWidth,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (details) {
        // Don't allow scrolling if selection fills the waveform
        if (maxScrollableDistance < 1) return;

        final delta = details.delta.dx;
        // Invert delta: dragging right scrolls waveform left (increases offset)
        final newOffset = (startOffset - delta / maxScrollableDistance).clamp(
          0.0,
          1.0,
        );
        onOffsetChanged(newOffset);
      },
      onHorizontalDragEnd: (details) {
        onDragEnd();
        if (maxScrollableDistance < 1) {
          // No scrolling possible, but still resume audio
          onFling(0);
          return;
        }
        // Convert velocity from pixels to normalized offset units
        // Invert velocity to match inverted drag direction
        final velocityInOffset =
            -(details.primaryVelocity ?? 0) / maxScrollableDistance / 1000;
        onFling(velocityInOffset);
      },
      child: Container(
        padding: const .fromLTRB(16, 8, 16, 11),
        height: 85,
        color: context.vineColors.background,
        child: ClipRect(
          child: BlocBuilder<SoundWaveformBloc, SoundWaveformState>(
            builder: (context, waveformState) {
              final (leftChannel, rightChannel) = switch (waveformState) {
                SoundWaveformLoaded(:final leftChannel, :final rightChannel) =>
                  (leftChannel, rightChannel),
                _ => (null, null),
              };

              return Stack(
                children: [
                  // Selection background always centered
                  Positioned(
                    left: selectionLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      key: VideoAudioEditorTimingScreen.waveformSelectionKey,
                      width: effectiveSelectionWidth,
                      decoration: BoxDecoration(
                        color: VineTheme.primary,
                        borderRadius: .circular(24),
                        border: Border.all(
                          color: VineTheme.accentYellow,
                          width: 4,
                        ),
                      ),
                    ),
                  ),

                  // Scrollable waveform (stereo bars) - offset based on selection
                  Positioned(
                    left: waveformLeft,
                    top: 10,
                    bottom: 10,
                    width: fullWaveformWidth,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(leftChannel != null),
                      tween: Tween(begin: 0, end: 1),
                      duration: WaveformConstants.animationDuration,
                      curve: WaveformConstants.animationCurve,
                      builder: (context, heightFactor, child) {
                        // The strip only translates while the user scrubs, so
                        // the boundary lets its raster be reused instead of
                        // re-running a paint that draws one bar per 5px of a
                        // strip many screens wide.
                        return RepaintBoundary(
                          child: ClipRRect(
                            borderRadius: .circular(24),
                            child: SizedBox.expand(
                              child: CustomPaint(
                                painter: StereoWaveformPainter(
                                  leftChannel: leftChannel ?? Float32List(0),
                                  rightChannel: rightChannel,
                                  progress: 1.0, // No progress indicator needed
                                  activeColor: VineTheme.whiteText,
                                  inactiveColor: VineTheme.whiteText,
                                  audioDuration: _secondsToDuration(
                                    audioDurationSecs,
                                  ),
                                  // The canvas is `waveformSpanSecs` wide, not
                                  // one video duration wide — telling the
                                  // painter otherwise stretches the opening
                                  // 6.3s across the whole track.
                                  maxDuration: _secondsToDuration(
                                    waveformSpanSecs,
                                  ),
                                  heightFactor: heightFactor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Selection overlay - always centered
                  Positioned(
                    left: selectionLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: effectiveSelectionWidth,
                      decoration: BoxDecoration(
                        borderRadius: .circular(24),
                        border: Border.all(
                          color: VineTheme.accentYellow,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
