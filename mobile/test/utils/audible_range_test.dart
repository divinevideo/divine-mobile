import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/audible_range.dart';

const _blocksPerSecond = 200;

/// The linear peak of a block at [dbfs].
double _peak(double dbfs) => math.pow(10, dbfs / 20).toDouble();

/// Block peaks of [seconds] seconds, all at [dbfs] except the stretches in
/// [loud], given in seconds, which peak at [loudDbfs].
Float32List _peaks(
  double seconds, {
  double dbfs = double.negativeInfinity,
  List<(double, double)> loud = const [],
  double loudDbfs = -6,
}) {
  final peaks = Float32List((seconds * _blocksPerSecond).round());
  for (var block = 0; block < peaks.length; block++) {
    final at = block / _blocksPerSecond;
    final isLoud = loud.any((range) => at >= range.$1 && at < range.$2);
    peaks[block] = isLoud ? _peak(loudDbfs) : _peak(dbfs);
  }
  return peaks;
}

Duration _seconds(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

AudibleRange? _rangeOf(List<Float32List> channels, double seconds) =>
    audibleRange(
      channels: channels,
      blocksPerSecond: _blocksPerSecond,
      duration: _seconds(seconds),
    );

void main() {
  group('audibleRange', () {
    test('finds nothing audible in digital silence', () {
      expect(_rangeOf([_peaks(4), _peaks(4)], 4), isNull);
    });

    test('finds nothing audible in noise just under the threshold', () {
      final peaks = _peaks(4, dbfs: soundSilenceThresholdDbfs - 1);

      expect(_rangeOf([peaks], 4), isNull);
    });

    test('counts a single 5 ms block as audible', () {
      final peaks = _peaks(
        4,
        loud: [(1, 1.005)],
        loudDbfs: soundSilenceThresholdDbfs,
      );

      expect(_rangeOf([peaks], 4), isNotNull);
    });

    test('keeps a quiet stretch well above the threshold', () {
      final peaks = _peaks(4, dbfs: soundSilenceThresholdDbfs + 10);

      expect(
        _rangeOf([peaks], 4),
        AudibleRange(start: Duration.zero, end: _seconds(4)),
      );
    });

    test('keeps the edge margin around the audible part', () {
      final peaks = _peaks(10, loud: [(2, 5)]);

      expect(
        _rangeOf([peaks], 10),
        AudibleRange(
          start: _seconds(2) - soundEdgeMargin,
          end: _seconds(5) + soundEdgeMargin,
        ),
      );
    });

    test('spans from the first to the last audible moment', () {
      final peaks = _peaks(10, loud: [(1, 2), (7, 8)]);

      final range = _rangeOf([peaks], 10)!;

      expect(range.start, _seconds(1) - soundEdgeMargin);
      expect(range.end, _seconds(8) + soundEdgeMargin);
    });

    test('keeps the whole sound when it is audible from edge to edge', () {
      final peaks = _peaks(3, loud: [(0, 3)]);

      expect(
        _rangeOf([peaks], 3),
        AudibleRange(start: Duration.zero, end: _seconds(3)),
      );
    });

    test('clamps the margin to the edges of the sound', () {
      final peaks = _peaks(3, loud: [(0.1, 2.9)]);

      expect(
        _rangeOf([peaks], 3),
        AudibleRange(start: Duration.zero, end: _seconds(3)),
      );
    });

    test('counts a sound heard on one channel only', () {
      final range = _rangeOf([
        _peaks(6),
        _peaks(6, loud: const [(3, 4)]),
      ], 6);

      expect(
        range,
        AudibleRange(
          start: _seconds(3) - soundEdgeMargin,
          end: _seconds(4) + soundEdgeMargin,
        ),
      );
    });

    test('measures the kept part', () {
      final range = _rangeOf([
        _peaks(10, loud: [(2, 5)]),
      ], 10)!;

      expect(range.duration, _seconds(3) + soundEdgeMargin * 2);
    });

    test('rejects a measurement without a block rate', () {
      expect(
        () => audibleRange(
          channels: [_peaks(1)],
          blocksPerSecond: 0,
          duration: _seconds(1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a measurement without a length', () {
      expect(
        () => audibleRange(
          channels: [_peaks(1)],
          blocksPerSecond: _blocksPerSecond,
          duration: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}
