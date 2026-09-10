// ABOUTME: Audio progress bar widget for video recorder
// ABOUTME: Shows waveform visualization with recording progress overlay
// ABOUTME: Uses BLoC for waveform state, Riverpod for existing recorder state

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';

/// Audio progress bar that displays waveform with recording progress.
///
/// Shows left channel on top and right channel (mirrored) on bottom.
/// Only visible during active recording when a sound is selected.
///
/// Uses [SoundWaveformBloc] for waveform extraction (new BLoC pattern)
/// and existing Riverpod providers for recorder state (legacy).
class VideoRecorderAudioProgressBar extends ConsumerWidget {
  /// Creates an audio progress bar widget.
  const VideoRecorderAudioProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = context.select(
      (VideoRecorderBloc b) => b.state.isRecording,
    );
    final selectedSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound),
    );

    return Align(
      alignment: .topCenter,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.ease,
          child: !isRecording || selectedSound == null
              ? const SizedBox.shrink(
                  key: ValueKey('Empty-Video-Recorder-Audio-Track'),
                )
              : BlocBuilder<SoundWaveformBloc, SoundWaveformState>(
                  builder: (context, waveformState) {
                    return switch (waveformState) {
                      SoundWaveformLoaded(
                        :final leftChannel,
                        :final rightChannel,
                        :final duration,
                      ) =>
                        _AudioWaveformProgress(
                          leftChannel: leftChannel,
                          rightChannel: rightChannel,
                          audioDuration: duration,
                        ),
                      SoundWaveformInitial() => const SizedBox.shrink(),
                      SoundWaveformLoading() ||
                      SoundWaveformError() => const _EmptyWaveformPlaceholder(),
                    };
                  },
                ),
        ),
      ),
    );
  }
}

/// Empty waveform placeholder shown when no waveform data is available.
class _EmptyWaveformPlaceholder extends StatelessWidget {
  const _EmptyWaveformPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.scrim15,
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, WaveformConstants.waveformHeight),
        painter: _EmptyWaveformPainter(
          barColor: VineTheme.whiteText.withValues(alpha: 0.32),
        ),
      ),
    );
  }
}

/// Painter for empty waveform placeholder with uniform bars.
class _EmptyWaveformPainter extends CustomPainter {
  _EmptyWaveformPainter({required this.barColor});

  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / WaveformConstants.barStep).floor();
    final halfHeight = size.height / 2;
    const totalHeight = WaveformConstants.emptyBarHeight * 2;

    final paint = Paint()
      ..color = barColor
      ..style = .fill;

    for (var i = 0; i < barCount; i++) {
      final x = i * WaveformConstants.barStep;
      canvas.drawRRect(
        .fromRectAndRadius(
          .fromLTWH(
            x,
            halfHeight - WaveformConstants.emptyBarHeight,
            WaveformConstants.barWidth,
            totalHeight,
          ),
          WaveformConstants.barRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyWaveformPainter oldDelegate) {
    return oldDelegate.barColor != barColor;
  }
}

class _AudioWaveformProgress extends ConsumerWidget {
  const _AudioWaveformProgress({
    required this.leftChannel,
    required this.audioDuration,
    this.rightChannel,
  });

  final Float32List leftChannel;
  final Float32List? rightChannel;
  final Duration audioDuration;

  /// Maximum allowed recording duration.
  static const Duration _maxDuration = VideoEditorConstants.maxDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      clipManagerProvider.select(
        (s) => (clips: s.clips, activeRecording: s.activeRecordingDuration),
      ),
    );
    final startOffset =
        ref.watch(
          videoEditorProvider.select((s) => s.selectedSound?.startOffset),
        ) ??
        Duration.zero;

    // Calculate total recorded duration
    var recordedDuration = Duration.zero;
    for (final clip in state.clips) {
      recordedDuration += clip.duration;
    }
    recordedDuration += state.activeRecording;

    // Calculate progress as ratio of recorded to max duration
    final progress =
        recordedDuration.inMilliseconds /
        _maxDuration.inMilliseconds.clamp(1, double.infinity);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: WaveformConstants.animationDuration,
      curve: WaveformConstants.animationCurve,
      builder: (context, heightFactor, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.scrim15,
            borderRadius: .circular(4),
          ),
          child: CustomPaint(
            size: const Size(double.infinity, WaveformConstants.waveformHeight),
            foregroundPainter: StereoWaveformPainter(
              leftChannel: leftChannel,
              rightChannel: rightChannel,
              progress: progress.clamp(0.0, 1.0),
              activeColor: VineTheme.whiteText,
              inactiveColor: VineTheme.whiteText.withValues(alpha: 0.32),
              activeBackgroundColor: VineTheme.scrim15,
              audioDuration: audioDuration,
              maxDuration: _maxDuration,
              heightFactor: heightFactor,
              startOffset: startOffset,
            ),
          ),
        );
      },
    );
  }
}
