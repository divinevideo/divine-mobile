// ABOUTME: Times how long the recorder takes to start a take and to stop it.
// ABOUTME: Emits recording_start and recording_stop traces with fixed fields.

import 'package:clock/clock.dart';
import 'package:divine_camera/divine_camera.dart'
    show DivineVideoStabilizationMode;
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// The recorder settings a take runs with, reported on both of its traces.
///
/// Three of them are attributes, so the console can filter by them; the
/// rarer switches are 0/1 metrics, which keeps each trace within Firebase's
/// five custom attributes.
class RecordingTraceContext {
  const RecordingTraceContext({
    required this.mode,
    required this.stabilization,
    required this.dualCamera,
    required this.chromaKey,
    required this.reaction,
  });

  /// The recorder mode the take is filmed in.
  final VideoRecorderMode mode;

  /// The stabilization the camera runs with. A look-ahead mode on iOS holds
  /// the stop until the camera hands over its last frames.
  final DivineVideoStabilizationMode stabilization;

  /// Whether the second camera films alongside the main one.
  final bool dualCamera;

  /// Whether the color mask is on for the take.
  final bool chromaKey;

  /// Whether the take is a Library reaction recording.
  final bool reaction;

  Map<String, String> get _attributes => {
    'mode': mode.name,
    'stabilization': stabilization.name,
    'dual_camera': dualCamera ? 'on' : 'off',
  };

  Map<String, int> get _metrics => {
    'chroma_key': chromaKey ? 1 : 0,
    'reaction': reaction ? 1 : 0,
  };
}

/// Starts the recorder's `recording_start` and `recording_stop` traces, and
/// carries the moment a take began from the one to the other so the stop
/// can report how long the take ran.
class RecordingTraces {
  RecordingTraces(this._monitor);

  final PerformanceTraceMonitor _monitor;
  Stopwatch? _take;

  /// Starts timing a take the shutter just asked for.
  ///
  /// [countdown] says whether a countdown runs first. Its time is kept out of
  /// the trace: the trace opens when [RecordingStartTrace.countdownEnded] is
  /// called, and the countdown goes into `countdown_ms` instead.
  /// [sound] says whether a sound plays along with the take.
  RecordingStartTrace start(
    RecordingTraceContext context, {
    required bool countdown,
    required bool sound,
  }) => RecordingStartTrace._(
    _monitor,
    context,
    countdown: countdown,
    sound: sound,
    onStarted: () => _take = clock.stopwatch()..start(),
  );

  /// Starts timing the stop of the take in progress.
  RecordingStopTrace stop(
    RecordingTraceContext context, {
    required RecordingStopTrigger trigger,
  }) {
    final take = _take;
    _take = null;
    return RecordingStopTrace._(
      _monitor,
      context,
      trigger: trigger,
      takeMs: take?.elapsedMilliseconds,
    );
  }
}

/// A step of starting a take that `recording_start` times on its own.
enum RecordingStartPhase {
  /// Loading the sound that plays along with the take.
  soundPrep('sound_prep_ms'),

  /// The camera starting to write the take.
  nativeStart('native_start_ms'),

  /// Keeping the screen awake for the take.
  wakelock('wakelock_ms');

  const RecordingStartPhase(this.metric);

  final String metric;
}

/// What ended a take.
enum RecordingStopTrigger {
  /// The user stopped it, or let go in hold-to-record.
  user,

  /// The camera ended it: the recording limit, or a capture session that
  /// was interrupted.
  auto,

  /// The recorder closed with a reaction take still running.
  teardown,
}

/// A step of stopping a take that `recording_stop` times on its own.
enum RecordingStopPhase {
  /// Stopping the sound that played along with the take.
  soundStop('sound_stop_ms'),

  /// Waiting for the camera to hand over the take's file.
  nativeStop('native_stop_ms'),

  /// Letting the screen sleep again.
  wakelock('wakelock_ms');

  const RecordingStopPhase(this.metric);

  final String metric;
}

/// One `recording_start` trace: from the shutter asking for a take until the
/// camera writes it and the recorder shows it running.
///
/// A countdown is kept out of the trace's duration and reported as
/// `countdown_ms`. Every method after the first terminal one is ignored, so
/// the trace stops exactly once: `success`, `failed` (the camera refused to
/// start), `aborted` (navigation took the camera, the reaction was
/// cancelled, or the recorder closed), or `error` (the start threw).
class RecordingStartTrace extends _RecordingTrace {
  RecordingStartTrace._(
    super.monitor,
    super.context, {
    required bool countdown,
    required bool sound,
    required void Function() onStarted,
  }) : _sound = sound,
       _onStarted = onStarted,
       super(name: traceName, totalMetric: 'start_ms') {
    if (!countdown) _open();
  }

