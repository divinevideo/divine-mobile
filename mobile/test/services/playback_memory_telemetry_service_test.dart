// ABOUTME: Pins bounded, privacy-safe native memory reporting and lifecycle context.
// ABOUTME: Exercises real sampling, anomaly grace, failure, and disposal behavior.

import 'dart:async';
import 'dart:convert';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/memory_telemetry_service.dart';
import 'package:openvine/services/playback_memory_telemetry_service.dart';

const _memory = MemorySnapshot(
  rssBytes: 100,
  peakRssBytes: 200,
  nativeControllers: 2,
  queueDepth: 0,
  imageCacheBytes: 0,
  peakImageCacheBytes: 0,
  imageCacheLiveCount: 0,
);

NativePlaybackDiagnostics _native({
  int footprint = 600 * 1024 * 1024,
  int disposed = 0,
  int pending = 0,
  int frames = 0,
}) => NativePlaybackDiagnostics.fromMap({
  'version': 1,
  'platform': 'ios_on_mac',
  'appState': 'background',
  'footprintBytes': footprint,
  'registeredPlayers': 2,
  'liveInstances': 2 + disposed,
  'players': 2 + disposed,
  'playingPlayers': 0,
  'textures': 2,
  'pendingLoads': pending,
  'disposedPlayers': disposed,
  'framesDelivered': frames,
})!;

class _Reporter implements CrashReporter {
  final keys = <String, Object>{};
  final breadcrumbs = <String>[];
  final errors = <Object>[];
  Map<String, Object>? keysAtError;
  bool fail = false;

  @override
  Future<void> setCustomKey(String key, Object value) async {
    if (fail) throw StateError('reporter unavailable');
    keys[key] = value;
  }

  @override
  void log(String message) => breadcrumbs.add(message);

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    keysAtError = Map.of(keys);
    errors.add(error);
  }
}

