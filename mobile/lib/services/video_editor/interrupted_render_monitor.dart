// ABOUTME: Keeps a marker on disk while a render runs and reports, on the next
// ABOUTME: launch, every render the process did not live to finish (#9872)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart'
    show NativePlaybackDiagnostics;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reported on the launch after a render the process did not survive.
///
/// [summary] is the marker the render left behind: what was rendering, for how
/// long, the memory footprint it reached, and the shape of the render. It holds
/// counts and sizes only, never a path or user content.
class InterruptedRenderException implements Exception {
  /// Creates an [InterruptedRenderException] carrying [summary].
  const InterruptedRenderException(this.summary);

  /// The `key=value` description of the interrupted render.
  final String summary;

  @override
  String toString() => 'InterruptedRenderException: $summary';
}

/// Notices renders that end with the process instead of with a result.
///
/// iOS ends an app that outgrows its memory limit without a crash report, so a
/// render that runs the device out of memory leaves nothing behind but a user
/// who saw the app close. [track] writes a marker before a render starts,
/// refreshes it with the memory footprint while the render runs, and deletes it
/// once the render settles either way. A marker that survives into the next
/// launch therefore names a render the process died in, and [initialize]
/// reports it.
///
/// The footprint trend is what tells the causes apart: a footprint climbing
/// right up to the last sample points at a memory kill, a flat one at a crash
/// or a force quit. The lifecycle state separates a background termination.
///
/// Markers are written synchronously and without `flush`: a write that
/// returned is in the kernel and survives the process being killed, and a
/// render never waits on the marker to start. Until [initialize] resolves
/// where markers live, renders run unmarked.
class InterruptedRenderMonitor {
  InterruptedRenderMonitor._();

  static const _logName = 'InterruptedRenderMonitor';

  /// Folder below the application support directory holding the markers.
  @visibleForTesting
  static const markerDirectoryName = 'render_markers';

  /// Crash reporting for this static utility (#4743).
  ///
  /// `app_bootstrap` assigns the real reporter at startup; tests assign a
  /// recording fake.
  static CrashReporter crashReporter = const SilentCrashReporter();

  /// Resolves the folder markers live in.
  @visibleForTesting
  static Future<Directory> Function() markerDirectory = _defaultMarkerDirectory;

  /// Reads the process's physical memory footprint in bytes, or `null` when
  /// the platform cannot tell.
  @visibleForTesting
  static Future<int?> Function() readFootprintBytes = _readNativeFootprintBytes;

  /// Reads the app's lifecycle state, or `null` before the binding exists.
  @visibleForTesting
  static String? Function() readLifecycleState = _readLifecycleState;

  /// How often a running render refreshes its marker.
  @visibleForTesting
  static Duration sampleInterval = const Duration(milliseconds: 250);

  /// Identifies the markers this process writes, so the launch sweep never
  /// reports a render that is still running here.
  static final String _sessionId =
      '${pid}_${DateTime.now().microsecondsSinceEpoch}';

  static final Set<_RenderMarker> _active = <_RenderMarker>{};

  /// Where markers are written, once [initialize] resolved it.
  static Directory? _directory;