  static const traceName = 'recording_start';

  final bool _sound;
  final void Function() _onStarted;
  int? _countdownMs;

  /// Records that the countdown is over. Only the first call counts, and
  /// only when the take began with a countdown.
  void countdownEnded() {
    if (isPending) _endCountdown();
  }

  /// Times [step] as [phase] and returns its result.
  Future<T> measure<T>(RecordingStartPhase phase, Future<T> Function() step) =>
      _measure(phase.metric, step);

  /// Records that the take is running.
  void succeeded() {
    if (!isPending) return;
    _end('success');
    _onStarted();
  }

  /// Records that the camera refused to start the take.
  void failed() => _end('failed');

  /// Records that the start was given up before the take ran.
  void aborted() => _end('aborted');

  /// Ends the trace as `error` unless it has already ended, so a start that
  /// threw still stops it when this runs in a `finally`.
  void errored() => _end('error');

  void _endCountdown() {
    if (_isOpen) return;
    _countdownMs = _elapsedMs;
    _open();
  }

  void _end(String outcome) {
    if (!isPending) return;
    // A start given up during the countdown still counts, with no time of
    // its own.
    _endCountdown();
    _finish(
      outcome,
      attributes: {'sound': _sound ? 'on' : 'off'},
      metrics: {'countdown_ms': ?_countdownMs},
    );
  }
}

/// One `recording_stop` trace: from the stop of a take until the camera has
/// handed over its file.
///
/// Stops exactly once: `success` (the take has a file), `no_file` (the take
/// is lost), or `error` (the stop threw and the recorder was reset).
class RecordingStopTrace extends _RecordingTrace {
  RecordingStopTrace._(
    super.monitor,
    super.context, {
    required RecordingStopTrigger trigger,
    required int? takeMs,
  }) : _trigger = trigger,
       _takeMs = takeMs,
       super(name: traceName, totalMetric: 'stop_ms') {
    _open();
  }

  static const traceName = 'recording_stop';

  final RecordingStopTrigger _trigger;
  final int? _takeMs;

  /// Times [step] as [phase] and returns its result.
  Future<T> measure<T>(RecordingStopPhase phase, Future<T> Function() step) =>
      _measure(phase.metric, step);

  /// Records how the stop ended: with a file when [file] holds, and with the
  /// second camera's file too when [secondaryFile] holds.
  void finished({required bool file, required bool secondaryFile}) =>
      _end(file ? 'success' : 'no_file', secondaryFile: secondaryFile);

  /// Records that the stop threw and the recorder was reset.
  void errored() => _end('error', secondaryFile: false);

  void _end(String outcome, {required bool secondaryFile}) => _finish(
    outcome,
    attributes: {'trigger': _trigger.name},
    metrics: {'take_ms': ?_takeMs, 'secondary_file': secondaryFile ? 1 : 0},
  );
}

/// The timing and reporting both recording traces share.
abstract class _RecordingTrace {
  _RecordingTrace(
    PerformanceTraceMonitor monitor,
    RecordingTraceContext context, {
    required String name,
    required String totalMetric,
  }) : _monitor = monitor,
       _context = context,
       _name = name,
       _totalMetric = totalMetric;

  final PerformanceTraceMonitor _monitor;
  final RecordingTraceContext _context;
  final String _name;
  final String _totalMetric;
  final Stopwatch _stopwatch = clock.stopwatch()..start();
  final Map<String, int> _phaseMetrics = {};
  PerformanceOperation? _operation;
  bool _finished = false;

  /// Whether the trace has not ended yet.
  bool get isPending => !_finished;

  bool get _isOpen => _operation != null;

  int get _elapsedMs => _stopwatch.elapsedMilliseconds;

  /// Opens the Firebase trace and starts its duration from here.
  void _open() {
    _stopwatch.reset();
    _operation = PerformanceOperation(_monitor, _name);
  }

  Future<T> _measure<T>(String metric, Future<T> Function() step) async {
    final began = _elapsedMs;
    try {
      return await step();
    } finally {
      if (isPending) _phaseMetrics[metric] = _elapsedMs - began;
    }
  }

  void _finish(
    String outcome, {
    required Map<String, String> attributes,
    required Map<String, int> metrics,
  }) {
    final operation = _operation;
    if (_finished || operation == null) return;
    _finished = true;
    _stopwatch.stop();
    final allAttributes = {
      'outcome': outcome,
      ...attributes,
      ..._context._attributes,
    };
    final allMetrics = {
      _totalMetric: _elapsedMs,
      ..._phaseMetrics,
      ...metrics,
      ..._context._metrics,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$_name $allAttributes $allMetrics',
      name: 'RecordingTraces',
      category: LogCategory.video,
    );
    operation.finish(attributes: allAttributes, metrics: allMetrics);
  }
}