void main() {
  group(PlaybackMemoryTelemetryService, () {
    test('captures lifecycle disagreement and resets frame intervals on transition', () async {
      var time = Duration.zero;
      var native = _native(frames: 100);
      final reporter = _Reporter();
      final service = PlaybackMemoryTelemetryService(
        readNative: () async => native,
        reporter: reporter,
        log: (_) {},
        isForeground: () => true,
        elapsed: () => time,
        initialLifecycle: 'hidden',
      );
      await service.sample(_memory, trigger: 'startup');
      time = const Duration(seconds: 30);
      native = _native(frames: 160);
      await service.sample(
        _memory,
        pressureEvents: 2,
        trigger: 'memory_pressure',
      );
      final values = jsonDecode(
        reporter.keys['mem_lifecycle']! as String,
      ) as Map<String, dynamic>;
      expect(values, containsPair('flutter', 'hidden'));
      expect(values, containsPair('foregroundGate', true));
      expect(values, containsPair('stateAgeS', 30));
      expect(values, containsPair('pressureEvents', 2));
      expect(values, containsPair('framesSinceSample', 60));
      expect(values, containsPair('sampleIntervalMs', 30000));
      expect(reporter.breadcrumbs.last, contains('memory_pressure'));
      service.onLifecycleChanged('resumed');
      await service.sample(_memory, trigger: 'lifecycle');
      expect(
        reporter.keys['mem_lifecycle'],
        isNot(contains('framesSinceSample')),
      );
      expect(reporter.keys['mem_lifecycle'], contains('"stateAgeS":0'));
    });

    test(
      'logs footprint separately from RSS and preserves sampled peak',
      () async {
        final reporter = _Reporter();
        final logs = <String>[];
        var native = _native();
        final service = PlaybackMemoryTelemetryService(
          readNative: () async => native,
          reporter: reporter,
          log: logs.add,
          isForeground: () => false,
          elapsed: () => const Duration(minutes: 10),
          initialLifecycle: 'hidden',
        );
        await service.sample(_memory);
        expect(reporter.keys['mem_footprint_mb'], '600.0');
        expect(logs.single, contains('"rssBytes":100'));
        native = _native(footprint: 300 * 1024 * 1024);
        await service.sample(_memory);
        expect(reporter.keys['mem_footprint_mb'], '300.0');
        expect(reporter.keys['mem_footprint_sampled_peak_mb'], '600.0');
        expect(reporter.errors, isEmpty); // High memory alone is not a leak.
        expect(
          reporter.keys.length,
          4,
        ); // Budget for existing Crashlytics keys.
      },
    );

    test(
      'records a persistent disposed-player invariant once, after keys',
      () async {
        var time = Duration.zero;
        final reporter = _Reporter();
        final service = PlaybackMemoryTelemetryService(
          readNative: () async => _native(disposed: 1),
          reporter: reporter,
          log: (_) {},
          isForeground: () => true,
          elapsed: () => time,
        );
        await service.sample(_memory);
        time = const Duration(seconds: 29);
        await service.sample(_memory);
        expect(reporter.errors, isEmpty);
        time = const Duration(seconds: 30);
        await service.sample(_memory);
        expect(
          reporter.errors.single,
          isA<PlaybackResourceInvariantException>(),
        );
        expect(
          reporter.keysAtError?['mem_native'],
          contains('"disposedPlayers":1'),
        );
        time = const Duration(days: 1);
        await service.sample(_memory);
        expect(reporter.errors, hasLength(1));
      },
    );

    test(
      'pending loads and failed reads reset the anomaly grace period',
      () async {
        var time = Duration.zero;
        NativePlaybackDiagnostics? native = _native(disposed: 1);
        final reporter = _Reporter();
        final service = PlaybackMemoryTelemetryService(
          readNative: () async => native,
          reporter: reporter,
          log: (_) {},
          isForeground: () => true,
          elapsed: () => time,
        );
        await service.sample(_memory);
        time = const Duration(minutes: 1);
        native = _native(disposed: 1, pending: 1);
        await service.sample(_memory);
        native = _native(disposed: 1);
        await service.sample(_memory);
        native = null;
        await service.sample(_memory);
        time = const Duration(minutes: 2);
        native = _native(disposed: 1);
        await service.sample(_memory);
        expect(reporter.errors, isEmpty);
      },
    );

    test(
      'lifecycle breadcrumb is immediate and invalidates an in-flight sample',
      () async {
        final native = Completer<NativePlaybackDiagnostics?>();
        final reporter = _Reporter();
        final service = PlaybackMemoryTelemetryService(
          readNative: () => native.future,
          reporter: reporter,
          log: (_) {},
          isForeground: () => true,
          elapsed: () => Duration.zero,
        );
        final pending = service.sample(_memory);
        service.onLifecycleChanged('hidden');
        expect(reporter.breadcrumbs.single, contains('hidden'));
        native.complete(_native());
        await pending;
        expect(reporter.keys, isEmpty);
        expect(reporter.errors, isEmpty);
      },
    );

    test('timeout does not create a queue of outstanding platform calls', () {
      fakeAsync((async) {
        var reads = 0;
        final native = Completer<NativePlaybackDiagnostics?>();
        final reporter = _Reporter();
        final service = PlaybackMemoryTelemetryService(
          readNative: () {
            reads++;
            return native.future;
          },
          reporter: reporter,
          log: (_) {},
          isForeground: () => false,
          elapsed: () => async.elapsed,
        );
        unawaited(service.sample(_memory));
        async.elapse(const Duration(seconds: 3));
        expect(reporter.keys['mem_native'], contains('timeout'));
        unawaited(service.sample(_memory));
        expect(reads, 1);
        native.complete(_native());
        async.flushMicrotasks();
        unawaited(service.sample(_memory));
        async.flushMicrotasks();
        expect(reads, 2);
        expect(reporter.keys['mem_footprint_mb'], '600.0');
      });
    });

    test(
      'failed read clears stale gauges and does not forward error text',
      () async {
        var fail = false;
        final reporter = _Reporter();
        final service = PlaybackMemoryTelemetryService(
          readNative: () async {
            if (fail) throw StateError('private@example.invalid');
            return _native();
          },
          reporter: reporter,
          log: (_) {},
          isForeground: () => true,
          elapsed: () => Duration.zero,
        );
        await service.sample(_memory);
        expect(reporter.keys['mem_footprint_mb'], '600.0');
        fail = true;
        await service.sample(_memory);
        expect(reporter.keys['mem_footprint_mb'], 'unavailable');
        expect(jsonDecode(reporter.keys['mem_native']! as String), {
          'status': 'failed',
        });
        expect(reporter.keys.toString(), isNot(contains('private@')));
      },
    );

    test('disposal suppresses late completion and further sampling', () async {
      final native = Completer<NativePlaybackDiagnostics?>();
      final reporter = _Reporter();
      var reads = 0;
      final service = PlaybackMemoryTelemetryService(
        readNative: () {
          reads++;
          return native.future;
        },
        reporter: reporter,
        log: (_) {},
        isForeground: () => true,
        elapsed: () => Duration.zero,
      );
      final pending = service.sample(_memory);
      service.dispose();
      native.complete(_native());
      await pending;
      await service.sample(_memory);
      service.onLifecycleChanged('resumed');
      expect(reads, 1);
      expect(reporter.keys, isEmpty);
      expect(reporter.breadcrumbs, isEmpty);
    });

    test(
      'reporter failures cannot escape into application error handling',
      () async {
        final reporter = _Reporter()..fail = true;
        final logs = <String>[];
        final service = PlaybackMemoryTelemetryService(
          readNative: () async => _native(),
          reporter: reporter,
          log: logs.add,
          isForeground: () => true,
          elapsed: () => Duration.zero,
        );
        await service.sample(_memory);
        expect(logs.last, contains('reporting unavailable'));
      },
    );
  });
}