  /// Resolves where markers live, then reports and deletes every marker a
  /// previous process left behind.
  ///
  /// Each one becomes a Crashlytics non-fatal so the dashboard counts renders
  /// the app did not survive. Markers this process wrote are left alone, so
  /// calling this again while a render runs is safe.
  static Future<void> initialize() async {
    final Directory directory;
    try {
      directory = await markerDirectory();
    } on Object catch (e) {
      Log.warning(
        'Could not resolve the render marker folder: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return;
    }
    _directory = directory;
    if (!directory.existsSync()) return;

    final files = directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.json'),
    );
    for (final file in files) {
      final marker = _readMarker(file);
      if (marker != null && marker['session'] == _sessionId) continue;

      // Deleted before reporting, so a report that itself fails cannot turn
      // one interrupted render into a report on every launch.
      try {
        file.deleteSync();
      } on FileSystemException catch (e) {
        Log.warning(
          'Could not delete render marker ${p.basename(file.path)}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        continue;
      }

      final summary = marker == null
          ? 'unreadable marker'
          : summarizeMarker(marker);
      Log.warning(
        'Previous session ended during a render: $summary',
        name: _logName,
        category: LogCategory.video,
      );
      await crashReporter.recordError(
        InterruptedRenderException(summary),
        // One stack for every report keeps them in one Crashlytics issue; the
        // message carries what differs.
        StackTrace.current,
        reason: 'render interrupted by process termination',
      );
    }
  }

  /// Runs [operation], keeping a marker on disk until it settles.
  ///
  /// [kind] names the render path and [details] describes its shape, see
  /// [describeVideoRender]. [operation] starts synchronously, and writing the
  /// marker never fails it: any error there is logged and the render runs
  /// unmarked.
  static Future<T> track<T>({
    required String taskId,
    required String kind,
    required Map<String, Object> details,
    required Future<T> Function() operation,
  }) async {
    final directory = _directory;
    final marker = directory == null
        ? null
        : _RenderMarker.open(
            directory: directory,
            taskId: taskId,
            kind: kind,
            details: details,
          );
    if (marker != null) _active.add(marker);
    try {
      return await operation();
    } finally {
      if (marker != null) {
        _active.remove(marker);
        marker.close();
      }
    }
  }

  /// Refreshes every running render's marker right away.
  @visibleForTesting
  static Future<void> sampleActiveRendersForTesting() =>
      Future.wait(_active.map((marker) => marker.sample()));

  /// Forgets the marker folder and the running renders, leaving their files.
  @visibleForTesting
  static void resetForTesting() {
    for (final marker in _active) {
      marker.stopSampling();
    }
    _active.clear();
    _directory = null;
  }

  static Map<String, Object?>? _readMarker(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object catch (e) {
      Log.warning(
        'Could not read render marker ${p.basename(file.path)}: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  static Future<Directory> _defaultMarkerDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, markerDirectoryName));
  }

  static Future<int?> _readNativeFootprintBytes() async {
    final diagnostics = await NativePlaybackDiagnostics.read();
    final bytes = diagnostics?.footprintBytes;
    return bytes == null || bytes < 0 ? null : bytes;
  }

  static String? _readLifecycleState() {
    try {
      return SchedulerBinding.instance.lifecycleState?.name;
    } on Object {
      // No binding yet (tests, very early startup): the state is unknown.
      return null;
    }
  }
}

/// One running render's marker file.
class _RenderMarker {
  _RenderMarker._(this._file, this._content);

  final File _file;
  final Map<String, Object?> _content;
  final Stopwatch _stopwatch = Stopwatch()..start();
  Timer? _timer;
  bool _sampling = false;
  bool _closed = false;
  int _samples = 0;
  int? _peakFootprint;

  /// Writes the marker for a render that is about to start, or returns `null`
  /// when it cannot be written.
  static _RenderMarker? open({
    required Directory directory,
    required String taskId,
    required String kind,
    required Map<String, Object> details,
  }) {
    try {
      directory.createSync(recursive: true);
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_'
          '${taskId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_')}.json';
      final marker = _RenderMarker._(
        File(p.join(directory.path, name)),
        <String, Object?>{
          'session': InterruptedRenderMonitor._sessionId,
          'kind': kind,
          'startedAt': DateTime.now().toUtc().toIso8601String(),
          'details': details,
        },
      ).._write();
      marker._timer = Timer.periodic(
        InterruptedRenderMonitor.sampleInterval,
        (_) => unawaited(marker.sample()),
      );
      unawaited(marker.sample());
      return marker;
    } on Object catch (e) {
      Log.warning(
        'Could not write a render marker for $kind: $e',
        name: InterruptedRenderMonitor._logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Records the current footprint and lifecycle state in the marker file.
  Future<void> sample() async {
    if (_sampling || _closed) return;
    _sampling = true;
    try {
      int? footprint;
      try {
        footprint = await InterruptedRenderMonitor.readFootprintBytes().timeout(
          const Duration(seconds: 1),
        );
      } on Object {
        // An unreadable footprint still refreshes the elapsed time.
        footprint = null;
      }
      if (_closed) return;
      if (footprint != null) {
        _content['startFootprintMb'] ??= _mb(footprint);
        _peakFootprint = math.max(_peakFootprint ?? 0, footprint);
        _content['footprintMb'] = _mb(footprint);
        _content['peakFootprintMb'] = _mb(_peakFootprint!);
      }
      _samples++;
      _content['samples'] = _samples;
      _write();
    } finally {
      _sampling = false;
    }
  }

  void _write() {
    _content['elapsedMs'] = _stopwatch.elapsedMilliseconds;
    _content['lifecycle'] = InterruptedRenderMonitor.readLifecycleState();
    try {
      _file.writeAsStringSync(jsonEncode(_content));
    } on FileSystemException catch (e) {
      Log.debug(
        'Could not refresh render marker: $e',
        name: InterruptedRenderMonitor._logName,
        category: LogCategory.video,
      );
    }
  }

  void stopSampling() {
    _timer?.cancel();
    _timer = null;
  }

  void close() {
    _closed = true;
    stopSampling();
    try {
      if (_file.existsSync()) _file.deleteSync();
    } on FileSystemException catch (e) {
      Log.warning(
        'Could not delete render marker: $e',
        name: InterruptedRenderMonitor._logName,
        category: LogCategory.video,
      );
    }
  }

  static int _mb(int bytes) => bytes ~/ (1024 * 1024);
}

/// The `key=value` line a report carries for [marker].
@visibleForTesting
String summarizeMarker(Map<String, Object?> marker) {
  final details = marker['details'];
  final fields = <String, Object?>{
    'kind': marker['kind'],
    'elapsedMs': marker['elapsedMs'],
    'samples': marker['samples'],
    'startFootprintMb': marker['startFootprintMb'],
    'footprintMb': marker['footprintMb'],
    'peakFootprintMb': marker['peakFootprintMb'],
    'lifecycle': marker['lifecycle'],
    if (details is Map) ...details.cast<String, Object?>(),
  };
  return fields.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
}

/// The shape of [data] for a render marker: counts, durations and sizes.
///
/// Layer sizes are read from the PNG header of each overlay, which is cheap
/// and what the native compositor will decode. Paths and contents stay out.
Map<String, Object> describeVideoRender(VideoRenderData data) {
  final segments = data.videoSegments ?? const <VideoSegment>[];
  final layers = data.imageLayers ?? const <ImageLayer>[];
  final compositionLayers = data.composition?.layers ?? const <VideoLayer>[];
  final resolution = data.qualityConfig?.resolution;

  var largestLayerPixels = 0;
  var largestLayer = '';
  var layerPixels = 0;
  var unsizedLayers = 0;
  for (final layer in layers) {
    final size = _pngSize(layer.image);
    if (size == null) {
      unsizedLayers++;
      continue;
    }
    final pixels = size.$1 * size.$2;
    layerPixels += pixels;
    if (pixels > largestLayerPixels) {
      largestLayerPixels = pixels;
      largestLayer = '${size.$1}x${size.$2}';
    }
  }

  double maxVolume(Iterable<double?> volumes) =>
      volumes.fold<double>(0, (max, v) => math.max(max, v ?? 1));

  return {
    'segments': segments.length,
    'reversed': segments.where((s) => s.reverseVideo).length,
    'segmentChromaKeys': segments.where((s) => s.chromaKey != null).length,
    'speedChanged': segments
        .where((s) => s.playbackSpeed != null && s.playbackSpeed != 1)
        .length,
    'transitions': segments.where((s) => s.transition != null).length,
    'transformed': segments.where((s) => s.transform != null).length,
    'maxSegmentVolume': maxVolume(segments.map((s) => s.volume)),
    'compositionLayers': compositionLayers.length,
    'compositionClips': compositionLayers.fold<int>(
      0,
      (sum, layer) => sum + layer.clips.length,
    ),
    'imageLayers': layers.length,
    'animatedLayers': layers.where((l) => l.animations.isNotEmpty).length,
    'censorLayers': layers.where((l) => l.censor != null).length,
    'largestLayer': largestLayer.isEmpty ? 'none' : largestLayer,
    'layerMegapixels': (layerPixels / 1000000).toStringAsFixed(1),
    'unsizedLayers': unsizedLayers,
    'audioTracks': data.audioTracks.length,
    'maxAudioVolume': maxVolume(data.audioTracks.map((t) => t.volume)),
    'effects': data.effects.length,
    'customEffects': data.customEffects.length,
    'colorFilters': data.colorFilters.length,
    'chromaKey': data.chromaKey != null,
    'resolution': resolution == null
        ? 'source'
        : '${resolution.width.round()}x${resolution.height.round()}',
    'trimmed': data.startTime != null || data.endTime != null,
  };
}

/// The shape of a stop-motion assembly for a render marker.
Map<String, Object> describeStopMotionRender(StopMotionRenderData data) {
  final resolution = data.resolution;
  return {
    'frames': data.frames.length,
    'frameRate': data.frameRate,
    'resolution': resolution == null
        ? 'source'
        : '${resolution.width.round()}x${resolution.height.round()}',
  };
}

/// Width and height from the PNG header of [image], or `null` when it is not
/// a PNG this can read without decoding.
(int, int)? _pngSize(EditorLayerImage image) {
  try {
    final List<int> header;
    if (image.byteArray case final bytes?) {
      if (bytes.length < 24) return null;
      header = bytes.sublist(0, 24);
    } else if (image.file case final file?) {
      // The plugin types `file` through a web-safe shim; only its path is
      // shared with dart:io's File.
      final handle = File(file.path).openSync();
      try {
        header = handle.readSync(24);
      } finally {
        handle.closeSync();
      }
    } else {
      return null;
    }
    const signature = [0x89, 0x50, 0x4E, 0x47];
    for (var i = 0; i < signature.length; i++) {
      if (header.length < 24 || header[i] != signature[i]) return null;
    }
    int readUint32(int offset) =>
        (header[offset] << 24) |
        (header[offset + 1] << 16) |
        (header[offset + 2] << 8) |
        header[offset + 3];
    return (readUint32(16), readUint32(20));
  } on FileSystemException {
    return null;
  }
}
