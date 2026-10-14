// ABOUTME: The live preview at the top of the visualizer sheet: the visualizer
// ABOUTME: as picked, moving with the video's sound or a sample beat.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/utils/audio_visualizer_sample_beat.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioVisualizerPainter, LayerAudioVisualizer;

/// Plays [data] in a loop, so the creator sees how a style, a number of
/// bands, a reaction and a bar width move before picking them.
///
/// It follows the sound of the video once [soundLevels] has read it, and a
/// sample beat until then, or when the video has no sound to follow. With
/// reduced motion it holds still at the loudest moment.
class AudioVisualizerPreview extends StatefulWidget {
  const AudioVisualizerPreview({
    required this.data,
    this.soundLevels,
    super.key,
  });

  /// The visualizer as picked so far.
  final AudioVisualizerLayerData data;

  /// Reads the sound of the edited video; `null` previews the sample beat.
  final VideoEditorAudioVisualizerCubit? soundLevels;

  @override
  State<AudioVisualizerPreview> createState() => _AudioVisualizerPreviewState();
}

class _AudioVisualizerPreviewState extends State<AudioVisualizerPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<Duration> _time = ValueNotifier(Duration.zero);
  StreamSubscription<VideoEditorAudioVisualizerState>? _subscription;

  /// The video's band energies once read, or `null` for the sample beat.
  Float32List? _videoEnergies;
  late LayerAudioVisualizer _visualizer;
  bool _reduceMotion = false;

  Float32List get _energies => _videoEnergies ?? audioVisualizerSampleBeat;

  Duration get _loopLength => Duration(
    microseconds:
        _energies.length ~/ audioBandCount * 1000000 ~/ audioBandFrameRate,
  );

  @override
  void initState() {
    super.initState();
    final soundLevels = widget.soundLevels;
    if (soundLevels != null) {
      _subscription = soundLevels.stream.listen(_onSound);
      _videoEnergies = _readyEnergies(soundLevels.state);
      soundLevels.setPreviewing(isPreviewing: true);
    }
    _visualizer = _visualizerFor(widget.data);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(AudioVisualizerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Style, color and bar width only change how the levels are drawn.
    if (oldWidget.data.bandCount != widget.data.bandCount ||
        oldWidget.data.reaction != widget.data.reaction) {
      _visualizer = _visualizerFor(widget.data);
      _syncMotion();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    unawaited(_subscription?.cancel());
    widget.soundLevels?.setPreviewing(isPreviewing: false);
    super.dispose();
  }

  /// The energies of [state] once they follow the video's sound.
  static Float32List? _readyEnergies(VideoEditorAudioVisualizerState state) =>
      state.status == VideoEditorAudioLevelStatus.ready ? state.energies : null;

  void _onSound(VideoEditorAudioVisualizerState state) {
    final energies = _readyEnergies(state);
    if (identical(energies, _videoEnergies)) return;
    setState(() {
      _videoEnergies = energies;
      _visualizer = _visualizerFor(widget.data);
    });
    _syncMotion();
  }

  LayerAudioVisualizer _visualizerFor(AudioVisualizerLayerData data) =>
      LayerAudioVisualizer(
        style: data.style,
        color: data.color,
        bandCount: data.bandCount,
        levels: audioVisualizerLevels(
          _energies,
          bandCount: data.bandCount,
          reaction: data.reaction,
        ),
        framesPerSecond: audioBandFrameRate.toDouble(),
      );

  /// Runs the loop, or holds the loudest moment with reduced motion.
  void _syncMotion() {
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
      _time.value = _loudestMoment();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final loop = _loopLength.inMicroseconds;
    if (loop <= 0) return;
    _time.value = Duration(microseconds: elapsed.inMicroseconds % loop);
  }

  /// The time of the row whose levels add up highest.
  Duration _loudestMoment() {
    final levels = _visualizer.levels;
    final bands = _visualizer.bandCount;
    var loudestRow = 0;
    var loudest = -1.0;
    for (var row = 0; row < levels.length ~/ bands; row++) {
      var sum = 0.0;
      for (var band = 0; band < bands; band++) {
        sum += levels[row * bands + band];
      }
      if (sum > loudest) {
        loudest = sum;
        loudestRow = row;
      }
    }
    return Duration(microseconds: loudestRow * 1000000 ~/ audioBandFrameRate);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // A picture of how it moves, which a screen reader cannot convey; the
    // controls below announce what they set.
    return ExcludeSemantics(
      child: DecoratedBox(
        // The visualizer is drawn over the video, so the preview shows it on
        // the dark of the editor canvas in either appearance.
        decoration: BoxDecoration(
          color: VineTheme.backgroundCamera,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          height: 128,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const .all(20),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: data.aspectRatio,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _PreviewPainter(
                            data: data,
                            visualizer: _visualizer,
                            time: _time,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_videoEnergies == null)
                Positioned(
                  left: 12,
                  top: 8,
                  child: Text(
                    context.l10n.videoEditorAudioVisualizerPreviewSampleBeat,
                    style: VineTheme.labelSmallFont(
                      color: VineTheme.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the visualizer at the preview's time, and again as it moves.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.data,
    required this.visualizer,
    required this.time,
  }) : super(repaint: time);

  final AudioVisualizerLayerData data;
  final LayerAudioVisualizer visualizer;
  final ValueListenable<Duration> time;

  @override
  void paint(Canvas canvas, Size size) {
    AudioVisualizerPainter(
      style: data.style,
      color: data.color,
      levels: visualizer.levelsAt(time.value),
      barFill: data.effectiveBarFill,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.data != data ||
      !identical(oldDelegate.visualizer, visualizer) ||
      !identical(oldDelegate.time, time);
}
