// ABOUTME: Folds the native render, stop-motion assembly and ProofMode phases
// ABOUTME: of one export into a single monotonic composite progress value.

import 'dart:async';

import 'package:pro_video_editor/pro_video_editor.dart';

/// Composite progress for one export task.
///
/// An export runs up to three phases — an optional stop-motion assembly, the
/// native composite render, and ProofMode finalisation — each reporting on its
/// own scale. The tracker maps them onto one `0..1` axis, in that order, and
/// forwards every increase through [emit]. Out-of-order or late stream events
/// never move the value backwards.
///
/// [proofBudget] is the share of the axis reserved for the proof steps
/// ([proofSteps] of them); the remainder is split between assembly and render.
class RenderProgressTracker {
  RenderProgressTracker({
    required this.taskId,
    required this.emit,
    required double proofBudget,
    required int proofSteps,
    bool hasAssemblyPhase = false,
  }) : _proofBudget = proofBudget,
       _proofSteps = proofSteps,
       _hasAssemblyPhase = hasAssemblyPhase;

  /// Share of the non-proof budget reserved for the stop-motion assembly
  /// pass. Assembly (stills → base mp4) and the composite render are both
  /// full encode passes over the same output duration, so they get equal
  /// halves.
  static const double _assemblyShare = 0.5;

  /// The native render task whose progress stream drives the render phase.
  final String taskId;

  /// Receives every composite progress value, including the initial reset.
  final void Function(double progress) emit;

  final double _proofBudget;
  final int _proofSteps;
  final bool _hasAssemblyPhase;
  StreamSubscription<ProgressModel>? _renderSubscription;
  StreamSubscription<ProgressModel>? _assemblySubscription;
  double _lastProgress = 0;

  double get _assemblyBudget =>
      _hasAssemblyPhase ? (1 - _proofBudget) * _assemblyShare : 0;
  double get _renderBudget => 1 - _proofBudget - _assemblyBudget;

  void start() {
    // Emit an explicit reset so a reused broadcast stream does not keep showing
    // the completed progress of a previous render.
    _lastProgress = 0;
    emit(0);
    _renderSubscription = ProVideoEditor.instance
        .progressStreamById(taskId)
        .listen((progressModel) {
          _emit(_assemblyBudget + progressModel.progress * _renderBudget);
        });
  }

  /// Routes the native progress of the stop-motion assembly running under
  /// [assemblyTaskId] (step [step] of [stepCount]) into the assembly slice
  /// of the composite progress.
  Future<void> startAssemblyStep({
    required String assemblyTaskId,
    required int step,
    required int stepCount,
  }) async {
    await _assemblySubscription?.cancel();
    _assemblySubscription = ProVideoEditor.instance
        .progressStreamById(assemblyTaskId)
        .listen((progressModel) {
          _emit(_assemblyBudget * (step + progressModel.progress) / stepCount);
        });
  }

  Future<void> markAssemblyComplete() async {
    // Stop listening so late assembly events cannot regress the composite
    // progress during the render phase.
    await _assemblySubscription?.cancel();
    _assemblySubscription = null;
    _emit(_assemblyBudget);
  }

  Future<void> markRenderComplete() async {
    // Stop listening to render progress so late events from the render stream
    // cannot regress the composite progress during the proof phase.
    await _renderSubscription?.cancel();
    _renderSubscription = null;
    _emit(1 - _proofBudget);
  }

  void markProofStepComplete(int completedSteps) {
    final normalizedSteps = completedSteps.clamp(0, _proofSteps);
    _emit(1 - _proofBudget + (_proofBudget * normalizedSteps / _proofSteps));
  }

  Future<void> dispose() async {
    await _renderSubscription?.cancel();
    _renderSubscription = null;
    await _assemblySubscription?.cancel();
    _assemblySubscription = null;
  }

  /// Emits a monotonically increasing composite progress value, guarding
  /// against backwards jumps caused by out-of-order stream events.
  void _emit(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= _lastProgress) return;
    _lastProgress = clamped;
    emit(clamped);
  }
}
