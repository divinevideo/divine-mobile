// ABOUTME: Tests for RenderProgressTracker — the assembly / render / proof
// ABOUTME: phases of one export folded into a single non-regressing value.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/render_progress_tracker.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _ProgressProVideoEditor extends ProVideoEditor {
  final _controller = StreamController<ProgressModel>.broadcast();

  @override
  void initializeStream() {}

  void emit(String taskId, double progress) =>
      _controller.add(ProgressModel(id: taskId, progress: progress));

  @override
  Stream<ProgressModel> progressStreamById(String taskId) =>
      _controller.stream.where((progress) => progress.id == taskId);
}

void main() {
  group(RenderProgressTracker, () {
    late _ProgressProVideoEditor plugin;
    late ProVideoEditor originalPlugin;
    late List<double> emitted;

    setUp(() {
      plugin = _ProgressProVideoEditor();
      originalPlugin = ProVideoEditor.instance;
      ProVideoEditor.instance = plugin;
      emitted = [];
    });

    tearDown(() => ProVideoEditor.instance = originalPlugin);

    RenderProgressTracker tracker({bool hasAssemblyPhase = false}) =>
        RenderProgressTracker(
          taskId: 'export',
          emit: emitted.add,
          proofBudget: 0.1,
          proofSteps: 2,
          hasAssemblyPhase: hasAssemblyPhase,
        );

    test('scales native render progress into the render slice and never '
        'moves backwards', () async {
      final progress = tracker()..start();
      addTearDown(progress.dispose);

      plugin
        ..emit('export', 0.5)
        // A late, out-of-order report must not regress the composite value.
        ..emit('export', 0.25)
        ..emit('other-task', 1);
      await pumpEventQueue();

      // Reset, then 0.5 of the 0.9 render slice.
      expect(emitted, [0, 0.45]);
    });

    test('walks assembly, render and proof phases in order', () async {
      final progress = tracker(hasAssemblyPhase: true)..start();
      addTearDown(progress.dispose);

      await progress.startAssemblyStep(
        assemblyTaskId: 'assemble-0',
        step: 0,
        stepCount: 1,
      );
      plugin.emit('assemble-0', 0.5);
      await pumpEventQueue();
      await progress.markAssemblyComplete();

      // The assembly stream is released: its late reports change nothing.
      plugin.emit('assemble-0', 1);
      plugin.emit('export', 0.5);
      await pumpEventQueue();
      await progress.markRenderComplete();

      progress
        ..markProofStepComplete(1)
        ..markProofStepComplete(2);

      // Assembly and render split the 0.9 non-proof slice in half.
      expect(emitted, [
        0,
        0.225,
        0.45,
        0.675,
        0.9,
        closeTo(0.95, 1e-9),
        1,
      ]);
    });
  });
}
