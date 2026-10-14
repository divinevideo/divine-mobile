// ABOUTME: The audio visualizer layer on the editor canvas: bars or a wave
// ABOUTME: drawn live at the playhead, the shapes the export renders.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioVisualizerPainter, LayerAudioVisualizer;

/// Draws [data] at the playhead, from the sound
/// [VideoEditorAudioVisualizerCubit] has read.
///
/// The same widget is mounted by the draft render path, which has neither the
/// cubit nor a playhead around it; it then draws the visualizer at rest, which
/// is also what it shows before the sound has been read.
class AudioVisualizerLayerView extends StatefulWidget {
  const AudioVisualizerLayerView({required this.data, super.key});

  final AudioVisualizerLayerData data;

  @override
  State<AudioVisualizerLayerView> createState() =>
      _AudioVisualizerLayerViewState();
}

class _AudioVisualizerLayerViewState extends State<AudioVisualizerLayerView> {
  /// The width the visualizer is laid out at before it is scaled.
  static const double _baseWidth = 300;

  VideoEditorAudioVisualizerCubit? _cubit;
  StreamSubscription<VideoEditorAudioVisualizerState>? _subscription;
  LayerAudioVisualizer? _visualizer;
  TransitionTimelineMap? _timelineMap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cubit = _readCubit();
    if (identical(cubit, _cubit)) return;
    unawaited(_subscription?.cancel());
    _cubit = cubit;
    _subscription = cubit?.stream.listen(_onState);
    _onState(cubit?.state);
  }

  @override
  void didUpdateWidget(AudioVisualizerLayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _visualizer = _visualizerFor(_cubit?.state.energies);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// The cubit, or `null` outside the editor, where nothing provides it.
  VideoEditorAudioVisualizerCubit? _readCubit() {
    try {
      return context.read<VideoEditorAudioVisualizerCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _onState(VideoEditorAudioVisualizerState? state) {
    final energies = state?.energies;
    if (identical(energies, _builtFrom) &&
        identical(state?.timelineMap, _timelineMap)) {
      return;
    }
    setState(() {
      _timelineMap = state?.timelineMap;
      // A sync that only moves the clips keeps the same energies.
      if (!identical(energies, _builtFrom)) {
        _visualizer = _visualizerFor(energies);
      }
    });
  }

  /// The energies [_visualizer] was built from.
  Float32List? _builtFrom;

  /// The visualizer of [energies] in this layer's style and color.
  LayerAudioVisualizer? _visualizerFor(Float32List? energies) {
    _builtFrom = energies;
    if (energies == null) return null;
    return widget.data.visualizerFor(energies);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final playTime = VideoEditorScope.maybeOf(context)?.playTimeNotifier;
    // The canvas lays a widget layer out without bounds and scales it to the
    // layer's width, so the box has a size of its own; elsewhere it is
    // scaled to fit what it is given. Every shape is measured in the box, so
    // the size it is drawn at does not change them.
    return FittedBox(
      child: SizedBox(
        width: _baseWidth,
        height: _baseWidth / data.aspectRatio,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _AudioVisualizerLayerPainter(
              data: data,
              visualizer: _visualizer,
              timelineMap: _timelineMap,
              playTime: playTime,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the visualizer at the playhead, mapped onto the exported video its
/// levels are timed on, and again whenever the playhead moves.
class _AudioVisualizerLayerPainter extends CustomPainter {
  _AudioVisualizerLayerPainter({
    required this.data,
    required this.visualizer,
    required this.timelineMap,
    required this.playTime,
  }) : super(repaint: playTime);

  final AudioVisualizerLayerData data;
  final LayerAudioVisualizer? visualizer;
  final TransitionTimelineMap? timelineMap;
  final ValueListenable<Duration>? playTime;

  @override
  void paint(Canvas canvas, Size size) {
    final editorTime = playTime?.value ?? Duration.zero;
    final outputTime = timelineMap?.editorToOutput(editorTime) ?? editorTime;
    AudioVisualizerPainter(
      style: data.style,
      color: data.color,
      levels: visualizer?.levelsAt(outputTime) ?? Float32List(data.bandCount),
      barFill: data.effectiveBarFill,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_AudioVisualizerLayerPainter oldDelegate) =>
      oldDelegate.data != data ||
      !identical(oldDelegate.visualizer, visualizer) ||
      !identical(oldDelegate.timelineMap, timelineMap) ||
      !identical(oldDelegate.playTime, playTime);
}
